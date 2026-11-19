unit VSoft.YAML.Parser.JSON;

interface

{$I 'VSoft.YAML.inc'}

uses
  System.SysUtils,
  System.Classes,
  VSoft.YAML,
  VSoft.YAML.IO,
  VSoft.YAML.Utils;

type
  /// <summary>
  ///  Reads strict JSON (RFC 8259) or JSON5 (https://spec.json5.org/, 1.0.0) into a document.
  ///  A recursive descent parser working straight on the input reader's window - there is no
  ///  lexer and there are no tokens - that builds the same value classes as the YAML parser.
  ///  Number text is kept as written (0x1F, +1, .5, Infinity), so it can be written back
  ///  unchanged.
  ///
  ///  JSON5 comments are kept: comments on the lines before a value go to its Comments (for
  ///  an object member, those before its key too), comments that start on the line where a
  ///  value ends - before or after its comma - to its Comment, comments left before a closing
  ///  bracket to that collection's EndComments and comments after the root value to the
  ///  document's EndComments. The // or /* */ is dropped along with the whitespace after //;
  ///  a block comment is trimmed and kept one entry per line.
  /// </summary>
  TJSONParserImpl = class
  private
    FReaderRef : IInputReader; // holds the reader's lifetime
    FReader : TBufferedInputReader;
    FText : PChar;   // FText[i] is the reader's Buffer[i] - the window, 1-based
    FLen : integer;  // chars in the window
    FPos : integer;  // window index of the current char; FLen + 1 at the end of the window
    FJSON5 : boolean;
    FDuplicateError : boolean;
    FLine : integer;
    FLineStart : integer;    // absolute index of the first char of the current line
    FDepth : integer;
    FScratch : string;       // decoded text of a string or key with escapes
    FScratchLen : integer;
    FComments : TStringList; // JSON5 comments not yet attached; Objects[i] is the start line
    FInterner : TYAMLStringInterner;
    FKeyIntern : TInternState;
    FValueIntern : TInternState;

    procedure RaiseError(const msg : string);overload;{$IFDEF NORETURN}noreturn;{$ENDIF}
    procedure RaiseError(const fmt : string; const args : array of const);overload;{$IFDEF NORETURN}noreturn;{$ENDIF}
    function DialectName : string;

    // window access
    function FillWindow(var p : integer) : boolean;
    function CharAt(var p : integer) : Char;inline;
    function CharAtSlow(var p : integer) : Char;
    function CurChar : Char;inline;
    function AtEnd : boolean;
    procedure NewLineAt(p : integer);inline;

    procedure ScratchAppend(p : PChar; count : integer);
    procedure ScratchAppendChar(ch : Char);

    // whitespace and comments
    procedure SkipWhitespace;
    procedure ReadComment;
    procedure AddComment(const text : string; line : integer);
    procedure AddBlockComment(const text : string; line : integer);
    procedure TakeLeadingComments(const value : IYAMLValue);
    procedure TakeSameLineComments(const value : IYAMLValue; line : integer);
    procedure TakeEndComments(const collection : IYAMLCollection);

    // strings and keys
    procedure ScanString(quote : Char; out text : PChar; out len : integer);
    procedure ReadEscape;
    function ReadHex(digits : integer) : integer;
    procedure ScanIdentifier(out text : PChar; out len : integer);

    // values
    function ParseValue(const parent : IYAMLValue) : IYAMLValue;
    function ParseObject(const parent : IYAMLValue) : IYAMLValue;
    function ParseArray(const parent : IYAMLValue) : IYAMLValue;
    function ParseNumber(const parent : IYAMLValue) : IYAMLValue;
    function ParseLiteral(const parent : IYAMLValue; const word : string; valueType : TYAMLValueType) : IYAMLValue;
    procedure EnterCollection;inline;
  public
    /// <summary> json5 selects JSON5; otherwise strict JSON is read. </summary>
    constructor Create(const reader : IInputReader; const options : IYAMLParserOptions; json5 : boolean);
    destructor Destroy;override;

    function Parse : IYAMLDocument;
  end;

implementation

uses
  System.Generics.Collections,
  VSoft.YAML.Classes;

const
  // Objects and arrays nested deeper than this are an error rather than a stack overflow.
  cMaxNestingDepth = 1000;

// True when ch would run a number or literal on into a name - an identifier char or the
// '\' of an escape. ASCII is tested inline; anything else by its Unicode category.
function RunsOnIntoName(ch : Char) : boolean;inline;
begin
  if Ord(ch) < 128 then
    result := CharInSet(ch, ['a'..'z', 'A'..'Z', '0'..'9', '$', '_', '\'])
  else
    result := TJSON5CharUtils.IsIdentifierPart(ch);
end;

{ TJSONParserImpl }

constructor TJSONParserImpl.Create(const reader : IInputReader; const options : IYAMLParserOptions; json5 : boolean);
var
  obj : TObject;
  sb : TStringBuilder;
begin
  inherited Create;
  obj := reader as TObject;
  if obj is TBufferedInputReader then
    FReaderRef := reader
  else
  begin
    // Some other reader implementation: drain what is left of it into a string reader.
    sb := TStringBuilder.Create;
    try
      while not reader.IsEOF do
        sb.Append(reader.Read);
      FReaderRef := TInputReaderFactory.CreateFromString(sb.ToString);
    finally
      sb.Free;
    end;
  end;
  FReader := FReaderRef as TObject as TBufferedInputReader;
  FJSON5 := json5;
  FDuplicateError := (options <> nil) and (options.DuplicateKeyBehavior = TYAMLDuplicateKeyBehavior.dkError);

  FText := PChar(Pointer(FReader.Buffer)) - 1;
  FLen := FReader.BufferLength;
  FPos := FReader.BufferPosition;
  if FPos < 1 then // empty input
    FPos := 1;
  FLine := 1;
  FLineStart := FReader.BufferBase + FPos;
end;

destructor TJSONParserImpl.Destroy;
begin
  FComments.Free;
  inherited;
end;

procedure TJSONParserImpl.RaiseError(const msg : string);
begin
  raise EYAMLParseException.Create(msg, FLine, FReader.BufferBase + FPos - FLineStart + 1);
end;

procedure TJSONParserImpl.RaiseError(const fmt : string; const args : array of const);
begin
  RaiseError(Format(fmt, args));
end;

function TJSONParserImpl.DialectName : string;
begin
  if FJSON5 then
    result := 'JSON5'
  else
    result := 'JSON';
end;

// Appends the next block of input to the window. p is the caller's scan index; it and FPos
// (a token start or the committed position, which the reader always keeps) move down by
// whatever the reader drops from the front of the window.
function TJSONParserImpl.FillWindow(var p : integer) : boolean;
var
  oldBase : integer;
begin
  oldBase := FReader.BufferBase;
  result := FReader.FillBuffer(p);
  if result then
  begin
    Dec(FPos, FReader.BufferBase - oldBase);
    FText := PChar(Pointer(FReader.Buffer)) - 1;
    FLen := FReader.BufferLength;
  end;
end;

// The char at scan index p, refilling the window when p is past it (p and FPos are moved
// down by whatever the refill drops). #0 at the end of the input - which callers tell apart
// from an actual #0 char by p > FLen.
function TJSONParserImpl.CharAt(var p : integer) : Char;
begin
  if p <= FLen then
    result := FText[p]
  else
    result := CharAtSlow(p);
end;

function TJSONParserImpl.CharAtSlow(var p : integer) : Char;
begin
  while p > FLen do
  begin
    if not FillWindow(p) then
      exit(#0);
  end;
  result := FText[p];
end;

function TJSONParserImpl.CurChar : Char;
var
  p : integer;
begin
  if FPos <= FLen then
    result := FText[FPos]
  else
  begin
    p := FPos;
    result := CharAtSlow(p); // FillWindow moves FPos along with p
  end;
end;

function TJSONParserImpl.AtEnd : boolean;
begin
  result := (CurChar = #0) and (FPos > FLen);
end;

procedure TJSONParserImpl.NewLineAt(p : integer);
begin
  Inc(FLine);
  FLineStart := FReader.BufferBase + p;
end;

procedure TJSONParserImpl.ScratchAppend(p : PChar; count : integer);
begin
  if count <= 0 then
    exit;
  if FScratchLen + count > Length(FScratch) then
    SetLength(FScratch, (FScratchLen + count) * 2);
  Move(p^, PChar(Pointer(FScratch))[FScratchLen], count * SizeOf(Char));
  Inc(FScratchLen, count);
end;

procedure TJSONParserImpl.ScratchAppendChar(ch : Char);
begin
  if FScratchLen >= Length(FScratch) then
    SetLength(FScratch, (FScratchLen + 1) * 2);
  PChar(Pointer(FScratch))[FScratchLen] := ch;
  Inc(FScratchLen);
end;

{ whitespace and comments }

// Skips whitespace - and in JSON5, comments, which are kept for the next value - leaving
// FPos on the next char (past the window at the end of the input).
procedure TJSONParserImpl.SkipWhitespace;
var
  p : integer;
  ch : Char;
begin
  p := FPos;
  while true do
  begin
    if p > FLen then
    begin
      if not FillWindow(p) then
        break;
    end;
    ch := FText[p];
    case ch of
      ' ', #9 :
        Inc(p);
      #10 :
      begin
        Inc(p);
        NewLineAt(p);
      end;
      #13 :
      begin
        Inc(p);
        if CharAt(p) <> #10 then // a CR LF pair counts at the LF
          NewLineAt(p);
      end;
    else
      if not FJSON5 then
        break;
      case ch of
        // JSON5 WhiteSpace beyond JSON's: VT, FF, NBSP, BOM and the other Zs characters
        #11, #12, #$00A0, #$FEFF, #$1680, #$2000..#$200A, #$202F, #$205F, #$3000 :
          Inc(p);
        #$2028, #$2029 :
        begin
          Inc(p);
          NewLineAt(p);
        end;
        '/' :
        begin
          FPos := p;
          ReadComment;
          p := FPos;
        end;
      else
        break;
      end;
    end;
  end;
  FPos := p;
end;

// FPos is on a '/' (JSON5). Reads a // or /* */ comment into the pending comments.
procedure TJSONParserImpl.ReadComment;
var
  p, startAbs, startLine : integer;
  ch : Char;
  blockText : string;
begin
  startLine := FLine;
  p := FPos + 1;
  ch := CharAt(p);
  if ch = '/' then
  begin
    Inc(p);
    while true do
    begin
      ch := CharAt(p);
      if (ch <> ' ') and (ch <> #9) then
        break;
      Inc(p);
    end;
    FPos := p;
    FReader.MarkAt(p);
    startAbs := FReader.BufferBase + p;
    while true do
    begin
      ch := CharAt(p);
      if (ch = #10) or (ch = #13) or (ch = #$2028) or (ch = #$2029) then
        break;
      if (ch = #0) and (p > FLen) then
        break;
      Inc(p);
    end;
    AddComment(FReader.CopyText(startAbs, FReader.BufferBase + p - startAbs), startLine);
    FPos := p;
  end
  else if ch = '*' then
  begin
    Inc(p);
    FPos := p;
    FReader.MarkAt(p);
    startAbs := FReader.BufferBase + p;
    while true do
    begin
      ch := CharAt(p);
      case ch of
        '*' :
        begin
          Inc(p);
          if CharAt(p) = '/' then
          begin
            // the text runs up to the '*'
            blockText := FReader.CopyText(startAbs, FReader.BufferBase + p - 1 - startAbs);
            Inc(p);
            break;
          end;
        end;
        #10, #$2028, #$2029 :
        begin
          Inc(p);
          NewLineAt(p);
        end;
        #13 :
        begin
          Inc(p);
          if CharAt(p) <> #10 then
            NewLineAt(p);
        end;
        #0 :
        begin
          if p > FLen then
          begin
            FPos := p;
            RaiseError('Unterminated comment - "/*" has no closing "*/"');
          end;
          Inc(p);
        end;
      else
        Inc(p);
      end;
    end;
    AddBlockComment(blockText, startLine);
    FPos := p;
  end
  else
    RaiseError('Unexpected character "/" - a comment starts with // or /*');
end;

procedure TJSONParserImpl.AddComment(const text : string; line : integer);
begin
  if FComments = nil then
    FComments := TStringList.Create;
  FComments.AddObject(text, TObject(NativeInt(line)));
end;

// A block comment is kept one trimmed entry per line, without the blank lines at its start
// and end (an empty one as a single empty entry), so it can be written as // or # lines.
procedure TJSONParserImpl.AddBlockComment(const text : string; line : integer);
var
  lines : TStringList;
  i, len, start, first, last : integer;
  ch : Char;
begin
  lines := TStringList.Create;
  try
    len := Length(text);
    start := 1;
    i := 1;
    while i <= len do
    begin
      ch := text[i];
      if (ch = #10) or (ch = #13) or (ch = #$2028) or (ch = #$2029) then
      begin
        lines.Add(Trim(Copy(text, start, i - start)));
        if (ch = #13) and (i < len) and (text[i + 1] = #10) then
          Inc(i);
        start := i + 1;
      end;
      Inc(i);
    end;
    lines.Add(Trim(Copy(text, start, len - start + 1)));
    first := 0;
    last := lines.Count - 1;
    while (first < last) and (lines[first] = '') do
      Inc(first);
    while (last > first) and (lines[last] = '') do
      Dec(last);
    for i := first to last do
      AddComment(lines[i], line);
  finally
    lines.Free;
  end;
end;

procedure TJSONParserImpl.TakeLeadingComments(const value : IYAMLValue);
var
  i : integer;
begin
  if FComments.Count = 0 then
    exit;
  for i := 0 to FComments.Count - 1 do
    value.AddComment(FComments[i]);
  FComments.Clear;
end;

// The pending comments that start on line - where value ended - become its Comment.
procedure TJSONParserImpl.TakeSameLineComments(const value : IYAMLValue; line : integer);
var
  n, i : integer;
  text : string;
begin
  n := 0;
  while (n < FComments.Count) and (NativeInt(FComments.Objects[n]) = line) do
    Inc(n);
  if n = 0 then
    exit;
  text := value.Comment;
  for i := 0 to n - 1 do
  begin
    if (text <> '') and (FComments[i] <> '') then
      text := text + ' ';
    text := text + FComments[i];
  end;
  value.Comment := text;
  for i := n - 1 downto 0 do
    FComments.Delete(i);
end;

procedure TJSONParserImpl.TakeEndComments(const collection : IYAMLCollection);
var
  i : integer;
begin
  if FComments.Count = 0 then
    exit;
  for i := 0 to FComments.Count - 1 do
    collection.AddEndComment(FComments[i]);
  FComments.Clear;
end;

{ strings and keys }

// FPos is on the opening quote. Leaves FPos after the closing quote, with text and len the
// content: in the window when there were no escapes (valid until the window is next
// refilled), otherwise in FScratch.
procedure TJSONParserImpl.ScanString(quote : Char; out text : PChar; out len : integer);
var
  p, runStartAbs : integer;
  ch : Char;
  escaped : boolean;
begin
  Inc(FPos);
  FReader.MarkAt(FPos);
  runStartAbs := FReader.BufferBase + FPos;
  escaped := false;
  p := FPos;
  while true do
  begin
    // the run of chars that need no handling
    ch := #0;
    if FJSON5 then
    begin
      while p <= FLen do
      begin
        ch := FText[p];
        if (ch = quote) or (ch = '\') or (ch = #10) or (ch = #13) then
          break;
        Inc(p);
      end;
    end
    else
    begin
      while p <= FLen do
      begin
        ch := FText[p];
        if (ch = '"') or (ch = '\') or (ch < ' ') then
          break;
        Inc(p);
      end;
    end;
    if p > FLen then
    begin
      if not FillWindow(p) then
      begin
        FPos := p;
        RaiseError('Unterminated string - the closing quote is missing');
      end;
      continue;
    end;

    if ch = quote then
    begin
      if escaped then
      begin
        ScratchAppend(@FText[runStartAbs - FReader.BufferBase], FReader.BufferBase + p - runStartAbs);
        text := PChar(Pointer(FScratch));
        len := FScratchLen;
      end
      else
      begin
        text := @FText[runStartAbs - FReader.BufferBase];
        len := FReader.BufferBase + p - runStartAbs;
      end;
      FPos := p + 1;
      exit;
    end;

    if ch = '\' then
    begin
      if not escaped then
      begin
        escaped := true;
        FScratchLen := 0;
      end;
      ScratchAppend(@FText[runStartAbs - FReader.BufferBase], FReader.BufferBase + p - runStartAbs);
      FPos := p + 1;
      ReadEscape;
      // the text so far is in FScratch, so the window need not keep it
      p := FPos;
      FReader.MarkAt(p);
      runStartAbs := FReader.BufferBase + p;
      continue;
    end;

    FPos := p;
    if FJSON5 then
      RaiseError('Unescaped line break in string - use \n, or end the line with \ to continue the string on the next')
    else
      RaiseError('Invalid control character (#%d) in string - JSON requires it to be escaped', [Ord(ch)]);
  end;
end;

// FPos is after a backslash in a string. Appends what the escape stands for to FScratch.
procedure TJSONParserImpl.ReadEscape;
var
  ch : Char;
begin
  ch := CurChar;
  if (ch = #0) and (FPos > FLen) then
    RaiseError('Unterminated string - the closing quote is missing');
  Inc(FPos);
  case ch of
    '"' : ScratchAppendChar('"');
    '\' : ScratchAppendChar('\');
    '/' : ScratchAppendChar('/');
    'b' : ScratchAppendChar(#8);
    'f' : ScratchAppendChar(#12);
    'n' : ScratchAppendChar(#10);
    'r' : ScratchAppendChar(#13);
    't' : ScratchAppendChar(#9);
    'u' : ScratchAppendChar(Char(ReadHex(4)));
  else
    if not FJSON5 then
    begin
      Dec(FPos, 2);
      RaiseError('Invalid escape sequence "\%s" in string - JSON allows \" \\ \/ \b \f \n \r \t and \uXXXX', [ch]);
    end;
    case ch of
      'v' : ScratchAppendChar(#11);
      '0' :
      begin
        ch := CurChar;
        if (ch >= '0') and (ch <= '9') then
          RaiseError('"\0" must not be followed by a digit - use \x00 or \u0000');
        ScratchAppendChar(#0);
      end;
      '1'..'9' :
      begin
        Dec(FPos, 2);
        RaiseError('Invalid escape sequence "\%s" - JSON5 has no octal escapes', [ch]);
      end;
      'x' : ScratchAppendChar(Char(ReadHex(2)));
      #10, #$2028, #$2029 :
        NewLineAt(FPos); // line continuation - the backslash and line break are dropped
      #13 :
      begin
        if CurChar = #10 then
          Inc(FPos);
        NewLineAt(FPos);
      end;
    else
      ScratchAppendChar(ch); // any other char escapes to itself
    end;
  end;
end;

function HexDigitValue(ch : Char) : integer;inline;
begin
  case ch of
    '0'..'9' : result := Ord(ch) - Ord('0');
    'a'..'f' : result := Ord(ch) - Ord('a') + 10;
    'A'..'F' : result := Ord(ch) - Ord('A') + 10;
  else
    result := -1;
  end;
end;

function TJSONParserImpl.ReadHex(digits : integer) : integer;
var
  i, digit : integer;
begin
  result := 0;
  for i := 1 to digits do
  begin
    digit := HexDigitValue(CurChar);
    if digit < 0 then
      RaiseError('Invalid escape sequence - %d hex digits were expected', [digits]);
    result := result * 16 + digit;
    Inc(FPos);
  end;
end;

// JSON5: FPos is on what should start an unquoted property name - an ES5 IdentifierName,
// which may contain \uXXXX escapes. Leaves FPos after it; text and len as for ScanString.
procedure TJSONParserImpl.ScanIdentifier(out text : PChar; out len : integer);
var
  p, q, startAbs : integer;
  ch, low : Char;
  first, escaped, ok : boolean;
begin
  startAbs := FReader.BufferBase + FPos;
  p := FPos;
  first := true;
  escaped := false;
  ch := CharAt(p);

  // the usual case: a plain ASCII name ending in the window
  if CharInSet(ch, ['a'..'z', 'A'..'Z', '$', '_']) then
  begin
    Inc(p);
    while p <= FLen do
    begin
      ch := FText[p];
      if not CharInSet(ch, ['a'..'z', 'A'..'Z', '0'..'9', '$', '_']) then
        break;
      Inc(p);
    end;
    if (p <= FLen) and (Ord(ch) < 128) and (ch <> '\') then
    begin
      text := @FText[startAbs - FReader.BufferBase];
      len := FReader.BufferBase + p - startAbs;
      FPos := p;
      exit;
    end;
    // otherwise carry on below, from the char that stopped the run
    first := false;
    ch := CharAt(p);
  end;

  while true do
  begin
    if Ord(ch) < 128 then
    begin
      if CharInSet(ch, ['a'..'z', 'A'..'Z', '$', '_']) or ((not first) and (ch >= '0') and (ch <= '9')) then
      begin
        if escaped then
          ScratchAppendChar(ch);
        Inc(p);
      end
      else if ch = '\' then
      begin
        if not escaped then
        begin
          escaped := true;
          FScratchLen := 0;
          ScratchAppend(@FText[startAbs - FReader.BufferBase], FReader.BufferBase + p - startAbs);
        end;
        Inc(p);
        if CharAt(p) <> 'u' then
        begin
          FPos := p;
          RaiseError('Invalid escape in property name - only \uXXXX is allowed');
        end;
        FPos := p + 1;
        ch := Char(ReadHex(4));
        p := FPos;
        if first then
          ok := TJSON5CharUtils.IsIdentifierStart(ch)
        else
          ok := TJSON5CharUtils.IsIdentifierPart(ch);
        if not ok then
          RaiseError('The escape \u%.4x is not a valid property name character', [Ord(ch)]);
        ScratchAppendChar(ch);
      end
      else
        break;
    end
    else if (ch >= #$D800) and (ch <= #$DBFF) then
    begin
      // a character outside the BMP, as a surrogate pair
      q := p + 1;
      low := CharAt(q);
      p := q - 1;
      if (low < #$DC00) or (low > #$DFFF) then
        break;
      if first then
        ok := TJSON5CharUtils.IsIdentifierStartPair(ch, low)
      else
        ok := TJSON5CharUtils.IsIdentifierPartPair(ch, low);
      if not ok then
        break;
      if escaped then
      begin
        ScratchAppendChar(ch);
        ScratchAppendChar(low);
      end;
      Inc(p, 2);
    end
    else
    begin
      if first then
        ok := TJSON5CharUtils.IsIdentifierStart(ch)
      else
        ok := TJSON5CharUtils.IsIdentifierPart(ch);
      if not ok then
        break;
      if escaped then
        ScratchAppendChar(ch);
      Inc(p);
    end;
    first := false;
    ch := CharAt(p);
  end;

  if first then
  begin
    FPos := p;
    if (ch = #0) and (p > FLen) then
      RaiseError('Unexpected end of input in object - "}" is missing')
    else if (ch >= '0') and (ch <= '9') then
      RaiseError('A property name cannot start with a digit - quote it')
    else
      RaiseError('Expected a property name but found "%s"', [ch]);
  end;

  if escaped then
  begin
    text := PChar(Pointer(FScratch));
    len := FScratchLen;
  end
  else
  begin
    text := @FText[startAbs - FReader.BufferBase];
    len := FReader.BufferBase + p - startAbs;
  end;
  FPos := p;
end;

{ values }

procedure TJSONParserImpl.EnterCollection;
begin
  Inc(FDepth);
  if FDepth > cMaxNestingDepth then
    RaiseError('Objects and arrays are nested more than %d deep', [cMaxNestingDepth]);
end;

function TJSONParserImpl.ParseValue(const parent : IYAMLValue) : IYAMLValue;
var
  ch : Char;
  text : PChar;
  len : integer;
begin
  ch := CurChar;
  FReader.MarkAt(FPos); // nothing before the value is needed again
  case ch of
    '{' :
      exit(ParseObject(parent));
    '[' :
      exit(ParseArray(parent));
    '"' :
    begin
      ScanString('"', text, len);
      result := TYAMLValue.Create(parent, TYAMLValueType.vtString, FInterner.InternChars(text, len, FValueIntern));
    end;
    '''' :
    begin
      if not FJSON5 then
        RaiseError('Strings must be enclosed in double quotes in JSON');
      ScanString('''', text, len);
      result := TYAMLValue.Create(parent, TYAMLValueType.vtString, FInterner.InternChars(text, len, FValueIntern));
    end;
    't' :
      result := ParseLiteral(parent, 'true', TYAMLValueType.vtBoolean);
    'f' :
      result := ParseLiteral(parent, 'false', TYAMLValueType.vtBoolean);
    'n' :
      result := ParseLiteral(parent, 'null', TYAMLValueType.vtNull);
    '-', '0'..'9' :
      result := ParseNumber(parent);
    '+', '.', 'I', 'N' :
    begin
      if not FJSON5 then
        RaiseError('Unexpected character "%s" - JSON numbers start with "-" or a digit (no "+", ".", Infinity or NaN)', [ch]);
      result := ParseNumber(parent);
    end;
  else
    if (ch = #0) and (FPos > FLen) then
      RaiseError('Unexpected end of input - a value was expected');
    if (ch = '/') and not FJSON5 then
      RaiseError('Comments are not allowed in JSON');
    RaiseError('Unexpected character "%s" - a %s value was expected', [ch, DialectName]);
  end;
  if FComments <> nil then
    TakeLeadingComments(result);
end;

function TJSONParserImpl.ParseLiteral(const parent : IYAMLValue; const word : string; valueType : TYAMLValueType) : IYAMLValue;
var
  p, i : integer;
begin
  p := FPos;
  for i := 1 to Length(word) do
  begin
    if CharAt(p) <> word[i] then
      RaiseError('Invalid literal - "%s" was expected', [word]);
    Inc(p);
  end;
  if RunsOnIntoName(CharAt(p)) then
    RaiseError('Invalid literal - "%s" was expected', [word]);
  FPos := p;
  result := TYAMLValue.Create(parent, valueType, word);
end;

// The number's text is kept exactly as written. JSON5 also allows a leading +, Infinity,
// NaN, 0x hex and a '.' with digits on one side only.
function TJSONParserImpl.ParseNumber(const parent : IYAMLValue) : IYAMLValue;
var
  p, startAbs, digits : integer;
  ch : Char;
  isFloat, isHex, hasIntPart : boolean;
  word : string;
  i : integer;
  numberText : string;
begin
  startAbs := FReader.BufferBase + FPos;
  p := FPos;
  isFloat := false;
  ch := CharAt(p);
  if (ch = '-') or ((ch = '+') and FJSON5) then
  begin
    Inc(p);
    ch := CharAt(p);
  end;

  if FJSON5 and ((ch = 'I') or (ch = 'N')) then
  begin
    if ch = 'I' then
      word := 'Infinity'
    else
      word := 'NaN';
    for i := 1 to Length(word) do
    begin
      if CharAt(p) <> word[i] then
      begin
        FPos := p;
        RaiseError('Invalid number - "%s" was expected', [word]);
      end;
      Inc(p);
    end;
    isFloat := true;
  end
  else
  begin
    isHex := false;
    hasIntPart := (ch >= '0') and (ch <= '9');
    if hasIntPart then
    begin
      Inc(p);
      if ch = '0' then
      begin
        ch := CharAt(p);
        if FJSON5 and ((ch = 'x') or (ch = 'X')) then
        begin
          // hex integer
          isHex := true;
          Inc(p);
          digits := 0;
          while CharInSet(CharAt(p), ['0'..'9', 'a'..'f', 'A'..'F']) do
          begin
            Inc(p);
            Inc(digits);
          end;
          if digits = 0 then
          begin
            FPos := p;
            RaiseError('Invalid number - "0x" must be followed by hex digits');
          end;
        end
        else if (ch >= '0') and (ch <= '9') then
        begin
          FPos := p;
          RaiseError('Invalid number - leading zeros are not allowed in %s', [DialectName]);
        end;
      end
      else
      begin
        while true do
        begin
          ch := CharAt(p);
          if (ch < '0') or (ch > '9') then
            break;
          Inc(p);
        end;
      end;
    end
    else if not (FJSON5 and (ch = '.')) then
    begin
      FPos := p;
      RaiseError('Invalid number - a digit was expected');
    end;

    if not isHex then
    begin
      ch := CharAt(p);
      if ch = '.' then
      begin
        Inc(p);
        digits := 0;
        while true do
        begin
          ch := CharAt(p);
          if (ch < '0') or (ch > '9') then
            break;
          Inc(p);
          Inc(digits);
        end;
        if (digits = 0) and ((not FJSON5) or (not hasIntPart)) then
        begin
          FPos := p;
          RaiseError('Invalid number - a digit was expected after "."');
        end;
        isFloat := true;
      end;
      if (ch = 'e') or (ch = 'E') then
      begin
        Inc(p);
        ch := CharAt(p);
        if (ch = '+') or (ch = '-') then
          Inc(p);
        digits := 0;
        while true do
        begin
          ch := CharAt(p);
          if (ch < '0') or (ch > '9') then
            break;
          Inc(p);
          Inc(digits);
        end;
        if digits = 0 then
        begin
          FPos := p;
          RaiseError('Invalid number - the exponent has no digits');
        end;
        isFloat := true;
      end;
    end;
  end;

  if FJSON5 then
  begin
    // a number must not run straight on into an identifier or another digit
    ch := CharAt(p);
    if RunsOnIntoName(ch) then
    begin
      FPos := p;
      RaiseError('Invalid character "%s" after a number', [ch]);
    end;
  end;

  numberText := FInterner.InternChars(@FText[startAbs - FReader.BufferBase], FReader.BufferBase + p - startAbs, FValueIntern);
  FPos := p;
  if isFloat then
    result := TYAMLValue.Create(parent, TYAMLValueType.vtFloat, numberText)
  else
    result := TYAMLValue.Create(parent, TYAMLValueType.vtInteger, numberText);
end;

function TJSONParserImpl.ParseArray(const parent : IYAMLValue) : IYAMLValue;
var
  sequence : IYAMLSequence;
  item : IYAMLValue;
  ch : Char;
  endLine : integer;
begin
  sequence := TYAMLSequence.Create(parent, '');
  result := sequence;
  if FComments <> nil then
    TakeLeadingComments(result);
  EnterCollection;
  Inc(FPos); // '['
  SkipWhitespace;
  ch := CurChar;
  if ch <> ']' then
  begin
    while true do
    begin
      if ch = ',' then
        RaiseError('Missing array element - a value was expected before ","');
      item := ParseValue(result);
      sequence.AddValue(item);
      endLine := FLine;
      SkipWhitespace;
      if FComments <> nil then
        TakeSameLineComments(item, endLine);
      ch := CurChar;
      if ch = ',' then
      begin
        Inc(FPos);
        SkipWhitespace;
        if FComments <> nil then
          TakeSameLineComments(item, endLine);
        ch := CurChar;
        if ch = ']' then
        begin
          if not FJSON5 then
            RaiseError('Trailing comma - JSON does not allow a "," before "]"');
          break;
        end;
      end
      else if ch = ']' then
        break
      else if (ch = #0) and (FPos > FLen) then
        RaiseError('Unexpected end of input in array - "]" is missing')
      else
        RaiseError('Expected "," or "]" in array but found "%s"', [ch]);
    end;
  end;
  if FComments <> nil then
    TakeEndComments(sequence);
  Inc(FPos); // ']'
  Dec(FDepth);
end;

function TJSONParserImpl.ParseObject(const parent : IYAMLValue) : IYAMLValue;
var
  mappingObj : TYAMLMapping;
  mapping : IYAMLMapping;
  mappingPriv : IYAMLMappingPrivate;
  key : string;
  value : IYAMLValue;
  ch : Char;
  text : PChar;
  len, endLine : integer;
begin
  // the class reference gives both interfaces without a QueryInterface
  mappingObj := TYAMLMapping.Create(parent, '');
  mapping := mappingObj;
  mappingPriv := mappingObj;
  result := mapping;
  if FComments <> nil then
    TakeLeadingComments(result);
  EnterCollection;
  Inc(FPos); // '{'
  SkipWhitespace;
  ch := CurChar;
  if ch <> '}' then
  begin
    while true do
    begin
      // the key
      FReader.MarkAt(FPos);
      case ch of
        '"' :
          ScanString('"', text, len);
        '''' :
        begin
          if not FJSON5 then
            RaiseError('Object keys must be strings in double quotes in JSON');
          ScanString('''', text, len);
        end;
        ',' :
          RaiseError('Missing object member - a property name was expected before ","');
      else
        if not FJSON5 then
        begin
          if (ch = #0) and (FPos > FLen) then
            RaiseError('Unexpected end of input in object - "}" is missing');
          RaiseError('Object keys must be strings in double quotes in JSON');
        end;
        ScanIdentifier(text, len);
      end;
      key := FInterner.InternChars(text, len, FKeyIntern);
      if FDuplicateError and mapping.ContainsKey(key) then
        RaiseError('duplicated mapping key : "%s"', [key]);

      SkipWhitespace;
      if CurChar <> ':' then
      begin
        if AtEnd then
          RaiseError('Unexpected end of input in object - "}" is missing');
        RaiseError('Expected ":" after the property name "%s"', [key]);
      end;
      Inc(FPos);
      SkipWhitespace;
      value := ParseValue(result);
      mappingPriv.AddOrSetValue(key, value);

      endLine := FLine;
      SkipWhitespace;
      if FComments <> nil then
        TakeSameLineComments(value, endLine);
      ch := CurChar;
      if ch = ',' then
      begin
        Inc(FPos);
        SkipWhitespace;
        if FComments <> nil then
          TakeSameLineComments(value, endLine);
        ch := CurChar;
        if ch = '}' then
        begin
          if not FJSON5 then
            RaiseError('Trailing comma - JSON does not allow a "," before "}"');
          break;
        end;
      end
      else if ch = '}' then
        break
      else if (ch = #0) and (FPos > FLen) then
        RaiseError('Unexpected end of input in object - "}" is missing')
      else
        RaiseError('Expected "," or "}" in object but found "%s"', [ch]);
    end;
  end;
  if FComments <> nil then
    TakeEndComments(mapping);
  Inc(FPos); // '}'
  Dec(FDepth);
end;

function TJSONParserImpl.Parse : IYAMLDocument;
var
  root : IYAMLValue;
  endLine, i : integer;
  directives : TList<IYAMLTagDirective>;
begin
  try
    // a byte order mark at the start of string input (a stream's is dropped as it is read)
    if CurChar = #$FEFF then
    begin
      Inc(FPos);
      FLineStart := FReader.BufferBase + FPos;
    end;
    SkipWhitespace;
    if AtEnd then
      RaiseError('The input is empty - a %s value was expected', [DialectName]);
    root := ParseValue(nil);
    endLine := FLine;
    SkipWhitespace;
    if not AtEnd then
      RaiseError('Unexpected content after the value - %s allows only one top-level value', [DialectName]);

    // the same default tag handles as the YAML parser gives a document
    directives := TList<IYAMLTagDirective>.Create;
    try
      directives.Add(TYAMLTagDirective.Create('!', '!'));
      directives.Add(TYAMLTagDirective.Create('!!', 'tag:yaml.org,2002:'));
      result := TYAMLDocument.Create(root, nil, directives);
    finally
      directives.Free;
    end;

    if (FComments <> nil) and (FComments.Count > 0) then
    begin
      TakeSameLineComments(root, endLine);
      for i := 0 to FComments.Count - 1 do
        result.AddEndComment(FComments[i]);
      FComments.Clear;
    end;
  except
    on E : EYAMLParseException do
      raise;
    on E : Exception do
      raise EYAMLParseException.Create(E.Message, FLine, FReader.BufferBase + FPos - FLineStart + 1);
  end;
end;

end.

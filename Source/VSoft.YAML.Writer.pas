unit VSoft.YAML.Writer;

interface

{$I 'VSoft.YAML.inc'}


uses
  System.SysUtils,
  System.Classes,
  VSoft.YAML.StreamWriter,
  VSoft.YAML;

type
  // Main YAML writer class
  TYAMLWriterImpl = class
  private
    FIndentLevel : UInt32;
    FIndentOffset : integer; // columns added to every level's indent - see WriteValueAtColumn
    FCurrentIndent : string;
    FIndentStrings : TArray<string>; // indent text per level, see UpdateIndentCache
    FOptions : IYAMLEmitOptions;
    FOut : TYAMLOutputBuffer;
    // scratch for FormatKey/FormatScalar quoting; lines are written straight to FOut
    FQuoteBuilder : TStringBuilder;

    // Helper methods for formatting
    procedure UpdateIndentCache;
    function NeedsQuoting(const value : string) : boolean;
    function ShouldUseDoubleQuotes(const value : string) : boolean;
    procedure EscapeString(const value : string; sb : TStringBuilder);overload;
    procedure EscapeForSingleQuotes(const value : string; sb : TStringBuilder);overload;
    function FormatKey(const key : string) : string;
    function FormatScalar(const value : IYAMLValue) : string;
    function GetFormattedTag(const value : IYAMLValue) : string;
    // the tag to write in front of value, with a space after it - '' when it has none, or
    // EmitTags is off
    function TagOf(const value : IYAMLValue) : string;
    // after 'key:', '-' or '?' on the line a collection starts: a space and its tag
    procedure WriteHeaderTag(const tag : string);
    // tag and a scalar's text, which start at column; the text is folded to MaxLineLength,
    // with continuation lines indented to contColumn
    procedure WriteScalarAt(column : integer; const tag, text : string; contColumn : integer);
    procedure WriteFoldedText(const text : string; startColumn, contColumn : integer);
    // True when value is to be written as a block scalar: text is its text with CR LF line
    // breaks as LF, and header the indicators after the key or dash ('|2-', '>+' ...).
    // relativeIndent is how far its lines are indented past the node it is in.
    function TryBlockScalar(const value : IYAMLValue; relativeIndent : integer; out text, header : string) : boolean;
    // lineStart (the indent and 'key: ', '- ' or '- key: '), the tag, the header and the
    // comment, then the lines of text at column
    procedure WriteBlockScalar(const lineStart, tag, header, text, comment : string; column : integer);
    procedure WriteFoldedBlockLine(const line : string; column : integer);

    // Core writing methods. headerWritten: the line before the collection ('key:', '-', '?'
    // or the root's tag) is written, with the collection's tag, and its Comments above that
    // line. A collection's Comments are the lines before its key, dash or '?', so the
    // collection only writes them itself at the root.
    procedure WriteRoot(const value : IYAMLValue);
    procedure WriteValue(const value : IYAMLValue; headerWritten : boolean);
    // WriteValue with the first line of the collection at column, after a line that has
    // its tag; the levels inside it are indented from there
    procedure WriteValueAtColumn(const value : IYAMLValue; column : integer);
    procedure WriteMapping(const mapping : IYAMLMapping; headerWritten : boolean);
    procedure WriteSequence(const sequence : IYAMLSequence; headerWritten : boolean);
    procedure WriteSet(const ASet : IYAMLSet; headerWritten : boolean);
    procedure WriteScalar(const value : IYAMLValue);
    // Flow style: a line of the indent, prefix ('key: ' or '') and the value in flow style
    procedure WriteFlowLine(const value : IYAMLValue; const prefix : string; includeTag : boolean);
    // value in flow style, with its tag when includeTag is set. An empty null in a sequence
    // is written as null, as there is nothing to write between the commas.
    function FlowText(const value : IYAMLValue; inSequence, includeTag : boolean) : string;

    // Sequence-specific mapping writer
    procedure WriteSequenceMapping(mapping : IYAMLMapping);

    // Utility methods
    function ShouldUseFlowStyle(const value : IYAMLValue) : boolean;
    procedure IncIndent;inline;
    procedure DecIndent;inline;
    // # lines, each at indent - the Comments of a value, above its key, dash or '?', and
    // EndComments
    procedure WriteCommentLines(const comments : TArray<string>; const indent : string);

    // Direct writing helpers
    procedure WriteIndent;inline;

  public
    constructor Create(const options : IYAMLEmitOptions);
    destructor Destroy; override;

    // Main writing methods
    function WriteToString(const value : IYAMLValue) : string;overload;
    function WriteToString(const doc : IYAMLDocument) : string;overload;

    procedure WriteToFile(const value : IYAMLValue; const fileName : string);overload;
    procedure WriteToFile(const doc : IYAMLDocument; const fileName : string);overload;

    procedure WriteToStream(const value : IYAMLValue; const stream : TStream);overload;
    procedure WriteToStream(const doc : IYAMLDocument; const stream : TStream);overload;

    property Options : IYAMLEmitOptions read FOptions;
  end;


implementation

uses
  VSoft.YAML.Classes,
  VSoft.YAML.Utils;

{ TYAMLWriterImpl }


constructor TYAMLWriterImpl.Create(const options : IYAMLEmitOptions);
begin
  inherited Create;
  // cloning options as we may need to modify them depending on methods called
  FOptions := options.Clone;
  FIndentLevel := 0;
  FCurrentIndent := '';
  FOut := nil;
  FQuoteBuilder := TStringBuilder.Create(256);
end;

destructor TYAMLWriterImpl.Destroy;
begin
  FQuoteBuilder.Free;
  inherited Destroy;
end;

procedure TYAMLWriterImpl.UpdateIndentCache;
begin
  if FIndentOffset <> 0 then
  begin
    // inside a collection placed at a column of its own (WriteValueAtColumn)
    FCurrentIndent := TYAMLCharUtils.SpaceStr(FIndentOffset + Integer(FIndentLevel * FOptions.IndentSize));
    exit;
  end;
  // one indent string per level, built once
  if Integer(FIndentLevel) >= Length(FIndentStrings) then
    SetLength(FIndentStrings, FIndentLevel + 8);
  if (FIndentLevel > 0) and (FIndentStrings[FIndentLevel] = '') then
    FIndentStrings[FIndentLevel] := TYAMLCharUtils.SpaceStr(FIndentLevel * FOptions.IndentSize);
  FCurrentIndent := FIndentStrings[FIndentLevel];
end;

function TYAMLWriterImpl.NeedsQuoting(const value : string) : boolean;
var
  i : integer;
  len : integer;
begin
  // Always quote if option is set
  if FOptions.QuoteStrings then
    exit(True);

  // Empty string needs quoting
  len := Length(value);
  if len = 0 then
    exit(True);

  // Leading or trailing whitespace would be lost from a plain scalar
  if (value[1] = ' ') or (value[1] = #9) or (value[len] = ' ') or (value[len] = #9) then
    exit(True);

  // Text the parser would read as something other than a string - null, a boolean, a number
  // or a timestamp, in any spelling it accepts - is quoted to stay a string. The parser
  // decides with the same function, so the two cannot disagree.
  if YAMLResolvePlainScalar(value) <> TYAMLValueType.vtString then
    exit(True);

  // The lexer drops '_' separators from a number before the parser sees it, so '1_000'
  // reads as 1000. Numbers start with a digit, a sign or '.'.
  if CharInSet(value[1], ['0'..'9', '+', '-', '.']) and (Pos('_', value) > 0) and
     (YAMLResolvePlainScalar(StringReplace(value, '_', '', [rfReplaceAll])) <> TYAMLValueType.vtString) then
    exit(True);

  // Indicator characters are only special at the START of a plain scalar. Mid-string they are
  // ordinary content (e.g. a URL's '*' or a Windows path), so quoting them is unnecessary.
  case value[1] of
    '!', '&', '*', '[', ']', '{', '}', ',', '#',
    '|', '>', '''', '"', '%', '@', '`':
      exit(True);
    '-', '?', ':':
      // '-', '?' and ':' only start a node when followed by a space (or are the whole value).
      if (len = 1) or (value[2] = ' ') then
        exit(True);
  end;

  // Characters that are special anywhere in the value.
  {$HIGHCHARUNICODE ON}
  for i := 1 to len do
  begin
    // fast skip of ordinary printable ASCII (everything the case below ignores)
    if (value[i] >= ' ') and (value[i] < #127) and not CharInSet(value[i], [':', '#', ',', '[', ']', '{', '}']) then
      continue;
    case value[i] of
      ':':
        // ': ' (colon + space) or a trailing colon would terminate the plain scalar / start a map
        if (i = len) or (value[i + 1] = ' ') then
          exit(True);
      '#':
        // ' #' begins a trailing comment
        if (i > 1) and (value[i - 1] = ' ') then
          exit(True);
      // Flow indicators are only special inside flow collections, but NeedsQuoting has no context
      // and the writer can emit flow output, so quote these whenever they appear.
      ',', '[', ']', '{', '}':
        exit(True);
      #0..#31, #127:
        exit(True);
      #$80..#$9F, #$A0, #$2028, #$2029, #$FEFF:
        exit(True);
    end;
  end;
  {$HIGHCHARUNICODE OFF}

  result := False;
end;

procedure TYAMLWriterImpl.EscapeString(const value: string; sb: TStringBuilder);
var
  i, runStart : integer;
begin
  // Characters that need no escape are appended in runs rather than one at a time.
  runStart := 1;
  {$HIGHCHARUNICODE ON}
  for i := 1 to Length(value) do
  begin
    // every character YAML does not allow in a stream as it is (YAML 1.2 section 5.1) has an
    // escape, as do " and \
    case value[i] of
      #0..#31, #127, '"', '\', #$80..#$9F, #$A0, #$2028, #$2029, #$FEFF : ;
    else
      continue;
    end;
    if i > runStart then
      sb.Append(value, runStart - 1, i - runStart);
    runStart := i + 1;
    case value[i] of
      #0: sb.Append('\0');     // Null character
      #7: sb.Append('\a');     // Bell character
      #8: sb.Append('\b');     // Backspace
      #9: sb.Append('\t');     // Horizontal tab
      #10: sb.Append('\n');    // Line feed
      #11: sb.Append('\v');    // Vertical tab
      #12: sb.Append('\f');    // Form feed
      #13: sb.Append('\r');    // Carriage return
      #27: sb.Append('\e');    // Escape character
      '"': sb.Append('\"');    // Double quote
      '\': sb.Append('\\');    // Backslash
      // Unicode characters that YAML requires escaping
      #$85: sb.Append('\N');   // Next line (NEL)
      #$A0: sb.Append('\_');   // Non-breaking space
      #$2028: sb.Append('\L'); // Line separator
      #$2029: sb.Append('\P'); // Paragraph separator
      #$FEFF:
      begin
        sb.Append('\');
        sb.Append('uFEFF');    // Byte order mark
      end;
    else
      // the other control characters (C0, DEL and C1) by their code
      sb.Append('\x');
      sb.Append(IntToHex(Ord(value[i]), 2));
    end;
  end;
 {$HIGHCHARUNICODE OFF}
  if Length(value) >= runStart then
    sb.Append(value, runStart - 1, Length(value) - runStart + 1);
end;

function TYAMLWriterImpl.ShouldUseDoubleQuotes(const value : string) : boolean;
var
  i : integer;
begin
  // Use double quotes if the string contains characters that need escaping
  {$HIGHCHARUNICODE ON}
  for i := 1 to Length(value) do
  begin
    case value[i] of
      #0..#31:     // Control characters
        exit(True);
      #127:        // DEL character
        exit(True);
      '\':         // Backslash
        exit(True);
      #$80..#$9F:  // C1 control characters, and next line (NEL)
        exit(True);
      #$A0:        // Non-breaking space
        exit(True);
      #$2028:      // Line separator
        exit(True);
      #$2029:      // Paragraph separator
        exit(True);
      #$FEFF:      // Byte order mark
        exit(True);
    end;
  end;
  {$HIGHCHARUNICODE OFF}
  result := False;
end;

procedure TYAMLWriterImpl.EscapeForSingleQuotes(const value: string; sb: TStringBuilder);
var
  i, runStart : integer;
begin
  // Every character is literal except the single quote, which is doubled. Appending
  // through each quote (inclusive) and starting the next run at it doubles it.
  runStart := 1;
  for i := 1 to Length(value) do
  begin
    if value[i] = '''' then
    begin
      sb.Append(value, runStart - 1, i - runStart + 1);
      runStart := i; // the quote is emitted again at the start of the next run
    end;
  end;
  if Length(value) >= runStart then
    sb.Append(value, runStart - 1, Length(value) - runStart + 1);
end;


function TYAMLWriterImpl.FormatKey(const key : string) : string;
begin
  if NeedsQuoting(key) then
  begin
    FQuoteBuilder.Reset;
    if ShouldUseDoubleQuotes(key) then
    begin
      FQuoteBuilder.Append('"');
      EscapeString(key, FQuoteBuilder);
      FQuoteBuilder.Append('"');
    end
    else
    begin
      FQuoteBuilder.Append('''');
      EscapeForSingleQuotes(key, FQuoteBuilder);
      FQuoteBuilder.Append('''');
    end;
    result := FQuoteBuilder.ToString;
  end
  else
    result := key;
end;

function TYAMLWriterImpl.FormatScalar(const value : IYAMLValue) : string;
var
  decimalText : string;
  isFloat : boolean;
begin
  case value.ValueType of
    TYAMLValueType.vtNull :
    begin
      if FOptions.EmitExplicitNull then
        result := 'null'
      else
        result := '';
    end;
    TYAMLValueType.vtBoolean :
    begin
      if value.AsBoolean then
        result := 'true'
      else
        result := 'false';
    end;
    TYAMLValueType.vtInteger :
    begin
      // Text that is a JSON number is also a YAML 1.2 int and is written as is, so a value
      // past Int64 keeps every digit; the other forms (0x1F, 0o17, +5, 007) are converted to
      // decimal, exactly whatever their size.
      result := value.RawValue;
      if not IsJSONNumber(result) then
      begin
        if YAMLIntegerToDecimalText(result, decimalText) then
          result := decimalText
        else
          result := IntToStr(value.AsInteger);
      end;
    end;
    TYAMLValueType.vtFloat :
    begin
      // Likewise a JSON number is a YAML 1.2 float, written as is rather than via Double.
      result := value.RawValue;
      if not IsJSONNumber(result) then
        result := YAMLFloatToStr(value.AsFloat);
      // Without a fraction or exponent ("2" from a whole-number Double or Currency) the text
      // would be read back as an !!int, so it gets one.
      if IsJSONNumber(result, isFloat) and not isFloat then
        result := result + '.0';
    end;
    TYAMLValueType.vtString :
    begin
      result := value.AsString; // fetched once; each AsString call is an interface call + string copy
      if NeedsQuoting(result) then
      begin
        FQuoteBuilder.Reset;
        if ShouldUseDoubleQuotes(result) then
        begin
          FQuoteBuilder.Append('"');
          EscapeString(result, FQuoteBuilder);
          FQuoteBuilder.Append('"');
        end
        else
        begin
          FQuoteBuilder.Append('''');
          EscapeForSingleQuotes(result, FQuoteBuilder);
          FQuoteBuilder.Append('''');
        end;
        result := FQuoteBuilder.ToString;
      end;
    end;
  else
    result := value.AsString;
  end;
end;


function TYAMLWriterImpl.GetFormattedTag(const value : IYAMLValue) : string;
var
  tagInfo : IYAMLTagInfo;
begin
  result := '';

  if value.Tag <> '' then
  begin
    tagInfo := value.TagInfo;
    if (tagInfo <> nil) and not tagInfo.IsUnresolved then
      result := tagInfo.ToString + ' '
    else
      result := value.Tag + ' ';
  end;
end;

function TYAMLWriterImpl.TagOf(const value : IYAMLValue) : string;
begin
  if FOptions.EmitTags then
    result := GetFormattedTag(value)
  else
    result := '';
end;

procedure TYAMLWriterImpl.WriteHeaderTag(const tag : string);
begin
  if tag <> '' then
  begin
    FOut.WriteChar(' ');
    FOut.Write(TrimRight(tag));
  end;
end;

procedure TYAMLWriterImpl.WriteScalarAt(column : integer; const tag, text : string; contColumn : integer);
begin
  if text = '' then
  begin
    // an empty null: the tag alone, without a space after it
    FOut.Write(TrimRight(tag));
    exit;
  end;
  FOut.Write(tag);
  WriteFoldedText(text, column + Length(tag), contColumn);
end;

// A plain, single quoted or double quoted scalar can go on over several lines: a line break
// between two lines reads as one space, and the indentation of the next line is dropped. So
// a single space between two characters that are not spaces can be written as a line break.
// A plain scalar does not break before a character that could start something else on a
// line of its own, such as # or -.
procedure TYAMLWriterImpl.WriteFoldedText(const text : string; startColumn, contColumn : integer);
var
  width, len, i, lineStart, column, lastBreak : integer;
  plain, canBreak : boolean;
  indent : string;
begin
  width := FOptions.MaxLineLength;
  len := Length(text);
  if (width = 0) or (startColumn + len <= width) then
  begin
    FOut.Write(text);
    exit;
  end;
  plain := not CharInSet(text[1], ['''', '"']);
  indent := TYAMLCharUtils.SpaceStr(contColumn);
  lineStart := 1;         // where the line being written starts in text
  column := startColumn;  // the column it starts at
  lastBreak := 0;         // the last space on that line the text can break at
  for i := 2 to len - 1 do
  begin
    canBreak := (text[i] = ' ') and (text[i - 1] <> ' ') and (text[i + 1] <> ' ');
    if canBreak and plain then
      canBreak := not CharInSet(text[i + 1], ['#', '-', '?', ':', ',', '[', ']', '{', '}', '&', '*', '!', '|', '>', '''', '"', '%', '@', '`'])
    else if canBreak then
      canBreak := (i > 2) and (i < len - 1); // not next to the quotes
    if not canBreak then
      continue;
    // the line would hold text[lineStart .. i - 1]
    if (column + (i - lineStart) > width) and (lastBreak >= lineStart) then
    begin
      FOut.Write(Copy(text, lineStart, lastBreak - lineStart));
      FOut.WriteNewLine;
      FOut.Write(indent);
      lineStart := lastBreak + 1;
      column := contColumn;
    end;
    lastBreak := i;
  end;
  // the rest of the text, broken once more if it does not fit
  if (column + (len + 1 - lineStart) > width) and (lastBreak >= lineStart) then
  begin
    FOut.Write(Copy(text, lineStart, lastBreak - lineStart));
    FOut.WriteNewLine;
    FOut.Write(indent);
    lineStart := lastBreak + 1;
  end;
  FOut.Write(Copy(text, lineStart, len - lineStart + 1));
end;

// Block scalars (YAML 1.2 section 8.1). A string is written as one when BlockScalarStyle is
// set and the string has a line break. The text a block scalar holds is not quite the text of
// its lines, so the header says how to read them:
// - the chomping indicator gives the line breaks at the end: '-' for none, none for one and
//   '+' for more (or for a text that is only line breaks). It is chosen from the string - the
//   deprecated BlockChompingIndicator option is not used, as only one indicator reads back as
//   the same text.
// - an indentation indicator gives the indent of the lines when the first line that is not
//   empty starts with a space, as the indent is otherwise taken from that line.
// A block scalar holds no carriage return - YAML reads every line break in one as a line
// feed - so a CR LF line break is written as a line break and reads back as LF. A string that
// has a CR on its own, or a character YAML does not allow in a stream, is written double
// quoted, with escapes, instead.
function TYAMLWriterImpl.TryBlockScalar(const value : IYAMLValue; relativeIndent : integer; out text, header : string) : boolean;
var
  i, len, trailing : integer;
  ch : Char;
begin
  result := false;
  if (FOptions.BlockScalarStyle = TYAMLBlockScalarStyle.bssNone) or (value.ValueType <> TYAMLValueType.vtString) then
    exit;
  text := StringReplace(value.AsString, #13#10, #10, [rfReplaceAll]);
  if Pos(#10, text) = 0 then
    exit;
  len := Length(text);
  {$HIGHCHARUNICODE ON}
  for i := 1 to len do
  begin
    ch := text[i];
    if ch = #$FEFF then
      exit;
    case ch of
      #9, #10, #32..#126, #$85, #$A0..#$D7FF, #$E000..#$FFFD : ;
      #$D800..#$DBFF :
        // a high surrogate must start a pair
        if not ((i < len) and (text[i + 1] >= #$DC00) and (text[i + 1] <= #$DFFF)) then
          exit;
      #$DC00..#$DFFF :
        if not ((i > 1) and (text[i - 1] >= #$D800) and (text[i - 1] <= #$DBFF)) then
          exit;
    else
      exit; // a CR on its own or another control character
    end;
  end;
  {$HIGHCHARUNICODE OFF}

  if FOptions.BlockScalarStyle = TYAMLBlockScalarStyle.bssFolded then
    header := '>'
  else
    header := '|';

  // the first line that is not empty
  i := 1;
  while (i <= len) and (text[i] = #10) do
    Inc(i);
  if (i <= len) and (text[i] = ' ') then
  begin
    // an indentation indicator is a single digit
    if (relativeIndent < 1) or (relativeIndent > 9) then
      exit;
    header := header + IntToStr(relativeIndent);
  end;

  trailing := 0;
  while (trailing < len) and (text[len - trailing] = #10) do
    Inc(trailing);
  if trailing = 0 then
    header := header + '-'
  else if (trailing > 1) or (trailing = len) then
    header := header + '+';
  result := true;
end;

procedure TYAMLWriterImpl.WriteBlockScalar(const lineStart, tag, header, text, comment : string; column : integer);
var
  indent, line : string;
  len, trailing, bodyEnd, start, stop, i, extra : integer;
  folded, normal, previousNormal : boolean;
begin
  FOut.Write(lineStart);
  FOut.Write(tag);
  FOut.Write(header);
  if comment <> '' then
  begin
    FOut.Write(' # ');
    FOut.Write(comment);
  end;
  FOut.WriteNewLine;

  indent := TYAMLCharUtils.SpaceStr(column);
  folded := header[1] = '>';
  len := Length(text);
  trailing := 0;
  while (trailing < len) and (text[len - trailing] = #10) do
    Inc(trailing);
  bodyEnd := len - trailing;

  // the lines before the final line breaks, each with its line break
  previousNormal := false;
  start := 1;
  while start <= bodyEnd do
  begin
    stop := start;
    while (stop <= bodyEnd) and (text[stop] <> #10) do
      Inc(stop);
    line := Copy(text, start, stop - start);
    if line = '' then
      FOut.WriteNewLine // an empty line, with no spaces
    else
    begin
      // In a folded scalar a single line break between two lines that do not start with
      // white space reads as a space, and an empty line between them as a line break - so
      // such a line break is written as an empty line. Line breaks next to a line that
      // starts with white space are read as they are.
      normal := not CharInSet(line[1], [' ', #9]);
      if folded and normal and previousNormal then
        FOut.WriteNewLine;
      FOut.Write(indent);
      if folded and normal then
        WriteFoldedBlockLine(line, column)
      else
        FOut.Write(line);
      FOut.WriteNewLine;
      previousNormal := normal;
    end;
    // (the body does not end with a line break, so the last line ends at bodyEnd)
    if stop > bodyEnd then
      break;
    start := stop + 1;
  end;

  // The line break of the last line is written above. With '+' the other final line breaks
  // are empty lines - all of them when the text is only line breaks.
  if bodyEnd = 0 then
    extra := trailing
  else
    extra := trailing - 1;
  for i := 1 to extra do
    FOut.WriteNewLine;
end;

// A line of a folded block scalar that does not start with white space, written at column:
// when MaxLineLength asks for it, it goes over several lines, broken at single spaces, which
// read back as those spaces.
procedure TYAMLWriterImpl.WriteFoldedBlockLine(const line : string; column : integer);
var
  width, len, i, lineStart, lastBreak : integer;
begin
  width := FOptions.MaxLineLength;
  len := Length(line);
  if (width = 0) or (column + len <= width) then
  begin
    FOut.Write(line);
    exit;
  end;
  lineStart := 1;
  lastBreak := 0;
  for i := 2 to len - 1 do
  begin
    if (line[i] <> ' ') or (line[i - 1] = ' ') or (line[i + 1] = ' ') then
      continue;
    if (column + (i - lineStart) > width) and (lastBreak >= lineStart) then
    begin
      FOut.Write(Copy(line, lineStart, lastBreak - lineStart));
      FOut.WriteNewLine;
      FOut.Write(TYAMLCharUtils.SpaceStr(column));
      lineStart := lastBreak + 1;
    end;
    lastBreak := i;
  end;
  if (column + (len + 1 - lineStart) > width) and (lastBreak >= lineStart) then
  begin
    FOut.Write(Copy(line, lineStart, lastBreak - lineStart));
    FOut.WriteNewLine;
    FOut.Write(TYAMLCharUtils.SpaceStr(column));
    lineStart := lastBreak + 1;
  end;
  FOut.Write(Copy(line, lineStart, len - lineStart + 1));
end;

function TYAMLWriterImpl.ShouldUseFlowStyle(const value : IYAMLValue) : boolean;
var
  seq : IYAMLSequence;
  map : IYAMLMapping;
  key : string;
  i : integer;
begin
  case FOptions.Format of
    TYAMLOutputFormat.yofFlow :
      result := True;
    TYAMLOutputFormat.yofBlock :
      result := False;
    TYAMLOutputFormat.yofMixed :
    begin
      // Use flow style for simple structures
      if value.ValueType in [TYAMLValueType.vtSet, TYAMLValueType.vtSequence] then
      begin
        // AsSequence rejects sets, but a set is a sequence (IYAMLSet extends IYAMLSequence)
        if value.ValueType = TYAMLValueType.vtSet then
          seq := value.AsSet
        else
          seq := value.AsSequence;
        result := (seq.Count <= 5);
        if result then
        begin
          for i := 0 to seq.Count - 1 do
          begin
            if not (seq[i].ValueType in [TYAMLValueType.vtNull, TYAMLValueType.vtBoolean, TYAMLValueType.vtInteger, TYAMLValueType.vtFloat, TYAMLValueType.vtString]) then
            begin
              result := False;
              Break;
            end;
          end;
        end;
      end
      else if value.ValueType = TYAMLValueType.vtMapping then
      begin
        result := (value.AsMapping.Count <= 3);
        // Check if all values are scalars
        if result then
        begin
          map := value.AsMapping;
          for i := 0 to map.Count - 1 do
          begin
            key := map.Keys[i];
            if not (map.Values[key].ValueType in [TYAMLValueType.vtNull, TYAMLValueType.vtBoolean, TYAMLValueType.vtInteger, TYAMLValueType.vtFloat, TYAMLValueType.vtString]) then
            begin
              result := False;
              Break;
            end;
          end;
        end;
      end
      else
        result := False;
    end;
  else
    result := False;
  end;
end;

procedure TYAMLWriterImpl.IncIndent;
begin
  Inc(FIndentLevel);
  UpdateIndentCache;
end;

procedure TYAMLWriterImpl.DecIndent;
begin
  Dec(FIndentLevel);
  UpdateIndentCache;
end;

procedure TYAMLWriterImpl.WriteCommentLines(const comments : TArray<string>; const indent : string);
var
  index : integer;
begin
  for index := 0 to Length(comments) - 1 do
  begin
    FOut.Write(indent);
    if comments[index] = '' then
      FOut.Write('#')
    else
    begin
      FOut.Write('# ');
      FOut.Write(comments[index]);
    end;
    FOut.WriteNewLine;
  end;
end;

procedure TYAMLWriterImpl.WriteIndent;
begin
  // Use cached indent string instead of recalculating each time
  FOut.Write(FCurrentIndent);
end;

procedure TYAMLWriterImpl.WriteRoot(const value : IYAMLValue);
var
  tag : string;
  headerWritten : boolean;
begin
  // The root has no line of its own to put its tag on. A block collection's tag goes on the
  // line before it; a scalar's goes in front of it, and a flow collection's into its text.
  headerWritten := false;
  if (value.ValueType in [TYAMLValueType.vtMapping, TYAMLValueType.vtSequence, TYAMLValueType.vtSet]) and
     not ShouldUseFlowStyle(value) then
  begin
    tag := TagOf(value);
    if tag <> '' then
    begin
      // its comments go above its tag
      if value.HasComments then
        WriteCommentLines(value.Comments, FCurrentIndent);
      WriteIndent;
      FOut.Write(TrimRight(tag));
      FOut.WriteNewLine;
      headerWritten := true;
    end;
  end;
  WriteValue(value, headerWritten);
end;

procedure TYAMLWriterImpl.WriteValue(const value : IYAMLValue; headerWritten : boolean);
begin
  case value.ValueType of
    TYAMLValueType.vtMapping  : WriteMapping(value.AsMapping, headerWritten);
    TYAMLValueType.vtSequence : WriteSequence(value.AsSequence, headerWritten);
    TYAMLValueType.vtSet      : WriteSet(value.AsSet, headerWritten);
  else
      WriteScalar(value);
  end;
end;

procedure TYAMLWriterImpl.WriteValueAtColumn(const value : IYAMLValue; column : integer);
var
  savedOffset : integer;
begin
  // the indent of each level is offset so that this level is at column
  savedOffset := FIndentOffset;
  FIndentOffset := column - Integer(FIndentLevel * FOptions.IndentSize);
  UpdateIndentCache;
  try
    WriteValue(value, true);
  finally
    FIndentOffset := savedOffset;
    UpdateIndentCache;
  end;
end;

procedure TYAMLWriterImpl.WriteMapping(const mapping : IYAMLMapping; headerWritten : boolean);
var
  priv : IYAMLMappingPrivate;
  i, keyColumn : integer;
  key : string;
  value : IYAMLValue;
  tag : string;
  valueStr, blockText, blockHeader : string;
begin
  if (not headerWritten) and mapping.HasComments then
    WriteCommentLines(mapping.Comments, FCurrentIndent);

  if mapping.Count = 0 then
  begin
    WriteIndent;
    if not headerWritten then
      FOut.Write(TagOf(mapping));
    FOut.Write('{}');
    FOut.WriteNewLine;
    if mapping.HasEndComments then
      WriteCommentLines(mapping.EndComments, FCurrentIndent);
    Exit;
  end;

  if ShouldUseFlowStyle(mapping) then
  begin
    WriteFlowLine(mapping, '', not headerWritten);
    Exit;
  end;

  if not Supports(mapping, IYAMLMappingPrivate, priv) then
    priv := nil;

  keyColumn := Length(FCurrentIndent);
  for i := 0 to mapping.Count - 1 do
  begin
    key := mapping.Keys[i];
    if priv <> nil then
      value := priv.ValueAt(i)
    else
      value := mapping.Values[key];

    tag := TagOf(value);
    key := FormatKey(key);
    // the comment lines before the entry, above its key
    if value.HasComments then
      WriteCommentLines(value.Comments, FCurrentIndent);

    case value.ValueType of
      TYAMLValueType.vtSequence,
      TYAMLValueType.vtSet,
      TYAMLValueType.vtMapping :
      begin
        if ShouldUseFlowStyle(value) then
          WriteFlowLine(value, key + ': ', true)
        else
        begin
          WriteIndent;
          FOut.Write(key);
          FOut.Write(':');
          WriteHeaderTag(tag);
          FOut.WriteNewLine;
          IncIndent;
          WriteValue(value, true);
          DecIndent;
        end;
      end;
    else
      begin
        // a multi-line string as a block scalar, its lines one level past the key
        if TryBlockScalar(value, Integer(FOptions.IndentSize), blockText, blockHeader) then
          WriteBlockScalar(FCurrentIndent + key + ': ', tag, blockHeader, blockText, value.Comment, keyColumn + Integer(FOptions.IndentSize))
        else
        begin
          valueStr := FormatScalar(value);
          FOut.Write(FCurrentIndent);
          FOut.Write(key);
          FOut.Write(': ');
          WriteScalarAt(keyColumn + Length(key) + 2, tag, valueStr, keyColumn + Integer(FOptions.IndentSize));
          if value.Comment <> '' then
          begin
            FOut.Write(' # ');
            FOut.Write(value.Comment);
          end;
          FOut.WriteNewLine;
        end;
      end;
    end;
  end;
  if mapping.HasEndComments then
    WriteCommentLines(mapping.EndComments, FCurrentIndent);
end;

procedure TYAMLWriterImpl.WriteSequence(const sequence : IYAMLSequence; headerWritten : boolean);
var
  i, dashColumn : integer;
  item : IYAMLValue;
  itemStr, tag, blockText, blockHeader : string;
begin
  if (not headerWritten) and sequence.HasComments then
    WriteCommentLines(sequence.Comments, FCurrentIndent);

  if sequence.Count = 0 then
  begin
    WriteIndent;
    if not headerWritten then
      FOut.Write(TagOf(sequence));
    FOut.Write('[]');
    FOut.WriteNewLine;
    if sequence.HasEndComments then
      WriteCommentLines(sequence.EndComments, FCurrentIndent);
    Exit;
  end;

  if ShouldUseFlowStyle(sequence) then
  begin
    WriteFlowLine(sequence, '', not headerWritten);
    Exit;
  end;

  dashColumn := Length(FCurrentIndent);
  for i := 0 to sequence.Count - 1 do
  begin
    item := sequence[i];
    tag := TagOf(item);
    // the comment lines before the item, above its dash
    if item.HasComments then
      WriteCommentLines(item.Comments, FCurrentIndent);

    case item.ValueType of
      TYAMLValueType.vtSequence,
      TYAMLValueType.vtSet :
      begin
        WriteIndent;
        FOut.Write('-');
        WriteHeaderTag(tag);
        FOut.WriteNewLine;
        IncIndent;
        WriteValue(item, true);
        DecIndent;
      end;
      TYAMLValueType.vtMapping :
        if tag = '' then
          WriteSequenceMapping(item.AsMapping)
        else
        begin
          // the tag goes after the dash, so the mapping starts on the next line (on the dash
          // line, the tag would be the first key's)
          WriteIndent;
          FOut.Write('-');
          WriteHeaderTag(tag);
          FOut.WriteNewLine;
          IncIndent;
          WriteValue(item, true);
          DecIndent;
        end;
    else
      begin
        // Check if we should use block scalar style for multiline strings
        // a multi-line string as a block scalar, its lines one level past the dash
        if TryBlockScalar(item, Integer(FOptions.IndentSize), blockText, blockHeader) then
          WriteBlockScalar(FCurrentIndent + '- ', tag, blockHeader, blockText, item.Comment, dashColumn + Integer(FOptions.IndentSize))
        else
        begin
          itemStr := FormatScalar(item);
          FOut.Write(FCurrentIndent);
          FOut.Write('- ');
          WriteScalarAt(dashColumn + 2, tag, itemStr, dashColumn + 2);
          if item.Comment <> '' then
          begin
            FOut.Write(' # ');
            FOut.Write(item.Comment);
          end;
          FOut.WriteNewLine;
        end;
      end;
    end;
  end;
  if sequence.HasEndComments then
    WriteCommentLines(sequence.EndComments, FCurrentIndent);
end;

procedure TYAMLWriterImpl.WriteScalar(const value : IYAMLValue);
var
  formattedValue : string;
begin
  if value.HasComments then
    WriteCommentLines(value.Comments, FCurrentIndent);
  formattedValue := FormatScalar(value);
  WriteIndent;
  WriteScalarAt(Length(FCurrentIndent), TagOf(value), formattedValue, Length(FCurrentIndent) + Integer(FOptions.IndentSize));
  if value.Comment <> '' then
  begin
    FOut.Write(' # ');
    FOut.Write(value.Comment);
  end;
  FOut.WriteNewLine;
end;

procedure TYAMLWriterImpl.WriteFlowLine(const value : IYAMLValue; const prefix : string; includeTag : boolean);
begin
  FOut.Write(FCurrentIndent);
  FOut.Write(prefix);
  FOut.Write(FlowText(value, false, includeTag));
  if value.Comment <> '' then
  begin
    FOut.Write(' # ');
    FOut.Write(value.Comment);
  end;
  FOut.WriteNewLine;
end;

function TYAMLWriterImpl.FlowText(const value : IYAMLValue; inSequence, includeTag : boolean) : string;
var
  priv : IYAMLMappingPrivate;
  mapping : IYAMLMapping;
  sequence : IYAMLSequence;
  item : IYAMLValue;
  i : integer;
  tag, body : string;
  sb : TStringBuilder;
begin
  if includeTag then
    tag := TagOf(value)
  else
    tag := '';
  case value.ValueType of
    TYAMLValueType.vtMapping :
    begin
      mapping := value.AsMapping;
      if not Supports(mapping, IYAMLMappingPrivate, priv) then
        priv := nil;
      sb := TStringBuilder.Create;
      try
        sb.Append('{');
        for i := 0 to mapping.Count - 1 do
        begin
          if priv <> nil then
            item := priv.ValueAt(i)
          else
            item := mapping.Values[mapping.Keys[i]];
          if i > 0 then
            sb.Append(', ');
          sb.Append(FormatKey(mapping.Keys[i]));
          sb.Append(': ');
          sb.Append(FlowText(item, false, true));
        end;
        sb.Append('}');
        body := sb.ToString;
      finally
        sb.Free;
      end;
    end;
    TYAMLValueType.vtSequence,
    TYAMLValueType.vtSet :
    begin
      // AsSequence rejects sets, but a set is a sequence (IYAMLSet extends IYAMLSequence)
      if value.ValueType = TYAMLValueType.vtSet then
        sequence := value.AsSet
      else
        sequence := value.AsSequence;
      sb := TStringBuilder.Create;
      try
        sb.Append('[');
        for i := 0 to sequence.Count - 1 do
        begin
          if i > 0 then
            sb.Append(', ');
          sb.Append(FlowText(sequence[i], true, true));
        end;
        sb.Append(']');
        body := sb.ToString;
      finally
        sb.Free;
      end;
    end;
  else
    body := FormatScalar(value);
    if (body = '') and inSequence then
      body := 'null';
  end;
  if body = '' then
    result := TrimRight(tag)
  else
    result := tag + body;
end;

procedure TYAMLWriterImpl.WriteSequenceMapping(mapping : IYAMLMapping);
var
  priv : IYAMLMappingPrivate;
  i, dashColumn, keyColumn, indentSize, column : integer;
  key, prefix : string;
  value : IYAMLValue;
  valueStr, tag, blockText, blockHeader : string;
begin
  // (WriteSequence wrote the mapping's comments, above the dash)
  if mapping.Count = 0 then
  begin
    WriteIndent;
    FOut.Write('- {}');
    FOut.WriteNewLine;
    if mapping.HasEndComments then
      WriteCommentLines(mapping.EndComments, FCurrentIndent + '  ');
    Exit;
  end;

  if not Supports(mapping, IYAMLMappingPrivate, priv) then
    priv := nil;
  // The first key goes on the line of the dash, after '- ', and the others line up with it.
  // What a key holds goes on the next lines, indented one level from the dash for the first
  // key and two for the others - or, where that would not be past the keys (when the indent
  // is less than 3), one level from the keys.
  dashColumn := Length(FCurrentIndent);
  keyColumn := dashColumn + 2;
  indentSize := Integer(FOptions.IndentSize);
  for i := 0 to mapping.Count - 1 do
  begin
    key := mapping.Keys[i];
    if priv <> nil then
      value := priv.ValueAt(i)
    else
      value := mapping.Values[key];

    key := FormatKey(key);
    tag := TagOf(value);
    if i = 0 then
    begin
      prefix := '- ';
      column := dashColumn + indentSize;
    end
    else
    begin
      prefix := '  ';
      column := dashColumn + 2 * indentSize;
    end;
    // the comment lines before the entry, above its key - for the first key, above the dash
    // line it is on
    if value.HasComments then
    begin
      if i = 0 then
        WriteCommentLines(value.Comments, FCurrentIndent)
      else
        WriteCommentLines(value.Comments, FCurrentIndent + '  ');
    end;

    case value.ValueType of
      TYAMLValueType.vtSequence,
      TYAMLValueType.vtSet :
      begin
        if ShouldUseFlowStyle(value) then
          WriteFlowLine(value, prefix + key + ': ', true)
        else
        begin
          WriteIndent;
          FOut.Write(prefix);
          FOut.Write(key);
          FOut.Write(':');
          WriteHeaderTag(tag);
          FOut.WriteNewLine;
          // a sequence may line up with the key it is the value of
          if column < keyColumn then
            column := keyColumn;
          WriteValueAtColumn(value, column);
        end;
      end;
      TYAMLValueType.vtMapping :
      begin
        WriteIndent;
        FOut.Write(prefix);
        FOut.Write(key);
        FOut.Write(':');
        WriteHeaderTag(tag);
        FOut.WriteNewLine;
        // a mapping must be past the key, or its keys would be this mapping's
        if column <= keyColumn then
          column := keyColumn + indentSize;
        WriteValueAtColumn(value, column);
      end;
    else
      begin
        // Check if we should use block scalar style for multiline strings
        // the lines of a block scalar must be past the key too
        if column <= keyColumn then
          column := keyColumn + indentSize;
        if TryBlockScalar(value, column - keyColumn, blockText, blockHeader) then
          WriteBlockScalar(FCurrentIndent + prefix + key + ': ', tag, blockHeader, blockText, value.Comment, column)
        else
        begin
          valueStr := FormatScalar(value);
          FOut.Write(FCurrentIndent);
          FOut.Write(prefix);
          FOut.Write(key);
          FOut.Write(': ');
          WriteScalarAt(keyColumn + Length(key) + 2, tag, valueStr, keyColumn + indentSize);
          if value.Comment <> '' then
          begin
            FOut.Write(' # ');
            FOut.Write(value.Comment);
          end;
          FOut.WriteNewLine;
        end;
      end;
    end;
  end;
  if mapping.HasEndComments then
    WriteCommentLines(mapping.EndComments, FCurrentIndent + '  ');
end;

procedure TYAMLWriterImpl.WriteSet(const ASet : IYAMLSet; headerWritten : boolean);
var
  i : integer;
  item : IYAMLValue;
  itemStr, tag : string;
begin
  if (not headerWritten) and ASet.HasComments then
    WriteCommentLines(ASet.Comments, FCurrentIndent);

  if ASet.Count = 0 then
  begin
    WriteIndent;
    if not headerWritten then
      FOut.Write(TagOf(ASet));
    FOut.Write('[]');
    FOut.WriteNewLine;
    Exit;
  end;

  if ShouldUseFlowStyle(ASet) then
  begin
    WriteFlowLine(ASet, '', not headerWritten);
    Exit;
  end;

  // a block set is a mapping of '? ' keys with no values
  for i := 0 to ASet.Count - 1 do
  begin
    item := ASet[i];
    tag := TagOf(item);
    // the comment lines before the item, above its '?'
    if item.HasComments then
      WriteCommentLines(item.Comments, FCurrentIndent);

    case item.ValueType of
      TYAMLValueType.vtSequence,
      TYAMLValueType.vtSet,
      TYAMLValueType.vtMapping :
      begin
        WriteIndent;
        FOut.Write('?');
        WriteHeaderTag(tag);
        FOut.WriteNewLine;
        IncIndent;
        WriteValue(item, true);
        DecIndent;
      end;
    else
      begin
        itemStr := FormatScalar(item);
        FOut.Write(FCurrentIndent);
        FOut.Write('? ');
        // a key, so never folded
        if itemStr = '' then
          FOut.Write(TrimRight(tag))
        else
        begin
          FOut.Write(tag);
          FOut.Write(itemStr);
        end;
        if item.Comment <> '' then
        begin
          FOut.Write(' # ');
          FOut.Write(item.Comment);
        end;
        FOut.WriteNewLine;
      end;
    end;
  end;
end;

function TYAMLWriterImpl.WriteToString(const value : IYAMLValue) : string;
begin
  //force utf16 to avoid round trip encoding conversions
  FOut := TYAMLOutputBuffer.CreateForString;
  try
    if FOptions.EmitDocumentMarkers then
      FOut.WriteLine('---');
    WriteRoot(value);
    if FOptions.EmitDocumentMarkers then
      FOut.WriteLine('...');
    result := FOut.ExtractString;
  finally
    FreeAndNil(FOut);
  end;
end;

function TYAMLWriterImpl.WriteToString(const doc : IYAMLDocument) : string;
var
  i : integer;
begin
  //force utf16 to avoid round trip encoding conversions
  FOptions.Encoding := TEncoding.Unicode;
  FOut := TYAMLOutputBuffer.CreateForString;
  try
    if FOptions.EmitYAMLDirective then
      FOut.WriteLine('%YAML ' + doc.Version.ToString);

    if FOptions.EmitTagDirectives then
    begin
      //skip the standard tag directives
      if doc.TagDirectives.Count > 2 then
      begin
        for i := 2 to doc.TagDirectives.Count -1 do
          FOut.WriteLine('%TAG ' + doc.TagDirectives[i].ToString);
      end;
    end;

    if FOptions.EmitDocumentMarkers or FOptions.EmitTagDirectives or FOptions.EmitYAMLDirective then
      FOut.WriteLine('---');

    WriteRoot(doc.Root);
    if doc.HasEndComments then
      WriteCommentLines(doc.EndComments, '');
    if FOptions.EmitDocumentMarkers then
      FOut.WriteLine('...') ;

    result := FOut.ExtractString;
  finally
    FreeAndNil(FOut);
  end;
end;

procedure TYAMLWriterImpl.WriteToFile(const value : IYAMLValue; const fileName : string);
var
  fileStream : TFileStream;
begin
  fileStream := TFileStream.Create(fileName,  fmCreate);
  try
    WriteToStream(value, fileStream);
  finally
    fileStream.Free;
  end;
end;

procedure TYAMLWriterImpl.WriteToFile(const doc : IYAMLDocument; const fileName : string);
var
  fileStream : TFileStream;
begin
  fileStream := TFileStream.Create(fileName, fmCreate);
  try
    WriteToStream(doc, fileStream);
  finally
    fileStream.Free;
  end;
end;

procedure TYAMLWriterImpl.WriteToStream(const value : IYAMLValue; const stream : TStream);
var
  ownsWriter : boolean;
begin
  ownsWriter := false;
  //if called from WriteToStreem(doc) then the writer will already exist
  if FOut = nil then
  begin
    FOut := TYAMLOutputBuffer.CreateForStream(stream, FOptions.Encoding, FOptions.WriteByteOrderMark);
    ownsWriter := true;
  end;
  try
    if ownsWriter and FOptions.EmitDocumentMarkers then
      FOut.WriteLine('---');
    WriteRoot(value);
    if ownsWriter and FOptions.EmitDocumentMarkers then
      FOut.WriteLine('...');
  finally
    if ownsWriter then
      FreeAndNil(FOut);
  end;
end;

procedure TYAMLWriterImpl.WriteToStream(const doc : IYAMLDocument; const stream : TStream);
var
  i : integer;
begin
  FOut := TYAMLOutputBuffer.CreateForStream(stream, FOptions.Encoding, FOptions.WriteByteOrderMark);
  try
    if FOptions.EmitYAMLDirective then
      FOut.WriteLine('%YAML ' + doc.Version.ToString);

    if FOptions.EmitTagDirectives then
    begin
      //skip the standard tag directives
      if doc.TagDirectives.Count > 2 then
      begin
        for i := 2 to doc.TagDirectives.Count -1 do
          FOut.WriteLine('%TAG ' + doc.TagDirectives[i].ToString);
      end;
    end;

    if FOptions.EmitDocumentMarkers or FOptions.EmitTagDirectives or FOptions.EmitYAMLDirective then
      FOut.WriteLine('---');

    WriteToStream(doc.Root,stream);
    if doc.HasEndComments then
      WriteCommentLines(doc.EndComments, '');

    if FOptions.EmitDocumentMarkers then
      FOut.WriteLine('...') ;
  finally
    FreeAndNil(FOut);
  end;

end;


end.

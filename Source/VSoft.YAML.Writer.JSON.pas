unit VSoft.YAML.Writer.JSON;

interface

{$I 'VSoft.YAML.inc'}


uses
  System.SysUtils,
  System.Classes,
  VSoft.YAML.StreamWriter,
  VSoft.YAML;

type
  // Writes JSON (RFC 8259), or JSON5 when created with json5 = true.
  TJSONWriterImpl = class
  private
    FOptions : IYAMLEmitOptions;
    FPrettyPrint : boolean;
    FMaxPlainChar : Char; // characters past this are \u escaped (#126 with EscapeNonASCII)
    FOut : TYAMLOutputBuffer;
    FIndentLevel : UInt32;
    FJSON5 : boolean;
    FQuote : Char;            // JSON5: the quote for strings and keys
    FUnquotedKeys : boolean;  // JSON5: identifier keys without quotes
    FTrailingCommas : boolean; // JSON5: a comma after the last item (pretty printed only)

    // Writes value as a JSON string literal (quotes included)
    procedure WriteQuoted(const value : string);
    procedure WriteNewlineAndIndent;inline;

    // the root value, then (JSON5) the document's end comments when not nil
    procedure WriteRoot(const value : IYAMLValue; const endComments : TArray<string>);

    // Core writing methods
    procedure WriteValue(const value : IYAMLValue);
    procedure WriteMapping(const mapping : IYAMLMapping);
    procedure WriteSequence(const sequence : IYAMLSequence);
    procedure WriteSet(const aSet : IYAMLSet);
    procedure WriteScalar(const value : IYAMLValue);

    // JSON5
    procedure WriteValue5(const value : IYAMLValue);
    procedure WriteMapping5(const mapping : IYAMLMapping);
    procedure WriteSequence5(const sequence : IYAMLSequence);
    procedure WriteScalar5(const value : IYAMLValue);
    procedure WriteQuoted5(const value : string);
    procedure WriteKey5(const key : string);
    procedure WriteCommentText5(const text : string);
    procedure WriteCommentLines5(const comments : TArray<string>);
    procedure WriteSameLineComment5(const text : string);

  public
    constructor Create(const options : IYAMLEmitOptions; json5 : boolean = false);
    destructor Destroy; override;

    // Main writing methods
    function WriteToString(const value : IYAMLValue) : string;overload;
    function WriteToString(const doc : IYAMLDocument) : string;overload;

    procedure WriteToFile(const value : IYAMLValue; const fileName : string);overload;
    procedure WriteToFile(const doc : IYAMLDocument; const fileName : string);overload;

    procedure WriteToStream(const value : IYAMLValue; const stream : TStream);overload;
    procedure WriteToStream(const doc : IYAMLDocument; const stream : TStream);overload;

  end;

implementation

uses
  System.Math,
  VSoft.YAML.Classes, VSoft.YAML.Utils;

{ TJSONWriterImpl }

constructor TJSONWriterImpl.Create(const options : IYAMLEmitOptions; json5 : boolean);
begin
  inherited Create;
  // cloning options as we may need to modify them depending on methods called
  FOptions := options.Clone;
  FPrettyPrint := FOptions.PrettyPrint;
  if FOptions.EscapeNonASCII then
    FMaxPlainChar := #126
  else
    FMaxPlainChar := #$FFFF;
  FOut := nil;
  FIndentLevel := 0;
  FJSON5 := json5;
  if FOptions.JSON5SingleQuotes then
    FQuote := ''''
  else
    FQuote := '"';
  FUnquotedKeys := FOptions.JSON5UnquotedKeys;
  FTrailingCommas := FOptions.JSON5TrailingCommas and FPrettyPrint;
end;

destructor TJSONWriterImpl.Destroy;
begin
  FOut.Free;
  inherited Destroy;
end;

procedure TJSONWriterImpl.WriteNewlineAndIndent;
begin
  if FPrettyPrint then
  begin
    FOut.WriteNewLine;
    FOut.WriteSpaces(FIndentLevel * FOptions.IndentSize);
  end;
end;

// '"', '\' and control characters are escaped, as is every surrogate (a valid pair as two
// \uXXXX escapes) - the same as TYAMLCharUtils.EscapeStringForJSON - and, with
// EscapeNonASCII, every character past #126. Runs of characters that need nothing are
// copied in one go.
procedure TJSONWriterImpl.WriteQuoted(const value : string);
var
  p : PChar;
  len, i, runStart : integer;
  ch : Char;
begin
  FOut.WriteChar('"');
  p := PChar(Pointer(value));
  len := Length(value);
  i := 0;
  runStart := 0;
  while i < len do
  begin
    ch := p[i];
    if (ch >= ' ') and (ch <= FMaxPlainChar) and (ch <> '"') and (ch <> '\') and ((Ord(ch) < $D800) or (Ord(ch) > $DFFF)) then
    begin
      Inc(i);
      continue;
    end;
    if i > runStart then
      FOut.Write(@p[runStart], i - runStart);
    case ch of
      '"': FOut.Write('\"');
      '\': FOut.Write('\\');
      #8: FOut.Write('\b');
      #12: FOut.Write('\f');
      #10: FOut.Write('\n');
      #13: FOut.Write('\r');
      #9: FOut.Write('\t');
    else
      // other control characters, surrogates (paired or not) and with EscapeNonASCII
      // everything past #126 - a valid pair simply comes out as two consecutive escapes,
      // one per code unit
      FOut.Write('\u');
      FOut.Write(IntToHex(Ord(ch), 4));
    end;
    Inc(i);
    runStart := i;
  end;
  if len > runStart then
    FOut.Write(@p[runStart], len - runStart);
  FOut.WriteChar('"');
end;

procedure TJSONWriterImpl.WriteScalar(const value : IYAMLValue);
var
  floatValue : Double;
  rawText : string;
  decimalText : string;
begin
  case value.ValueType of
    TYAMLValueType.vtNull :
      FOut.Write('null');
    TYAMLValueType.vtBoolean :
    begin
      if value.AsBoolean then
        FOut.Write('true')
      else
        FOut.Write('false');
    end;
    TYAMLValueType.vtInteger :
    begin
      // Text that is already a JSON number is written as is, so every digit survives - a
      // UInt64, or an integer read from JSON that is past Int64. The YAML-only forms
      // (0x1F, 0o17, +5, 007) are converted to decimal, exactly whatever their size.
      rawText := value.RawValue;
      if IsJSONNumber(rawText) then
        FOut.Write(rawText)
      else if YAMLIntegerToDecimalText(rawText, decimalText) then
        FOut.Write(decimalText)
      else
        FOut.Write(IntToStr(value.AsInteger));
    end;
    TYAMLValueType.vtFloat :
    begin
      // As for integers - a Currency, an AddOrSetNumber DECIMAL(38,10) or a parsed value
      // keeps every digit rather than going through Double.
      rawText := value.RawValue;
      if IsJSONNumber(rawText) then
        FOut.Write(rawText)
      else
      begin
        // RFC 8259 has no representation for NaN/Infinity; emit JSON null instead.
        floatValue := value.AsFloat;
        if IsNan(floatValue) or IsInfinite(floatValue) then
          FOut.Write('null')
        else
          FOut.Write(FloatToStr(floatValue, YAMLFormatSettings));
      end;
    end;
  else
    // strings, and timestamps in their text form - escaped, so the output is valid JSON
    // whatever the text holds
    WriteQuoted(value.AsString);
  end;
end;

procedure TJSONWriterImpl.WriteValue(const value : IYAMLValue);
begin
  if FJSON5 then
  begin
    WriteValue5(value);
    exit;
  end;
  case value.ValueType of
    TYAMLValueType.vtMapping  : WriteMapping(value.AsMapping);
    TYAMLValueType.vtSequence : WriteSequence(value.AsSequence);
    TYAMLValueType.vtSet      : WriteSet(value.AsSet);
  else
      WriteScalar(value);
  end;
end;

procedure TJSONWriterImpl.WriteMapping(const mapping : IYAMLMapping);
var
  priv : IYAMLMappingPrivate;
  i : integer;
  key : string;
  value : IYAMLValue;
  count : integer;
begin
  FOut.WriteChar('{');

  count := mapping.Count;

  if count > 0 then
  begin
    Inc(FIndentLevel);
    if not Supports(mapping, IYAMLMappingPrivate, priv) then
      priv := nil;
    for i := 0 to count - 1 do
    begin
      if i > 0 then
        FOut.WriteChar(',');
      WriteNewlineAndIndent;

      key := mapping.Keys[i];
      if priv <> nil then
        value := priv.ValueAt(i)
      else
        value := mapping.Values[key];

      WriteQuoted(key);
      FOut.WriteChar(':');
      if FPrettyPrint then
        FOut.WriteChar(' ');

      WriteValue(value);
    end;
    Dec(FIndentLevel);
    WriteNewlineAndIndent;
  end;

  FOut.WriteChar('}');
end;

procedure TJSONWriterImpl.WriteSequence(const sequence : IYAMLSequence);
var
  i : integer;
  count : integer;
begin
  FOut.WriteChar('[');

  count := sequence.Count;
  if count > 0 then
  begin
    Inc(FIndentLevel);
    for i := 0 to count - 1 do
    begin
      if i > 0 then
        FOut.WriteChar(',');
      WriteNewlineAndIndent;
      WriteValue(sequence[i]);
    end;
    Dec(FIndentLevel);
    WriteNewlineAndIndent;
  end;
  FOut.WriteChar(']');
end;

procedure TJSONWriterImpl.WriteSet(const aSet : IYAMLSet);
begin
  // JSON doesn't have sets, so write as array
  WriteSequence(aSet);
end;

procedure TJSONWriterImpl.WriteRoot(const value : IYAMLValue; const endComments : TArray<string>);
var
  i : integer;
  comments : TArray<string>;
begin
  if not FJSON5 then
  begin
    WriteValue(value);
    exit;
  end;
  // the root's comments: those before it, on its line, and the document's after it
  if value.HasComments then
  begin
    comments := value.Comments;
    for i := 0 to Length(comments) - 1 do
    begin
      WriteCommentText5(comments[i]);
      FOut.WriteNewLine;
    end;
  end;
  WriteValue5(value);
  if value.Comment <> '' then
    WriteSameLineComment5(value.Comment);
  for i := 0 to Length(endComments) - 1 do
  begin
    FOut.WriteNewLine;
    WriteCommentText5(endComments[i]);
  end;
end;

{ JSON5 }

procedure TJSONWriterImpl.WriteValue5(const value : IYAMLValue);
begin
  case value.ValueType of
    TYAMLValueType.vtMapping  : WriteMapping5(value.AsMapping);
    TYAMLValueType.vtSequence : WriteSequence5(value.AsSequence);
    TYAMLValueType.vtSet      : WriteSequence5(value.AsSet);
  else
    WriteScalar5(value);
  end;
end;

// As WriteQuoted, with the JSON5 quote char. U+2028 and U+2029 are escaped as the JSON5
// spec recommends, so the text is also valid ECMAScript.
procedure TJSONWriterImpl.WriteQuoted5(const value : string);
var
  p : PChar;
  len, i, runStart : integer;
  ch : Char;
begin
  FOut.WriteChar(FQuote);
  p := PChar(Pointer(value));
  len := Length(value);
  i := 0;
  runStart := 0;
  while i < len do
  begin
    ch := p[i];
    if (ch >= ' ') and (ch <= FMaxPlainChar) and (ch <> FQuote) and (ch <> '\') and
       ((Ord(ch) < $D800) or (Ord(ch) > $DFFF)) and (ch <> #$2028) and (ch <> #$2029) then
    begin
      Inc(i);
      continue;
    end;
    if i > runStart then
      FOut.Write(@p[runStart], i - runStart);
    case ch of
      '"': FOut.Write('\"');
      '''': FOut.Write('\''');
      '\': FOut.Write('\\');
      #8: FOut.Write('\b');
      #12: FOut.Write('\f');
      #10: FOut.Write('\n');
      #13: FOut.Write('\r');
      #9: FOut.Write('\t');
    else
      FOut.Write('\u');
      FOut.Write(IntToHex(Ord(ch), 4));
    end;
    Inc(i);
    runStart := i;
  end;
  if len > runStart then
    FOut.Write(@p[runStart], len - runStart);
  FOut.WriteChar(FQuote);
end;

procedure TJSONWriterImpl.WriteKey5(const key : string);
var
  i : integer;
  plain : boolean;
begin
  plain := FUnquotedKeys and TJSON5CharUtils.IsIdentifierName(key);
  if plain and (FMaxPlainChar < #$FFFF) then
  begin
    // with EscapeNonASCII, only ASCII names are written as they are
    for i := 1 to Length(key) do
    begin
      if key[i] > FMaxPlainChar then
      begin
        plain := false;
        break;
      end;
    end;
  end;
  if plain then
    FOut.Write(key)
  else
    WriteQuoted5(key);
end;

// a comment is written on one line
function SingleLine(const text : string) : string;
var
  i : integer;
begin
  result := text;
  for i := 1 to Length(result) do
  begin
    case result[i] of
      #10, #13, #$2028, #$2029 : result[i] := ' ';
    end;
  end;
end;

procedure TJSONWriterImpl.WriteCommentText5(const text : string);
begin
  FOut.Write('//');
  if text <> '' then
  begin
    FOut.WriteChar(' ');
    FOut.Write(SingleLine(text));
  end;
end;

// Comments before an entry or a closing bracket, each on a line of its own. In compact
// output a line break follows them, so the next token does not end up in the last one.
procedure TJSONWriterImpl.WriteCommentLines5(const comments : TArray<string>);
var
  i : integer;
begin
  for i := 0 to Length(comments) - 1 do
  begin
    if FPrettyPrint then
      WriteNewlineAndIndent
    else
      FOut.WriteNewLine;
    WriteCommentText5(comments[i]);
  end;
  if not FPrettyPrint then
    FOut.WriteNewLine;
end;

// After a value and its comma. Pretty printed output always starts a new line next; compact
// output uses /* */ so the rest can follow on the same line.
procedure TJSONWriterImpl.WriteSameLineComment5(const text : string);
var
  line : string;
begin
  line := SingleLine(text);
  if FPrettyPrint then
  begin
    FOut.WriteChar(' ');
    WriteCommentText5(line);
  end
  else if Pos('*/', line) = 0 then
  begin
    FOut.Write(' /* ');
    FOut.Write(line);
    FOut.Write(' */');
  end
  else
  begin
    FOut.WriteChar(' ');
    WriteCommentText5(line);
    FOut.WriteNewLine;
  end;
end;

procedure TJSONWriterImpl.WriteScalar5(const value : IYAMLValue);
var
  floatValue : Double;
  rawText : string;
  decimalText : string;
begin
  case value.ValueType of
    TYAMLValueType.vtNull :
      FOut.Write('null');
    TYAMLValueType.vtBoolean :
    begin
      if value.AsBoolean then
        FOut.Write('true')
      else
        FOut.Write('false');
    end;
    TYAMLValueType.vtInteger :
    begin
      // JSON5 number text (0x1F, +1 and JSON numbers) is written as it is; the YAML-only
      // forms (0o17, 1_000) are converted to decimal
      rawText := value.RawValue;
      if IsJSON5Number(rawText) then
        FOut.Write(rawText)
      else if YAMLIntegerToDecimalText(rawText, decimalText) then
        FOut.Write(decimalText)
      else
        FOut.Write(IntToStr(value.AsInteger));
    end;
    TYAMLValueType.vtFloat :
    begin
      rawText := value.RawValue;
      if IsJSON5Number(rawText) then
        FOut.Write(rawText)
      else
      begin
        floatValue := value.AsFloat;
        if IsNan(floatValue) then
          FOut.Write('NaN')
        else if IsInfinite(floatValue) then
        begin
          if floatValue > 0 then
            FOut.Write('Infinity')
          else
            FOut.Write('-Infinity');
        end
        else
          FOut.Write(FloatToStr(floatValue, YAMLFormatSettings));
      end;
    end;
  else
    // strings, and timestamps in their text form
    WriteQuoted5(value.AsString);
  end;
end;

procedure TJSONWriterImpl.WriteMapping5(const mapping : IYAMLMapping);
var
  priv : IYAMLMappingPrivate;
  i, count : integer;
  key : string;
  value : IYAMLValue;
  hasEndComments : boolean;
begin
  FOut.WriteChar('{');
  count := mapping.Count;
  hasEndComments := mapping.HasEndComments;
  if (count = 0) and not hasEndComments then
  begin
    FOut.WriteChar('}');
    exit;
  end;

  Inc(FIndentLevel);
  if not Supports(mapping, IYAMLMappingPrivate, priv) then
    priv := nil;
  for i := 0 to count - 1 do
  begin
    key := mapping.Keys[i];
    if priv <> nil then
      value := priv.ValueAt(i)
    else
      value := mapping.Values[key];

    if value.HasComments then
      WriteCommentLines5(value.Comments);
    WriteNewlineAndIndent;
    WriteKey5(key);
    FOut.WriteChar(':');
    if FPrettyPrint then
      FOut.WriteChar(' ');
    WriteValue5(value);
    if (i < count - 1) or FTrailingCommas then
      FOut.WriteChar(',');
    if value.Comment <> '' then
      WriteSameLineComment5(value.Comment);
  end;
  if hasEndComments then
    WriteCommentLines5(mapping.EndComments);
  Dec(FIndentLevel);
  WriteNewlineAndIndent;
  FOut.WriteChar('}');
end;

procedure TJSONWriterImpl.WriteSequence5(const sequence : IYAMLSequence);
var
  i, count : integer;
  item : IYAMLValue;
  hasEndComments : boolean;
begin
  FOut.WriteChar('[');
  count := sequence.Count;
  hasEndComments := sequence.HasEndComments;
  if (count = 0) and not hasEndComments then
  begin
    FOut.WriteChar(']');
    exit;
  end;

  Inc(FIndentLevel);
  for i := 0 to count - 1 do
  begin
    item := sequence[i];
    if item.HasComments then
      WriteCommentLines5(item.Comments);
    WriteNewlineAndIndent;
    WriteValue5(item);
    if (i < count - 1) or FTrailingCommas then
      FOut.WriteChar(',');
    if item.Comment <> '' then
      WriteSameLineComment5(item.Comment);
  end;
  if hasEndComments then
    WriteCommentLines5(sequence.EndComments);
  Dec(FIndentLevel);
  WriteNewlineAndIndent;
  FOut.WriteChar(']');
end;

function TJSONWriterImpl.WriteToString(const value : IYAMLValue) : string;
begin
  FreeAndNil(FOut);
  FOut := TYAMLOutputBuffer.CreateForString;
  try
    WriteRoot(value, nil);
    result := FOut.ExtractString;
  finally
    FreeAndNil(FOut);
  end;
end;

function TJSONWriterImpl.WriteToString(const doc : IYAMLDocument) : string;
begin
  FreeAndNil(FOut);
  FOut := TYAMLOutputBuffer.CreateForString;
  try
    if doc.HasEndComments then
      WriteRoot(doc.Root, doc.EndComments)
    else
      WriteRoot(doc.Root, nil);
    result := FOut.ExtractString;
  finally
    FreeAndNil(FOut);
  end;
end;

procedure TJSONWriterImpl.WriteToFile(const value : IYAMLValue; const fileName : string);
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

procedure TJSONWriterImpl.WriteToFile(const doc : IYAMLDocument; const fileName : string);
var
  fileStream : TFileStream;
begin
  fileStream := TFileStream.Create(fileName,  fmCreate);
  try
    WriteToStream(doc, fileStream);
  finally
    fileStream.Free;
  end;
end;

procedure TJSONWriterImpl.WriteToStream(const value : IYAMLValue; const stream : TStream);
begin
  FreeAndNil(FOut);
  FOut := TYAMLOutputBuffer.CreateForStream(stream, FOptions.Encoding, FOptions.WriteByteOrderMark);
  try
    WriteRoot(value, nil);
    FOut.Flush;
  finally
    FreeAndNil(FOut);
  end;
end;

procedure TJSONWriterImpl.WriteToStream(const doc : IYAMLDocument; const stream : TStream);
begin
  FreeAndNil(FOut);
  FOut := TYAMLOutputBuffer.CreateForStream(stream, FOptions.Encoding, FOptions.WriteByteOrderMark);
  try
    if doc.HasEndComments then
      WriteRoot(doc.Root, doc.EndComments)
    else
      WriteRoot(doc.Root, nil);
    FOut.Flush;
  finally
    FreeAndNil(FOut);
  end;
end;

end.

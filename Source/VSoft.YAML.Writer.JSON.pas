unit VSoft.YAML.Writer.JSON;

interface

{$I 'VSoft.YAML.inc'}


uses
  System.SysUtils,
  System.Classes,
  VSoft.YAML.StreamWriter,
  VSoft.YAML;

type
  // Main JSON writer class
  TJSONWriterImpl = class
  private
    FOptions : IYAMLEmitOptions;
    FPrettyPrint : boolean;
    FMaxPlainChar : Char; // characters past this are \u escaped (#126 with EscapeNonASCII)
    FOut : TYAMLOutputBuffer;
    FIndentLevel : UInt32;

    // Writes value as a JSON string literal (quotes included)
    procedure WriteQuoted(const value : string);
    procedure WriteNewlineAndIndent;inline;

    // Core writing methods
    procedure WriteValue(const value : IYAMLValue);
    procedure WriteMapping(const mapping : IYAMLMapping);
    procedure WriteSequence(const sequence : IYAMLSequence);
    procedure WriteSet(const aSet : IYAMLSet);
    procedure WriteScalar(const value : IYAMLValue);

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

  end;

implementation

uses
  System.Math,
  VSoft.YAML.Classes, VSoft.YAML.Utils;

{ TJSONWriterImpl }

constructor TJSONWriterImpl.Create(const options : IYAMLEmitOptions);
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
    TYAMLValueType.vtTimestamp :
    begin
      FOut.WriteChar('"');
      FOut.Write(value.AsString);
      FOut.WriteChar('"');
    end;
  else
    WriteQuoted(value.AsString);
  end;
end;

procedure TJSONWriterImpl.WriteValue(const value : IYAMLValue);
begin
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

function TJSONWriterImpl.WriteToString(const value : IYAMLValue) : string;
begin
  FreeAndNil(FOut);
  FOut := TYAMLOutputBuffer.CreateForString;
  try
    WriteValue(value);
    result := FOut.ExtractString;
  finally
    FreeAndNil(FOut);
  end;
end;

function TJSONWriterImpl.WriteToString(const doc : IYAMLDocument) : string;
begin
  result := WriteToString(doc.Root)
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
begin
  WriteToFile(doc.Root, fileName);
end;

procedure TJSONWriterImpl.WriteToStream(const value : IYAMLValue; const stream : TStream);
begin
  FreeAndNil(FOut);
  FOut := TYAMLOutputBuffer.CreateForStream(stream, FOptions.Encoding, FOptions.WriteByteOrderMark);
  try
    WriteValue(value);
    FOut.Flush;
  finally
    FreeAndNil(FOut);
  end;
end;

procedure TJSONWriterImpl.WriteToStream(const doc : IYAMLDocument; const stream : TStream);
begin
   WriteToStream(doc.Root, stream);
end;

end.

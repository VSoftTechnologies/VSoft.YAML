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
    FWriter : TYAMLWriter;
    FIndentLevel : UInt32;
    FStringBuilder : TStringBuilder;

    // Helper methods for formatting
    function FormatScalar(const value : IYAMLValue) : string;

    // Direct writing helpers
    procedure WriteIndent;inline;
    procedure WriteNewlineAndIndent;inline;

    // Core writing methods
    procedure WriteValue(const value : IYAMLValue);
    procedure WriteMapping(const mapping : IYAMLMapping);
    procedure WriteSequence(const sequence : IYAMLSequence);
    procedure WriteSet(const aSet : IYAMLSet);
    procedure WriteScalar(const value : IYAMLValue);

    // Utility methods
    procedure WriteString(const str : string);inline;
    function IsFirstItem(const index : integer) : boolean;inline;
    procedure IncIndent;inline;
    procedure DecIndent;inline;


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
  VSoft.YAML.Classes, VSoft.YAML.Utils;

{ TJSONWriterImpl }

constructor TJSONWriterImpl.Create(const options : IYAMLEmitOptions);
begin
  inherited Create;
  // cloning options as we may need to modify them depending on methods called
  FOptions := options.Clone;
  FPrettyPrint := FOptions.PrettyPrint;
  FWriter := nil;
  FIndentLevel := 0;
  FStringBuilder := TStringBuilder.Create(1024);
end;

destructor TJSONWriterImpl.Destroy;
begin
  //do not free FWriter here we do not own it.
  FStringBuilder.Free;
  inherited Destroy;
end;
procedure TJSONWriterImpl.IncIndent;
begin
  Inc(FIndentLevel);
end;

procedure TJSONWriterImpl.DecIndent;
begin
  Dec(FIndentLevel);
end;

procedure TJSONWriterImpl.WriteIndent;
begin
  FWriter.Write(TYAMLCharUtils.SpaceStr(FIndentLevel * FOptions.IndentSize));
end;

procedure TJSONWriterImpl.WriteNewlineAndIndent;
begin
  if FPrettyPrint then
  begin
    FWriter.Write(sLineBreak);
    WriteIndent;
  end;
end;

function TJSONWriterImpl.FormatScalar(const value : IYAMLValue) : string;
begin
  FStringBuilder.Reset;
  case value.ValueType of
    TYAMLValueType.vtNull :
      FStringBuilder.Append('null');
    TYAMLValueType.vtBoolean :
    begin
      if value.AsBoolean then
        FStringBuilder.Append('true')
      else
        FStringBuilder.Append('false');
    end;
    TYAMLValueType.vtInteger :
      FStringBuilder.Append(IntToStr(value.AsInteger));
    TYAMLValueType.vtFloat :
      FStringBuilder.Append(FloatToStr(value.AsFloat, YAMLFormatSettings));
    TYAMLValueType.vtString :
    begin
      FStringBuilder.Append('"');
      TYAMLCharUtils.EscapeStringForJSON(value.AsString, FStringBuilder);
      FStringBuilder.Append('"');
    end;
    TYAMLValueType.vtTimestamp :
    begin
      FStringBuilder.Append('"');
      FStringBuilder.Append(value.AsString);
      FStringBuilder.Append('"');
    end;
    else
    begin
      FStringBuilder.Append('"');
      TYAMLCharUtils.EscapeStringForJSON(value.AsString, FStringBuilder);
      FStringBuilder.Append('"');
    end;
  end;
  result := FStringBuilder.ToString;
end;

procedure TJSONWriterImpl.WriteString(const str : string);
begin
//  Assert(FWriter <> nil);
  FWriter.Write(str);
end;

function TJSONWriterImpl.IsFirstItem(const index : integer) : boolean;
begin
  result := index = 0;
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
  i : integer;
  key : string;
  value : IYAMLValue;
  count : integer;
begin
  WriteString('{');

  count := mapping.Count;

  if count > 0 then
  begin
    IncIndent;
    for i := 0 to count - 1 do
    begin
      if not IsFirstItem(i) then
        WriteString(',');

      FStringBuilder.Reset;
      WriteNewlineAndIndent;

      key := mapping.Keys[i];
      value := mapping.Values[key];

      FStringBuilder.Append('"');
      TYAMLCharUtils.EscapeStringForJSON(key, FStringBuilder);
      FStringBuilder.Append('":');
      if FPrettyPrint then
        FStringBuilder.Append(' ');

      WriteString(FStringBuilder.ToString);
      WriteValue(value);
    end;
    DecIndent;
    FStringBuilder.Reset;
    WriteNewlineAndIndent;
    WriteString(FStringBuilder.ToString);
  end;

  WriteString('}');
end;

procedure TJSONWriterImpl.WriteSequence(const sequence : IYAMLSequence);
var
  i : integer;
  item : IYAMLValue;
  count : integer;
begin
  WriteString('[');

  count := sequence.Count;
  if count > 0 then
  begin
    IncIndent;
    for i := 0 to count - 1 do
    begin
      if not IsFirstItem(i) then
        WriteString(',');

      FStringBuilder.Reset;
      WriteNewlineAndIndent;
      WriteString(FStringBuilder.ToString);

      item := sequence[i];
      WriteValue(item);
    end;
    DecIndent;
    FStringBuilder.Reset;
    WriteNewlineAndIndent;
    WriteString(FStringBuilder.ToString);
  end;
  WriteString(']');
end;

procedure TJSONWriterImpl.WriteSet(const aSet : IYAMLSet);
var
  i : integer;
  item : IYAMLValue;
begin
  // JSON doesn't have sets, so write as array
  WriteString('[');

  if aSet.Count > 0 then
  begin
    IncIndent;
    for i := 0 to aSet.Count - 1 do
    begin
      if not IsFirstItem(i) then
        WriteString(',');

      FStringBuilder.Reset;
      WriteNewlineAndIndent;
      WriteString(FStringBuilder.ToString);

      item := aSet[i];
      WriteValue(item);
    end;
    DecIndent;
    FStringBuilder.Reset;
    WriteNewlineAndIndent;
    WriteString(FStringBuilder.ToString);
  end;

  WriteString(']');
end;

procedure TJSONWriterImpl.WriteScalar(const value : IYAMLValue);
begin
  WriteString(FormatScalar(value));
end;

function TJSONWriterImpl.WriteToString(const value : IYAMLValue) : string;
begin
  FWriter := TYAMLStringWriter.Create;
  try
    WriteValue(value);
    result := FWriter.ToString;
  finally
    FreeAndNil(FWriter);
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
    FWriter.Free;
    fileStream.Free;
  end;
end;

procedure TJSONWriterImpl.WriteToFile(const doc : IYAMLDocument; const fileName : string);
begin
  WriteToFile(doc.Root, fileName);
end;

procedure TJSONWriterImpl.WriteToStream(const value : IYAMLValue; const stream : TStream);
var
  ownsWriter : boolean;
begin
  ownsWriter := false;
  //if called from WriteToStream(doc) then the writer will already exist
  if FWriter = nil then
  begin
    FWriter := TYAMLStreamWriter.Create(stream, FOptions.WriteByteOrderMark, FOptions.Encoding);
    ownsWriter := true;
  end;
  try
    WriteValue(value);
  finally
    if ownsWriter then
      FreeAndNil(FWriter);
  end;
end;

procedure TJSONWriterImpl.WriteToStream(const doc : IYAMLDocument; const stream : TStream);
begin
   WriteToStream(doc.Root, stream);
end;

end.

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
    FWriter : TYAMLStreamWriter;
    FIndentLevel : UInt32;

    // Helper methods for formatting
    function FormatScalar(const value : IYAMLValue) : string;
    function GetIndent : string;
    function GetNewlineAndIndent : string;

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
    procedure WriteToStream(const doc : IYAMLDocument; writeBOM : boolean; const stream : TStream);overload;

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
  FWriter := nil;
  FIndentLevel := 0;
end;

destructor TJSONWriterImpl.Destroy;
begin
  //do not free FWriter here we do not own it.
  inherited Destroy;
end;

function TJSONWriterImpl.GetIndent : string;
begin
  result := StringOfChar(' ', FIndentLevel * FOptions.IndentSize);
end;

function TJSONWriterImpl.GetNewlineAndIndent : string;
begin
  if FOptions.PrettyPrint then
    result := sLineBreak + GetIndent
  else
    result := '';
end;

procedure TJSONWriterImpl.IncIndent;
begin
  Inc(FIndentLevel);
end;

procedure TJSONWriterImpl.DecIndent;
begin
  Dec(FIndentLevel);
end;

function TJSONWriterImpl.FormatScalar(const value : IYAMLValue) : string;
begin
  case value.ValueType of
    TYAMLValueType.vtNull :
      result := 'null';
    TYAMLValueType.vtBoolean :
    begin
      if value.AsBoolean then
        result := 'true'
      else
        result := 'false';
    end;
    TYAMLValueType.vtInteger : 
      result := IntToStr(value.AsInteger);
    TYAMLValueType.vtFloat :   
      result := FloatToStr(value.AsFloat, YAMLFormatSettings);
    TYAMLValueType.vtString :
      result := '"' + TYAMLCharUtils.EscapeStringForJSON(value.AsString) + '"';
    TYAMLValueType.vtTimestamp :
      result := '"' + value.AsString + '"';  // Convert timestamp to ISO8601 string
  else
    result := '"' + TYAMLCharUtils.EscapeStringForJSON(value.AsString) + '"';
  end;
end;

procedure TJSONWriterImpl.WriteString(const str : string);
begin
  Assert(FWriter <> nil);
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
begin
  WriteString('{');
  
  if mapping.Count > 0 then
  begin
    IncIndent;
    for i := 0 to mapping.Count - 1 do
    begin
      if not IsFirstItem(i) then
        WriteString(',');
      
      WriteString(GetNewlineAndIndent);
      
      key := mapping.Keys[i];
      value := mapping.Values[key];
      
      WriteString('"' + TYAMLCharUtils.EscapeStringForJSON(key) + '":');
      if FOptions.PrettyPrint then
        WriteString(' ');
      WriteValue(value);
    end;
    DecIndent;
    WriteString(GetNewlineAndIndent);
  end;
  
  WriteString('}');
end;

procedure TJSONWriterImpl.WriteSequence(const sequence : IYAMLSequence);
var
  i : integer;
  item : IYAMLValue;
begin
  WriteString('[');
  
  if sequence.Count > 0 then
  begin
    IncIndent;
    for i := 0 to sequence.Count - 1 do
    begin
      if not IsFirstItem(i) then
        WriteString(',');
      
      WriteString(GetNewlineAndIndent);
      
      item := sequence[i];
      WriteValue(item);
    end;
    DecIndent;
    WriteString(GetNewlineAndIndent);
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
      
      WriteString(GetNewlineAndIndent);
      
      item := aSet[i];
      WriteValue(item);
    end;
    DecIndent;
    WriteString(GetNewlineAndIndent);
  end;
  
  WriteString(']');
end;

procedure TJSONWriterImpl.WriteScalar(const value : IYAMLValue);
begin
  WriteString(FormatScalar(value));
end;

function TJSONWriterImpl.WriteToString(const value : IYAMLValue) : string;
var
  stream : TStringStream;
begin
  //force utf16 to avoid round trip encoding conversions
  FOptions.Encoding := TEncoding.Unicode;
  stream := TStringStream.Create('', FOptions.Encoding, false);
  try
    WriteToStream(value, stream);
    result := stream.DataString;
  finally
    stream.Free;
  end;
end;

function TJSONWriterImpl.WriteToString(const doc : IYAMLDocument) : string;
var
  stream : TStringStream;
begin
  //force utf16 to avoid round trip encoding conversions
  FOptions.Encoding := TEncoding.Unicode;
  stream := TStringStream.Create('', FOptions.Encoding, false);
  try
    //WriteToStream will create the writer
    WriteToStream(doc, false, stream);
    result := stream.DataString;
  finally
    stream.Free;
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
  fileStream := TFileStream.Create(fileName, fmCreate);
  try
    WriteToStream(doc, FOptions.WriteByteOrderMark, fileStream);
  finally
    fileStream.Free;
  end;
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

procedure TJSONWriterImpl.WriteToStream(const doc : IYAMLDocument; writeBOM : boolean; const stream : TStream);
begin
  FWriter := TYAMLStreamWriter.Create(stream, writeBOM, FOptions.Encoding);
  try
    WriteToStream(doc.Root, stream);
  finally
    FreeAndNil(FWriter);
  end;
end;

end.

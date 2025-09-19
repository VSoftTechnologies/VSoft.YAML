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
    FOptions : IYAMLEmitOptions;
    FWriter : TYAMLStreamWriter;

    // Helper methods for formatting
    function GetIndent : string;
    function NeedsQuoting(const value : string) : boolean;
    function ShouldUseDoubleQuotes(const value : string) : boolean;
    function EscapeString(const value : string) : string;
    function EscapeForSingleQuotes(const value : string) : string;
    function FormatKey(const key : string) : string;
    function FormatScalar(const value : IYAMLValue) : string;
    function GetFormattedTag(const value : IYAMLValue) : string;

    // Core writing methods
    procedure WriteValue(const value : IYAMLValue);
    procedure WriteMapping(const mapping : IYAMLMapping);
    procedure WriteSequence(const sequence : IYAMLSequence);
    procedure WriteSet(const ASet : IYAMLSet);
    procedure WriteScalar(const value : IYAMLValue);

    // Flow style methods
    procedure WriteMappingFlow(const mapping : IYAMLMapping; const mapKey : string = '');
    procedure WriteSequenceFlow(const sequence : IYAMLSequence; const key : string = '');

    function WriteNestedMappingFlow(const mapping : IYAMLMapping) : string;
    function WriteNestedSequenceFlow(const sequence : IYAMLSequence) : string;
    function WriteNestedSetFlow(const ASet : IYAMLSet) : string;

    // Sequence-specific mapping writer
    procedure WriteSequenceMapping(mapping : IYAMLMapping);

    // Utility methods
    function ShouldUseFlowStyle(const value : IYAMLValue) : boolean;
    procedure AddLine(const ALine : string);inline;
    procedure IncIndent;inline;
    procedure DecIndent;inline;
    function AddCommentToLine(const line : string; const comment : string) : string;
    procedure WriteCollectionComments(const collection : IYAMLCollection);

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
  VSoft.YAML.Classes;

{ TYAMLWriterImpl }


constructor TYAMLWriterImpl.Create(const options : IYAMLEmitOptions);
begin
  inherited Create;
  // cloning options as we may need to modify them depending on methods called
  FOptions := options.Clone;
  FIndentLevel := 0;
  FWriter := nil;
end;

destructor TYAMLWriterImpl.Destroy;
begin
  //do not free FWriter here we do not own it.
  inherited Destroy;
end;

function TYAMLWriterImpl.GetIndent : string;
begin
  result := StringOfChar(' ', FIndentLevel * FOptions.IndentSize);
end;

function TYAMLWriterImpl.NeedsQuoting(const value : string) : boolean;
var
  i : integer;
  hasSpecialChars : boolean;
  intVal : integer;
  floatVal : Double;
begin
  // Always quote if option is set
  if FOptions.QuoteStrings then
    exit(True);

  // Empty string needs quoting
  if value = '' then
    exit(True);

  // Check for special YAML values that need quoting
  if (value = 'true') or (value = 'false') or
     (value = 'null') or (value = '~') or
     (value = 'yes') or (value = 'no') or
     (value = 'on') or (value = 'off') then
    exit(True);

  // Check if it looks like a number
  if TryStrToInt(value, intVal) or TryStrToFloat(value, floatVal, YAMLFormatSettings) then
    exit(True);

  // Check for special characters
  hasSpecialChars := False;
  {$HIGHCHARUNICODE ON}
  for i := 1 to Length(value) do
  begin
    case value[i] of
      ':', '[', ']', '{', '}', ',', '"', '''', '|', '>',
      '#', '&', '*', '!', '%', '@', '`', '\':
        begin
          hasSpecialChars := True;
          Break; // Exit early once special char found
        end;
      #0..#31, #127:
        begin
          hasSpecialChars := True;
          Break; // Exit early once special char found
        end;
      #$85, #$A0, #$2028, #$2029:
        begin
          hasSpecialChars := True;
          Break; // Exit early once special char found
        end;
    end;
  end;
  {$HIGHCHARUNICODE OFF}

  // Check for leading/trailing whitespace
  if (Length(value) > 0) and ((value[1] = ' ') or (value[Length(value)] = ' ')) then
    hasSpecialChars := True;

  result := hasSpecialChars;
end;

function TYAMLWriterImpl.EscapeString(const value : string) : string;
var
  i : integer;
begin
  result := '';
  {$HIGHCHARUNICODE ON}
  for i := 1 to Length(value) do
  begin
    case value[i] of
      #0: result := result + '\0';     // Null character
      #7: result := result + '\a';     // Bell character
      #8: result := result + '\b';     // Backspace
      #9: result := result + '\t';     // Horizontal tab
      #10: result := result + '\n';    // Line feed
      #11: result := result + '\v';    // Vertical tab
      #12: result := result + '\f';    // Form feed
      #13: result := result + '\r';    // Carriage return
      #27: result := result + '\e';    // Escape character
      '"': result := result + '\"';    // Double quote
      '\': result := result + '\\';    // Backslash
      // Unicode characters that YAML requires escaping
      #$85: result := result + '\N';   // Next line (NEL)
      #$A0: result := result + '\_';   // Non-breaking space
      #$2028: result := result + '\L'; // Line separator
      #$2029: result := result + '\P'; // Paragraph separator
      else
        result := result + value[i];
    end;
  end;
 {$HIGHCHARUNICODE OFF}
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
      #$85:        // Next line (NEL)
        exit(True);
      #$A0:        // Non-breaking space
        exit(True);
      #$2028:      // Line separator
        exit(True);
      #$2029:      // Paragraph separator
        exit(True);
    end;
  end;
  {$HIGHCHARUNICODE OFF}
  result := False;
end;

function TYAMLWriterImpl.EscapeForSingleQuotes(const value : string) : string;
var
  i : integer;
begin
  result := '';
  for i := 1 to Length(value) do
  begin
    if value[i] = '''' then
      result := result + '''''' // Double the single quote
    else
      result := result + value[i]; // All other characters are literal
  end;
end;

function TYAMLWriterImpl.FormatKey(const key : string) : string;
begin
  if NeedsQuoting(key) then
  begin
    if ShouldUseDoubleQuotes(key) then
      result := '"' + EscapeString(key) + '"'
    else
      result := '''' + EscapeForSingleQuotes(key) + '''';
  end
  else
    result := key;
end;

function TYAMLWriterImpl.FormatScalar(const value : IYAMLValue) : string;
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
    TYAMLValueType.vtInteger : result := IntToStr(value.AsInteger);
    TYAMLValueType.vtFloat :   result := FloatToStr(value.AsFloat, YAMLFormatSettings );
    TYAMLValueType.vtString :
    begin
      if NeedsQuoting(value.AsString) then
      begin
        if ShouldUseDoubleQuotes(value.AsString) then
          result := '"' + EscapeString(value.AsString) + '"'
        else
          result := '''' + EscapeForSingleQuotes(value.AsString) + '''';
      end
      else
        result := value.AsString;
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
        result := (value.AsSequence.Count <= 5);
        if result then
        begin
          seq := value.AsSequence;
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

procedure TYAMLWriterImpl.AddLine(const ALine : string);
begin
  Assert(FWriter <> nil);
  FWriter.WriteLine(ALine);
end;

procedure TYAMLWriterImpl.IncIndent;
begin
  Inc(FIndentLevel);
end;

procedure TYAMLWriterImpl.DecIndent;
begin
  Dec(FIndentLevel);
end;

function TYAMLWriterImpl.AddCommentToLine(const line : string; const comment : string) : string;
begin
  if comment <> '' then
    result := line + ' # ' + comment
  else
    result := line;
end;

procedure TYAMLWriterImpl.WriteCollectionComments(const collection : IYAMLCollection);
var
  index : integer;
begin
  if collection.HasComments then
  begin
    for index := 0 to collection.Comments.Count - 1 do
      AddLine(GetIndent + '# ' + collection.Comments[index]);
  end;
end;

procedure TYAMLWriterImpl.WriteValue(const value : IYAMLValue);
begin
  case value.ValueType of
    TYAMLValueType.vtMapping  : WriteMapping(value.AsMapping);
    TYAMLValueType.vtSequence : WriteSequence(value.AsSequence);
    TYAMLValueType.vtSet      : WriteSet(value.AsSet);
  else
      WriteScalar(value);
  end;
end;

procedure TYAMLWriterImpl.WriteMapping(const mapping : IYAMLMapping);
var
  i : integer;
  key : string;
  value : IYAMLValue;
  tag : string;
begin
  WriteCollectionComments(mapping);
  
  if mapping.Count = 0 then
  begin
    AddLine(GetIndent + '{}');
    Exit;
  end;

  if ShouldUseFlowStyle(mapping) then
  begin
    WriteMappingFlow(mapping);
    Exit;
  end;


  for i := 0 to mapping.Count - 1 do
  begin
    key := mapping.Keys[i];
    value := mapping.Values[key];

    if FOptions.EmitTags then
      tag := GetFormattedTag(value)
    else
      tag := '';


    key := FormatKey(key);

    case value.ValueType of
      TYAMLValueType.vtSequence :
      begin
        if ShouldUseFlowStyle(value) then
          WriteSequenceFlow(value.AsSequence, key + ': ')
        else
        begin
          AddLine(GetIndent + key + ':' + tag);
          IncIndent;
          WriteValue(value);
          DecIndent;
        end;
      end;
      TYAMLValueType.vtSet :
      begin
        if ShouldUseFlowStyle(value) then
          WriteSequenceFlow(value.AsSet, key + ': ')
        else
        begin
          AddLine(GetIndent + key + ':' + tag);
          IncIndent;
          WriteValue(value);
          DecIndent;
        end;
      end;
      TYAMLValueType.vtMapping :
      begin
        if ShouldUseFlowStyle(value) then
          WriteMappingFlow(value.AsMapping, key + ': ')
        else
        begin
          AddLine(GetIndent + key + ':' + tag);
          IncIndent;
          WriteValue(value);
          DecIndent;
        end;
      end;

    else
      AddLine(AddCommentToLine(GetIndent + key + ': ' + tag + FormatScalar(value), value.Comment));
    end;

  end;
end;

procedure TYAMLWriterImpl.WriteSequence(const sequence : IYAMLSequence);
var
  i : integer;
  item : IYAMLValue;
begin
  WriteCollectionComments(sequence);
  
  if sequence.Count = 0 then
  begin
    AddLine(GetIndent + '[]');
    Exit;
  end;

  if ShouldUseFlowStyle(sequence) then
  begin
    WriteSequenceFlow(sequence);
    Exit;
  end;

  for i := 0 to sequence.Count - 1 do
  begin
    item := sequence[i];

    case item.ValueType of
      TYAMLValueType.vtSequence,
      TYAMLValueType.vtSet :
      begin
        AddLine(GetIndent + '-');
        IncIndent;
        WriteValue(item);
        DecIndent;
      end;
      TYAMLValueType.vtMapping : WriteSequenceMapping(item.AsMapping);
    else
      AddLine(AddCommentToLine(GetIndent + '- ' + FormatScalar(item), item.Comment));
    end;
  end;
end;

procedure TYAMLWriterImpl.WriteScalar(const value : IYAMLValue);
var
  formattedValue : string;
  lineWithComment : string;
begin
  formattedValue := FormatScalar(value);
  lineWithComment := AddCommentToLine(GetIndent + formattedValue, value.Comment);
  AddLine(lineWithComment);
end;

procedure TYAMLWriterImpl.WriteMappingFlow(const mapping : IYAMLMapping; const mapKey : string);
var
  i : integer;
  key : string;
  value : IYAMLValue;
  line : string;
  valueStr : string;
begin
  line := mapKey + '{';

  for i := 0 to mapping.Count - 1 do
  begin
    key := mapping.Keys[i];
    value := mapping.Values[key];

    if i > 0 then
      line := line + ', ';

    key := FormatKey(key);

    // Handle nested structures properly in flow style
    case value.ValueType of
      TYAMLValueType.vtMapping :
      begin
        if value.AsMapping.Count = 0 then
          valueStr := '{}'
        else
          valueStr := WriteNestedMappingFlow(value.AsMapping);
      end;
    TYAMLValueType.vtSequence :
      begin
        if value.AsSequence.Count = 0 then
          valueStr := '[]'
        else
          valueStr := WriteNestedSequenceFlow(value.AsSequence);
      end;
    else
      valueStr := FormatScalar(value);
    end;

    line := line + key + ': ' + valueStr;
  end;

  line := line + '}';
  AddLine(AddCommentToLine(GetIndent + line, mapping.Comment));
end;

function TYAMLWriterImpl.WriteNestedMappingFlow(const mapping : IYAMLMapping) : string;
var
  i : integer;
  key : string;
  value : IYAMLValue;
  valueStr : string;
begin
  result := '{';

  for i := 0 to mapping.Count - 1 do
  begin
    key := mapping.Keys[i];
    value := mapping.Values[key];

    if i > 0 then
      result := result + ', ';

    key := FormatKey(key);

    // Recursively handle nested structures
    case value.ValueType of
      TYAMLValueType.vtMapping :
      begin
        if value.AsMapping.Count = 0 then
          valueStr := '{}'
        else
          valueStr := WriteNestedMappingFlow(value.AsMapping);
      end;
      TYAMLValueType.vtSequence :
      begin
        if value.AsSequence.Count = 0 then
          valueStr := '[]'
        else
          valueStr := WriteNestedSequenceFlow(value.AsSequence);
      end;
      TYAMLValueType.vtSet :
      begin
        if value.AsSet.Count = 0 then
          valueStr := '[]'
        else
          valueStr := WriteNestedSetFlow(value.AsSet);
      end;
      else
        valueStr := FormatScalar(value);
    end;

    result := result + key + ': ' + valueStr;
  end;

  result := result + '}';
end;

function TYAMLWriterImpl.WriteNestedSequenceFlow(const sequence : IYAMLSequence) : string;
var
  i : integer;
  item : IYAMLValue;
  itemStr : string;
begin
  result := '[';

  for i := 0 to sequence.Count - 1 do
  begin
    item := sequence[i];

    if i > 0 then
      result := result + ', ';

    // Recursively handle nested structures
    case item.ValueType of
      TYAMLValueType.vtMapping :
      begin
        if item.AsMapping.Count = 0 then
          itemStr := '{}'
        else
          itemStr := WriteNestedMappingFlow(item.AsMapping);
      end;
      TYAMLValueType.vtSequence :
      begin
        if item.AsSequence.Count = 0 then
          itemStr := '[]'
        else
          itemStr := WriteNestedSequenceFlow(item.AsSequence);
      end;
      TYAMLValueType.vtSet :
      begin
        if item.AsSet.Count = 0 then
          itemStr := '[]'
        else
          itemStr := WriteNestedSetFlow(item.AsSet);
      end;
    else
        itemStr := FormatScalar(item);
    end;

    result := result + itemStr;
  end;

  result := result + ']';
end;

function TYAMLWriterImpl.WriteNestedSetFlow(const ASet : IYAMLSet) : string;
var
  i : integer;
  item : IYAMLValue;
  itemStr : string;
begin
  result := '[';

  for i := 0 to ASet.Count - 1 do
  begin
    item := ASet[i];

    if i > 0 then
      result := result + ', ';

    // Recursively handle nested structures
    case item.ValueType of
      TYAMLValueType.vtMapping :
      begin
        if item.AsMapping.Count = 0 then
          itemStr := '{}'
        else
          itemStr := WriteNestedMappingFlow(item.AsMapping);
      end;
      TYAMLValueType.vtSequence :
      begin
        if item.AsSequence.Count = 0 then
          itemStr := '[]'
        else
          itemStr := WriteNestedSequenceFlow(item.AsSequence);
      end;
      TYAMLValueType.vtSet :
      begin
        if item.AsSet.Count = 0 then
          itemStr := '[]'
        else
          itemStr := WriteNestedSetFlow(item.AsSet);
      end;
      else
        itemStr := FormatScalar(item);
    end;

    result := result + itemStr;
  end;

  result := result + ']';
end;


procedure TYAMLWriterImpl.WriteSequenceFlow(const sequence : IYAMLSequence; const key : string = '');
var
  i : integer;
  item : IYAMLValue;
  line : string;
  itemStr : string;
begin
  line := key + '[';

  for i := 0 to sequence.Count - 1 do
  begin
    item := sequence[i];

    if i > 0 then
      line := line + ', ';

    // Handle nested structures properly in flow style
    case item.ValueType of
      TYAMLValueType.vtMapping :
      begin
        if item.AsMapping.Count = 0 then
          itemStr := '{}'
        else
          itemStr := WriteNestedMappingFlow(item.AsMapping);
      end;
      TYAMLValueType.vtSequence :
      begin
        if item.AsSequence.Count = 0 then
          itemStr := '[]'
        else
          itemStr := WriteNestedSequenceFlow(item.AsSequence);
      end;
    else
      itemStr := FormatScalar(item);
    end;

    line := line + itemStr;
  end;

  line := line + ']';
  AddLine(AddCommentToLine(GetIndent + line, sequence.Comment));
end;

procedure TYAMLWriterImpl.WriteSequenceMapping(mapping : IYAMLMapping);
var
  i : integer;
  key : string;
  value : IYAMLValue;
  firstKey : boolean;
begin
  if mapping.Count = 0 then
  begin
    AddLine(GetIndent + '- {}');
    Exit;
  end;

  firstKey := True;
  for i := 0 to mapping.Count - 1 do
  begin
    key := mapping.Keys[i];
    value := mapping.Values[key];

    key := FormatKey(key);

    if firstKey then
    begin
      // First key-value pair goes on the same line as the dash
      case value.ValueType of
        TYAMLValueType.vtSequence :
        begin
          if ShouldUseFlowStyle(value) then
            AddLine(AddCommentToLine(GetIndent + '- ' + key + ': ' + WriteNestedSequenceFlow(value.AsSequence), value.Comment))
          else
          begin
            AddLine(GetIndent + '- ' + key + ':');
            IncIndent;
            WriteValue(value);
            DecIndent;
          end;
        end;
        TYAMLValueType.vtMapping :
        begin
          AddLine(GetIndent + '- ' + key + ':');
          IncIndent;
          WriteValue(value);
          DecIndent;
        end;
      else
        AddLine(AddCommentToLine(GetIndent + '- ' + key + ': ' + FormatScalar(value), value.Comment));
      end;
      firstKey := False;
    end
    else
    begin
      // Subsequent key-value pairs at the same indentation level as the first key

      case value.ValueType of
        TYAMLValueType.vtSequence :
        begin
          if ShouldUseFlowStyle(value) then
            AddLine(AddCommentToLine(GetIndent + '  ' + key + ': ' + WriteNestedSequenceFlow(value.AsSequence), value.Comment))
          else
          begin
            AddLine(GetIndent + '  ' + key + ':');
            IncIndent;
            IncIndent; // Extra indent for sequence context
            WriteValue(value);
            DecIndent;
            DecIndent;
          end;
        end;
        TYAMLValueType.vtMapping :
        begin
          AddLine(GetIndent + '  ' + key + ':');
          IncIndent;
          IncIndent; // Extra indent for sequence context
          WriteValue(value);
          DecIndent;
          DecIndent;
        end;
      else
        AddLine(AddCommentToLine(GetIndent + '  ' + key + ': ' + FormatScalar(value), value.Comment));
      end;
    end;
  end;

end;

procedure TYAMLWriterImpl.WriteSet(const ASet : IYAMLSet);
var
  i : integer;
  item : IYAMLValue;
begin
  WriteCollectionComments(ASet);
  
  if ASet.Count = 0 then
  begin
    AddLine(GetIndent + '[]');
    Exit;
  end;

//  UseFlow := ShouldUseFlowStyle(sequence);
  if ShouldUseFlowStyle(ASet) then
  begin
    WriteSequenceFlow(ASet);
    Exit;
  end;

  for i := 0 to ASet.Count - 1 do
  begin
    item := ASet[i];

    case item.ValueType of
      TYAMLValueType.vtSequence :
      begin
        AddLine(GetIndent + '?');
        IncIndent;
        WriteValue(item);
        DecIndent;
      end;
      TYAMLValueType.vtSet :
      begin
        AddLine(GetIndent + '?');
        IncIndent;
        WriteValue(item);
        DecIndent;
      end;
      TYAMLValueType.vtMapping : WriteSequenceMapping(item.AsMapping);
    else
      AddLine(AddCommentToLine(GetIndent + '? ' + FormatScalar(item), item.Comment));
    end;
  end;
end;

function TYAMLWriterImpl.WriteToString(const value : IYAMLValue) : string;
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

function TYAMLWriterImpl.WriteToString(const doc : IYAMLDocument) : string;
var
  stream : TStringStream;
begin
  FIndentLevel := 0;
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
    WriteToStream(doc, FOptions.WriteByteOrderMark, fileStream);
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
  if FWriter = nil then
  begin
    FWriter := TYAMLStreamWriter.Create(stream, FOptions.WriteByteOrderMark, FOptions.Encoding);
    ownsWriter := true;
  end;
  try
    //if we own the writer then we are responsible for writing markers
    if ownsWriter then
    begin
      if FOptions.EmitDocumentMarkers then
        FWriter.WriteLine('---');
    end;

    WriteValue(value);
    if ownsWriter then
    begin
      if FOptions.EmitDocumentMarkers then
        FWriter.WriteLine('---');
    end;

  finally
    if ownsWriter then
      FreeAndNil(FWriter);
  end;



end;

procedure TYAMLWriterImpl.WriteToStream(const doc : IYAMLDocument; writeBOM : boolean; const stream : TStream);
var
  i : integer;
begin
  FWriter := TYAMLStreamWriter.Create(stream, writeBOM, FOptions.Encoding);
  try
    if FOptions.EmitYAMLDirective then
      FWriter.WriteLine('%YAML ' + doc.Version.ToString);

    if FOptions.EmitTagDirectives then
    begin
      //skip the standard tag directives
      if doc.TagDirectives.Count > 2 then
      begin
        for i := 2 to doc.TagDirectives.Count -1 do
          FWriter.WriteLine('%TAG ' + doc.TagDirectives[i].ToString);
      end;
    end;

    if FOptions.EmitDocumentMarkers or FOptions.EmitTagDirectives or FOptions.EmitYAMLDirective then
      FWriter.WriteLine('---');

    WriteToStream(doc.Root,stream);

    if FOptions.EmitDocumentMarkers then
      FWriter.WriteLine('...') ;
  finally
    FreeAndNil(FWriter);
  end;

end;


end.

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
    FWriter : TYAMLWriter;
    FStringBuilder : TStringBuilder;

    // Helper methods for formatting
    function GetIndent : string;
    function NeedsQuoting(const value : string) : boolean;
    function ShouldUseDoubleQuotes(const value : string) : boolean;
    procedure EscapeString(const value : string; sb : TStringBuilder);overload;
    procedure EscapeForSingleQuotes(const value : string; sb : TStringBuilder);overload;
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
  FWriter := nil;
  FStringBuilder := TStringBuilder.Create(4096);
end;

destructor TYAMLWriterImpl.Destroy;
begin
  //do not free FWriter here we do not own it.
  FStringBuilder.Free;
  inherited Destroy;
end;

function TYAMLWriterImpl.GetIndent : string;
begin
  result := TYAMLCharUtils.SpaceStr(FIndentLevel * FOptions.IndentSize);
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

procedure TYAMLWriterImpl.EscapeString(const value: string; sb: TStringBuilder);
var
  i : integer;
begin
  {$HIGHCHARUNICODE ON}
  for i := 1 to Length(value) do
  begin
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
      else
        sb.Append(value[i]);
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

procedure TYAMLWriterImpl.EscapeForSingleQuotes(const value: string; sb: TStringBuilder);
var
  i : integer;
begin
  for i := 1 to Length(value) do
  begin
    if value[i] = '''' then
      sb.Append('''''') // Double the single quote
    else
      sb.Append(value[i]); // All other characters are literal
  end;
end;


function TYAMLWriterImpl.FormatKey(const key : string) : string;
var
  sb : TStringBuilder;
begin
  if NeedsQuoting(key) then
  begin
    sb := TStringBuilder.Create;
    try
      if ShouldUseDoubleQuotes(key) then
      begin
        sb.Append('"');
        EscapeString(key, sb);
        sb.Append('"');
      end
      else
      begin
        sb.Append('''');
        EscapeForSingleQuotes(key, sb);
        sb.Append('''');
      end;
      result := sb.ToString;
    finally
      sb.Free;
    end;
  end
  else
    result := key;
end;

function TYAMLWriterImpl.FormatScalar(const value : IYAMLValue) : string;
var
  sb : TStringBuilder;
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
        sb := TStringBuilder.Create;
        try
          if ShouldUseDoubleQuotes(value.AsString) then
          begin
            sb.Append('"');
            EscapeString(value.AsString, sb);
            sb.Append('"');
          end
          else
          begin
            sb.Append('''');
            EscapeForSingleQuotes(value.AsString, sb);
            sb.Append('''');
          end;
          result := sb.ToString;
        finally
          sb.Free;
        end;
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
    begin
      FStringBuilder.Reset;
      WriteIndent;
      FStringBuilder.Append('# ');
      FStringBuilder.Append(collection.Comments[index]);
      AddLine(FStringBuilder.ToString);
    end;
  end;
end;

procedure TYAMLWriterImpl.WriteIndent;
begin
  FStringBuilder.Append(TYAMLCharUtils.SpaceStr(FIndentLevel * FOptions.IndentSize));
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
    FStringBuilder.Reset;
    WriteIndent;
    FStringBuilder.Append('{}');
    AddLine(FStringBuilder.ToString);
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
          FStringBuilder.Reset;
          WriteIndent;
          FStringBuilder.Append(key);
          FStringBuilder.Append(':');
          FStringBuilder.Append(tag);
          AddLine(FStringBuilder.ToString);
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
          FStringBuilder.Reset;
          WriteIndent;
          FStringBuilder.Append(key);
          FStringBuilder.Append(':');
          FStringBuilder.Append(tag);
          AddLine(FStringBuilder.ToString);
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
          FStringBuilder.Reset;
          WriteIndent;
          FStringBuilder.Append(key);
          FStringBuilder.Append(':');
          FStringBuilder.Append(tag);
          AddLine(FStringBuilder.ToString);
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
    FStringBuilder.Reset;
    WriteIndent;
    FStringBuilder.Append('[]');
    AddLine(FStringBuilder.ToString);
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
        FStringBuilder.Reset;
        WriteIndent;
        FStringBuilder.Append('-');
        AddLine(FStringBuilder.ToString);
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
begin
  formattedValue := FormatScalar(value);
  FStringBuilder.Reset;
  WriteIndent;
  FStringBuilder.Append(formattedValue);
  AddLine(AddCommentToLine(FStringBuilder.ToString, value.Comment));
end;

procedure TYAMLWriterImpl.WriteMappingFlow(const mapping : IYAMLMapping; const mapKey : string);
var
  i : integer;
  key : string;
  value : IYAMLValue;
  valueStr : string;
  flowSB : TStringBuilder;
begin
  flowSB := TStringBuilder.Create(512);
  try
    flowSB.Append(mapKey);
    flowSB.Append('{');

    for i := 0 to mapping.Count - 1 do
    begin
      key := mapping.Keys[i];
      value := mapping.Values[key];

      if i > 0 then
        flowSB.Append(', ');

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

      flowSB.Append(key);
      flowSB.Append(': ');
      flowSB.Append(valueStr);
    end;

    flowSB.Append('}');
    AddLine(AddCommentToLine(GetIndent + flowSB.ToString, mapping.Comment));
  finally
    flowSB.Free;
  end;
end;

function TYAMLWriterImpl.WriteNestedMappingFlow(const mapping : IYAMLMapping) : string;
var
  i : integer;
  key : string;
  value : IYAMLValue;
  valueStr : string;
  sb : TStringBuilder;
begin
  sb := TStringBuilder.Create;
  try
    sb.Append('{');

  for i := 0 to mapping.Count - 1 do
  begin
    key := mapping.Keys[i];
    value := mapping.Values[key];

    if i > 0 then
      sb.Append(', ');

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

    sb.Append(key + ': ' + valueStr);
  end;

  sb.Append('}');
  result := sb.ToString;
  finally
    sb.Free;
  end;
end;

function TYAMLWriterImpl.WriteNestedSequenceFlow(const sequence : IYAMLSequence) : string;
var
  i : integer;
  item : IYAMLValue;
  itemStr : string;
  sb : TStringBuilder;
begin
  sb := TStringBuilder.Create;
  try
    sb.Append('[');

  for i := 0 to sequence.Count - 1 do
  begin
    item := sequence[i];

    if i > 0 then
      sb.Append(', ');

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

    sb.Append(itemStr);
  end;

  sb.Append(']');
  result := sb.ToString;
  finally
    sb.Free;
  end;
end;

function TYAMLWriterImpl.WriteNestedSetFlow(const ASet : IYAMLSet) : string;
var
  i : integer;
  item : IYAMLValue;
  itemStr : string;
  sb : TStringBuilder;
begin
  sb := TStringBuilder.Create;
  try
    sb.Append('[');

  for i := 0 to ASet.Count - 1 do
  begin
    item := ASet[i];

    if i > 0 then
      sb.Append(', ');

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

    sb.Append(itemStr);
  end;

  sb.Append(']');
  result := sb.ToString;
  finally
    sb.Free;
  end;
end;


procedure TYAMLWriterImpl.WriteSequenceFlow(const sequence : IYAMLSequence; const key : string = '');
var
  i : integer;
  item : IYAMLValue;
  itemStr : string;
  flowSB : TStringBuilder;
begin
  flowSB := TStringBuilder.Create(512);
  try
    flowSB.Append(key);
    flowSB.Append('[');

    for i := 0 to sequence.Count - 1 do
    begin
      item := sequence[i];

      if i > 0 then
        flowSB.Append(', ');

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

      flowSB.Append(itemStr);
    end;

    flowSB.Append(']');
    AddLine(AddCommentToLine(GetIndent + flowSB.ToString, sequence.Comment));
  finally
    flowSB.Free;
  end;
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
    FStringBuilder.Reset;
    WriteIndent;
    FStringBuilder.Append('- {}');
    AddLine(FStringBuilder.ToString);
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
            FStringBuilder.Reset;
            WriteIndent;
            FStringBuilder.Append('- ');
            FStringBuilder.Append(key);
            FStringBuilder.Append(':');
            AddLine(FStringBuilder.ToString);
            IncIndent;
            WriteValue(value);
            DecIndent;
          end;
        end;
        TYAMLValueType.vtMapping :
        begin
          FStringBuilder.Reset;
          WriteIndent;
          FStringBuilder.Append('- ');
          FStringBuilder.Append(key);
          FStringBuilder.Append(':');
          AddLine(FStringBuilder.ToString);
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
            FStringBuilder.Reset;
            WriteIndent;
            FStringBuilder.Append('  ');
            FStringBuilder.Append(key);
            FStringBuilder.Append(':');
            AddLine(FStringBuilder.ToString);
            IncIndent;
            IncIndent; // Extra indent for sequence context
            WriteValue(value);
            DecIndent;
            DecIndent;
          end;
        end;
        TYAMLValueType.vtMapping :
        begin
          FStringBuilder.Reset;
          WriteIndent;
          FStringBuilder.Append('  ');
          FStringBuilder.Append(key);
          FStringBuilder.Append(':');
          AddLine(FStringBuilder.ToString);
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
    FStringBuilder.Reset;
    WriteIndent;
    FStringBuilder.Append('[]');
    AddLine(FStringBuilder.ToString);
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
        FStringBuilder.Reset;
        WriteIndent;
        FStringBuilder.Append('?');
        AddLine(FStringBuilder.ToString);
        IncIndent;
        WriteValue(item);
        DecIndent;
      end;
      TYAMLValueType.vtSet :
      begin
        FStringBuilder.Reset;
        WriteIndent;
        FStringBuilder.Append('?');
        AddLine(FStringBuilder.ToString);
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
begin
  //force utf16 to avoid round trip encoding conversions
  FWriter := TYAMLStringWriter.Create;
  try
    WriteValue(value);
    result := FWriter.ToString;
  finally
    FreeAndNil(FWriter);
  end;
end;

function TYAMLWriterImpl.WriteToString(const doc : IYAMLDocument) : string;
var
  i : integer;
begin
  //force utf16 to avoid round trip encoding conversions
  FOptions.Encoding := TEncoding.Unicode;
  FWriter := TYAMLStringWriter.Create;
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

    WriteValue(doc.Root);
    if FOptions.EmitDocumentMarkers then
      FWriter.WriteLine('...') ;

    result := FWriter.ToString;
  finally
    FreeAndNil(FWriter);
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
  i : integer;
begin
  fileStream := TFileStream.Create(fileName, fmCreate);
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

    WriteToStream(doc.Root,fileStream);

    if FOptions.EmitDocumentMarkers then
      FWriter.WriteLine('...') ;

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
    WriteValue(value);
  finally
    if ownsWriter then
      FreeAndNil(FWriter);
  end;
end;

procedure TYAMLWriterImpl.WriteToStream(const doc : IYAMLDocument; const stream : TStream);
var
  i : integer;
begin
  FWriter := TYAMLStreamWriter.Create(stream, FOptions.WriteByteOrderMark, FOptions.Encoding);
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

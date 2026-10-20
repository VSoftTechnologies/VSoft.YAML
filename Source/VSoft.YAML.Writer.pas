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
    function ContainsLineBreaks(const value : string) : boolean;
    function ShouldUseBlockScalar(const value : IYAMLValue) : boolean;
    function GetChompingIndicator : string;
    procedure WriteBlockScalar(const value : string; const key : string; const tag : string);
    procedure WriteSequenceBlockScalar(const value : string);
    procedure WriteSequenceMappingBlockScalar(const value : string; const key : string; const prefix : string);

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
    procedure IncIndent;inline;
    procedure DecIndent;inline;
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
  intVal : integer;
  floatVal : Double;
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

  // Check for special YAML values that need quoting (only compare when the length fits)
  case len of
    1 : if value = '~' then exit(True);
    2 : if (value = 'no') or (value = 'on') then exit(True);
    3 : if (value = 'yes') or (value = 'off') then exit(True);
    4 : if (value = 'true') or (value = 'null') then exit(True);
    5 : if value = 'false' then exit(True);
  end;

  // Check if it looks like a number. The RTL parsers are slow, so only call them when
  // the first character could start something they accept: digits, sign, '.', the
  // '$' / 'x' / '0x' hex prefixes Val takes, or the INF / NAN text TextToFloat takes.
  case value[1] of
    '0'..'9', '+', '-', '.', '$', 'x', 'X', 'i', 'I', 'n', 'N':
      if TryStrToInt(value, intVal) or TryStrToFloat(value, floatVal, YAMLFormatSettings) then
        exit(True);
  end;

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
      #$85, #$A0, #$2028, #$2029:
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
    case value[i] of
      #0, #7..#13, #27, '"', '\', #$85, #$A0, #$2028, #$2029 : ;
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
    TYAMLValueType.vtFloat :
      if not YAMLCanonicalFloatText(value.RawValue, result) then
        result := YAMLFloatToStr(value.AsFloat);
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

function TYAMLWriterImpl.ContainsLineBreaks(const value : string) : boolean;
var
  i : integer;
begin
  result := False;
  for i := 1 to Length(value) do
  begin
    if (value[i] = #10) or (value[i] = #13) then
    begin
      result := True;
      Exit;
    end;
  end;
end;

function TYAMLWriterImpl.ShouldUseBlockScalar(const value : IYAMLValue) : boolean;
var
  str : string;
begin
  result := False;

  // Only for strings
  if value.ValueType <> TYAMLValueType.vtString then
    Exit;

  // Only if block scalar style is enabled
  if FOptions.BlockScalarStyle = TYAMLBlockScalarStyle.bssNone then
    Exit;

  str := value.AsString;

  // Empty strings should not use block scalars
  if str = '' then
    Exit;

  // Check if string contains line breaks
  result := ContainsLineBreaks(str);
end;

function TYAMLWriterImpl.GetChompingIndicator : string;
begin
  case FOptions.BlockChompingIndicator of
    TYAMLBlockChompingIndicator.bciStrip : result := '-';
    TYAMLBlockChompingIndicator.bciKeep : result := '+';
  else
    result := ''; // bciClip - no indicator needed (default)
  end;
end;

procedure TYAMLWriterImpl.WriteBlockScalar(const value : string; const key : string; const tag : string);
var
  lines : TStringList;
  i : integer;
  indicator : Char;
  lineContent : string;
begin
  // Determine block indicator based on style
  if FOptions.BlockScalarStyle = TYAMLBlockScalarStyle.bssFolded then
    indicator := '>'
  else
    indicator := '|';

  // Write the key and block indicator with chomping
  FOut.Write(FCurrentIndent);
  FOut.Write(key);
  FOut.Write(': ');
  FOut.Write(tag);
  FOut.Write(indicator);
  FOut.Write(GetChompingIndicator);
  FOut.WriteNewLine;

  // Split the value into lines and write each with proper indentation
  lines := TStringList.Create;
  try
    // Handle both CRLF and LF line endings
    lines.Text := value;

    IncIndent;
    for i := 0 to lines.Count - 1 do
    begin
      lineContent := lines[i];
      FOut.Write(FCurrentIndent);
      FOut.Write(lineContent);
      FOut.WriteNewLine;
    end;
    DecIndent;
  finally
    lines.Free;
  end;
end;

procedure TYAMLWriterImpl.WriteSequenceBlockScalar(const value : string);
var
  lines : TStringList;
  i : integer;
  indicator : Char;
  lineContent : string;
begin
  // Determine block indicator based on style
  if FOptions.BlockScalarStyle = TYAMLBlockScalarStyle.bssFolded then
    indicator := '>'
  else
    indicator := '|';

  // Write the dash and block indicator with chomping
  FOut.Write(FCurrentIndent);
  FOut.Write('- ');
  FOut.Write(indicator);
  FOut.Write(GetChompingIndicator);
  FOut.WriteNewLine;

  // Split the value into lines and write each with proper indentation
  lines := TStringList.Create;
  try
    // Handle both CRLF and LF line endings
    lines.Text := value;

    IncIndent;
    for i := 0 to lines.Count - 1 do
    begin
      lineContent := lines[i];
      FOut.Write(FCurrentIndent);
      FOut.Write(lineContent);
      FOut.WriteNewLine;
    end;
    DecIndent;
  finally
    lines.Free;
  end;
end;

procedure TYAMLWriterImpl.WriteSequenceMappingBlockScalar(const value : string; const key : string; const prefix : string);
var
  lines : TStringList;
  i : integer;
  indicator : Char;
  lineContent : string;
begin
  // Determine block indicator based on style
  if FOptions.BlockScalarStyle = TYAMLBlockScalarStyle.bssFolded then
    indicator := '>'
  else
    indicator := '|';

  // Write the prefix (e.g., '- ' or '  '), key and block indicator with chomping
  FOut.Write(FCurrentIndent);
  FOut.Write(prefix);
  FOut.Write(key);
  FOut.Write(': ');
  FOut.Write(indicator);
  FOut.Write(GetChompingIndicator);
  FOut.WriteNewLine;

  // Split the value into lines and write each with proper indentation
  lines := TStringList.Create;
  try
    // Handle both CRLF and LF line endings
    lines.Text := value;

    IncIndent;
    if prefix = '  ' then
      IncIndent; // Extra indent for non-first keys in sequence mapping
    for i := 0 to lines.Count - 1 do
    begin
      lineContent := lines[i];
      FOut.Write(FCurrentIndent);
      FOut.Write(lineContent);
      FOut.WriteNewLine;
    end;
    if prefix = '  ' then
      DecIndent;
    DecIndent;
  finally
    lines.Free;
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

procedure TYAMLWriterImpl.WriteCollectionComments(const collection : IYAMLCollection);
var
  index : integer;
begin
  if collection.HasComments then
  begin
    for index := 0 to collection.Comments.Count - 1 do
    begin
      WriteIndent;
      FOut.Write('# ');
      FOut.Write(collection.Comments[index]);
      FOut.WriteNewLine;
    end;
  end;
end;

procedure TYAMLWriterImpl.WriteIndent;
begin
  // Use cached indent string instead of recalculating each time
  FOut.Write(FCurrentIndent);
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
  priv : IYAMLMappingPrivate;
  i : integer;
  key : string;
  value : IYAMLValue;
  tag : string;
  valueStr : string;
begin
  WriteCollectionComments(mapping);

  if mapping.Count = 0 then
  begin
    WriteIndent;
    FOut.Write('{}');
    FOut.WriteNewLine;
    Exit;
  end;

  if ShouldUseFlowStyle(mapping) then
  begin
    WriteMappingFlow(mapping);
    Exit;
  end;


  if not Supports(mapping, IYAMLMappingPrivate, priv) then


    priv := nil;


  for i := 0 to mapping.Count - 1 do
  begin
    key := mapping.Keys[i];
    if priv <> nil then
      value := priv.ValueAt(i)
    else
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
          WriteIndent;
          FOut.Write(key);
          FOut.Write(':');
          FOut.Write(tag);
          FOut.WriteNewLine;
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
          WriteIndent;
          FOut.Write(key);
          FOut.Write(':');
          FOut.Write(tag);
          FOut.WriteNewLine;
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
          WriteIndent;
          FOut.Write(key);
          FOut.Write(':');
          FOut.Write(tag);
          FOut.WriteNewLine;
          IncIndent;
          WriteValue(value);
          DecIndent;
        end;
      end;

    else
      begin
        // Check if we should use block scalar style for multiline strings
        if ShouldUseBlockScalar(value) then
        begin
          WriteBlockScalar(value.AsString, key, tag);
        end
        else
        begin
          valueStr := FormatScalar(value);
          FOut.Write(FCurrentIndent);
          FOut.Write(key);
          FOut.Write(': ');
          FOut.Write(tag);
          FOut.Write(valueStr);
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
end;

procedure TYAMLWriterImpl.WriteSequence(const sequence : IYAMLSequence);
var
  i : integer;
  item : IYAMLValue;
  itemStr : string;
begin
  WriteCollectionComments(sequence);

  if sequence.Count = 0 then
  begin
    WriteIndent;
    FOut.Write('[]');
    FOut.WriteNewLine;
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
        WriteIndent;
        FOut.Write('-');
        FOut.WriteNewLine;
        IncIndent;
        WriteValue(item);
        DecIndent;
      end;
      TYAMLValueType.vtMapping : WriteSequenceMapping(item.AsMapping);
    else
      begin
        // Check if we should use block scalar style for multiline strings
        if ShouldUseBlockScalar(item) then
        begin
          WriteSequenceBlockScalar(item.AsString);
        end
        else
        begin
          itemStr := FormatScalar(item);
          FOut.Write(FCurrentIndent);
          FOut.Write('- ');
          FOut.Write(itemStr);
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
end;

procedure TYAMLWriterImpl.WriteScalar(const value : IYAMLValue);
var
  formattedValue : string;
begin
  formattedValue := FormatScalar(value);
  WriteIndent;
  FOut.Write(formattedValue);
  if value.Comment <> '' then
  begin
    FOut.Write(' # ');
    FOut.Write(value.Comment);
  end;
  FOut.WriteNewLine;
end;

procedure TYAMLWriterImpl.WriteMappingFlow(const mapping : IYAMLMapping; const mapKey : string);
var
  priv : IYAMLMappingPrivate;
  i : integer;
  key : string;
  value : IYAMLValue;
  valueStr : string;
begin
  FOut.Write(FCurrentIndent);
  FOut.Write(mapKey);
  FOut.WriteChar('{');

  if not Supports(mapping, IYAMLMappingPrivate, priv) then

    priv := nil;

  for i := 0 to mapping.Count - 1 do
  begin
    key := mapping.Keys[i];
    if priv <> nil then
      value := priv.ValueAt(i)
    else
      value := mapping.Values[key];

    if i > 0 then
      FOut.Write(', ');

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

    FOut.Write(key);
    FOut.Write(': ');
    FOut.Write(valueStr);
  end;

  FOut.Write('}');
  if mapping.Comment <> '' then
  begin
    FOut.Write(' # ');
    FOut.Write(mapping.Comment);
  end;
  FOut.WriteNewLine;
end;

function TYAMLWriterImpl.WriteNestedMappingFlow(const mapping : IYAMLMapping) : string;
var
  priv : IYAMLMappingPrivate;
  i : integer;
  key : string;
  value : IYAMLValue;
  valueStr : string;
  sb : TStringBuilder;
begin
  sb := TStringBuilder.Create;
  try
    sb.Append('{');

  if not Supports(mapping, IYAMLMappingPrivate, priv) then

    priv := nil;

  for i := 0 to mapping.Count - 1 do
  begin
    key := mapping.Keys[i];
    if priv <> nil then
      value := priv.ValueAt(i)
    else
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
begin
  FOut.Write(FCurrentIndent);
  FOut.Write(key);
  FOut.WriteChar('[');

  for i := 0 to sequence.Count - 1 do
  begin
    item := sequence[i];

    if i > 0 then
      FOut.Write(', ');

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

    FOut.Write(itemStr);
  end;

  FOut.Write(']');
  if sequence.Comment <> '' then
  begin
    FOut.Write(' # ');
    FOut.Write(sequence.Comment);
  end;
  FOut.WriteNewLine;
end;

procedure TYAMLWriterImpl.WriteSequenceMapping(mapping : IYAMLMapping);
var
  priv : IYAMLMappingPrivate;
  i : integer;
  key : string;
  value : IYAMLValue;
  valueStr : string;
  firstKey : boolean;
begin
  if mapping.Count = 0 then
  begin
    WriteIndent;
    FOut.Write('- {}');
    FOut.WriteNewLine;
    Exit;
  end;

  firstKey := True;
  if not Supports(mapping, IYAMLMappingPrivate, priv) then
    priv := nil;
  for i := 0 to mapping.Count - 1 do
  begin
    key := mapping.Keys[i];
    if priv <> nil then
      value := priv.ValueAt(i)
    else
      value := mapping.Values[key];

    key := FormatKey(key);

    if firstKey then
    begin
      // First key-value pair goes on the same line as the dash
      case value.ValueType of
        TYAMLValueType.vtSequence :
        begin
          if ShouldUseFlowStyle(value) then
          begin
            valueStr := WriteNestedSequenceFlow(value.AsSequence);
            FOut.Write(FCurrentIndent);
            FOut.Write('- ');
            FOut.Write(key);
            FOut.Write(': ');
            FOut.Write(valueStr);
            if value.Comment <> '' then
            begin
              FOut.Write(' # ');
              FOut.Write(value.Comment);
            end;
            FOut.WriteNewLine;
          end
          else
          begin
            WriteIndent;
            FOut.Write('- ');
            FOut.Write(key);
            FOut.Write(':');
            FOut.WriteNewLine;
            IncIndent;
            WriteValue(value);
            DecIndent;
          end;
        end;
        TYAMLValueType.vtMapping :
        begin
          WriteIndent;
          FOut.Write('- ');
          FOut.Write(key);
          FOut.Write(':');
          FOut.WriteNewLine;
          IncIndent;
          WriteValue(value);
          DecIndent;
        end;
      else
        begin
          // Check if we should use block scalar style for multiline strings
          if ShouldUseBlockScalar(value) then
          begin
            WriteSequenceMappingBlockScalar(value.AsString, key, '- ');
          end
          else
          begin
            valueStr := FormatScalar(value);
            FOut.Write(FCurrentIndent);
            FOut.Write('- ');
            FOut.Write(key);
            FOut.Write(': ');
            FOut.Write(valueStr);
            if value.Comment <> '' then
            begin
              FOut.Write(' # ');
              FOut.Write(value.Comment);
            end;
            FOut.WriteNewLine;
          end;
        end;
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
          begin
            valueStr := WriteNestedSequenceFlow(value.AsSequence);
            FOut.Write(FCurrentIndent);
            FOut.Write('  ');
            FOut.Write(key);
            FOut.Write(': ');
            FOut.Write(valueStr);
            if value.Comment <> '' then
            begin
              FOut.Write(' # ');
              FOut.Write(value.Comment);
            end;
            FOut.WriteNewLine;
          end
          else
          begin
            WriteIndent;
            FOut.Write('  ');
            FOut.Write(key);
            FOut.Write(':');
            FOut.WriteNewLine;
            IncIndent;
            IncIndent; // Extra indent for sequence context
            WriteValue(value);
            DecIndent;
            DecIndent;
          end;
        end;
        TYAMLValueType.vtMapping :
        begin
          WriteIndent;
          FOut.Write('  ');
          FOut.Write(key);
          FOut.Write(':');
          FOut.WriteNewLine;
          IncIndent;
          IncIndent; // Extra indent for sequence context
          WriteValue(value);
          DecIndent;
          DecIndent;
        end;
      else
        begin
          // Check if we should use block scalar style for multiline strings
          if ShouldUseBlockScalar(value) then
          begin
            WriteSequenceMappingBlockScalar(value.AsString, key, '  ');
          end
          else
          begin
            valueStr := FormatScalar(value);
            FOut.Write(FCurrentIndent);
            FOut.Write('  ');
            FOut.Write(key);
            FOut.Write(': ');
            FOut.Write(valueStr);
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
  end;

end;

procedure TYAMLWriterImpl.WriteSet(const ASet : IYAMLSet);
var
  i : integer;
  item : IYAMLValue;
  itemStr : string;
begin
  WriteCollectionComments(ASet);

  if ASet.Count = 0 then
  begin
    WriteIndent;
    FOut.Write('[]');
    FOut.WriteNewLine;
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
        WriteIndent;
        FOut.Write('?');
        FOut.WriteNewLine;
        IncIndent;
        WriteValue(item);
        DecIndent;
      end;
      TYAMLValueType.vtSet :
      begin
        WriteIndent;
        FOut.Write('?');
        FOut.WriteNewLine;
        IncIndent;
        WriteValue(item);
        DecIndent;
      end;
      TYAMLValueType.vtMapping : WriteSequenceMapping(item.AsMapping);
    else
      begin
        itemStr := FormatScalar(item);
        FOut.Write(FCurrentIndent);
        FOut.Write('? ');
        FOut.Write(itemStr);
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
    WriteValue(value);
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

    WriteValue(doc.Root);
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
    WriteValue(value);
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

    if FOptions.EmitDocumentMarkers then
      FOut.WriteLine('...') ;
  finally
    FreeAndNil(FOut);
  end;

end;


end.

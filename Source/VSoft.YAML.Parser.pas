unit VSoft.YAML.Parser;

interface

uses
  System.Generics.Collections,
  System.Classes,
  VSoft.YAML,
  VSoft.YAML.Lexer;

{$I 'VSoft.YAML.inc'}

type
  // YAML Parser class
  TYAMLParser = class
  private
    FOptions : IYAMLParserOptions;
    FJSONMode : boolean;
    FLexer : TYAMLLexer;
    FCurrentToken : TYAMLToken;
    FCurrentIndentLevel : integer;
    FAnchorMap : TDictionary<string, IYAMLValue>;
    FPendingComments : TStringList;
    FLastTokenLine : integer;
    FIsDocumentLevel : boolean;
    
    // Directive processing fields
    FYAMLVersion : IYAMLVersionDirective;
    FHasYAMLDirective : boolean;
    FTagDirectives : TList<IYAMLTagDirective>;
  protected

    procedure RaiseParseError(const message : string);overload;{$IFDEF NORETURN}noreturn;{$ENDIF}
    procedure RaiseParseError(const fmt : string; const Args : array of const);overload;{$IFDEF NORETURN}noreturn;{$ENDIF}

    procedure NextToken;

    /// <summary>  Raises exception if the expected token </summary>
    procedure ExpectToken(tokenKind : TYAMLTokenKind);

    /// <summary>  if expected token then calls nexttoken and returns true </summary>
    function MatchToken(tokenKind : TYAMLTokenKind) : boolean;

    // Recursive descent parsing methods
    function ParseDocument : IYAMLValue;
    function ParseValue(const parent : IYAMLValue; const tag : string = '') : IYAMLValue;
    function ParseMapping(const parent : IYAMLValue; const tag : string; const firstKey : string = '') : IYAMLMapping;
    function ParseSet(const parent : IYAMLValue; const tag : string = '') : IYAMLSet;
    function ParseMappingOrSet(const parent : IYAMLValue; const tag : string = '') : IYAMLValue;
    function ParseSequence(const parent : IYAMLValue; const tag : string = '') : IYAMLSequence;
    function ParseScalar(const parent : IYAMLValue; const tag : string = '') : IYAMLValue;
    function ParseFlowMapping(const parent : IYAMLValue; const tag : string = '') : IYAMLMapping;
    function ParseFlowSequence(const parent : IYAMLValue; const tag : string = '') : IYAMLSequence;
    function ParseAnchoredValue(const parent : IYAMLValue; const tag : string = '') : IYAMLValue;
    function ParseAlias(const parent : IYAMLValue) : IYAMLValue;
    function ParseTaggedValue(const parent : IYAMLValue) : IYAMLValue;

    // Helper methods
    function IsTimestampPattern(const value : string) : boolean;
    function IsScalarValue(const value : string; jsonMode : boolean = false) : TYAMLValueType;
    procedure SkipNewlines;
    procedure RegisterAnchor(const anchorName : string; const value : IYAMLValue);
    function ResolveAlias(const aliasName : string) : IYAMLValue;
    
    // Comment handling methods
    procedure ProcessComment;
    procedure AssignPendingCommentsToCollection(const collection : IYAMLCollection);
    procedure AssignSameLineCommentToValue(const value : IYAMLValue; const commentText : string);
    procedure CheckForSameLineComment(const value : IYAMLValue);
    
    // Directive processing methods
    procedure ProcessDirective(const directiveText : string);
    procedure ParseYAMLDirective(const directiveContent : string);
    procedure ParseTAGDirective(const directiveContent : string);
    function ResolveTag(const tagText : string) : string;
    function CreateTagInfo(const tagText : string) : IYAMLTagInfo;
    procedure InitializeDirectiveDefaults;
    procedure ClearDirectives;

  public
    constructor Create(ALexer : TYAMLLexer; const options : IYAMLParserOptions);
    destructor Destroy; override;

    function Parse : IYAMLDocument;
    function ParseAll : TArray<IYAMLDocument>;
  end;

implementation

uses
  System.SysUtils,
  System.TypInfo,
  VSoft.YAML.IO,
  VSoft.YAML.Classes,
  VSoft.YAML.Utils,
  VSoft.YAML.TagInfo;

{ TYAMLParser }

constructor TYAMLParser.Create(ALexer : TYAMLLexer; const options : IYAMLParserOptions);
begin
  inherited Create;
  FOptions := options;
  if FOptions <> nil then
    FJSONMode := FOptions.JSONMode
  else
    FJSONMode := false;

  FLexer := ALexer;
  FCurrentIndentLevel := 0;
  FAnchorMap := TDictionary<string, IYAMLValue>.Create;
  FPendingComments := TStringList.Create;
  FLastTokenLine := 0;
  FIsDocumentLevel := True;
  
  // Initialize directive handling
  FTagDirectives := TList<IYAMLTagDirective>.Create;
  InitializeDirectiveDefaults;
  
  NextToken; // Initialize with first token
end;

destructor TYAMLParser.Destroy;
begin
  FAnchorMap.Free;
  FPendingComments.Free;
  FTagDirectives.Free;
  inherited Destroy;
end;

procedure TYAMLParser.NextToken;
begin
  FLastTokenLine := FLexer.Line;
  FCurrentToken := FLexer.NextToken;
end;

procedure TYAMLParser.ExpectToken(tokenKind : TYAMLTokenKind);
begin
  if FCurrentToken.TokenKind <> tokenKind then
    RaiseParseError('Expected %s but got %s', [GetEnumName(TypeInfo(TYAMLTokenKind), Ord(tokenKind)), GetEnumName(TypeInfo(TYAMLTokenKind), Ord(FCurrentToken.TokenKind))]);
  NextToken;
end;

function TYAMLParser.MatchToken(tokenKind : TYAMLTokenKind) : boolean;
begin
  result := FCurrentToken.TokenKind = tokenKind;
  if result then
    NextToken;
end;


procedure TYAMLParser.SkipNewlines;
begin
    while ((FCurrentToken.TokenKind = TYAMLTokenKind.NewLine) or (FCurrentToken.TokenKind = TYAMLTokenKind.Comment)) and
        (FCurrentToken.TokenKind <> TYAMLTokenKind.EOF) do
    begin
      if FCurrentToken.TokenKind = TYAMLTokenKind.Comment then
        ProcessComment
      else
        NextToken;
    end;
end;

function TYAMLParser.IsScalarValue(const value : string; jsonMode : boolean) : TYAMLValueType;
var
  intVal : Int64;
  floatVal : Double;
  trimmedValue : string;
begin
  trimmedValue := Trim(value);

  if jsonMode then
  begin
    // In JSON mode, only 'null' is valid null literal
    if SameText(trimmedValue, 'null') then
      result := TYAMLValueType.vtNull
    // In JSON mode, only 'true' and 'false' are valid boolean literals
    else if SameText(trimmedValue, 'true') or SameText(trimmedValue, 'false') then
      result := TYAMLValueType.vtBoolean
     // In JSON mode, reject hex/octal/binary number formats
    else if (Length(trimmedValue) > 2) and (trimmedValue[1] = '0') and CharInSet(trimmedValue[2], ['x','X','o','O','b','B']) then
        result := TYAMLValueType.vtString
    else if TryStrToInt64(trimmedValue, intVal) then
        result := TYAMLValueType.vtInteger
    else if TryStrToFloat(trimmedValue, floatVal, YAMLFormatSettings) then
      result := TYAMLValueType.vtFloat
    // In JSON mode, default unrecognized values to string (will be validated later)
    else
      result := TYAMLValueType.vtString;
  end
  else
  begin
    // YAML mode - more permissive
    if SameText(trimmedValue, 'null') or SameText(trimmedValue, '~') or (trimmedValue = '') then
      result := TYAMLValueType.vtNull
    else if SameText(trimmedValue, 'true') or SameText(trimmedValue, 'false') or
            SameText(trimmedValue, 'yes') or SameText(trimmedValue, 'no') or
            SameText(trimmedValue, 'on') or SameText(trimmedValue, 'off') then
      result := TYAMLValueType.vtBoolean
    else if IsTimestampPattern(trimmedValue) then
      result := TYAMLValueType.vtTimestamp
    else if TryStrToInt64(trimmedValue, intVal) then
      result := TYAMLValueType.vtInteger
    // Check for hex, octal, and binary number formats
    else if (Length(trimmedValue) > 2) and (trimmedValue[1] = '0') then
    begin
      if ((trimmedValue[2] = 'x') or (trimmedValue[2] = 'X')) and (Length(trimmedValue) > 2) then
      begin
        // Hexadecimal format (0x or 0X)
        result := TYAMLValueType.vtInteger;
      end
      else if ((trimmedValue[2] = 'o') or (trimmedValue[2] = 'O')) and (Length(trimmedValue) > 2) then
      begin
        // Octal format (0o or 0O)
        result := TYAMLValueType.vtInteger;
      end
      else if ((trimmedValue[2] = 'b') or (trimmedValue[2] = 'B')) and (Length(trimmedValue) > 2) then
      begin
        // Binary format (0b or 0B)
        result := TYAMLValueType.vtInteger;
      end
      else if TryStrToFloat(trimmedValue, floatVal, YAMLFormatSettings) then
        result := TYAMLValueType.vtFloat
      else
        result := TYAMLValueType.vtString;
    end
    else if TryStrToFloat(trimmedValue, floatVal, YAMLFormatSettings) then
      result := TYAMLValueType.vtFloat
    // Check for special YAML float values
    else if SameText(trimmedValue, '.nan') or SameText(trimmedValue, '.NaN') or SameText(trimmedValue, '.NAN') or
            SameText(trimmedValue, '.inf') or SameText(trimmedValue, '.Inf') or SameText(trimmedValue, '.INF') or
            SameText(trimmedValue, '+.inf') or SameText(trimmedValue, '+.Inf') or SameText(trimmedValue, '+.INF') or
            SameText(trimmedValue, '-.inf') or SameText(trimmedValue, '-.Inf') or SameText(trimmedValue, '-.INF') then
      result := TYAMLValueType.vtFloat
    // Default to string
    else
      result := TYAMLValueType.vtString;
  end;
end;


//This is horrible code - refactor
function TYAMLParser.IsTimestampPattern(const value : string) : boolean;
var
  trimmedValue : string;
  year, month, day, hour, min, sec : integer;
  datePart, timePart : string;
  spacePos, tPos, colonPos1, colonPos2, dashPos1, dashPos2 : integer;
begin
  result := False;
  trimmedValue := Trim(value);

  // Must be at least 8 characters for shortest date format (YYYY-MM-DD = 10, but allow some flexibility)
  if Length(trimmedValue) < 8 then
    Exit;
    
  // Quick early exit: timestamps must start with a digit (year)
  if not ((trimmedValue[1] >= '0') and (trimmedValue[1] <= '9')) then
    Exit;
    
  // Quick early exit: second character should also be a digit for 4-digit year
  if not ((trimmedValue[2] >= '0') and (trimmedValue[2] <= '9')) then
    Exit;
    
  // Quick early exit: check for basic YYYY- pattern (most common case)
  if (Length(trimmedValue) >= 5) and (trimmedValue[5] <> '-') then
    Exit;
    
  // Quick early exit: third and fourth characters should be digits for 4-digit year  
  if (Length(trimmedValue) >= 4) then
  begin
    if not (((trimmedValue[3] >= '0') and (trimmedValue[3] <= '9')) and
            ((trimmedValue[4] >= '0') and (trimmedValue[4] <= '9'))) then
      Exit;
  end;

  // Check for ISO 8601 date patterns : YYYY-MM-DD or YYYY-MM-DDTHH :MM :SS
  // Also support space-separated : YYYY-MM-DD HH :MM :SS

  // Find date/time separator (T or space)
  tPos := Pos('T', trimmedValue);
  spacePos := Pos(' ', trimmedValue);

  if tPos > 0 then
    datePart := Copy(trimmedValue, 1, tPos - 1)
  else if spacePos > 0 then
    datePart := Copy(trimmedValue, 1, spacePos - 1)
  else
    datePart := trimmedValue; // Date only

  // Check date part format : YYYY-MM-DD
  if Length(datePart) = 10 then
  begin
    dashPos1 := Pos('-', datePart);
    if dashPos1 = 5 then
    begin
      dashPos2 := Pos('-', Copy(datePart, 6, Length(datePart)));
      if dashPos2 = 3 then // Second dash at position 8 in original string
      begin
        // Try to parse date components
        if TryStrToInt(Copy(datePart, 1, 4), year) and
           TryStrToInt(Copy(datePart, 6, 2), month) and
           TryStrToInt(Copy(datePart, 9, 2), day) then
        begin
          // Basic range validation
          if (year >= 100) and (year <= 2400) and
             (month >= 1) and (month <= 12) and
             (day >= 1) and (day <= 31) then
          begin
            // If it's date only, we're done
            if (tPos = 0) and (spacePos = 0) then
              exit(true);

            // Check time part if present
            if tPos > 0 then
              timePart := Copy(trimmedValue, tPos + 1, Length(trimmedValue))
            else if spacePos > 0 then
              timePart := Copy(trimmedValue, spacePos + 1, Length(trimmedValue));
              
            // Remove timezone suffix for parsing (Z, +HH:MM, -HH:MM)
            if (Length(timePart) > 0) and (timePart[Length(timePart)] = 'Z') then
              timePart := Copy(timePart, 1, Length(timePart) - 1)
            else if (Length(timePart) >= 6) and CharInSet(timePart[Length(timePart) - 5], ['+', '-']) then
              timePart := Copy(timePart, 1, Length(timePart) - 6)
            else if (Length(timePart) >= 3) and CharInSet(timePart[Length(timePart) - 2], ['+', '-']) then
              timePart := Copy(timePart, 1, Length(timePart) - 3);

            // Basic time format check : HH :MM or HH :MM :SS
            if Length(timePart) >= 5 then
            begin
              colonPos1 := Pos(':', timePart);
              if colonPos1 = 3 then
              begin
                if TryStrToInt(Copy(timePart, 1, 2), hour) and TryStrToInt(Copy(timePart, 4, 2), min) then
                begin
                  if (hour >= 0) and (hour <= 23) and (min >= 0) and (min <= 59) then
                  begin
                    // Check for seconds
                    if Length(timePart) >= 8 then
                    begin
                      colonPos2 := Pos(':', Copy(timePart, 4, Length(timePart)));
                      if colonPos2 = 3 then // Second colon at position 6
                      begin
                        if TryStrToInt(Copy(timePart, 7, 2), sec) then
                        begin
                          if (sec >= 0) and (sec <= 59) then
                            result := True;
                        end;
                      end;
                    end
                    else
                      result := True; // HH :MM format is valid
                  end;
                end;
              end;
            end;
          end;
        end;
      end;
    end;
  end;
end;

function TYAMLParser.ParseScalar(const parent : IYAMLValue; const tag : string) : IYAMLValue;
var
  value : string;
  valueType : TYAMLValueType;
  parts : TStringList;
  i : integer;
  specialCharCount : integer;
begin
  case FCurrentToken.TokenKind of
    TYAMLTokenKind.Literal,
    TYAMLTokenKind.Folded :
    begin
      value := FCurrentToken.value;
      valueType := TYAMLValueType.vtString; // Block scalars are always strings
      NextToken;
      result := TYAMLValue.Create(parent, valueType, value, tag);
      CheckForSameLineComment(result);
    end;

    TYAMLTokenKind.Value,
    TYAMLTokenKind.QuotedString :
    begin
      value := FCurrentToken.value;

      // For unquoted values, collect multiple consecutive value tokens
      // This handles cases like "123 Main St" which gets tokenized as separate values
      if FCurrentToken.TokenKind = TYAMLTokenKind.Value then
      begin
        parts := TStringList.Create;
        try
          parts.Add(value);
          NextToken;

          // Collect consecutive value tokens on the same line with same indent
          while (FCurrentToken.TokenKind = TYAMLTokenKind.Value) do
          begin
            parts.Add(FCurrentToken.value);
            NextToken;
          end;

          // Join all parts with spaces
          value := '';
          for i := 0 to parts.Count - 1 do
          begin
            if i > 0 then value := value + ' ';
            value := value + Parts[i];
          end;
          
          // Validate: if we're at document root and have multiple parts that look like key-value,
          // but no colon, this might be malformed YAML
          if (parent = nil) and (parts.Count > 1) then
          begin
            // Check if this looks like a key followed by value(s) without colon
            // This is a heuristic - if the first part looks like an identifier and
            // there are additional parts, it might be missing a colon
            if (Length(Parts[0]) > 0) and
               (CharInSet(Parts[0][1], ['a'..'z', 'A'..'Z', '_'])) then
              RaiseParseError('Missing colon after key "' + Parts[0] + '"');
          end;
        finally
          parts.Free;
        end;

        valueType := IsScalarValue(value, FJSONMode);

        // Additional JSON mode validation for invalid literals
        if FJSONMode and (valueType = TYAMLValueType.vtString) then
        begin
          // Check for YAML-style boolean/null values that are invalid in JSON
          if SameText(value, 'yes') or SameText(value, 'no') or SameText(value, 'on') or SameText(value, 'off') or
             SameText(value, 'truth') or SameText(value, 'false') or SameText(value, 'True') or SameText(value, 'False') or
             SameText(value, '~') or (value = '') then
          begin
            RaiseParseError('Invalid literal value in JSON: "' + value + '". JSON only supports true, false, null, numbers, and quoted strings.');
          end;
        end;

        // Additional validation for potentially problematic unquoted strings
        if (valueType = TYAMLValueType.vtString) then
        begin
          // @ is valid in unquoted values provided it is not the first character
          if (Length(value) > 0) and (value[1] = '@') then
            RaiseParseError('Invalid characters in unquoted string: "' + value + '"');
            
          // Check for other problematic character patterns
          // Look for dense concentrations of special characters that suggest invalid input
          specialCharCount := 0;
          for i := 1 to Length(value) do
          begin
            if CharInSet(value[i], ['#', '$', '%', '^', '&', '*', '(', ')', '<', '>', '|', '\']) then
              Inc(specialCharCount);
          end;
          
          // If more than 40% of characters are special symbols, it's likely invalid YAML
          if (Length(value) > 2) and (specialCharCount * 100 div Length(value) > 40) then
            RaiseParseError('Invalid characters in unquoted string: "' + value + '"');
        end;
      end
      else
      begin
        // Quoted strings are used as-is
        valueType := TYAMLValueType.vtString;
        NextToken;
      end;

      result := TYAMLValue.Create(parent, valueType, value, tag);
      CheckForSameLineComment(result);
    end;
  else
    RaiseParseError('Expected scalar value');
  end;
end;

function TYAMLParser.ParseFlowSequence(const parent : IYAMLValue; const tag : string) : IYAMLSequence;
var
  item : IYAMLValue;
begin
  result := TYAMLSequence.Create(parent, tag);
  AssignPendingCommentsToCollection(result);
  ExpectToken(TYAMLTokenKind.LBracket); // '['

  SkipNewlines;

  // Handle empty sequence
  if MatchToken(TYAMLTokenKind.RBracket) then
    Exit;

  // In JSON mode, check for leading comma (missing first element)
  if FJSONMode and (FCurrentToken.TokenKind = TYAMLTokenKind.Comma) then
  begin
    RaiseParseError('Missing array element: array cannot start with comma in JSON');
  end;

  // Parse items
  repeat
    // In JSON mode, check for invalid mapping syntax inside arrays
    if FJSONMode then
    begin
      if (FCurrentToken.TokenKind in [TYAMLTokenKind.Value, TYAMLTokenKind.QuotedString]) and (FLexer.PeekToken.TokenKind = TYAMLTokenKind.Colon) then
      begin
        RaiseParseError('Invalid syntax: object key-value pairs are not allowed in JSON arrays');
      end;
    end;
    
    item := ParseValue(result);
    result.AddValue(item);

    SkipNewlines;

    if MatchToken(TYAMLTokenKind.Comma) then
    begin
      SkipNewlines;
      // In JSON mode, check for missing array elements after comma
      if FJSONMode then
      begin
        if (FCurrentToken.TokenKind = TYAMLTokenKind.Comma) then
        begin
          RaiseParseError('Missing array element: consecutive commas are not allowed in JSON');
        end
        else if (FCurrentToken.TokenKind = TYAMLTokenKind.RBracket) then
        begin
          RaiseParseError('Missing array element: trailing comma is not allowed in JSON');
        end;
      end;
      Continue;
    end
    else if FCurrentToken.TokenKind = TYAMLTokenKind.RBracket then
      Break
    else if FCurrentToken.TokenKind = TYAMLTokenKind.EOF then
      RaiseParseError('Unexpected end of file in flow sequence (missing "]")')
    else
      RaiseParseError('Expected "," or "]" in flow sequence');
  until False;

  ExpectToken(TYAMLTokenKind.RBracket); // ']'
  CheckForSameLineComment(result);
  
  // Check for unexpected tokens after flow sequence
  if (parent = nil) then
  begin
    case FCurrentToken.TokenKind of
      TYAMLTokenKind.RBracket:
        RaiseParseError('Unexpected closing bracket "]" - no matching opening bracket');
      TYAMLTokenKind.Comma:
        RaiseParseError('Unexpected comma after closing bracket');
      TYAMLTokenKind.Value, TYAMLTokenKind.QuotedString:
        RaiseParseError('Unexpected text after closing bracket');
      TYAMLTokenKind.EOF, TYAMLTokenKind.NewLine, TYAMLTokenKind.Comment:
        ; // These are acceptable
    else
      RaiseParseError('Unexpected token after closing bracket: ' + GetEnumName(TypeInfo(TYAMLTokenKind), Ord(FCurrentToken.TokenKind)));
    end;
  end;
end;

function TYAMLParser.ParseFlowMapping(const parent : IYAMLValue; const tag : string) : IYAMLMapping;
var
  key : string;
  value : IYAMLValue;
begin
  result := TYAMLMapping.Create(parent, tag);
  AssignPendingCommentsToCollection(result);
  ExpectToken(TYAMLTokenKind.LBrace); // '{'

  SkipNewlines;

  // Handle empty mapping
  if MatchToken(TYAMLTokenKind.RBrace) then
    Exit;

  // Parse key-value pairs
  repeat
    if (FCurrentToken.TokenKind = TYAMLTokenKind.Indent) then
      NextToken;

    // Parse key
    if (FCurrentToken.TokenKind = TYAMLTokenKind.Value) or (FCurrentToken.TokenKind = TYAMLTokenKind.QuotedString) then
    begin
      // In JSON mode, keys must be quoted strings
      if FJSONMode and (FCurrentToken.TokenKind = TYAMLTokenKind.Value) then
      begin
        RaiseParseError('Object keys must be quoted strings in JSON');
      end;
      
      key := FCurrentToken.value;
      NextToken;
    end
    else if FCurrentToken.TokenKind = TYAMLTokenKind.EOF then
      RaiseParseError('Unexpected end of file in flow mapping (expected key)')
    else
      RaiseParseError('Expected key in flow mapping');

    SkipNewlines; // Allow newlines before colon in both YAML and JSON modes
    ExpectToken(TYAMLTokenKind.Colon); // ':'
    SkipNewlines;

    // Parse value
    value := ParseValue(result);
    (result as IYAMLMappingPrivate).AddOrSetValue(key, value);

    SkipNewlines;

    if MatchToken(TYAMLTokenKind.Comma) then
    begin
      SkipNewlines;
      Continue;
    end
    else if FCurrentToken.TokenKind = TYAMLTokenKind.RBrace then
      Break
    else
      RaiseParseError('Expected "," or "}" in flow mapping');
  until False;

  ExpectToken(TYAMLTokenKind.RBrace); // '}'
  CheckForSameLineComment(result);
  
  // Check for unexpected tokens after flow mapping
  if (parent = nil) then
  begin
    case FCurrentToken.TokenKind of
      TYAMLTokenKind.RBrace:
        RaiseParseError('Unexpected closing brace "}" - no matching opening brace');
      TYAMLTokenKind.Comma:
        RaiseParseError('Unexpected comma after closing brace');
      TYAMLTokenKind.Value, TYAMLTokenKind.QuotedString:
        RaiseParseError('Unexpected text after closing brace');
      TYAMLTokenKind.EOF, TYAMLTokenKind.NewLine, TYAMLTokenKind.Comment:
        ; // These are acceptable
    else
      RaiseParseError('Unexpected token after closing brace: ' + GetEnumName(TypeInfo(TYAMLTokenKind), Ord(FCurrentToken.TokenKind)));
    end;
  end;
end;

function TYAMLParser.ParseSequence(const parent : IYAMLValue; const tag : string) : IYAMLSequence;
var
  item : IYAMLValue;
  expectedIndent : integer;
begin
  result := TYAMLSequence.Create(parent, tag);
  AssignPendingCommentsToCollection(result);
  expectedIndent := FCurrentToken.IndentLevel;

  while (FCurrentToken.TokenKind = TYAMLTokenKind.SequenceItem) and
        (FCurrentToken.IndentLevel = expectedIndent) do
  begin
    NextToken; // Skip '-'

    // Parse the item value
    item := ParseValue(result);
    //(result as IYAMSequencePrivate).AddValue(item);
    result.AddValue(item);

    // Skip newlines and check if there are more sequence items
    SkipNewlines;

    // Handle indentation changes that might affect next token classification
    if (FCurrentToken.TokenKind = TYAMLTokenKind.Indent) then
      NextToken;
  end;
end;

function TYAMLParser.ParseSet(const parent : IYAMLValue; const tag : string) : IYAMLSet;
var
  item : IYAMLValue;
  expectedIndent : integer;
begin
  result := TYAMLSet.Create(parent, tag);
  AssignPendingCommentsToCollection(result);
  expectedIndent := FCurrentToken.IndentLevel;

  while (FCurrentToken.TokenKind = TYAMLTokenKind.SetItem) and  (FCurrentToken.IndentLevel = expectedIndent) do
  begin
    NextToken; // Skip '?'
    SkipNewlines;

    // Parse the set item value
    item := ParseValue(result);
    result.AddValue(item);

    // Skip newlines and check if there are more set items
    SkipNewlines;

    // Handle indentation changes that might affect next token classification
    if (FCurrentToken.TokenKind = TYAMLTokenKind.Indent) then
      NextToken;
  end;
end;

function TYAMLParser.ParseMapping(const parent : IYAMLValue; const tag : string; const firstKey : string = '') : IYAMLMapping;
var
  key : string;
  value : IYAMLValue;
  expectedIndent : integer;
  keyIndentLevel : integer;
begin
  result := TYAMLMapping.Create(parent, tag);
  AssignPendingCommentsToCollection(result);
  expectedIndent := FCurrentToken.IndentLevel;

  repeat
    keyIndentLevel := 0;
    // Parse key
    if (firstKey <> '') or (FCurrentToken.TokenKind = TYAMLTokenKind.Value) or (FCurrentToken.TokenKind = TYAMLTokenKind.QuotedString) then
    begin
      if firstKey = '' then
      begin
        // In JSON mode, keys must be quoted strings
        if FJSONMode and (FCurrentToken.TokenKind = TYAMLTokenKind.Value) then
        begin
          RaiseParseError('Object keys must be quoted strings in JSON');
        end;
        
        key := FCurrentToken.value;
        //don't check dupes here, we need to parse fully
        if result.ContainsKey(key) then
        begin
          if FOptions.DuplicateKeyBehavior = TYAMLDuplicateKeyBehavior.dkError then
            RaiseParseError('duplicated mapping key : "' + key + '"');
        end;

        keyIndentLevel := FCurrentToken.IndentLevel; // Store the key's indentation
        
        NextToken;

        ExpectToken(TYAMLTokenKind.Colon); // ':'

      end
      else
        key := firstKey;
      // Skip any newlines and indentation after colon
      SkipNewlines;
      if FCurrentToken.TokenKind = TYAMLTokenKind.Indent then
        NextToken;
        // Enhanced empty value detection that handles comments
        // We need to look ahead through comments and whitespace to see if there's actual content
        // or just a sibling key at the same indentation level
        if (FCurrentToken.TokenKind = TYAMLTokenKind.EOF) then
        begin
          // This is clearly an empty value
          value := TYAMLValue.Create(result, TYAMLValueType.vtNull, '', '');
        end
        else if ((FCurrentToken.TokenKind in [TYAMLTokenKind.Value, TYAMLTokenKind.QuotedString]) and (FLexer.PeekToken.TokenKind = TYAMLTokenKind.Colon) and (FCurrentToken.IndentLevel <= keyIndentLevel)) then
        begin
          // This is clearly an empty value
          value := TYAMLValue.Create(result, TYAMLValueType.vtNull, '', '');
        end
        else if (FCurrentToken.TokenKind = TYAMLTokenKind.NewLine) or
                (FCurrentToken.TokenKind = TYAMLTokenKind.Indent) or
                (FCurrentToken.TokenKind = TYAMLTokenKind.Comment) then
        begin
          // We have whitespace/indentation/comments after a colon
          // Let ParseValue handle the comment/newline skipping and determine if there's content
          value := ParseValue(result);
        end
      else if FCurrentToken.TokenKind = TYAMLTokenKind.Indent then
        value := ParseTaggedValue(result)
      else
        // Parse value normally
        value := ParseValue(result);



      // Handle merge key
      if key = '<<' then
      begin
        //TODO : if enforcing yaml 1.2 then this should raise as merge keys were removed from 1.2

        // Merge the aliased mapping into current mapping
        if value.IsMapping then
        begin
          (result as IYAMLMappingPrivate).MergeMapping(value.AsMapping);
        end;
        // Don't store the merge key itself
      end
      else
        (result as IYAMLMappingPrivate).AddOrSetValue(key, value);

      SkipNewlines;

      // Handle indentation tokens that might appear between key-value pairs
      if FCurrentToken.TokenKind = TYAMLTokenKind.Indent then
        NextToken;

      SkipNewlines;

      // Check if there are more key-value pairs
      if ((FCurrentToken.TokenKind = TYAMLTokenKind.Value) or (FCurrentToken.TokenKind = TYAMLTokenKind.QuotedString)) then
      begin
        // Check if this is a key (followed by colon)
        if (FLexer.PeekToken.TokenKind = TYAMLTokenKind.Colon) then
        begin
          // This is a key - check indentation to see if it belongs to this mapping
          if (FCurrentToken.IndentLevel >= expectedIndent) then
            Continue
          else
            Break; // Lower indentation means we're done with this mapping
        end
        else
          Break; // Not a key, so we're done
      end
      else if (FCurrentToken.TokenKind = TYAMLTokenKind.SequenceItem) then
        Break // Encountered next sequence item, stop mapping
      else
        Break;
    end
    else
      Break;
  until False;
end;

function TYAMLParser.ParseMappingOrSet(const parent : IYAMLValue; const tag : string) : IYAMLValue;
begin
  // complex key support with explicit '?' notation is diffcult,
  // as it involves rewriting the parent.
  // for now it's not supported.

  // a newline after a ? indicates a complex key
  if FLexer.PeekTokenKind = TYAMLTokenKind.NewLine then
    RaiseParseError('complex keys in non flow format are not currently supported');

  result := ParseSet(parent, tag);

end;

function TYAMLParser.ParseValue(const parent : IYAMLValue; const tag : string) : IYAMLValue;
begin
  SkipNewlines;
//  WriteLn('ParseValue : ' + FCurrentToken.value);

  case FCurrentToken.TokenKind of
    TYAMLTokenKind.EOF :
      begin
        // Handle EOF gracefully by returning a null value
        result := TYAMLValue.Create(parent, TYAMLValueType.vtNull, '', '');
      end;

    TYAMLTokenKind.LBracket :
      result := ParseFlowSequence(parent, tag);

    TYAMLTokenKind.LBrace :
      result := ParseFlowMapping(parent, tag);

    TYAMLTokenKind.SequenceItem :
      result := ParseSequence(parent, tag);

    TYAMLTokenKind.Value,
    TYAMLTokenKind.QuotedString :
      begin
      // Check if this is the start of a mapping (key followed by colon)
        if (FLexer.PeekToken.TokenKind = TYAMLTokenKind.Colon) then
        begin
          // This is a mapping key
          result := ParseMapping(parent, tag);
        end
        else
          result := ParseScalar(parent, tag);
      end;

    TYAMLTokenKind.Anchor :
      result := ParseAnchoredValue(parent, tag);

    TYAMLTokenKind.Alias :
      result := ParseAlias(parent);

    TYAMLTokenKind.Tag :
      result := ParseTaggedValue(parent);

    TYAMLTokenKind.SetItem :
    begin
        // Need to distinguish between set items and explicit complex keys
        // If there's a colon after parsing the complex value, it's a mapping with complex keys
        // Otherwise, it's a set
        result := ParseMappingOrSet(parent, tag);
    end;
    TYAMLTokenKind.Literal,
    TYAMLTokenKind.Folded :
      result := ParseScalar(parent, tag);

    TYAMLTokenKind.NewLine :
    begin
      NextToken;
      result := ParseValue(parent); // Recursively parse after newline
    end;

    TYAMLTokenKind.Indent :
    begin
      NextToken;
      result := ParseValue(parent); // Parse indented content
    end;
    TYAMLTokenKind.Comment :
    begin
      ProcessComment;
      result := ParseValue(parent);
    end;

    TYAMLTokenKind.RBracket :
      RaiseParseError('Unexpected closing bracket "]" - no matching opening bracket');

    TYAMLTokenKind.RBrace :
      RaiseParseError('Unexpected closing brace "}" - no matching opening brace')

  else
    RaiseParseError('Unexpected token in value context : ' + GetEnumName(TypeInfo(TYAMLTokenKind), Ord(FCurrentToken.TokenKind)));
  end;
end;

function TYAMLParser.ParseDocument : IYAMLValue;
begin
  while (FCurrentToken.TokenKind in [TYAMLTokenKind.Comment, TYAMLTokenKind.NewLine, TYAMLTokenKind.Directive]) do
  begin
    if FCurrentToken.TokenKind = TYAMLTokenKind.Comment then
      ProcessComment
    else if FCurrentToken.TokenKind = TYAMLTokenKind.Directive then
    begin
      ProcessDirective(FCurrentToken.Value);
      NextToken;
    end
    else
      NextToken;
  end;

  // Skip document start marker if present
  if FCurrentToken.TokenKind = TYAMLTokenKind.DocStart then
    NextToken;

  // Skip comments and newlines after document start
  SkipNewlines;

  // Parse the main document value
  result := ParseValue(nil);
  // Skip document end marker if present
  if FCurrentToken.TokenKind = TYAMLTokenKind.DocEnd then
    NextToken;
end;

function TYAMLParser.ParseAnchoredValue(const parent : IYAMLValue; const tag : string) : IYAMLValue;
var
  anchorName : string;
begin
  // Expect anchor token
  if FCurrentToken.TokenKind <> TYAMLTokenKind.Anchor then
    RaiseParseError('Expected anchor');

  anchorName := FCurrentToken.value;
  NextToken; // Skip anchor token

  // Parse the actual value
  result := ParseValue(parent);

  // Register the anchor with the parsed value
  RegisterAnchor(anchorName, result);
end;

function TYAMLParser.ParseAlias(const parent : IYAMLValue) : IYAMLValue;
var
  aliasName : string;
begin
  // Expect alias token
  if FCurrentToken.TokenKind <> TYAMLTokenKind.Alias then
    RaiseParseError('Expected alias');

  aliasName := FCurrentToken.value;
  NextToken; // Skip alias token

  // Resolve the alias
  result := ResolveAlias(aliasName);
end;

function TYAMLParser.ParseAll: TArray<IYAMLDocument>;
var
  documents: TList<IYAMLDocument>;
  root: IYAMLValue;
  doc: IYAMLDocument;
  documentCount: integer;
  hasExplicitStart: boolean;
begin
  documents := TList<IYAMLDocument>.Create;
  try
    documentCount := 0;
    
    // Skip initial whitespace and comments
    while (FCurrentToken.TokenKind in [TYAMLTokenKind.NewLine, TYAMLTokenKind.Comment]) and (FCurrentToken.TokenKind <> TYAMLTokenKind.EOF) do
    begin
      if FCurrentToken.TokenKind = TYAMLTokenKind.Comment then
        ProcessComment
      else
        NextToken;
    end;
    
    // Parse documents
    while FCurrentToken.TokenKind <> TYAMLTokenKind.EOF do
    begin
      try
        // Clear anchors between documents and initialize directives
        if documentCount > 0 then
        begin
          FAnchorMap.Clear;
          InitializeDirectiveDefaults;
        end;
          
        hasExplicitStart := False;
        
        // Skip whitespace and comments before document
        while (FCurrentToken.TokenKind in [TYAMLTokenKind.NewLine, TYAMLTokenKind.Comment]) and
              (FCurrentToken.TokenKind <> TYAMLTokenKind.EOF) do
        begin
          if FCurrentToken.TokenKind = TYAMLTokenKind.Comment then
            ProcessComment
          else
            NextToken;
        end;
        
        // Handle document-level directives
        while (FCurrentToken.TokenKind = TYAMLTokenKind.Directive) and (FCurrentToken.TokenKind <> TYAMLTokenKind.EOF) do
        begin
          ProcessDirective(FCurrentToken.Value);
          NextToken;
          
          // Skip whitespace after directives
          while (FCurrentToken.TokenKind in [TYAMLTokenKind.NewLine, TYAMLTokenKind.Comment]) and
                (FCurrentToken.TokenKind <> TYAMLTokenKind.EOF) do
          begin
            if FCurrentToken.TokenKind = TYAMLTokenKind.Comment then
              ProcessComment
            else
              NextToken;
          end;
        end;
        
        // Check for EOF
        if FCurrentToken.TokenKind = TYAMLTokenKind.EOF then
          Break;
          
        // Handle explicit document start
        if FCurrentToken.TokenKind = TYAMLTokenKind.DocStart then
        begin
          hasExplicitStart := True;
          NextToken; // Skip DocStart
          
          // Skip whitespace after DocStart
          while (FCurrentToken.TokenKind in [TYAMLTokenKind.NewLine, TYAMLTokenKind.Comment]) and
                (FCurrentToken.TokenKind <> TYAMLTokenKind.EOF) do
          begin
            if FCurrentToken.TokenKind = TYAMLTokenKind.Comment then
              ProcessComment
            else
              NextToken;
          end;
        end;
        
        // Check if this is an empty document
        if (FCurrentToken.TokenKind = TYAMLTokenKind.DocStart) or 
           (FCurrentToken.TokenKind = TYAMLTokenKind.DocEnd) or
           (FCurrentToken.TokenKind = TYAMLTokenKind.EOF) then
        begin
          // Always create empty document if we had explicit start
          if hasExplicitStart then
          begin
            root := TYAMLValue.Create(nil, TYAMLValueType.vtNull, '', '');
            doc := TYAMLDocument.Create(root, FYAMLVersion, FTagDirectives);
            documents.Add(doc);
            Inc(documentCount);
            
            // If EOF after DocStart, we're done
            if FCurrentToken.TokenKind = TYAMLTokenKind.EOF then
              Break;
          end;
          
          // Handle DocEnd
          if FCurrentToken.TokenKind = TYAMLTokenKind.DocEnd then
            NextToken;
            
          Continue;
        end;
        
        // Parse document content
        root := ParseValue(nil);
        doc := TYAMLDocument.Create(root, FYAMLVersion, FTagDirectives);
        documents.Add(doc);
        Inc(documentCount);
        
        // Skip DocEnd if present
        if FCurrentToken.TokenKind = TYAMLTokenKind.DocEnd then
          NextToken;
          
      except
        on E: EYAMLParseException do
        begin
          raise EYAMLParseException.Create(
            Format('Error in document %d: %s', [documentCount + 1, E.Message], YAMLFormatSettings),
            E.Line,
            E.Column
          );
        end;
      end;
    end;
    
    // If no documents found, create empty one
    if documents.Count = 0 then
    begin
      root := TYAMLValue.Create(nil, TYAMLValueType.vtNull, '', '');
      doc := TYAMLDocument.Create(root, FYAMLVersion, nil);
      documents.Add(doc);
    end;
    
    result := documents.ToArray;
    
  finally
    documents.Free;
  end;
end;

procedure TYAMLParser.RaiseParseError(const message : string);
begin
  raise EYAMLParseException.Create(message, FCurrentToken.Line, FCurrentToken.Column);
end;

procedure TYAMLParser.RaiseParseError(const fmt : string; const Args : array of const);
begin
  raise EYAMLParseException.Create(
    Format(fmt, Args),
    FCurrentToken.Line,
    FCurrentToken.Column
  );
end;


procedure TYAMLParser.RegisterAnchor(const anchorName : string; const value : IYAMLValue);
begin
  if FAnchorMap.ContainsKey(anchorName) then
    RaiseParseError('Anchor "%s" already defined', [anchorName]);

  // Store a reference to the value (not a copy)
  FAnchorMap.Add(anchorName, value);
end;

function TYAMLParser.ResolveAlias(const aliasName : string) : IYAMLValue;
begin
  // Return the actual resolved value, not an alias wrapper
  // The result is already set by TryGetValue above
  if not FAnchorMap.TryGetValue(aliasName, result) then
    RaiseParseError('Undefined alias "%s"', [aliasName]);


  //TODO : this will likely break jsonpath
end;

function TYAMLParser.ParseTaggedValue(const parent : IYAMLValue) : IYAMLValue;
var
  tagValue : string;
  nextValue : IYAMLValue;
  i : integer;
  key : string;
begin
  // Expect tag token
  if FCurrentToken.TokenKind <> TYAMLTokenKind.Tag then
    RaiseParseError('Expected tag');

  tagValue := FCurrentToken.value;
  NextToken; // Skip tag token

  // Skip any whitespace or newlines after tag
  SkipNewlines;

  // Resolve tag shortcuts using TAG directives
  tagValue := ResolveTag(tagValue);

  // Parse the actual value that follows the tag
  nextValue := ParseValue(parent, tagValue);


  if SameText(tagValue, '!!set') then
  begin
    if nextValue.IsSet then
    begin
      // Already a set, just return it
      result := nextValue;
    end
    else if nextValue.IsMapping then
    begin
      // Convert mapping to set (keys become set items)
      result := TYAMLSet.Create(parent, tagValue);
      for i := 0 to nextValue.AsMapping.Count - 1 do
      begin
        key := nextValue.AsMapping.Keys[i];
        result.AsSet.AddValue(key);
      end;
      nextValue := nil;
    end
    else if nextValue.IsSequence then
    begin
      // Convert sequence to set
      result := TYAMLSet.Create(parent, tagValue);
      for i := 0 to nextValue.AsSequence.Count - 1 do
      begin
        result.AsSet.AddValue(nextValue.AsSequence[i].AsString);
      end;
      nextValue := nil;
    end
    else
    begin
      // Can't convert scalar to set
      RaiseParseError('Cannot apply !!set tag to scalar value');
    end;
  end
  else
    result := nextValue;
end;

function TYAMLParser.Parse : IYAMLDocument;
var
  root : IYAMLValue;
begin
  try
    // Initialize directives for this document
    InitializeDirectiveDefaults;
    
    // Process any initial newlines or directives
    while (FCurrentToken.TokenKind = TYAMLTokenKind.NewLine) or (FCurrentToken.TokenKind = TYAMLTokenKind.Directive) do
    begin
      if FCurrentToken.TokenKind = TYAMLTokenKind.Directive then
      begin
        ProcessDirective(FCurrentToken.Value);
        NextToken;
      end
      else
        NextToken;
    end;

    if FCurrentToken.TokenKind = TYAMLTokenKind.EOF then
      root := TYAMLValue.Create(nil, TYAMLValueType.vtNull, '', '')
    else
      root := ParseDocument;

    result := TYAMLDocument.Create(root, FYAMLVersion, FTagDirectives);

  except
    on E : EYAMLParseException do
      raise
    else
      raise EYAMLParseException.Create(
        'Unexpected parsing error',
        FCurrentToken.Line,
        FCurrentToken.Column
      );
  end;
end;

procedure TYAMLParser.ProcessComment;
begin
  // Add comment to pending comments buffer
  if FCurrentToken.Value <> '' then
    FPendingComments.Add(FCurrentToken.Value);
  NextToken;
end;

procedure TYAMLParser.AssignPendingCommentsToCollection(const collection : IYAMLCollection);
var
  index : integer;
begin
  // Skip assignment if this is the document-level root collection
  // Document-level comments should go to the first content structure, not the root container
  if FIsDocumentLevel and (collection.Parent = nil) then
    Exit;
    
  if FPendingComments.Count > 0 then
  begin
    for index := 0 to FPendingComments.Count - 1 do
      collection.AddComment(FPendingComments[index]);
    FPendingComments.Clear;
    FIsDocumentLevel := False; // No longer at document level once we've assigned comments
  end;
end;

procedure TYAMLParser.AssignSameLineCommentToValue(const value : IYAMLValue; const commentText : string);
begin
  if commentText <> '' then
    value.Comment := commentText;
end;

procedure TYAMLParser.CheckForSameLineComment(const value : IYAMLValue);
begin
  // Check if the next token is a comment on the same line as the last token
  if (FCurrentToken.TokenKind = TYAMLTokenKind.Comment) and (FCurrentToken.Line = FLastTokenLine) then
  begin
    AssignSameLineCommentToValue(value, FCurrentToken.Value);
    NextToken;
  end;
end;


{ TYAMLParser - Directive Methods }

procedure TYAMLParser.InitializeDirectiveDefaults;
var
  tagDir : IYAMLTagDirective;
begin
  // Set default YAML version to 1.2
  FYAMLVersion := TYAMLVersionDirective.Create(1, 2);
  FHasYAMLDirective := False;

  // Clear any existing tag directives
  ClearDirectives;

  // Add default tag handles according to YAML 1.2 spec
  tagDir := TYAMLTagDirective.Create('!', '!');  // Primary tag handle
  FTagDirectives.Add(tagDir);
  tagDir := TYAMLTagDirective.Create('!!', 'tag:yaml.org,2002:'); // Secondary tag handle
  FTagDirectives.Add(tagDir);
end;

procedure TYAMLParser.ClearDirectives;
begin
  FTagDirectives.Clear;
  FHasYAMLDirective := False;
end;

procedure TYAMLParser.ProcessDirective(const directiveText : string);
var
  spacePos : integer;
  directiveName : string;
  directiveContent : string;
begin
  // Parse directive format: %DIRECTIVE_NAME parameters
  spacePos := Pos(' ', directiveText);
  if spacePos > 0 then
  begin
    directiveName := Copy(directiveText, 2, spacePos - 2); // Skip the '%'
    directiveContent := Trim(Copy(directiveText, spacePos + 1, Length(directiveText)));
  end
  else
  begin
    directiveName := Copy(directiveText, 2, Length(directiveText)); // Skip the '%', no parameters
    directiveContent := '';
  end;
  
  if SameText(directiveName, 'YAML') then
    ParseYAMLDirective(directiveContent)
  else if SameText(directiveName, 'TAG') then
    ParseTAGDirective(directiveContent)
  else
  begin
    // Unknown directive - issue warning but continue parsing
    // In a real implementation, this might be logged
  end;
end;

procedure TYAMLParser.ParseYAMLDirective(const directiveContent : string);
var
  dotPos : integer;
  majorStr, minorStr : string;
  major, minor : integer;
  requestedVersion : IYAMLVersionDirective;
  yaml12 : IYAMLVersionDirective;
begin
  if FHasYAMLDirective then
    RaiseParseError('Multiple YAML directives are not allowed in the same document');

  // Parse version format: major.minor
  dotPos := Pos('.', directiveContent);
  if dotPos = 0 then
    RaiseParseError('Invalid YAML directive format, expected "major.minor"');

  majorStr := Copy(directiveContent, 1, dotPos - 1);
  minorStr := Copy(directiveContent, dotPos + 1, Length(directiveContent));

  if not TryStrToInt(majorStr, major) or not TryStrToInt(minorStr, minor) then
    RaiseParseError('Invalid YAML version numbers');

  requestedVersion := TYAMLVersionDirective.Create(major, minor);

  // Validate version compatibility according to YAML 1.2 spec
  if major > 1 then
    RaiseParseError('Unsupported YAML version %s - major version %d not supported', [requestedVersion.ToString, major])
  else if (major = 1) and (minor > 2) then
  begin
    // Warn about higher minor versions but continue
    // hmm what to do here?
  end
  else
  begin
    yaml12 := TYAMLVersionDirective.YAML_1_2;
    if not requestedVersion.IsCompatible(yaml12) then
      RaiseParseError('Incompatible YAML version %s', [requestedVersion.ToString]);
  end;
    
  FYAMLVersion := requestedVersion;
  FHasYAMLDirective := True;
end;

procedure TYAMLParser.ParseTAGDirective(const directiveContent : string);
var
  parts : TStringList;
  handle, prefix : string;
  i : integer;
  newTagDir : IYAMLTagDirective;
begin
  if directiveContent = '' then
    RaiseParseError('TAG directive requires handle and prefix');

  parts := TStringList.Create;
  try
    // Split by space to get handle and prefix
    parts.Delimiter := ' ';
    parts.DelimitedText := directiveContent;

    if parts.Count < 2 then
      RaiseParseError('TAG directive requires both handle and prefix');

    handle := parts[0];
    prefix := parts[1];

    // Validate handle format
    if (Length(handle) < 1) or (handle[1] <> '!') then
      RaiseParseError('TAG handle must start with "!"');

    if (Length(handle) > 1) and (handle[Length(handle)] <> '!') and (handle <> '!') then
      RaiseParseError('Named TAG handle must end with "!"');

    // Check for duplicate handle
    for i := 0 to FTagDirectives.Count - 1 do
    begin
      if FTagDirectives[i].Handle = handle then
      begin
        // Replace existing handle
        FTagDirectives[i] := TYAMLTagDirective.Create(handle, prefix);
        Exit;
      end;
    end;

    // Add new tag directive
    newTagDir := TYAMLTagDirective.Create(handle, prefix);
    FTagDirectives.Add(newTagDir);
    
  finally
    parts.Free;
  end;
end;

function TYAMLParser.ResolveTag(const tagText : string) : string;
var
  i : integer;
  handle : string;
  suffix : string;
begin
  result := tagText;
  
  // Check for shorthand tag format (handle + suffix)
  for i := 0 to FTagDirectives.Count - 1 do
  begin
    handle := FTagDirectives[i].Handle;
    if (Length(tagText) >= Length(handle)) and 
       (Copy(tagText, 1, Length(handle)) = handle) then
    begin
      suffix := Copy(tagText, Length(handle) + 1, Length(tagText));
      result := FTagDirectives[i].Prefix + suffix;
      Exit;
    end;
  end;
end;

function TYAMLParser.CreateTagInfo(const tagText : string) : IYAMLTagInfo;
var
  i : integer;
  handle : string;
  suffix : string;
  resolvedURI : string;
begin
  // Handle empty or unresolved tags
  if (tagText = '') or (tagText = '?') then
  begin
    result := TYAMLTagInfoFactory.CreateUnresolvedTag(tagText);
    Exit;
  end;
  
  // Check for shorthand tag format that matches directive handles
  for i := 0 to FTagDirectives.Count - 1 do
  begin
    handle := FTagDirectives[i].Handle;
    if (Length(tagText) >= Length(handle)) and 
       (Copy(tagText, 1, Length(handle)) = handle) then
    begin
      suffix := Copy(tagText, Length(handle) + 1, Length(tagText));
      resolvedURI := FTagDirectives[i].Prefix + suffix;
      
      // Create appropriate tag type based on handle
      if handle = '!!' then
        result := TYAMLTagInfoFactory.CreateStandardTag(suffix)
      else if handle = '!' then
        result := TYAMLTagInfoFactory.CreateLocalTag(suffix)
      else
        result := TYAMLTagInfoFactory.CreateCustomTag(handle, suffix, FTagDirectives[i].Prefix);
      
      Exit;
    end;
  end;
  
  // If no directive match, parse using factory
  result := TYAMLTagInfoFactory.ParseTag(tagText);
end;

end.


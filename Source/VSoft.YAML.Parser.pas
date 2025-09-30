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
    function IsScalarValueJSON(const trimmedValue : string; len : Integer) : TYAMLValueType;
    function IsScalarValueYAML(const trimmedValue : string; len : Integer) : TYAMLValueType;
    function FastIsNumber(const value : string; out isFloat : Boolean) : Boolean;
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


function TYAMLParser.FastIsNumber(const value: string; out isFloat: Boolean): Boolean;
var
  i, len: Integer;
  ch: Char;
begin
  isFloat := False;
  len := Length(value);
  if len = 0 then
  begin
    result := False;
    Exit;
  end;

  i := 1;

  // Stage 1: Optional leading sign
  ch := value[i];
  if (ch = '+') or (ch = '-') then
  begin
    Inc(i);
    if i > len then
    begin
      result := False; // A sign by itself is not a number
      Exit;
    end;
  end;

  // Stage 2: Integer part
  if not TCharClassHelper.IsDigit(value[i]) then
  begin
    result := False;
    Exit;
  end;

  // Consume the integer part's digits
  while (i <= len) and TCharClassHelper.IsDigit(value[i]) do
    Inc(i);

  // Stage 3: Optional fractional part
  if (i <= len) and (value[i] = '.') then
  begin
    isFloat := True;
    Inc(i);

    // JSON requires at least one digit after the decimal point.
    if (i > len) or not TCharClassHelper.IsDigit(value[i]) then
    begin
      result := False;
      Exit;
    end;

    // Consume the fractional part's digits
    while (i <= len) and TCharClassHelper.IsDigit(value[i]) do
      Inc(i);
  end;

  // Stage 4: Optional exponent part
  if (i <= len) and ((value[i] = 'e') or (value[i] = 'E')) then
  begin
    isFloat := True;
    Inc(i);

    // Check for an optional sign for the exponent
    if i <= len then
    begin
      ch := value[i];
      if (ch = '+') or (ch = '-') then
        Inc(i);
    end;

    // The exponent must have at least one digit.
    if (i > len) or not TCharClassHelper.IsDigit(value[i]) then
    begin
      result := False;
      Exit;
    end;

    // Consume the exponent's digits
    while (i <= len) and TCharClassHelper.IsDigit(value[i]) do
    begin
      Inc(i);
    end;
  end;

  // Stage 5: Final check. To be a valid number, we must have consumed the entire string.
  result := (i > len);
end;

function TYAMLParser.IsScalarValue(const value : string; jsonMode : boolean) : TYAMLValueType;
var
  trimmedValue : string;
  len : integer;
begin
  len := Length(value);

  // Fast path: empty string
  if len = 0 then
  begin
    if jsonMode then
      result := TYAMLValueType.vtString
    else
      result := TYAMLValueType.vtNull;
    Exit;
  end;

  // Fast path: check if trimming is needed
  if (value[1] <= ' ') or (value[len] <= ' ') then
    trimmedValue := Trim(value)
  else
    trimmedValue := value;

  len := Length(trimmedValue);

  // Fast path: empty string after trim
  if len = 0 then
  begin
    if jsonMode then
      result := TYAMLValueType.vtString
    else
      result := TYAMLValueType.vtNull;
    Exit;
  end;

  // Delegate to specialized functions
  if jsonMode then
    result := IsScalarValueJSON(trimmedValue, len)
  else
    result := IsScalarValueYAML(trimmedValue, len);
end;

function TYAMLParser.IsScalarValueJSON(const trimmedValue : string; len : Integer) : TYAMLValueType;
var
  firstChar : Char;
  secondChar : Char;
  isFloat : Boolean;
begin
  firstChar := trimmedValue[1];

  // Fast path: check first character for common cases
  case firstChar of
    'n': // null
      if (len = 4) and (trimmedValue[2] = 'u') and (trimmedValue[3] = 'l') and (trimmedValue[4] = 'l') then
      begin
        result := TYAMLValueType.vtNull;
        Exit;
      end;
    't': // true
      if (len = 4) and (trimmedValue[2] = 'r') and (trimmedValue[3] = 'u') and (trimmedValue[4] = 'e') then
      begin
        result := TYAMLValueType.vtBoolean;
        Exit;
      end;
    'f': // false
      if (len = 5) and (trimmedValue[2] = 'a') and (trimmedValue[3] = 'l') and (trimmedValue[4] = 's') and (trimmedValue[5] = 'e') then
      begin
        result := TYAMLValueType.vtBoolean;
        Exit;
      end;
    '0': // Check for hex/octal/binary (not valid in JSON, treat as string)
      begin
        if (len > 2) then
        begin
          secondChar := trimmedValue[2];
          if CharInSet(secondChar, ['x','X','o','O','b','B']) then
          begin
            result := TYAMLValueType.vtString;
            Exit;
          end;
        end;
        // Valid JSON number starting with 0 - use fast checker
        if FastIsNumber(trimmedValue, isFloat) then
        begin
          if isFloat then
            result := TYAMLValueType.vtFloat
          else
            result := TYAMLValueType.vtInteger;
          Exit;
        end;
        result := TYAMLValueType.vtString;
        Exit;
      end;
    '1'..'9', '-', '+': // Likely a number - use fast checker
      begin
        if FastIsNumber(trimmedValue, isFloat) then
        begin
          if isFloat then
            result := TYAMLValueType.vtFloat
          else
            result := TYAMLValueType.vtInteger;
          Exit;
        end;
        // Not a valid number, treat as string
        result := TYAMLValueType.vtString;
        Exit;
      end;
  end;

  // Fallback for non-numeric strings
  result := TYAMLValueType.vtString;
end;

function TYAMLParser.IsScalarValueYAML(const trimmedValue : string; len : Integer) : TYAMLValueType;
var
  firstChar : Char;
  secondChar : Char;
  isFloat : Boolean;
begin
  firstChar := trimmedValue[1];

  // YAML mode - fast path checks
  case firstChar of
    '~': // null
        if len = 1 then
        begin
          result := TYAMLValueType.vtNull;
          Exit;
        end;
      'n': // null, no
        if (len = 4) and (trimmedValue[2] = 'u') and (trimmedValue[3] = 'l') and (trimmedValue[4] = 'l') then
        begin
          result := TYAMLValueType.vtNull;
          Exit;
        end
        else if (len = 2) and ((trimmedValue[2] = 'o') or (trimmedValue[2] = 'O')) then
        begin
          result := TYAMLValueType.vtBoolean;
          Exit;
        end;
      'N': // Null, NO, NaN, NEL variants
        if (len = 4) then
        begin
          if (trimmedValue[2] = 'u') and (trimmedValue[3] = 'l') and (trimmedValue[4] = 'l') then
          begin
            result := TYAMLValueType.vtNull;
            Exit;
          end;
        end
        else if (len = 2) and (trimmedValue[2] = 'O') then
        begin
          result := TYAMLValueType.vtBoolean;
          Exit;
        end;
      't': // true
        if (len = 4) and (trimmedValue[2] = 'r') and (trimmedValue[3] = 'u') and (trimmedValue[4] = 'e') then
        begin
          result := TYAMLValueType.vtBoolean;
          Exit;
        end;
      'T': // True
        if (len = 4) and (trimmedValue[2] = 'r') and (trimmedValue[3] = 'u') and (trimmedValue[4] = 'e') then
        begin
          result := TYAMLValueType.vtBoolean;
          Exit;
        end;
      'f': // false
        if (len = 5) and (trimmedValue[2] = 'a') and (trimmedValue[3] = 'l') and (trimmedValue[4] = 's') and (trimmedValue[5] = 'e') then
        begin
          result := TYAMLValueType.vtBoolean;
          Exit;
        end;
      'F': // False
        if (len = 5) and (trimmedValue[2] = 'a') and (trimmedValue[3] = 'l') and (trimmedValue[4] = 's') and (trimmedValue[5] = 'e') then
        begin
          result := TYAMLValueType.vtBoolean;
          Exit;
        end;
      'y': // yes
        if (len = 3) and (trimmedValue[2] = 'e') and (trimmedValue[3] = 's') then
        begin
          result := TYAMLValueType.vtBoolean;
          Exit;
        end;
      'Y': // Yes, YES
        if (len = 3) and ((trimmedValue[2] = 'e') or (trimmedValue[2] = 'E')) and ((trimmedValue[3] = 's') or (trimmedValue[3] = 'S')) then
        begin
          result := TYAMLValueType.vtBoolean;
          Exit;
        end;
      'o': // on, off
        if (len = 2) then
        begin
          if (trimmedValue[2] = 'n') then
          begin
            result := TYAMLValueType.vtBoolean;
            Exit;
          end;
        end
        else if (len = 3) and (trimmedValue[2] = 'f') and (trimmedValue[3] = 'f') then
        begin
          result := TYAMLValueType.vtBoolean;
          Exit;
        end;
      'O': // On, ON, Off, OFF
        if (len = 2) then
        begin
          if (trimmedValue[2] = 'n') or (trimmedValue[2] = 'N') then
          begin
            result := TYAMLValueType.vtBoolean;
            Exit;
          end;
        end
        else if (len = 3) and ((trimmedValue[2] = 'f') or (trimmedValue[2] = 'F')) and ((trimmedValue[3] = 'f') or (trimmedValue[3] = 'F')) then
        begin
          result := TYAMLValueType.vtBoolean;
          Exit;
        end;
      '.': // .nan, .inf variants
        if (len = 4) then
        begin
          secondChar := trimmedValue[2];
          if ((secondChar = 'n') or (secondChar = 'N')) and
             ((trimmedValue[3] = 'a') or (trimmedValue[3] = 'A')) and
             ((trimmedValue[4] = 'n') or (trimmedValue[4] = 'N')) then
          begin
            result := TYAMLValueType.vtFloat;
            Exit;
          end
          else if ((secondChar = 'i') or (secondChar = 'I')) and
                  ((trimmedValue[3] = 'n') or (trimmedValue[3] = 'N')) and
                  ((trimmedValue[4] = 'f') or (trimmedValue[4] = 'F')) then
          begin
            result := TYAMLValueType.vtFloat;
            Exit;
          end;
        end;
      '+', '-': // +.inf, -.inf variants
        if (len = 5) and (trimmedValue[2] = '.') then
        begin
          if ((trimmedValue[3] = 'i') or (trimmedValue[3] = 'I')) and
             ((trimmedValue[4] = 'n') or (trimmedValue[4] = 'N')) and
             ((trimmedValue[5] = 'f') or (trimmedValue[5] = 'F')) then
          begin
            result := TYAMLValueType.vtFloat;
            Exit;
          end;
        end;
  end;

  // Check for timestamp pattern (expensive, do after literals)
  if IsTimestampPattern(trimmedValue) then
  begin
    result := TYAMLValueType.vtTimestamp;
    Exit;
  end;

  // Check for hex, octal, and binary number formats
  if (len > 2) and (firstChar = '0') then
  begin
    secondChar := trimmedValue[2];
    if CharInSet(secondChar, ['x','X','o','O','b','B']) then
    begin
      result := TYAMLValueType.vtInteger;
      Exit;
    end;
  end;

  // Try number parsing using fast checker
  if FastIsNumber(trimmedValue, isFloat) then
  begin
    if isFloat then
      result := TYAMLValueType.vtFloat
    else
      result := TYAMLValueType.vtInteger;
    Exit;
  end;

  // Not a recognized type, treat as string
  result := TYAMLValueType.vtString;
end;


function TYAMLParser.IsTimestampPattern(const value : string) : boolean;
var
  len : integer;
  year, month, day, hour, min, sec : integer;
  timeStart : integer;
  timeEnd : integer;
begin
  result := False;
  len := Length(value);

  // Must be at least 10 characters for YYYY-MM-DD
  if len < 10 then
    Exit;

  // Quick validation: YYYY-MM-DD pattern
  // Characters 1-4 must be digits (year)
  if not (TCharClassHelper.IsDigit(value[1]) and
          TCharClassHelper.IsDigit(value[2]) and
          TCharClassHelper.IsDigit(value[3]) and
          TCharClassHelper.IsDigit(value[4])) then
    Exit;

  // Character 5 must be '-'
  if value[5] <> '-' then
    Exit;

  // Characters 6-7 must be digits (month)
  if not (TCharClassHelper.IsDigit(value[6]) and
          TCharClassHelper.IsDigit(value[7])) then
    Exit;

  // Character 8 must be '-'
  if value[8] <> '-' then
    Exit;

  // Characters 9-10 must be digits (day)
  if not (TCharClassHelper.IsDigit(value[9]) and
          TCharClassHelper.IsDigit(value[10])) then
    Exit;

  // Parse and validate date components
  year := (Ord(value[1]) - Ord('0')) * 1000 + (Ord(value[2]) - Ord('0')) * 100 +
          (Ord(value[3]) - Ord('0')) * 10 + (Ord(value[4]) - Ord('0'));
  month := (Ord(value[6]) - Ord('0')) * 10 + (Ord(value[7]) - Ord('0'));
  day := (Ord(value[9]) - Ord('0')) * 10 + (Ord(value[10]) - Ord('0'));

  // Basic range validation
  if not ((year >= 100) and (year <= 2400) and
          (month >= 1) and (month <= 12) and
          (day >= 1) and (day <= 31)) then
    Exit;

  // If exactly 10 characters, valid date-only timestamp
  if len = 10 then
  begin
    result := True;
    Exit;
  end;

  // Check for time separator (T or space)
  if (len < 11) or not ((value[11] = 'T') or (value[11] = ' ')) then
    Exit;

  timeStart := 12;
  timeEnd := len;

  // Strip timezone suffix: Z, +HH:MM, -HH:MM
  if value[len] = 'Z' then
    Dec(timeEnd)
  else if (len >= 16) and CharInSet(value[len - 5], ['+', '-']) and (value[len - 2] = ':') then
    timeEnd := len - 6
  else if (len >= 13) and CharInSet(value[len - 2], ['+', '-']) then
    timeEnd := len - 3;

  // Need at least HH:MM (5 chars)
  if (timeEnd - timeStart + 1) < 5 then
    Exit;

  // Validate time format: HH:MM or HH:MM:SS
  // Characters timeStart and timeStart+1 must be digits (hour)
  if (timeStart + 1 > timeEnd) or
     not (TCharClassHelper.IsDigit(value[timeStart]) and
          TCharClassHelper.IsDigit(value[timeStart + 1])) then
    Exit;

  // Character timeStart+2 must be ':'
  if (timeStart + 2 > timeEnd) or (value[timeStart + 2] <> ':') then
    Exit;

  // Characters timeStart+3 and timeStart+4 must be digits (minute)
  if (timeStart + 4 > timeEnd) or
     not (TCharClassHelper.IsDigit(value[timeStart + 3]) and
          TCharClassHelper.IsDigit(value[timeStart + 4])) then
    Exit;

  // Parse hour and minute
  hour := (Ord(value[timeStart]) - Ord('0')) * 10 + (Ord(value[timeStart + 1]) - Ord('0'));
  min := (Ord(value[timeStart + 3]) - Ord('0')) * 10 + (Ord(value[timeStart + 4]) - Ord('0'));

  if not ((hour >= 0) and (hour <= 23) and (min >= 0) and (min <= 59)) then
    Exit;

  // If we have just HH:MM, we're done
  if (timeEnd - timeStart + 1) = 5 then
  begin
    result := True;
    Exit;
  end;

  // Check for seconds if present
  if (timeEnd - timeStart + 1) >= 8 then
  begin
    // Character timeStart+5 must be ':'
    if value[timeStart + 5] <> ':' then
      Exit;

    // Characters timeStart+6 and timeStart+7 must be digits (second)
    if not (TCharClassHelper.IsDigit(value[timeStart + 6]) and
            TCharClassHelper.IsDigit(value[timeStart + 7])) then
      Exit;

    // Parse seconds
    sec := (Ord(value[timeStart + 6]) - Ord('0')) * 10 + (Ord(value[timeStart + 7]) - Ord('0'));

    if (sec >= 0) and (sec <= 59) then
      result := True;
  end;
end;

function TYAMLParser.ParseScalar(const parent : IYAMLValue; const tag : string) : IYAMLValue;
var
  value : string;
  valueType : TYAMLValueType;
  firstPart : string;
  partCount : integer;
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
        firstPart := value;
        partCount := 1;
        NextToken;

        // Collect consecutive value tokens on the same line with same indent
        while (FCurrentToken.TokenKind = TYAMLTokenKind.Value) do
        begin
          value := value + ' ' + FCurrentToken.value;
          Inc(partCount);
          NextToken;
        end;

        // Validate: if we're at document root and have multiple parts that look like key-value,
        // but no colon, this might be malformed YAML
        if (parent = nil) and (partCount > 1) then
        begin
          // Check if this looks like a key followed by value(s) without colon
          // This is a heuristic - if the first part looks like an identifier and
          // there are additional parts, it might be missing a colon
          if (Length(firstPart) > 0) and
             (CharInSet(firstPart[1], ['a'..'z', 'A'..'Z', '_'])) then
            RaiseParseError('Missing colon after key "' + firstPart + '"');
        end;

        valueType := IsScalarValue(value, FJSONMode);

        // Additional JSON mode validation for invalid literals
        if FJSONMode and (valueType = TYAMLValueType.vtString) then
        begin
          // Check for hex/octal/binary numbers (not valid in JSON)
          if (Length(value) > 2) and (value[1] = '0') and
             CharInSet(value[2], ['x','X','o','O','b','B']) then
          begin
            RaiseParseError('Invalid number format in JSON: "' + value + '". JSON does not support hex, octal, or binary number literals.');
          end;

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


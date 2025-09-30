unit VSoft.YAML.Lexer;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  VSoft.YAML.Utils,
  VSoft.YAML.IO,
  VSoft.YAML;

{$I 'VSoft.YAML.inc'}

type
  // Token types
  TYAMLTokenKind = (
    EOF,          // End of file
    NewLine,      // New line
    Indent,       // Indentation
    Key,          // Map key
    Value,        // Scalar value
    SequenceItem, // Sequence item marker (-)
    Colon,        // : (key-value separator)
    Comma,        // , (flow separator)
    LBracket,     // [ (flow sequence start)
    RBracket,     // ] (flow sequence end)
    LBrace,       // { (flow mapping start)
    RBrace,       // } (flow mapping end)
    QuotedString, // Quoted string
    Literal,      // Literal scalar
    Folded,       // Folded scalar
    Directive,    // YAML directive
    DocStart,     // Document start (---)
    DocEnd,       // Document end (...)
    Anchor,       // Anchor definition (&anchor)
    Alias,        // Alias reference (*alias)
    Tag,          // Type tag (!!str, !!int, etc.)
    Comment,      // Comment (# comment text)
    SetItem       // ? Set Item
  );

  // Token record
  TYAMLToken = record
    TokenKind : TYAMLTokenKind;
    Prefix : string; //tag prefix
    Value : string;
    Line : integer;
    Column : integer;
    IndentLevel : integer;
  end;

  // YAML Lexer class
  TYAMLLexer = class
  private
    type
      TTag = record
        Prefix : string;
        Handle : string;
      end;
  private
    FReader : IInputReader;
    FOptions : IYAMLParserOptions;
    FJSONMode : boolean;
    FIndentStack : TList<Integer>;
    FSequenceItemIndent : integer;
    FInValueContext : boolean; // Track if we're reading a value (after colon) vs key
    FStringBuilder : TStringBuilder;
    FHexBuilder : TStringBuilder;  // For building hex strings in Unicode escapes

    // Peek token cache for performance
    FPeekedToken: TYAMLToken;
    FHasPeekedToken: Boolean;

    // Stack management methods
    procedure PushIndentLevel(level: Integer);
    function PopIndentLevel: Integer;
    function CurrentIndentLevel: Integer;
  protected
    function GetLine : integer;inline;
    function GetColumn : integer;inline;
    function IsAtEnd : boolean;inline;
    function IsWhitespace(ch : Char) : boolean;inline;

    procedure SkipWhitespace;
    function SkipWhitespaceAndCalculateIndent : integer;
    function ReadDirective : string;
    function ReadComment : string;
    function ReadDoubleQuotedString : string;
    function ReadSingleQuotedString : string;
    function ReadUnquotedString(reset : boolean = true) : string;
    function ReadNumber : string;
    function ReadAnchorOrAlias : string;
    function ReadTag : TTag;
    function ReadLiteralScalar : string;
    function ReadFoldedScalar : string;
    function ReadTimestamp : string;
    function IsTimestampStart : boolean;
    function IsSpecialFloat : boolean;
    function ReadSpecialFloat : string;
  public
    constructor Create(const reader : IInputReader; const options : IYAMLParserOptions = nil);
    destructor Destroy; override;

    function NextToken : TYAMLToken;
    function PeekToken : TYAMLToken;
    function PeekTokenKind : TYAMLTokenKind;inline;

    property Line : integer read GetLine;
    property Column : integer read GetColumn;
  end;

implementation

uses
  System.Character,
  System.Classes;

// Static escape sequence lookup tables - initialized once at startup
var
  // Maps escape character to replacement character
  // Special values: #0 = invalid escape, #1 = complex escape (u/U/x)
  EscapeTable: array[0..255] of Char;
  
  // Tracks which escapes are valid in JSON mode
  JSONValidEscapes: array[0..255] of Boolean;

{ TYAMLLexer }

constructor TYAMLLexer.Create(const reader : IInputReader; const options : IYAMLParserOptions);
begin
  inherited Create;
  FReader := reader;
  FOptions := options;
  if FOptions <> nil then
    FJSONMode := FOptions.JSONMode
  else
    FJSONMode := false;

  FSequenceItemIndent := -1;
  FInValueContext := False;
  FHasPeekedToken := False;

  // Initialize indent stack with base level 0
  FIndentStack := TList<Integer>.Create;
  FIndentStack.Add(0);
  FStringBuilder := TStringBuilder.Create(1024);
  FHexBuilder := TStringBuilder.Create(8);  // Max 8 chars for \UXXXXXXXX
end;

destructor TYAMLLexer.Destroy;
begin
  FIndentStack.Free;
  FStringBuilder.Free;
  FHexBuilder.Free;
  inherited Destroy;
end;

function TYAMLLexer.GetColumn: integer;
begin
  result := FReader.Column;
end;

function TYAMLLexer.GetLine: integer;
begin
  result := FReader.Line
end;


function TYAMLLexer.IsAtEnd : boolean;
begin
  result := FReader.IsEOF;
end;

function TYAMLLexer.IsWhitespace(ch : Char) : boolean;
begin
  result := TCharClassHelper.IsWhitespace(ch);
end;



procedure TYAMLLexer.SkipWhitespace;
var
  ch : Char;
begin
  // Optimized: check character first, then IsAtEnd only if needed
  while True do
  begin
    ch := FReader.Current;
    if not TCharClassHelper.IsWhitespace(ch) then
      Break;
    if IsAtEnd then
      Break;
    FReader.Read;
  end;
end;

function TYAMLLexer.SkipWhitespaceAndCalculateIndent : integer;
var
  count : integer;
begin
  count := 0;
  while IsWhitespace(FReader.Current) and not IsAtEnd do
  begin
    if FReader.Current = ' ' then
      Inc(count)
    else if FReader.Current = #9 then
    begin
      if FJSONMode then
      begin
        // In JSON mode, treat tabs as 2 spaces
        Inc(count, 2);
      end
      else
      begin
        // YAML 1.2 specification: Tabs are not allowed for indentation
        raise EYAMLParseException.Create('Tabs are not allowed for indentation in YAML', FReader.Line, FReader.Column);
      end;
    end;
    FReader.Read;
  end;

  result := count;
end;

function TYAMLLexer.ReadComment : string;
var
  ch: Char;
begin
  FStringBuilder.Reset;
  // Skip the '#' character
  FReader.Read;

  // Skip any leading whitespace after #
  SkipWhitespace;

  // Read the comment text until end of line
  while not IsAtEnd do
  begin
    ch := FReader.Current;
    if (ch = #10) or (ch = #13) then
      Break;
    FStringBuilder.Append(ch);
    FReader.Read;
  end;
  
  result := FStringBuilder.ToString;
end;

function TYAMLLexer.ReadDirective: string;
var
  ch: Char;
begin
  FStringBuilder.Reset;
  //just read the whole directive, we'll parse it later
  while not IsAtEnd do
  begin
    ch := FReader.Current;
    if (ch = #10) or (ch = #13) then
      Break;
    FStringBuilder.Append(ch);
    FReader.Read;
  end;

  result := FStringBuilder.ToString;
end;

function TYAMLLexer.ReadDoubleQuotedString : string;
var
  foundClosingQuote : boolean;
  i : Integer;
  codePoint : Integer;
  codePoint64 : Int64;
  peekChar : Char;
  escapeChar : Char;
  currentCharOrd : Integer;
begin
  FStringBuilder.Reset;
  FReader.Read; // Skip opening quote
  foundClosingQuote := False;

  while not IsAtEnd do
  begin
    // Double-quoted strings: backslash acts as escape character
    if FReader.Current = '\' then
    begin
      // Check if this is a line continuation (backslash followed by newline)
      peekChar := FReader.Peek();
      if (peekChar = #10) or (peekChar = #13) then
      begin
        // In JSON mode, line continuation is not allowed
        if FJSONMode then
        begin
          raise EYAMLParseException.Create('Line continuation (backslash followed by newline) is not valid in JSON', FReader.Line, FReader.Column);
        end;
        
        // Line continuation - skip the backslash and newline, consume any leading whitespace on next line
        FReader.Read; // Skip the backslash
        
        // Skip the newline character(s)
        if FReader.Current = #13 then
        begin
          FReader.Read;
          if FReader.Current = #10 then
            FReader.Read;
        end
        else if FReader.Current = #10 then
          FReader.Read;
        
        // Skip any leading whitespace on the continuation line
        while IsWhitespace(FReader.Current) and not IsAtEnd do
          FReader.Read;
        
        // Continue processing without adding anything to the result
        Continue;
      end
      else
      begin
        // This is an escape sequence - process it using lookup table
        FReader.Read; // Skip the backslash
        if not IsAtEnd then
        begin
          // Cache the character ordinal value
          currentCharOrd := Ord(FReader.Current);
          
          // Check if character is in valid ASCII range for escape sequences
          if currentCharOrd > 255 then
            raise EYAMLParseException.Create('Invalid escape sequence: \' + FReader.Current, FReader.Line, FReader.Column);
            
          escapeChar := EscapeTable[currentCharOrd];
          
          // Check for invalid escape
          {$WARN CVT_ACHAR_TO_WCHAR OFF}
          if escapeChar = #255 then
            raise EYAMLParseException.Create('Invalid escape sequence: \' + FReader.Current, FReader.Line, FReader.Column);
          {$WARN CVT_ACHAR_TO_WCHAR ON}

          // Check JSON mode validity  
          if FJSONMode and not JSONValidEscapes[currentCharOrd] then
            raise EYAMLParseException.Create('Invalid escape sequence in JSON: \' + FReader.Current + ' is not supported', FReader.Line, FReader.Column);
          
          // Handle complex escapes that need special processing
          if escapeChar = #1 then
          begin
            case FReader.Current of
            'u': begin
              // Unicode escape sequence \uXXXX (4 hex digits)
              FReader.Read; // Skip 'u'
              FHexBuilder.Clear;
              
              // Read and validate 4 hex digits
              for i := 1 to 4 do
              begin
                if IsAtEnd or not TYAMLCharUtils.IsHexidecimal(FReader.Current) then
                  raise EYAMLParseException.Create('Invalid Unicode escape sequence: \u requires 4 hex digits', FReader.Line, FReader.Column);
                FHexBuilder.Append(FReader.Current);
                FReader.Read;
              end;
              
              // Convert hex to character
              codePoint := StrToInt('$' + FHexBuilder.ToString);
              FStringBuilder.Append(Char(codePoint));
              Continue;
            end;
            'U': begin
              // Unicode escape sequence \UXXXXXXXX (8 hex digits) - not valid in JSON mode
              if FJSONMode then
                raise EYAMLParseException.Create('Invalid escape sequence in JSON: \U is not supported, use \u instead', FReader.Line, FReader.Column);
              
              FReader.Read; // Skip 'U'
              FHexBuilder.Clear;
              
              // Read and validate 8 hex digits
              for i := 1 to 8 do
              begin
                if IsAtEnd or not TYAMLCharUtils.IsHexidecimal(FReader.Current) then
                  raise EYAMLParseException.Create('Invalid Unicode escape sequence: \U requires 8 hex digits', FReader.Line, FReader.Column);
                FHexBuilder.Append(FReader.Current);
                FReader.Read;
              end;
              
              // Convert hex to character
              codePoint64 := StrToInt64('$' + FHexBuilder.ToString);
              if codePoint64 <= $FFFF then
                FStringBuilder.Append(Char(codePoint64))
              else if codePoint64 <= $10FFFF then
              begin
                // Convert to UTF-16 surrogate pair for code points > U+FFFF
                codePoint64 := codePoint64 - $10000;
                FStringBuilder.Append(Char($D800 + (codePoint64 shr 10)));    // High surrogate
                FStringBuilder.Append(Char($DC00 + (codePoint64 and $3FF))); // Low surrogate
              end
              else
                FStringBuilder.Append('?'); // Invalid Unicode code point
              Continue;
            end;
            'x': begin
              // Hex escape sequence \xXX - not valid in JSON mode
              if FJSONMode then
                raise EYAMLParseException.Create('Invalid escape sequence in JSON: \x is not supported', FReader.Line, FReader.Column);
                
              FReader.Read; // Skip 'x'
              FHexBuilder.Clear;
              
              // Read and validate 2 hex digits
              for i := 1 to 2 do
              begin
                if IsAtEnd or not TYAMLCharUtils.IsHexidecimal(FReader.Current) then
                  raise EYAMLParseException.Create('Invalid hex escape sequence: \x requires 2 hex digits', FReader.Line, FReader.Column);
                FHexBuilder.Append(FReader.Current);
                FReader.Read;
              end;
              
              // Convert hex to character
              codePoint := StrToInt('$' + FHexBuilder.ToString);
              FStringBuilder.Append(Char(codePoint));
              Continue;
            end;
            end;
          end
          else
          begin
            // Simple escape - use lookup table result
            FStringBuilder.Append(escapeChar);
            FReader.Read; // Read the escape character we just processed
            Continue;
          end;
        end;
      end;
    end
    else if FReader.Current = '"' then
    begin
      FReader.Read; // Skip closing quote
      foundClosingQuote := True;
      Break;
    end
    else
    begin
      // In JSON mode, check for literal newlines which are not allowed
      if FJSONMode and CharInSet(FReader.Current,[#10, #13]) then
      begin
        raise EYAMLParseException.Create('Literal line breaks are not allowed in JSON strings. Use \n for newlines.', FReader.Line, FReader.Column);
      end;
      FStringBuilder.Append(FReader.Current);
    end;

    FReader.Read;
  end;

  // If we exited the loop without finding a closing quote, it's an error
  if not foundClosingQuote then
    raise EYAMLParseException.Create('Unterminated quoted string', FReader.Line, FReader.Column);
  
  result := FStringBuilder.ToString;
end;

function TYAMLLexer.ReadSingleQuotedString : string;
var
  foundClosingQuote : boolean;
  peekChar : Char;
  ch : Char;
begin
  FStringBuilder.Reset;
  FReader.Read; // Skip opening quote
  foundClosingQuote := False;

  while not IsAtEnd do
  begin
    // Single-quoted strings: only single quotes need escaping (by doubling)
    if FReader.Current = '''' then
    begin
      peekChar := FReader.Peek();
      if peekChar = '''' then
      begin
        // Escaped single quote: '' becomes '
        FStringBuilder.Append('''');
        FReader.Read; // Skip the first quote
        FReader.Read; // Skip the second quote
        Continue;
      end
      else
      begin
        // End of string
        FReader.Read; // Skip closing quote
        foundClosingQuote := True;
        Break;
      end;
    end
    else if FReader.Current = '\' then
    begin
      // Check if this is a line continuation (backslash followed by newline)
      // Even in single-quoted strings, line continuation should work
      peekChar := FReader.Peek(); //peek can be expensive so cache when possible;
      if (peekChar = #10) or (peekChar = #13) then
      begin
        // In JSON mode, line continuation is not allowed
        if FJSONMode then
        begin
          raise EYAMLParseException.Create('Line continuation (backslash followed by newline) is not valid in JSON', FReader.Line, FReader.Column);
        end;
        
        // Line continuation - skip the backslash and newline, consume any leading whitespace on next line
        FReader.Read; // Skip the backslash
        
        // Skip the newline character(s)
        if FReader.Current = #13 then
        begin
          FReader.Read;
          if FReader.Current = #10 then
            FReader.Read;
        end
        else if FReader.Current = #10 then
          FReader.Read;
        
        // Skip any leading whitespace on the continuation line
        while IsWhitespace(FReader.Current) and not IsAtEnd do
          FReader.Read;
        
        // Continue processing without adding anything to the result
        Continue;
      end
      else
      begin
        // All other backslashes are literal in single-quoted strings
        FStringBuilder.Append(FReader.Current);
      end;
    end
    else
    begin
      ch := FReader.Current;
      // In JSON mode, check for literal newlines which are not allowed
      if FJSONMode and ((ch = #10) or (ch = #13)) then
      begin
        raise EYAMLParseException.Create('Literal line breaks are not allowed in JSON strings. Use \n for newlines.', FReader.Line, FReader.Column);
      end;
      // All other characters are literal
      FStringBuilder.Append(ch);
    end;

    FReader.Read;
  end;

  // If we exited the loop without finding a closing quote, it's an error
  if not foundClosingQuote then
    raise EYAMLParseException.Create('Unterminated quoted string', FReader.Line, FReader.Column);
  
  result := FStringBuilder.ToString;
end;

function TYAMLLexer.ReadUnquotedString(reset : boolean) : string;
const
  cValueSet =  [#10, #13, '#', '[', ']', '{', '}', ','];
  cNonValueSet = [':', #10, #13, '#', '[', ']', '{', '}', ','];

  function DoCheck : boolean;
  begin
    if FInValueContext then
      result := not CharInSet(FReader.Current, cValueSet)
    else
      result := not CharInSet(FReader.Current, cNonValueSet)
  end;

begin
  if reset then
    FStringBuilder.Reset;


  while not IsAtEnd and DoCheck do
  begin
    FStringBuilder.Append(FReader.Current);
    FReader.Read;
  end;

  result := Trim(FStringBuilder.ToString);
end;

function TYAMLLexer.ReadNumber : string;
var
  dotCount : integer;
  tempChar : Char;
  ch : Char;
begin
  FStringBuilder.Reset;
  dotCount := 0;

  // Handle negative numbers
  if FReader.Current = '-' then
  begin
    FStringBuilder.Append(FReader.Current);
    FReader.Read;
  end;

  // Check for hex, octal, or binary prefixes after optional minus
  if FReader.Current = '0' then
  begin
    FStringBuilder.Append(FReader.Current);
    FReader.Read;

    // Check for hex prefix (0x or 0X)
    ch := FReader.Current;
    if (ch = 'x') or (ch = 'X') then
    begin
      // In JSON mode, hex numbers are not allowed - treat as unquoted string
      if FJSONMode then
      begin
        result := ReadUnquotedString(false); // Tell it not to reset the stringbuilder
        Exit;
      end;
        
      FStringBuilder.Append(FReader.Current);
      FReader.Read;
      // Read hex digits
      while TCharClassHelper.IsHexDigit(FReader.Current) and not IsAtEnd do
      begin
        FStringBuilder.Append(FReader.Current);
        FReader.Read;
      end;
      result := FStringBuilder.ToString;
      Exit; // Done reading hex number
    end
    // Check for octal prefix (0o or 0O)
    else if (ch = 'o') or (ch = 'O') then
    begin
      // In JSON mode, octal numbers are not allowed - treat as unquoted string
      if FJSONMode then
      begin
        result := ReadUnquotedString(false); // Tell it not to reset the stringbuilder
        Exit;
      end;
      
      FStringBuilder.Append(FReader.Current);
      FReader.Read;
      // Read octal digits (0-7)
      while TCharClassHelper.IsOctalDigit(FReader.Current) and not IsAtEnd do
      begin
        FStringBuilder.Append(FReader.Current);
        FReader.Read;
      end;
      result := FStringBuilder.ToString;
      Exit; // Done reading octal number
    end
    // Check for binary prefix (0b or 0B)
    else if (ch = 'b') or (ch = 'B') then
    begin
      // In JSON mode, binary numbers are not allowed - treat as unquoted string
      if FJSONMode then
      begin
        result := ReadUnquotedString(false); // Tell it not to reset the stringbuilder
        Exit;
      end;
      
      FStringBuilder.Append(FReader.Current);
      FReader.Read;
      // Read binary digits (0-1)
      while TCharClassHelper.IsBinaryDigit(FReader.Current) and not IsAtEnd do
      begin
        FStringBuilder.Append(FReader.Current);
        FReader.Read;
      end;
      result := FStringBuilder.ToString;
      Exit; // Done reading binary number
    end
    else
    begin
      // In JSON mode, numbers starting with 0 followed by digits are not allowed (leading zeros)
      if FJSONMode and TCharClassHelper.IsDigit(FReader.Current) then
        raise EYAMLParseException.Create('Numbers with leading zeros are not valid in JSON', FReader.Line, FReader.Column);
    end;
    // If no special prefix, continue reading as regular decimal number
  end;

  // Read remaining integer digits for decimal numbers with integrated dot checking
  while TCharClassHelper.IsDigitOrUnderscore(FReader.Current) and not IsAtEnd do
  begin
    tempChar := FReader.Current;
    if tempChar <> '_' then
    begin
      FStringBuilder.Append(tempChar);
    end;
    FReader.Read;
  end;

  // Read decimal part with dot counting integrated
  if FReader.Current = '.' then
  begin
    Inc(dotCount);
    FStringBuilder.Append(FReader.Current);
    FReader.Read;
    
    while TYAMLCharUtils.IsDigit(FReader.Current) and not IsAtEnd do
    begin
      tempChar := FReader.Current;
      FStringBuilder.Append(tempChar);
      FReader.Read;
    end;
  end;

  // Check for second dot - if found, delegate to ReadUnquotedString
  if FReader.Current = '.' then
  begin
    Inc(dotCount);
    if dotCount > 1 then
    begin
      // Hit second dot - this is not a number, delegate to ReadUnquotedString
      result := ReadUnquotedString(false); //tell it not to reset the stringbuilder
      Exit;
    end;
  end;

  // Read exponent part (only for decimal numbers)
  ch := FReader.Current;
  if (ch = 'e') or (ch = 'E') then
  begin
    FStringBuilder.Append(ch);
    FReader.Read;
    ch := FReader.Current;
    if (ch = '+') or (ch = '-') then
    begin
      FStringBuilder.Append(ch);
      FReader.Read;
    end;
    
    // In JSON mode, there must be at least one digit after e/E (and optional sign)
    if FJSONMode and not TCharClassHelper.IsDigit(FReader.Current) then
    begin
      raise EYAMLParseException.Create('Invalid number format in JSON: exponent must have at least one digit after e/E', FReader.Line, FReader.Column);
    end;

    while TCharClassHelper.IsDigit(FReader.Current) and not IsAtEnd do
    begin
      FStringBuilder.Append(FReader.Current);
      FReader.Read;
    end;
  end;
  
  result := FStringBuilder.ToString;
end;

function TYAMLLexer.ReadAnchorOrAlias : string;
begin
  FStringBuilder.Reset;

  // Read anchor or alias name
  while TCharClassHelper.IsIdentifierChar(FReader.Current) and not IsAtEnd do
  begin
    FStringBuilder.Append(FReader.Current);
    FReader.Read;
  end;

  result := FStringBuilder.ToString;
end;

function TYAMLLexer.ReadTag : TTag;
var
  ch: Char;
begin
  // YAML supports multiple tag formats:
  // 1. !!tag (short form)
  // 2. !prefix!tag (prefixed form)
  // 3. !<uri> (verbatim form)

  if FReader.Current = '!' then
  begin
    FStringBuilder.Reset;
    FStringBuilder.Append('!');
    FReader.Read; //skip the !

    // Check for verbatim tag format: !<uri>
    if FReader.Current = '<' then
    begin
      FStringBuilder.Append(FReader.Current);
      FReader.Read;
      // Read everything until closing >
      while not IsAtEnd do
      begin
        ch := FReader.Current;
        if (ch = '>') or (ch = #10) or (ch = #13) then
          Break;
        FStringBuilder.Append(ch);
        FReader.Read;
      end;
      // Include the closing >
      if FReader.Current = '>' then
      begin
        FStringBuilder.Append(FReader.Current);
        FReader.Read;
      end;
      Result.Handle := FStringBuilder.ToString;
    end
    else if FReader.Current = '!' then
    begin
      FStringBuilder.Append('!');
      // Short form: !!tag
      FReader.Read;
      // Read tag name (letters, digits, underscores, hyphens)
      while TCharClassHelper.IsIdentifierChar(FReader.Current) and not IsAtEnd do
      begin
        FStringBuilder.Append(FReader.Current);
        FReader.Read;
      end;
      Result.Handle := FStringBuilder.ToString;
    end
    else
    begin
      // Prefixed form: !prefix!tag or just !tag
      // First read the prefix/tag name part
      FStringBuilder.Reset;
      while TCharClassHelper.IsIdentifierChar(FReader.Current) and not IsAtEnd do
      begin
        FStringBuilder.Append(FReader.Current);
        FReader.Read;
      end;

      // Check for second ! (prefix!tag format)
      if FReader.Current = '!' then
      begin
        // This was a prefix, store it
        Result.Prefix := FStringBuilder.ToString;
        FReader.Read;
        // Read the tag name after the second !
        FStringBuilder.Reset;
        while TCharClassHelper.IsIdentifierChar(FReader.Current) and not IsAtEnd do
        begin
          FStringBuilder.Append(FReader.Current);
          FReader.Read;
        end;
        Result.Handle := FStringBuilder.ToString;
      end
      else
      begin
        //local tag - what we read is the handle
        result.Handle := FStringBuilder.ToString;
        result.Prefix := '';
      end;

    end;
  end;
end;


// Stack management methods
const
  MAX_INDENT_DEPTH = 100; // Reasonable limit for YAML nesting

procedure TYAMLLexer.PushIndentLevel(level: Integer);
begin
  if FIndentStack.Count >= MAX_INDENT_DEPTH then
    raise EYAMLParseException.Create('Maximum nesting depth exceeded', FReader.Line, FReader.Column);
  FIndentStack.Add(level);
end;

function TYAMLLexer.PopIndentLevel: Integer;
begin
  if FIndentStack.Count <= 1 then
    raise EYAMLParseException.Create('Cannot pop base indent level', FReader.Line, FReader.Column);
  result := FIndentStack[FIndentStack.Count - 1];
  FIndentStack.Delete(FIndentStack.Count - 1);
end;

function TYAMLLexer.CurrentIndentLevel: Integer;
begin
  if FIndentStack.Count = 0 then
    result := 0
  else
    result := FIndentStack[FIndentStack.Count - 1];
end;

function TYAMLLexer.IsTimestampStart : boolean;
var
  i : integer;
  digitCount : integer;
begin
  // Check if current position looks like start of a timestamp
  // Look for patterns like : YYYY-MM-DD, YYYY-MM-DDTHH:MM:SS
  result := False;

  if not TYAMLCharUtils.IsDigit(FReader.Current) then
    Exit;

  digitCount := 0;
  i := 0;

  // Check for 4 digits (year)
  while (i < 4) and TYAMLCharUtils.IsDigit(FReader.Peek(i)) do
  begin
    Inc(digitCount);
    Inc(i);
  end;

  // Must have at least 4 digits followed by a dash to be considered a timestamp
  if (digitCount >= 4) and (FReader.Peek(i) = '-') then
    result := True;
end;

function TYAMLLexer.ReadTimestamp : string;
var
  i : integer;
  hasColon : boolean;
begin
  FStringBuilder.Reset;

  // Read timestamp pattern : YYYY-MM-DD or YYYY-MM-DDTHH:MM:SS or variations
  // This function should read complete timestamp tokens including colons within time portions
  while not CharInSet(FReader.Current, [#0,#9,#13,#10,'#','[',']','{','}',',', ' ']) do
  begin
    // Stop reading if we hit a colon followed by space (YAML key separator)
    if (FReader.Current = ':') and IsWhitespace(FReader.Peek()) then
      Break;

    FStringBuilder.Append(FReader.Current);
    FReader.Read;
  end;

  // Also read time portion if separated by space : YYYY-MM-DD HH:MM:SS
  if (FReader.Current = ' ') and TYAMLCharUtils.IsDigit(FReader.Peek) then
  begin
    // Look ahead to see if this looks like a time portion
    i := 1;
    hasColon := False;
    while (i <= 10) and not IsAtEnd and (FReader.Peek(i) <> ' ') and (FReader.Peek(i) <> #10) and (FReader.Peek(i) <> #13) do
    begin
      if FReader.Peek(i) = ':' then
        hasColon := True;
      Inc(i);
    end;

    if hasColon then
    begin
      FStringBuilder.Append(FReader.Current); // Add the space
      FReader.Read;

     // Read the time portion including colons
      while not CharInSet(FReader.Current, [#0,#9,'#','[',']','{','}',',', ' ']) do
      begin
        // Stop if we hit colon followed by space (YAML separator)
        if (FReader.Current = ':') and IsWhitespace(FReader.Peek) then
          Break;

        FStringBuilder.Append(FReader.Current);
        FReader.Read;
      end;
    end;
  end;

  result := Trim(FStringBuilder.ToString);
end;

function TYAMLLexer.IsSpecialFloat : boolean;
var
  i : integer;
  testStr : string;
  ch : Char;
begin
  result := False;
  testStr := '';

  // Handle optional sign for infinity
  i := 0;
  ch := FReader.Current;
  if (ch = '+') or (ch = '-') then
  begin
    testStr := testStr + FReader.Peek(i);
    Inc(i);
  end;

  // Check for .nan, .NaN, .NAN
  if FReader.Peek(i) = '.' then
  begin
    testStr := testStr + FReader.Peek(i);
    Inc(i);

    // Check for 'nan' variations
    if ((FReader.Peek(i) = 'n') and (FReader.Peek(i+1) = 'a') and (FReader.Peek(i+2) = 'n')) or
       ((FReader.Peek(i) = 'N') and (FReader.Peek(i+1) = 'a') and (FReader.Peek(i+2) = 'N')) or
       ((FReader.Peek(i) = 'N') and (FReader.Peek(i+1) = 'A') and (FReader.Peek(i+2) = 'N')) then
    begin
      // Check that the character after 'nan' is not alphanumeric (word boundary)
      if not TYAMLCharUtils.IsAlphaNumeric(FReader.Peek(i+3)) then
        result := True;
    end
    // Check for 'inf' variations
    else if ((FReader.Peek(i) = 'i') and (FReader.Peek(i+1) = 'n') and (FReader.Peek(i+2) = 'f')) or
            ((FReader.Peek(i) = 'I') and (FReader.Peek(i+1) = 'n') and (FReader.Peek(i+2) = 'f')) or
            ((FReader.Peek(i) = 'I') and (FReader.Peek(i+1) = 'N') and (FReader.Peek(i+2) = 'F')) then
    begin
      // Check that the character after 'inf' is not alphanumeric (word boundary)
      if not TYAMLCharUtils.IsAlphaNumeric(FReader.Peek(i+3)) then
        result := True;
    end;
  end;
end;

function TYAMLLexer.ReadSpecialFloat : string;
var
  ch: Char;
begin
  FStringBuilder.Reset;

  // Handle optional sign
  ch := FReader.Current;
  if (ch = '+') or (ch = '-') then
  begin
    FStringBuilder.Append(ch);
    FReader.Read;
  end;

  // Should be at '.' now
  if FReader.Current = '.' then
  begin
    FStringBuilder.Append(FReader.Current);
    FReader.Read;

    // Read the special float identifier (nan, NaN, NAN, inf, Inf, INF)
    while TYAMLCharUtils.IsAlpha(FReader.Current) and not IsAtEnd do
    begin
      FStringBuilder.Append(FReader.Current);
      FReader.Read;
    end;
  end;
  
  result := FStringBuilder.ToString;
end;

function TYAMLLexer.NextToken : TYAMLToken;
var
  startLine, startColumn : integer;
  currentIndent : integer;
  tag : TTag;
  peekChar : Char;
begin
  // Check for cached peeked token first
  if FHasPeekedToken then
  begin
    result := FPeekedToken;
    FHasPeekedToken := False;
    Exit;
  end;

  // Initialize token
  result.TokenKind := TYAMLTokenKind.EOF;
  result.Value := '';
  result.Line := FReader.Line;
  result.Column := FReader.Column;
  result.IndentLevel := 0;

  // Skip whitespace but track indentation at line start
  if FReader.Column = 1 then
  begin
    currentIndent := SkipWhitespaceAndCalculateIndent;
    result.IndentLevel := currentIndent;
    if currentIndent > CurrentIndentLevel then
    begin
      PushIndentLevel(currentIndent);
      result.TokenKind := TYAMLTokenKind.Indent;
      Exit;
    end
    else if currentIndent < CurrentIndentLevel then
    begin
      // Handle dedent - pop indent levels until we find matching or lower level
      while (FIndentStack.Count > 1) and (currentIndent < CurrentIndentLevel) do
        PopIndentLevel;
      
      // Set the result indent level to the current level after popping
      result.IndentLevel := currentIndent;
    end
    else
    begin
      // Same indentation level, just preserve indent level
      result.IndentLevel := currentIndent;
    end;
  end
  else
  begin
    // Set indent level to current stack level for tokens not at line start
    // Special handling for tokens following sequence items
    if FSequenceItemIndent >= 0 then
      result.IndentLevel := FSequenceItemIndent
    else
      result.IndentLevel := CurrentIndentLevel;
    SkipWhitespace;
  end;

  if IsAtEnd then
  begin
    result.TokenKind := TYAMLTokenKind.EOF;
    Exit;
  end;

  startLine := FReader.Line;
  startColumn := FReader.Column;

  case FReader.Current of
    #10, #13 :
      begin
        result.TokenKind := TYAMLTokenKind.NewLine;
        // Reset sequence item indent tracking at newlines
        FSequenceItemIndent := -1;
        // Reset to key context at newlines
        FInValueContext := False;
        FReader.Read;
        if (FReader.Current = #10) and (FReader.Previous = #13) then
          FReader.Read; // Skip LF after CR
      end;

    ':':
      begin
        result.TokenKind := TYAMLTokenKind.Colon;
        // Switch to value context after colon
        FInValueContext := True;
        FReader.Read;
      end;

    '-':
      begin
        peekChar := FReader.Peek();
        if IsWhitespace(peekChar) then
        begin
          result.TokenKind := TYAMLTokenKind.SequenceItem;
          // For sequence items, use the actual column position for proper nesting
          // Override the FSequenceItemIndent setting for this token
          result.IndentLevel := FReader.Column - 1; // Column is 1-based, indent is 0-based
          // For subsequent tokens, subsequent tokens should be at the sequence item level
          // until we encounter a newline that changes indentation
          FSequenceItemIndent := result.IndentLevel;
          FReader.Read;
        end
        else if (peekChar = '-') and (FReader.Peek(2) = '-') then
        begin
          result.TokenKind := TYAMLTokenKind.DocStart;
          // No value assignment needed for ttDocStart
          FReader.Read; FReader.Read; FReader.Read;
        end
        else if IsSpecialFloat then
        begin
          result.TokenKind := TYAMLTokenKind.Value;
          result.Value := ReadSpecialFloat;
        end
        else
        begin
          result.TokenKind := TYAMLTokenKind.Value;
          result.Value := ReadNumber; //if it isn't a numbeer then it will call ReadUnquotedString
        end;
      end;

    '+':
      begin
        if IsSpecialFloat then
        begin
          result.TokenKind := TYAMLTokenKind.Value;
          result.Value := ReadSpecialFloat;
        end
        else
        begin
          result.TokenKind := TYAMLTokenKind.Value;
          result.Value := ReadNumber;
        end;
      end;

    '.':
      begin
        peekChar := FReader.Peek();
        if (peekChar = '.') and (FReader.Peek(2) = '.') then
        begin
          result.TokenKind := TYAMLTokenKind.DocEnd;
          // No value assignment needed for ttDocEnd
          FReader.Read; FReader.Read; FReader.Read;
        end
        else if IsSpecialFloat then
        begin
          result.TokenKind := TYAMLTokenKind.Value;
          result.Value := ReadSpecialFloat;
        end
        else if TYAMLCharUtils.IsDigit(peekChar) then
        begin
          // In JSON mode, decimal numbers must have a leading digit before the dot
          if FJSONMode then
            raise EYAMLParseException.Create('Decimal numbers must have a leading digit before the dot in JSON', FReader.Line, FReader.Column);
            
          result.TokenKind := TYAMLTokenKind.Value;
          result.Value := ReadNumber;
        end
        else
        begin
          result.TokenKind := TYAMLTokenKind.Value;
          result.Value := ReadUnquotedString;
        end;
      end;

    ',':
      begin
        result.TokenKind := TYAMLTokenKind.Comma;
        // Reset to key context after comma in flow collections
        FInValueContext := False;
        FReader.Read;
      end;

    '[':
      begin
        result.TokenKind := TYAMLTokenKind.LBracket;
        // Reset to key context when entering flow sequence
        FInValueContext := False;
        FReader.Read;
      end;

    ']':
      begin
        result.TokenKind := TYAMLTokenKind.RBracket;
        // Reset to key context when exiting flow sequence
        FInValueContext := False;
        FReader.Read;
      end;

    '{':
      begin
        result.TokenKind := TYAMLTokenKind.LBrace;
        // Reset to key context when exiting flow sequence
        FInValueContext := False;
        FReader.Read;
      end;

    '}':
      begin
        result.TokenKind := TYAMLTokenKind.RBrace;
        FReader.Read;
      end;

    '"':
      begin
        result.TokenKind := TYAMLTokenKind.QuotedString;
        result.Value := ReadDoubleQuotedString;
      end;

    '''':
      begin
        // Single-quoted strings are not valid in JSON mode
        if FJSONMode then
          raise EYAMLParseException.Create('Single-quoted strings are not valid in JSON', FReader.Line, FReader.Column);

        result.TokenKind := TYAMLTokenKind.QuotedString;
        result.Value := ReadSingleQuotedString;
      end;

    '#':
      begin
        result.TokenKind := TYAMLTokenKind.Comment;
        result.Value := ReadComment;
      end;

    '%':
      begin
        // YAML directive
        result.TokenKind := TYAMLTokenKind.Directive;
        result.Value := ReadDirective;
      end;

    '&':
      begin
        // Anchor definition
        FReader.Read; // Skip '&'
        result.Value := ReadAnchorOrAlias;
        if result.Value <> '' then
          result.TokenKind := TYAMLTokenKind.Anchor
        else
          raise EYAMLParseException.Create('Invalid anchor name', FReader.Line, FReader.Column);
      end;

    '*':
      begin
        // Alias reference
        FReader.Read; // Skip '*'
        result.Value := ReadAnchorOrAlias;
        if result.Value <> '' then
          result.TokenKind := TYAMLTokenKind.Alias
        else
          raise EYAMLParseException.Create('Invalid alias name', FReader.Line, FReader.Column);
      end;

    '!':
      begin
        // YAML tag
        tag := ReadTag;
        result.Prefix := tag.Prefix;
        result.Value := tag.Handle;
        if result.Value <> '' then
          result.TokenKind := TYAMLTokenKind.Tag
        else
          raise EYAMLParseException.Create('Invalid tag name', FReader.Line, FReader.Column);
      end;

    '|':
      begin
        // Literal scalar
        result.TokenKind := TYAMLTokenKind.Literal;
        result.Value := ReadLiteralScalar;
      end;

    '>':
      begin
        // Folded scalar
        result.TokenKind := TYAMLTokenKind.Folded;
        result.Value := ReadFoldedScalar;
      end;

      '?':
      begin
        // Set item indicator or mapping key in complex key syntax
        // Check if this is followed by whitespace (set item) or more content (complex key)
        peekChar := FReader.Peek();
        if IsWhitespace(peekChar) or (peekChar = #10) or (peekChar = #13) then
        begin
          result.TokenKind := TYAMLTokenKind.SetItem;
          FReader.Read; // Skip '?'
        end
        else
        begin
          // Complex key syntax, treat as value
          result.TokenKind := TYAMLTokenKind.Value;
          result.Value := ReadUnquotedString;
        end;
      end;

  else
    if TYAMLCharUtils.IsDigit(FReader.Current) then
    begin
      result.TokenKind := TYAMLTokenKind.Value;
      // Check if this looks like a timestamp pattern first
      if IsTimestampStart then
        result.Value := ReadTimestamp
      else
        result.Value := ReadNumber;
    end
    else if IsSpecialFloat then
    begin
      result.TokenKind := TYAMLTokenKind.Value;
      result.Value := ReadSpecialFloat;
    end
    else
    begin

      result.Value := ReadUnquotedString;
      if result.Value <> '' then
        result.TokenKind := TYAMLTokenKind.Value
      else
        result := NextToken; // Skip empty values
    end;
  end;

  result.Line := startLine;
  result.Column := startColumn;
end;

function TYAMLLexer.PeekToken : TYAMLToken;
begin
  // Use cached token if available
  if not FHasPeekedToken then
  begin
    FPeekedToken := NextToken;
    FHasPeekedToken := True;
  end;
  result := FPeekedToken;
end;

function TYAMLLexer.PeekTokenKind: TYAMLTokenKind;
begin
  result := PeekToken.TokenKind;
end;

function TYAMLLexer.ReadLiteralScalar : string;
var
  chompIndicator : Char;
  indentIndicator : integer;
  baseIndent : integer;
  lineIndent : integer;
  lines : TStringList;
  i : integer;
  currentLine : string;
begin
  FStringBuilder.Reset;
  chompIndicator := ' '; // Default (clip)
  indentIndicator := 0;   // Auto-detect

  FReader.Read; // Skip '|'

  // Parse header (chomping and indentation indicators)
  while not IsAtEnd and (FReader.Current <> #10) and (FReader.Current <> #13) do
  begin
    if FReader.Current = '-' then
      chompIndicator := '-' // Strip
    else if FReader.Current = '+' then
      chompIndicator := '+' // Keep
    else if TYAMLCharUtils.IsDigit(FReader.Current) then
      indentIndicator := Ord(FReader.Current) - Ord('0')
    else if not IsWhitespace(FReader.Current) then
      break; // End of header
    FReader.Read;
  end;

  // Skip to next line
  while (FReader.Current = #10) or (FReader.Current = #13) do
    FReader.Read;

  lines := TStringList.Create;
  try
    baseIndent := -1; // Will be set from first content line

    // Read all lines of the block
    while not IsAtEnd do
    begin
      FReader.Save;
      lineIndent := 0;

      // count leading spaces for this line
      while (FReader.Current = ' ') and not IsAtEnd do
      begin
        Inc(lineIndent);
        FReader.Read;
      end;

      // Check if this is an empty line or end of block
      if (FReader.Current = #10) or (FReader.Current = #13) or IsAtEnd then
      begin
        // Empty line - add to collection
        lines.Add('');
        // Skip newline (handle both CRLF and LF)
        if (FReader.Current = #13) then
        begin
          FReader.Read;
          if (FReader.Current = #10) then
            FReader.Read;
        end
        else if (FReader.Current = #10) then
        begin
          FReader.Read;
        end;
        // Discard save point since we're not restoring
        FReader.DiscardSave;
        continue;
      end;

      // Check if we've reached the end of the block (dedent)
      if (baseIndent >= 0) and (lineIndent < baseIndent) then
      begin
        // Restore position to start of this line for next token
        FReader.Restore;
        // Reset context state after block scalar completion
        FInValueContext := False;
        break;
      end;

      // Set base indentation from first content line
      if baseIndent < 0 then
      begin
        if indentIndicator > 0 then
          baseIndent := indentIndicator
        else
          baseIndent := lineIndent;
      end;

      // Read the rest of the line using FHexBuilder (reuse existing builder)
      FHexBuilder.Clear;
      while (FReader.Current <> #10) and (FReader.Current <> #13) and not IsAtEnd do
      begin
        FHexBuilder.Append(FReader.Current);
        FReader.Read;
      end;
      currentLine := FHexBuilder.ToString;

      // Add line with proper indentation preserved
      if lineIndent >= baseIndent then
        lines.Add(TYAMLCharUtils.SpaceStr(lineIndent - baseIndent) + currentLine)
      else
        lines.Add(currentLine);

      // Skip newline (handle both CRLF and LF)
      if (FReader.Current = #13) then
      begin
        FReader.Read;
        if (FReader.Current = #10) then
          FReader.Read;
      end
      else if (FReader.Current = #10) then
      begin
        FReader.Read;
      end;

      // Discard save point since we consumed the line and don't need to restore
      FReader.DiscardSave;
    end;

    // Apply chomping rules and build result
    case chompIndicator of
      '-': // Strip - remove all trailing newlines
        begin
          // Remove trailing empty lines
          while (lines.Count > 0) and (lines[lines.Count - 1] = '') do
            lines.Delete(lines.Count - 1);
          // Join without final newline
          for i := 0 to lines.Count - 1 do
          begin
            if i > 0 then
              FStringBuilder.Append(sLineBreak);
            FStringBuilder.Append(lines[i]);
          end;
        end;
      '+': // Keep - preserve all trailing newlines
        begin
          for i := 0 to lines.Count - 1 do
          begin
            if i > 0 then
              FStringBuilder.Append(sLineBreak);
            FStringBuilder.Append(lines[i]);
          end;
          if lines.Count > 0 then
            FStringBuilder.Append(sLineBreak); // Final newline
        end;
      else // Clip (default) - keep one trailing newline
      begin
          // Remove trailing empty lines except the last one
          while (lines.Count > 1) and (lines[lines.Count - 1] = '') do
            lines.Delete(lines.Count - 1);
          for i := 0 to lines.Count - 1 do
          begin
            if i > 0 then FStringBuilder.Append(#13#10);
            FStringBuilder.Append(lines[i]);
          end;
          if lines.Count > 0 then
            FStringBuilder.Append(sLineBreak); // Final newline
      end;
    end;
  finally
    lines.Free;
  end;

  result := FStringBuilder.ToString;
end;

function TYAMLLexer.ReadFoldedScalar : string;
var
  chompIndicator : Char;
  indentIndicator : integer;
  baseIndent : integer;
  lineIndent : integer;
  lines : TStringList;
  i : integer;
  currentLine : string;
  inParagraph : boolean;
  paragraphLines : TStringList;
begin
  FStringBuilder.Reset;
  chompIndicator := ' '; // Default (clip)
  indentIndicator := 0;   // Auto-detect

  FReader.Read; // Skip '>'

  // Parse header (chomping and indentation indicators)
  while not IsAtEnd and (FReader.Current <> #10) and (FReader.Current <> #13) do
  begin
    if FReader.Current = '-' then
      chompIndicator := '-' // Strip
    else if FReader.Current = '+' then
      chompIndicator := '+' // Keep
    else if TYAMLCharUtils.IsDigit(FReader.Current) then
      indentIndicator := Ord(FReader.Current) - Ord('0')
    else if not IsWhitespace(FReader.Current) then
      break; // End of header
    FReader.Read;
  end;

  // Skip to next line
  while (FReader.Current = #10) or (FReader.Current = #13) do
    FReader.Read;

  lines := TStringList.Create;
  paragraphLines := TStringList.Create;
  try
    baseIndent := -1; // Will be set from first content line
    inParagraph := False;

    // Read all lines of the block
    while not IsAtEnd do
    begin
      FReader.Save;
      lineIndent := 0;

      // Count leading spaces for this line
      while (FReader.Current = ' ') and not IsAtEnd do
      begin
        Inc(lineIndent);
        FReader.Read;
      end;

      // Check if this is an empty line or end of block
      if (FReader.Current = #10) or (FReader.Current = #13) or IsAtEnd then
      begin
        // Empty line - end current paragraph if in one
        if inParagraph then
        begin
          // Join paragraph lines with spaces using FHexBuilder
          FHexBuilder.Clear;
          for i := 0 to paragraphLines.Count - 1 do
          begin
            if i > 0 then FHexBuilder.Append(' ');
            FHexBuilder.Append(paragraphLines[i]);
          end;
          lines.Add(FHexBuilder.ToString);
          paragraphLines.Clear;
          inParagraph := False;
        end;
        // For folded scalars, empty lines separate paragraphs
        // Skip newline (handle both CRLF and LF)
        if (FReader.Current = #13) then
        begin
          FReader.Read;
          if (FReader.Current = #10) then
            FReader.Read;
        end
        else if (FReader.Current = #10) then
        begin
          FReader.Read;
        end;
        // Discard save point since we're not restoring
        FReader.DiscardSave;
        continue;
      end;

      if (indentIndicator <> 0) and (lineIndent <> indentIndicator) then
        raise EYAMLParseException.Create('bad indentation of a mapping entry at ',FReader.Line, FReader.Column);

      // Check if we've reached the end of the block (dedent)
      if (baseIndent >= 0) and (lineIndent < baseIndent) then
      begin
        // Restore position to start of this line for next token
        FReader.Restore;
        // Reset context state after block scalar completion
        FInValueContext := False;

        break;
      end;

      // Set base indentation from first content line
      if baseIndent < 0 then
      begin
        if indentIndicator > 0 then
          baseIndent := indentIndicator
        else
          baseIndent := lineIndent;
      end;

      // Read the rest of the line using FHexBuilder
      FHexBuilder.Clear;
      while (FReader.Current <> #10) and (FReader.Current <> #13) and not IsAtEnd do
      begin
        FHexBuilder.Append(FReader.Current);
        FReader.Read;
      end;
      currentLine := FHexBuilder.ToString;

      // Handle indented lines (preserve more indentation as literal)
      if lineIndent > baseIndent then
      begin
        // End current paragraph if in one
        if inParagraph then
        begin
          // Join paragraph lines with spaces using FHexBuilder
          FHexBuilder.Clear;
          for i := 0 to paragraphLines.Count - 1 do
          begin
            if i > 0 then FHexBuilder.Append(' ');
            FHexBuilder.Append(Trim(paragraphLines[i]));
          end;
          lines.Add(FHexBuilder.ToString);
          paragraphLines.Clear;
          inParagraph := False;
        end;
        // Add indented line as-is
        lines.Add(TYAMLCharUtils.SpaceStr(lineIndent - baseIndent) + currentLine);
      end
      else
      begin
        // Regular line - add to current paragraph
        paragraphLines.Add(Trim(currentLine));
        inParagraph := True;
      end;

      // Skip newline (handle both CRLF and LF)
      if (FReader.Current = #13) then
      begin
        FReader.Read;
        if (FReader.Current = #10) then
          FReader.Read;
      end
      else if (FReader.Current = #10) then
      begin
        FReader.Read;
      end;

      // Discard save point since we consumed the line and don't need to restore
      FReader.DiscardSave;
    end;

    // Handle final paragraph
    if inParagraph then
    begin
      // Join paragraph lines with spaces using FHexBuilder
      FHexBuilder.Clear;
      for i := 0 to paragraphLines.Count - 1 do
      begin
        if i > 0 then FHexBuilder.Append(' ');
        FHexBuilder.Append(Trim(paragraphLines[i]));
      end;
      lines.Add(FHexBuilder.ToString);
    end;

    // Apply chomping rules and build result
    case chompIndicator of
      '-': // Strip - remove all trailing newlines
        begin
          // Remove trailing empty lines
          while (lines.Count > 0) and (lines[lines.Count - 1] = '') do
            lines.Delete(lines.Count - 1);
          // Join without final newline
          for i := 0 to lines.Count - 1 do
          begin
            if i > 0 then FStringBuilder.Append(sLineBreak);
            FStringBuilder.Append(lines[i]);
          end;
        end;
      '+': // Keep - preserve all trailing newlines
        begin
          for i := 0 to lines.Count - 1 do
          begin
            if i > 0 then FStringBuilder.Append(sLineBreak);
            FStringBuilder.Append(lines[i]);
          end;
          if lines.Count > 0 then
            FStringBuilder.Append(sLineBreak); // Final newline
        end;
    else // Clip (default) - keep one trailing newline
      begin
        // Remove trailing empty lines except the last one
        while (lines.Count > 1) and (lines[lines.Count - 1] = '') do
          lines.Delete(lines.Count - 1);
        for i := 0 to lines.Count - 1 do
        begin
          if i > 0 then FStringBuilder.Append(sLineBreak);
          FStringBuilder.Append(lines[i]);
        end;
        if lines.Count > 0 then
          FStringBuilder.Append(sLineBreak); // Final newline
      end;
    end;

  finally
    lines.Free;
    paragraphLines.Free;
  end;
  
  result := FStringBuilder.ToString;
end;

procedure InitEscapeTables;
var
  i: Integer;
begin
  // Initialize escape sequence lookup tables
  {$WARN CVT_ACHAR_TO_WCHAR OFF}
  for i := 0 to 255 do
    EscapeTable[i] := #255;  // Initialize all to invalid
  {$WARN CVT_ACHAR_TO_WCHAR ON}
  FillChar(JSONValidEscapes, SizeOf(JSONValidEscapes), False);

  // YAML escape sequences (valid in double-quoted strings)
  EscapeTable[Ord('0')] := #0;    // Null
  EscapeTable[Ord('a')] := #7;    // Bell
  EscapeTable[Ord('b')] := #8;    // Backspace
  EscapeTable[Ord('t')] := #9;    // Tab
  EscapeTable[Ord('n')] := #10;   // Line feed
  EscapeTable[Ord('v')] := #11;   // Vertical tab
  EscapeTable[Ord('f')] := #12;   // Form feed
  EscapeTable[Ord('r')] := #13;   // Carriage return
  EscapeTable[Ord('e')] := #27;   // Escape
  EscapeTable[Ord(' ')] := ' ';   // Space
  EscapeTable[Ord('"')] := '"';   // Double quote
  EscapeTable[Ord('/')] := '/';   // Forward slash
  EscapeTable[Ord('\')] := '\';   // Backslash
  EscapeTable[Ord('N')] := #$0085; // Next line (NEL)
  EscapeTable[Ord('_')] := #$00A0; // Non-breaking space
  EscapeTable[Ord('L')] := #$2028; // Line separator
  EscapeTable[Ord('P')] := #$2029; // Paragraph separator

  // Complex escapes that need special handling
  EscapeTable[Ord('u')] := #1;    // Unicode 16-bit
  EscapeTable[Ord('U')] := #1;    // Unicode 32-bit
  EscapeTable[Ord('x')] := #1;    // Hex 8-bit

  // JSON valid escapes (subset of YAML)
  JSONValidEscapes[Ord('b')] := True;   // Backspace
  JSONValidEscapes[Ord('f')] := True;   // Form feed
  JSONValidEscapes[Ord('n')] := True;   // Line feed
  JSONValidEscapes[Ord('r')] := True;   // Carriage return
  JSONValidEscapes[Ord('t')] := True;   // Tab
  JSONValidEscapes[Ord('"')] := True;   // Double quote
  JSONValidEscapes[Ord('\')] := True;   // Backslash
  JSONValidEscapes[Ord('/')] := True;   // Forward slash (optional)
  JSONValidEscapes[Ord('u')] := True;   // Unicode 16-bit only
end;

initialization
  InitEscapeTables;

end.

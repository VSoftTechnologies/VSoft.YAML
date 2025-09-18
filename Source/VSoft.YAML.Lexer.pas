unit VSoft.YAML.Lexer;

interface

uses
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
    FIndentStack : TList<Integer>;
    FSequenceItemIndent : integer;
    FInValueContext : boolean; // Track if we're reading a value (after colon) vs key

    // Stack management methods
    procedure PushIndentLevel(level: Integer);
    function PopIndentLevel: Integer;
    function CurrentIndentLevel: Integer;
  protected
    function GetLine : integer;
    function GetColumn : integer;
    function IsAtEnd : boolean;inline;
    function IsWhitespace(ch : Char) : boolean;inline;

    procedure SkipWhitespace;
    function ReadDirective : string;
    function ReadComment : string;
    function ReadQuotedString(Quote : Char) : string;
    function ReadUnquotedString : string;
    function ReadNumber : string;
    function ReadAnchorOrAlias : string;
    function ReadTag : TTag;
    function ReadLiteralScalar : string;
    function ReadFoldedScalar : string;
    function ReadTimestamp : string;
    function IsTimestampStart : boolean;
    function IsSpecialFloat : boolean;
    function ReadSpecialFloat : string;
    function CalculateIndentLevel : integer;
  public
    constructor Create(const reader : IInputReader);
    destructor Destroy; override;

    function NextToken : TYAMLToken;
    function PeekToken : TYAMLToken;
    function PeekTokenKind : TYAMLTokenKind;

    property Line : integer read GetLine;
    property Column : integer read GetColumn;
  end;

implementation

uses
  System.Character,
  System.SysUtils,
  System.Classes;

{ TYAMLLexer }

constructor TYAMLLexer.Create(const reader : IInputReader);
begin
  inherited Create;
  FReader := reader;
  FSequenceItemIndent := -1;
  FInValueContext := False;

  // Initialize indent stack with base level 0
  FIndentStack := TList<Integer>.Create;
  FIndentStack.Add(0);
end;

destructor TYAMLLexer.Destroy;
begin
  FIndentStack.Free;
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
  result := (ch = ' ') or (ch = #9);
end;



procedure TYAMLLexer.SkipWhitespace;
begin
  while IsWhitespace(FReader.Current) and not IsAtEnd do
    FReader.Read;
end;


function TYAMLLexer.ReadComment : string;
var
  commentText : string;
begin
  commentText := '';
  // Skip the '#' character
  FReader.Read;

  // Skip any leading whitespace after #
  SkipWhitespace;
    
  // Read the comment text until end of line
  while (not CharInSet(FReader.Current, [#10, #13])) and not IsAtEnd do
  begin
    commentText := commentText + FReader.Current;
    FReader.Read;
  end;
  
  result := commentText;
end;

function TYAMLLexer.ReadDirective: string;
begin
  //just read the whole directive, we'll parse it later
  while (FReader.Current <> #10) and (FReader.Current <> #13) and not IsAtEnd do
  begin
    result := result + FReader.Current;
    FReader.Read;
  end;
end;

function TYAMLLexer.ReadQuotedString(Quote : Char) : string;
var
  foundClosingQuote : boolean;
  isValidUnicodeEscape : Boolean;
  i : Integer;
  hexStr : string;
  codePoint : Integer;
  codePoint64 : Int64;
begin
  result := '';
  FReader.Read; // Skip opening quote
  foundClosingQuote := False;

  while not IsAtEnd do
  begin
    if Quote = '"' then
    begin
      // Double-quoted strings: backslash acts as escape character
      if FReader.Current = '\' then
      begin
        // Check if this is a line continuation (backslash followed by newline)
        if (FReader.Peek() = #10) or (FReader.Peek() = #13) then
        begin
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
          // This is an escape sequence - process it immediately
          FReader.Read; // Skip the backslash
          if not IsAtEnd then
          begin
            case FReader.Current of
              // Basic escape sequences
              '0': begin
                result := result + #0;     // Null character
                FReader.Read; // Read the escape character we just processed
                Continue; // Skip the FReader.Read at the end of the loop
              end;
              'a': begin
                result := result + #7;     // Bell character
                FReader.Read; // Read the escape character we just processed
                Continue; // Skip the FReader.Read at the end of the loop
              end;
              'b': begin
                result := result + #8;     // Backspace
                FReader.Read; // Read the escape character we just processed
                Continue; // Skip the FReader.Read at the end of the loop
              end;
              't': begin
                result := result + #9;     // Horizontal tab
                FReader.Read; // Read the escape character we just processed
                Continue; // Skip the FReader.Read at the end of the loop
              end;
              'n': begin
                result := result + #10;    // Line feed
                FReader.Read; // Read the escape character we just processed
                Continue; // Skip the FReader.Read at the end of the loop
              end;
              'v': begin
                result := result + #11;    // Vertical tab
                FReader.Read; // Read the escape character we just processed
                Continue; // Skip the FReader.Read at the end of the loop
              end;
              'f': begin
                result := result + #12;    // Form feed
                FReader.Read; // Read the escape character we just processed
                Continue; // Skip the FReader.Read at the end of the loop
              end;
              'r': begin
                result := result + #13;    // Carriage return
                FReader.Read; // Read the escape character we just processed
                Continue; // Skip the FReader.Read at the end of the loop
              end;
              'e': begin
                result := result + #27;    // Escape character
                FReader.Read; // Read the escape character we just processed
                Continue; // Skip the FReader.Read at the end of the loop
              end;
              ' ': begin
                result := result + ' ';    // Space
                FReader.Read; // Read the escape character we just processed
                Continue; // Skip the FReader.Read at the end of the loop
              end;
              '"': begin
                result := result + '"';    // Double quote
                FReader.Read; // Read the escape character we just processed
                Continue; // Skip the FReader.Read at the end of the loop
              end;
              '/': begin
                result := result + '/';    // Forward slash
                FReader.Read; // Read the escape character we just processed
                Continue; // Skip the FReader.Read at the end of the loop
              end;
              '\': begin
                result := result + '\';    // Backslash
                FReader.Read; // Read the escape character we just processed
                Continue; // Skip the FReader.Read at the end of the loop
              end;
              'N': begin
                result := result + #$85;   // Next line (NEL)
                FReader.Read; // Read the escape character we just processed
                Continue; // Skip the FReader.Read at the end of the loop
              end;
              '_': begin
                result := result + #$A0;   // Non-breaking space
                FReader.Read; // Read the escape character we just processed
                Continue; // Skip the FReader.Read at the end of the loop
              end;
              'L': begin
                result := result + #$2028; // Line separator
                FReader.Read; // Read the escape character we just processed
                Continue; // Skip the FReader.Read at the end of the loop
              end;
              'P': begin
                result := result + #$2029; // Paragraph separator
                FReader.Read; // Read the escape character we just processed
                Continue; // Skip the FReader.Read at the end of the loop
              end;
              'u': begin
                // Unicode escape sequence \uXXXX (4 hex digits)
                // Check if the next characters look like hex digits
                isValidUnicodeEscape := True;
                FReader.Save;
                FReader.Read;// Skip 'u'

                // Check if we have 4 hex digits following
                for i := 1 to 4 do
                begin
                  if IsAtEnd or not TYAMLCharUtils.IsHexidecimal(FReader.Current) then
                  begin
                    isValidUnicodeEscape := False;
                    break;
                  end;
                  FReader.Read;
                end;

                // Restore position
                FReader.Restore;
                
                if isValidUnicodeEscape then
                begin
                  FReader.Read; // Skip 'u'
                  hexStr := '';
                  for i := 1 to 4 do
                  begin
                    hexStr := hexStr + FReader.Current;
                    FReader.Read;
                  end;
                  // Convert hex to character
                  codePoint := StrToInt('$' + hexStr);
                  result := result + Char(codePoint);
                  Continue; // Skip the FReader.Read at the end of the loop
                end
                else
                begin
                  // Invalid Unicode escape sequence - raise an error
                  raise EYAMLParseException.Create('Invalid Unicode escape sequence: \u' + FReader.Current, FReader.Line, FReader.Column);
                end;
              end;
              'U': begin
                // Unicode escape sequence \UXXXXXXXX (8 hex digits)
                // Check if the next characters look like hex digits
                isValidUnicodeEscape := True;
                FReader.Save;
                FReader.Read; // Skip 'U'

                // Check if we have 8 hex digits following
                for i := 1 to 8 do
                begin
                  if IsAtEnd or not TYAMLCharUtils.IsHexidecimal(FReader.Current) then
                  begin
                    isValidUnicodeEscape := False;
                    break;
                  end;
                  FReader.Read;
                end;
                
                // Restore position
                FReader.Restore;

                if isValidUnicodeEscape then
                begin
                  FReader.Read; // Skip 'U'
                  hexStr := '';
                  for i := 1 to 8 do
                  begin
                    hexStr := hexStr + FReader.Current;
                    FReader.Read;
                  end;
                  // Convert hex to character
                  codePoint64 := StrToInt64('$' + hexStr);
                  if codePoint64 <= $FFFF then
                    result := result + Char(codePoint64)
                  else if codePoint64 <= $10FFFF then
                  begin
                    // Convert to UTF-16 surrogate pair for code points > U+FFFF
                    codePoint64 := codePoint64 - $10000;
                    result := result + Char($D800 + (codePoint64 shr 10));    // High surrogate
                    result := result + Char($DC00 + (codePoint64 and $3FF)); // Low surrogate
                  end
                  else
                    result := result + '?'; // Invalid Unicode code point
                  Continue; // Skip the FReader.Read at the end of the loop
                end
                else
                begin
                  // Invalid Unicode escape sequence - raise an error
                  raise EYAMLParseException.Create('Invalid Unicode escape sequence: \U' + FReader.Current, FReader.Line, FReader.Column);
                end;
              end;
              'x': begin
                // Hex escape sequence \xXX  
                FReader.Read; // Skip 'x'
                if not IsAtEnd and (((FReader.Current >= '0') and (FReader.Current <= '9')) or
                   ((FReader.Current >= 'A') and (FReader.Current <= 'F')) or
                   ((FReader.Current >= 'a') and (FReader.Current <= 'f'))) then
                begin
                  // For now, simplified - just include literally
                  result := result + '\x' + FReader.Current;
                  FReader.Read; // Read the hex character we just processed
                  Continue; // Skip the FReader.Read at the end of the loop
                end
                else
                  raise EYAMLParseException.Create('Invalid hex escape sequence', FReader.Line, FReader.Column);
              end;
            else
              // Invalid escape sequence - raise an error
              raise EYAMLParseException.Create('Invalid escape sequence: \' + FReader.Current, FReader.Line, FReader.Column);
            end;
          end;
        end;
      end
      else if FReader.Current = Quote then
      begin
        FReader.Read; // Skip closing quote
        foundClosingQuote := True;
        Break;
      end
      else
        result := result + FReader.Current;
    end
    else if Quote = '''' then
    begin
      // Single-quoted strings: only single quotes need escaping (by doubling)
      if FReader.Current = '''' then
      begin
        if FReader.Peek() = '''' then
        begin
          // Escaped single quote: '' becomes '
          result := result + '''';
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
        if (FReader.Peek() = #10) or (FReader.Peek() = #13) then
        begin
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
          result := result + FReader.Current;
        end;
      end
      else
      begin
        // All other characters are literal
        result := result + FReader.Current;
      end;
    end;

    FReader.Read;
  end;

  // If we exited the loop without finding a closing quote, it's an error
  if not foundClosingQuote then
    raise EYAMLParseException.Create('Unterminated quoted string', FReader.Line, FReader.Column);
end;

function TYAMLLexer.ReadUnquotedString : string;
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
  result := '';

  while not IsAtEnd and DoCheck do
  begin
    result := result + FReader.Current;
    FReader.Read;
  end;

  result := Trim(result);
end;

function TYAMLLexer.ReadNumber : string;
var
  dotCount : integer;
  tempChar : Char;
begin
  result := '';
  dotCount := 0;
  FReader.Save;
  // First, scan ahead to count dots - if more than 1, this is not a valid number
  if FReader.Current = '-' then
    FReader.Read; // Skip potential minus sign

  while not FReader.IsEOF do
  begin
    tempChar := FReader.Current;
    if tempChar = '.' then
      Inc(dotCount)
    else if not TYAMLCharUtils.IsDigitOrUnderScore(tempChar) and not CharInSet(tempChar, ['e','E','+','-']) then
      Break; // End of potential number
    FReader.Read;
  end;

  // If more than 1 dot, this is not a valid number - return empty to indicate caller should use ReadUnquotedString
  if dotCount > 1 then
  begin
    FReader.Restore;
    result := '';
    Exit;
  end;

  FReader.Restore;

  // Handle negative numbers
  if FReader.Current = '-' then
  begin
    result := result + FReader.Current;
    FReader.Read;
  end;

  // Check for hex, octal, or binary prefixes after optional minus
  if FReader.Current = '0' then
  begin
    result := result + FReader.Current;
    FReader.Read;

    // Check for hex prefix (0x or 0X)
    if (FReader.Current = 'x') or (FReader.Current = 'X') then
    begin
      result := result + FReader.Current;
      FReader.Read;
      // Read hex digits
      while ((FReader.Current >= '0') and (FReader.Current <= '9')) or
            ((FReader.Current >= 'a') and (FReader.Current <= 'f')) or
            ((FReader.Current >= 'A') and (FReader.Current <= 'F')) and not IsAtEnd do
      begin
        result := result + FReader.Current;
        FReader.Read;
      end;
      Exit; // Done reading hex number
    end
    // Check for octal prefix (0o or 0O)
    else if (FReader.Current = 'o') or (FReader.Current = 'O') then
    begin
      result := result + FReader.Current;
      FReader.Read;
      // Read octal digits (0-7)
      while (FReader.Current >= '0') and (FReader.Current <= '7') and not IsAtEnd do
      begin
        result := result + FReader.Current;
        FReader.Read;
      end;
      Exit; // Done reading octal number
    end
    // Check for binary prefix (0b or 0B)
    else if (FReader.Current = 'b') or (FReader.Current = 'B') then
    begin
      result := result + FReader.Current;
      FReader.Read;
      // Read binary digits (0-1)
      while ((FReader.Current = '0') or (FReader.Current = '1')) and not IsAtEnd do
      begin
        result := result + FReader.Current;
        FReader.Read;
      end;
      Exit; // Done reading binary number
    end;
    // If no special prefix, continue reading as regular decimal number
  end;

  // Read remaining integer digits for decimal numbers
  while TYAMLCharUtils.IsDigitOrUnderScore(FReader.Current) and not IsAtEnd do
  begin
    if FReader.Current <> '_' then
      result := result + FReader.Current;
    FReader.Read;
  end;

  // Read decimal part (only for decimal numbers, not hex/octal/binary)
  if FReader.Current = '.' then
  begin
    result := result + FReader.Current;
    FReader.Read;
    while TYAMLCharUtils.IsDigit(FReader.Current) and not IsAtEnd do
    begin
      result := result + FReader.Current;
      FReader.Read;
    end;
  end;

  // Read exponent part (only for decimal numbers)
  if (FReader.Current = 'e') or (FReader.Current = 'E') then
  begin
    result := result + FReader.Current;
    FReader.Read;
    if (FReader.Current = '+') or (FReader.Current = '-') then
    begin
      result := result + FReader.Current;
      FReader.Read;
    end;
    while TYAMLCharUtils.IsDigit(FReader.Current) and not IsAtEnd do
    begin
      result := result + FReader.Current;
      FReader.Read;
    end;
  end;
end;

function TYAMLLexer.ReadAnchorOrAlias : string;
begin
  result := '';

  // Read anchor or alias name
  while (TYAMLCharUtils.IsAlphaNumeric(FReader.Current) or (FReader.Current = '_') or (FReader.Current = '-')) and not IsAtEnd do
  begin
    result := result + FReader.Current;
    FReader.Read;
  end;
end;

function TYAMLLexer.ReadTag : TTag;
begin
  // YAML supports multiple tag formats:
  // 1. !!tag (short form)
  // 2. !prefix!tag (prefixed form)
  // 3. !<uri> (verbatim form)

  if FReader.Current = '!' then
  begin
    Result.Handle := '!';
    FReader.Read; //skip the !

    // Check for verbatim tag format: !<uri>
    if FReader.Current = '<' then
    begin
      Result.Handle := Result.Handle + FReader.Current;
      FReader.Read;
      // Read everything until closing >
      while (FReader.Current <> '>') and not IsAtEnd and (FReader.Current <> #10) and (FReader.Current <> #13) do
      begin
        Result.Handle := Result.Handle + FReader.Current;
        FReader.Read;
      end;
      // Include the closing >
      if FReader.Current = '>' then
      begin
        Result.Handle := Result.Handle + FReader.Current;
        FReader.Read;
      end;
    end
    else if FReader.Current = '!' then
    begin
      Result.Handle := Result.Handle + '!';
      // Short form: !!tag
      FReader.Read;
      // Read tag name (letters, digits, underscores, hyphens)
      while (TYAMLCharUtils.IsAlphaNumeric(FReader.Current) or (FReader.Current = '_') or (FReader.Current = '-')) and not IsAtEnd do
      begin
        Result.Handle := Result.Handle + FReader.Current;
        FReader.Read;
      end;
    end
    else
    begin
      // Prefixed form: !prefix!tag or just !tag
      // Read prefix/tag name (letters, digits, underscores, hyphens)
      while (TYAMLCharUtils.IsAlphaNumeric(FReader.Current) or (FReader.Current = '_') or (FReader.Current = '-')) and not IsAtEnd do
      begin
        Result.Prefix := Result.Prefix + FReader.Current;
        FReader.Read;
      end;

      // Check for second ! (prefix!tag format)
      if FReader.Current = '!' then
      begin
        FReader.Read;
        // Read the tag name after the second !
        while (TYAMLCharUtils.IsAlphaNumeric(FReader.Current) or (FReader.Current = '_') or (FReader.Current = '-')) and not IsAtEnd do
        begin
          Result.Handle := Result.Handle + FReader.Current;
          FReader.Read;
        end;
      end
      else
      begin
        //local tag
        result.Handle := result.Prefix;
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

function TYAMLLexer.CalculateIndentLevel : integer;
var
  count : integer;
begin
  // Save current position
  FReader.Save;
  count := 0;
  while IsWhitespace(FReader.Current) and not IsAtEnd do
  begin
    if FReader.Current = ' ' then
      Inc(count)
    else if FReader.Current = #9 then
    begin
      // YAML 1.2 specification: Tabs are not allowed for indentation
      FReader.Restore;
      raise EYAMLParseException.Create('Tabs are not allowed for indentation in YAML', FReader.Line, FReader.Column);
    end;
    FReader.Read;
  end;

  // Restore position
  FReader.Restore;

  result := count;
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
  result := '';

  // Read timestamp pattern : YYYY-MM-DD or YYYY-MM-DDTHH:MM:SS or variations
  // This function should read complete timestamp tokens including colons within time portions
  while not CharInSet(FReader.Current, [#0,#9,#13,#10,'#','[',']','{','}',',', ' ']) do
  begin
    // Stop reading if we hit a colon followed by space (YAML key separator)
    if (FReader.Current = ':') and IsWhitespace(FReader.Peek()) then
      Break;

    result := result + FReader.Current;
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
      result := result + FReader.Current; // Add the space
      FReader.Read;

     // Read the time portion including colons
      while not CharInSet(FReader.Current, [#0,#9,'#','[',']','{','}',',', ' ']) do
      begin
        // Stop if we hit colon followed by space (YAML separator)
        if (FReader.Current = ':') and IsWhitespace(FReader.Peek) then
          Break;

        result := result + FReader.Current;
        FReader.Read;
      end;
    end;
  end;

  result := Trim(result);
end;

function TYAMLLexer.IsSpecialFloat : boolean;
var
  i : integer;
  testStr : string;
begin
  result := False;
  testStr := '';

  // Handle optional sign for infinity
  i := 0;
  if (FReader.Current = '+') or (FReader.Current = '-') then
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
begin
  result := '';

  // Handle optional sign
  if (FReader.Current = '+') or (FReader.Current = '-') then
  begin
    result := result + FReader.Current;
    FReader.Read;
  end;

  // Should be at '.' now
  if FReader.Current = '.' then
  begin
    result := result + FReader.Current;
    FReader.Read;

    // Read the special float identifier (nan, NaN, NAN, inf, Inf, INF)
    while TYAMLCharUtils.IsAlpha(FReader.Current) and not IsAtEnd do
    begin
      result := result + FReader.Current;
      FReader.Read;
    end;
  end;
end;

function TYAMLLexer.NextToken : TYAMLToken;
var
  startLine, startColumn : integer;
  currentIndent : integer;
  tag : TTag;
begin
  // Initialize token
  result.TokenKind := TYAMLTokenKind.EOF;
  result.Value := '';
  result.Line := FReader.Line;
  result.Column := FReader.Column;
  result.IndentLevel := 0;

  // Skip whitespace but track indentation at line start
  if FReader.Column = 1 then
  begin
    currentIndent := CalculateIndentLevel;
    result.IndentLevel := currentIndent;
    if currentIndent > CurrentIndentLevel then
    begin
      PushIndentLevel(currentIndent);
      result.TokenKind := TYAMLTokenKind.Indent;
      SkipWhitespace;
      Exit;
    end
    else if currentIndent < CurrentIndentLevel then
    begin
      // Handle dedent - pop indent levels until we find matching or lower level
      while (FIndentStack.Count > 1) and (currentIndent < CurrentIndentLevel) do
        PopIndentLevel;
      
      // Set the result indent level to the current level after popping
      result.IndentLevel := currentIndent;
      SkipWhitespace;
    end
    else
    begin
      // Same indentation level, just skip whitespace but preserve indent level
      result.IndentLevel := currentIndent;
      SkipWhitespace;
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
        if IsWhitespace(FReader.Peek()) then
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
        else if (FReader.Peek() = '-') and (FReader.Peek(2) = '-') then
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
          result.Value := ReadNumber;
          // If ReadNumber returns empty (due to multiple dots), treat as unquoted string
          if result.Value = '' then
            result.Value := ReadUnquotedString;
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
          // If ReadNumber returns empty (due to multiple dots), treat as unquoted string
          if result.Value = '' then
            result.Value := ReadUnquotedString;
        end;
      end;

    '.':
      begin
        if (FReader.Peek() = '.') and (FReader.Peek(2) = '.') then
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
        else
        begin
          result.TokenKind := TYAMLTokenKind.Value;
          result.Value := ReadNumber;
          // If ReadNumber returns empty (due to multiple dots), treat as unquoted string
          if result.Value = '' then
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
        result.Value := ReadQuotedString('"');
      end;

    '''':
      begin
        result.TokenKind := TYAMLTokenKind.QuotedString;
        result.Value := ReadQuotedString('''');
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
        if IsWhitespace(FReader.Peek()) or (FReader.Peek = #10) or (FReader.Peek = #13) then
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
      begin
        result.Value := ReadNumber;
        // If ReadNumber returns empty (due to multiple dots), treat as unquoted string
        if result.Value = '' then
          result.Value := ReadUnquotedString;
      end;
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
  // Save current state
  FReader.Save;
  // Get next token
  result := NextToken;
  // Restore state
  FReader.Restore;
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
  result := '';
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
        if (FReader.Current = #10) or (FReader.Current = #13) then
          FReader.Read;
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

      // Read the rest of the line
      currentLine := '';
      while (FReader.Current <> #10) and (FReader.Current <> #13) and not IsAtEnd do
      begin
        currentLine := currentLine + FReader.Current;
        FReader.Read;
      end;

      // Add line with proper indentation preserved
      if lineIndent >= baseIndent then
        lines.Add(StringOfChar(' ', lineIndent - baseIndent) + currentLine)
      else
        lines.Add(currentLine);

      // Skip newline
      if (FReader.Current = #13) then
      begin
        FReader.Read;
        if (FReader.Current = #10) then
          FReader.Read;
      end;
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
              result := result + sLineBreak;
            result := result + lines[i];
          end;
        end;
      '+': // Keep - preserve all trailing newlines
        begin
          for i := 0 to lines.Count - 1 do
          begin
            if i > 0 then
              result := result + sLineBreak;
            result := result + lines[i];
          end;
          if lines.Count > 0 then
            result := result + sLineBreak; // Final newline
        end;
      else // Clip (default) - keep one trailing newline
      begin
          // Remove trailing empty lines except the last one
          while (lines.Count > 1) and (lines[lines.Count - 1] = '') do
            lines.Delete(lines.Count - 1);
          for i := 0 to lines.Count - 1 do
          begin
            if i > 0 then result := result + #13#10;
            result := result + lines[i];
          end;
          if lines.Count > 0 then
            result := result + sLineBreak; // Final newline
      end;
    end;
  finally
    lines.Free;
  end;
end;

function TYAMLLexer.ReadFoldedScalar : string;
var
  chompIndicator : Char;
  indentIndicator : integer;
  baseIndent : integer;
  lineIndent : integer;
  lines : TStringList;
  i : integer;
  line : string;
  currentLine : string;
  inParagraph : boolean;
  paragraphLines : TStringList;
begin
  result := '';
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
          // Join paragraph lines with spaces
          line := '';
          for i := 0 to paragraphLines.Count - 1 do
          begin
            if i > 0 then line := line + ' ';
            line := line + paragraphLines[i];
          end;
          lines.Add(line);
          paragraphLines.Clear;
          inParagraph := False;
        end;
        // For folded scalars, empty lines separate paragraphs
        if (FReader.Current = #10) or (FReader.Current = #13) then
          FReader.Read;
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

      // Read the rest of the line
      currentLine := '';
      while (FReader.Current <> #10) and (FReader.Current <> #13) and not IsAtEnd do
      begin
        currentLine := currentLine + FReader.Current;
        FReader.Read;
      end;

      // Handle indented lines (preserve more indentation as literal)
      if lineIndent > baseIndent then
      begin
        // End current paragraph if in one
        if inParagraph then
        begin
          line := '';
          for i := 0 to paragraphLines.Count - 1 do
          begin
            if i > 0 then line := line + ' ';
            line := line + Trim(paragraphLines[i]);
          end;
          lines.Add(line);
          paragraphLines.Clear;
          inParagraph := False;
        end;
        // Add indented line as-is
        lines.Add(StringOfChar(' ', lineIndent - baseIndent) + currentLine);
      end
      else
      begin
        // Regular line - add to current paragraph
        paragraphLines.Add(Trim(currentLine));
        inParagraph := True;
      end;

      // Skip newline
      if (FReader.Current = #13) then
      begin
        FReader.Read;
        if (FReader.Current = #10) then
          FReader.Read;
      end;
    end;

    // Handle final paragraph
    if inParagraph then
    begin
      line := '';
      for i := 0 to paragraphLines.Count - 1 do
      begin
        if i > 0 then line := line + ' ';
        line := line + Trim(paragraphLines[i]);
      end;
      lines.Add(line);
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
            if i > 0 then result := result + sLineBreak;
            result := result + lines[i];
          end;
        end;
      '+': // Keep - preserve all trailing newlines
        begin
          for i := 0 to lines.Count - 1 do
          begin
            if i > 0 then result := result + sLineBreak;
            result := result + lines[i];
          end;
          if lines.Count > 0 then
            result := result + sLineBreak; // Final newline
        end;
    else // Clip (default) - keep one trailing newline
      begin
        // Remove trailing empty lines except the last one
        while (lines.Count > 1) and (lines[lines.Count - 1] = '') do
          lines.Delete(lines.Count - 1);
        for i := 0 to lines.Count - 1 do
        begin
          if i > 0 then result := result + sLineBreak;
          result := result + lines[i];
        end;
        if lines.Count > 0 then
          result := result + sLineBreak; // Final newline
      end;
    end;

  finally
    lines.Free;
    paragraphLines.Free;
  end;
end;

end.

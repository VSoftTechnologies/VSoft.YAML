{***************************************************************************
{***************************************************************************}

unit VSoft.YAML.Path;

{
     Inspired by Neslib.Json.Path implementation
     https://github.com/neslib/Neslib.Json/blob/master/Neslib.Json.Path.pas

}

interface

{$I 'VSoft.YAML.inc'}


uses
  VSoft.YAML.Utils,
  VSoft.YAML.IO,
  VSoft.YAML,
  VSoft.YAML.Classes,
  System.SysUtils,
  System.RegularExpressions;

{$SCOPEDENUMS ON}

type
  /// <summary>
  ///
  /// </summary>
  TYAMLPathProcessor = record
  {$REGION 'Internal Declarations'}
  private type
    TFilterOperator = (
      foEquals,      // ==
      foNotEquals,   // !=
      foGreater,     // >
      foGreaterEq,   // >=
      foLess,        // <
      foLessEq,      // <=
      foRegexMatch,  // =~
      foIn,          // in
      foNotIn,       // nin
      foContains,    // contains
      foSize,        // size
      foEmpty        // empty
    );
    
    TFilterLogical = (
      flAnd,         // &&
      flOr,          // ||
      flNot          // !
    );
    
    TFilterOperandType = (
      fotCurrentItem,    // @
      fotRootItem,       // $
      fotLiteral,        // string, number, boolean, null
      fotPath,           // property path like @.price or $.store.book[0]
      fotList            // a list of literals, as in ['a', 'b'] (for in and nin)
    );

    TFilterLiteralKind = (
      flkString,
      flkNumber,
      flkBoolean,
      flkNull
    );

    TFilterOperand = record
      OperandType: TFilterOperandType;
      LiteralKind: TFilterLiteralKind; // For literals
      StringValue: string;    // For literals and paths
      NumericValue: Double;   // For numeric literals
      NumericText: string;    // For numeric literals: the number as written
      BoolValue: Boolean;     // For boolean literals
      Path: string;           // For property paths
      ListValue: IYAMLSequence; // For lists
      IsTruthinessCheck: Boolean; // For auto-generated truthiness checks
      IsNumericLiteral: Boolean; // True if this was parsed as a numeric literal
    end;

    // Forward declarations
    TFilterExpression = class;

    TFilterComparison = class(TObject)
    public
      LeftOperand: TFilterOperand;
      Operator: TFilterOperator;
      RightOperand: TFilterOperand;
      // size: the comparison of the size with the right operand (== when none is written)
      SizeOperator: TFilterOperator;
      // =~ with a regex or string literal: the pattern, compiled once, to match whole values
      HasRegex: Boolean;
      Regex: TRegEx;
      destructor Destroy; override;
    end;
    
    TFilterLogicalExpression = class(TObject)
    public
      LogicalOp: TFilterLogical;
      Left: TFilterExpression;
      Right: TFilterExpression;
      destructor Destroy; override;
    end;
    
    TFilterExpression = class(TObject)
    public
      IsComparison: Boolean;
      Comparison: TFilterComparison;
      LogicalExpr: TFilterLogicalExpression;
      destructor Destroy; override;
    end;
    
    TFilterContext = record
      CurrentItem: IYAMLValue;
      RootDocument: IYAMLValue;
      class function Create(const ACurrent, ARoot: IYAMLValue): TFilterContext; static;
    end;
  private type
    TOperatorType = (
      ChildName,        // Name of a child element (as in .store or ['store'])
      ChildIndex,       // Index of a child element (as in [3])
      RecursiveDescent, // .. operator
      Wildcard,         // * operator
      IndexList,        // [a,b,c,...]
      Slice,            // [start :end :step]
      Filter);          // [?(...)] operator
  private type
    POperator = ^TOperator;
    TOperator = record
    public
      procedure Init(const AType : TOperatorType);
    public
      OperatorType : TOperatorType;
      Next : POperator;
      Name : string;                  // For ChildName
      Indices : TArray<integer>;          // For IndexList - negative counts from the end
      case Byte of
        0 : (Index : integer);             // For ChildIndex - negative counts from the end
        // For Slice, as RFC 9535 2.3.4: start and stop are left out unless HasStart and
        // HasStop, and step is 1 unless it is given
        1 : (Start, Stop, Step : integer; HasStart, HasStop : boolean);
        2 : (FilterExpression : TFilterExpression); // For Filter
    end;
  private
    FInitialized : boolean;
    FOperators : TArray<TOperator>;
    FOperatorCount : integer;
    FMatches : IYAMLSequence;
    FMatchList : TYAMLSequence; // FMatches' object: matches go in through AddItem, as they are
    FMatchCount : integer;
    FSingleMatch : boolean;
    FRootDocument : IYAMLValue;
    // QueryMatches: each match and where it is goes in FLocations instead of FMatches
    FTrackLocations : boolean;
    FLocations : TArray<TYAMLPathMatch>;
  private
    class procedure SkipWhitespace(const reader : IInputReader); inline; static;
    class function ParseInteger(const reader : IInputReader; out AValue : integer) : boolean; static;
    class function IsQuote(const ch : Char) : boolean; inline; static;
    // the index into count items that AIndex selects - a negative one counts from the end
    class function NormalizeIndex(AIndex, ACount : integer) : integer; inline; static;
  private
    procedure AddOperator(const AOperator : TOperator);
    procedure AddMatch(const AMatch : IYAMLValue; const AParent : IYAMLCollection; const AKey : string; AIndex : integer; const APath : string);
    procedure ParseDotOperator(const reader : IInputReader);
    // a member name after '.' or '..', up to the next '.', '[' or the end
    procedure ParseMemberName(const reader : IInputReader);
    procedure ParseBracketOperator(const reader : IInputReader);

    function InternalMatch(const root : IYAMLValue; const AMatchSingle : boolean) : IYAMLSequence;
    function InternalMatches(const root : IYAMLValue) : TArray<TYAMLPathMatch>;
    // the normalized path of a child of the node at AParentPath - a member when AIndex is -1,
    // an item otherwise; '' when locations are not tracked
    function PathTo(const AParentPath, AKey : string; AIndex : integer) : string;
    // AValue was selected: it is a match when there is no next operator, else the next
    // operator runs on it
    procedure Select(const ANext : POperator; const AValue : IYAMLValue; const AParent : IYAMLCollection;
      const AParentPath, AKey : string; AIndex : integer);
    procedure VisitOperator(const AOp : POperator; const ARoot : IYAMLValue; const ARootPath : string);
    
    // Filter processing methods
    function ParseFilterExpression(const reader : IInputReader) : TFilterExpression;
    function ParseLogicalExpression(const reader : IInputReader) : TFilterExpression;
    function ParseOrExpression(const reader : IInputReader) : TFilterExpression;
    function ParseAndExpression(const reader : IInputReader) : TFilterExpression;
    function ParseNotExpression(const reader : IInputReader) : TFilterExpression;
    function ParsePrimaryExpression(const reader : IInputReader) : TFilterExpression;
    function ParseComparisonExpression(const reader : IInputReader) : TFilterComparison;
    function ParseOperand(const reader : IInputReader) : TFilterOperand;
    function ParseFilterOperator(const reader : IInputReader) : TFilterOperator;
    // ==, !=, >, >=, < or <= at the reader, read when there is one
    class function ParseComparisonOperator(const reader : IInputReader; out AOperator : TFilterOperator) : boolean; static;
    // /pattern/flags at the reader, compiled to match whole values
    class function ParseRegexLiteral(const reader : IInputReader) : TRegEx; static;
    class function CompileRegex(const APattern : string; const AOptions : TRegExOptions) : TRegEx; static;
    // [literal, literal, ...] at the reader
    function ParseListLiteral(const reader : IInputReader) : IYAMLSequence;
    function EvaluateFilterExpression(const Expr : TFilterExpression; const Context : TFilterContext) : Boolean;
    function EvaluateComparison(const Comp : TFilterComparison; const Context : TFilterContext) : Boolean;
    function ResolveOperand(const Operand : TFilterOperand; const Context : TFilterContext) : IYAMLValue;
    function CompareYAMLValues(const Left, Right : IYAMLValue; const Op : TFilterOperator) : Boolean;
    // true when collection, a sequence or a set, has an item equal to value
    function SequenceHas(const collection, value : IYAMLValue) : Boolean;
  {$ENDREGION 'Internal Declarations'}
  public
    /// <summary>
    /// Parses a JSONPath expression that can be used for matching later.
    /// If you plan to use the same JSONPath expression multiple times, then it
    /// is faster to parse it just once using this constructor, and execute it
    /// multiple times using one of the (non-static) Match* methods.
    /// </summary>
    /// <param name="AExpression">the JSONPath expression to parse</param>
    /// <exception cref="EYAMLPathError">if AExpression is invalid</exception>
    constructor Create(const expression : string);

    /// <summary>
    /// Releases the heap allocated objects owned by this processor (a record
    /// cannot do this in a destructor). Must be called before the record goes out
    /// of scope. Guards on the initialized flag, so it is safe to call on an
    /// unused/partially constructed record and safe to call more than once.
    /// </summary>
    procedure Cleanup;

    /// <summary>
    /// Executes this JSONPath expression on a document.
    /// </summary>
    /// <param name="root">the document to use this JSONPath on</param>
    /// <returns>A yaml sequence that match this JSONPath expression</returns>
    function Query(const root : IYAMLValue) : IYAMLSequence; overload;

    /// <summary>
    /// Executes this JSONPath expression on a document and returns the first match.
    /// </summary>
    /// <param name="ADoc">the document to use this JSONPath on</param>
    /// <param name="AMatch">is set to the first match found, or a Null value if no match is found</param>
    /// <returns>True if a match is found or False otherwise</returns>
    function QuerySingle(const ADoc : IYAMLValue; out AMatch : IYAMLValue) : boolean; overload;

    /// <summary>
    /// Executes a JSONPath expression on a document.
    /// If you plan to use the same expression multiple times, then it is faster
    /// to parse it just once using the constructor, and execute it multiple times
    /// using one of the (non-static) Match* methods.
    /// </summary>
    /// <param name="root">the document to use the expression on</param>
    /// <param name="AExpression">the JSONPath expression to run</param>
    /// <returns>A yaml sequence that match this JSONPath expression</returns>
    /// <exception cref="EYAMLPathError">if AExpression is invalid</exception>
    class function Query(const root : IYAMLValue; const AExpression : string) : IYAMLSequence; overload; static;

    /// <summary>
    /// Executes a JSONPath expression on a document and returns the first match.
    /// If you plan to use the same expression multiple times, then it is faster
    /// to parse it just once using the constructor, and execute it multiple times
    /// using one of the (non-static) Match* methods.
    /// </summary>
    /// <param name="ADoc">the document to use the expression on</param>
    /// <param name="AExpression">the JSONPath expression to run</param>
    /// <param name="AMatch">is set to the first match found, or a Null value if no match is found</param>
    /// <returns>True if a match is found or False otherwise</returns>
    /// <exception cref="EYAMLPathError">if AExpression is invalid</exception>
    class function QuerySingle(const ADoc : IYAMLValue; const AExpression : string; out AMatch : IYAMLValue) : boolean; overload; static;

    /// <summary>
    /// Executes this JSONPath expression on a document and returns each match with where it
    /// is - see TYAMLPathMatch.
    /// </summary>
    /// <param name="root">the document to use this JSONPath on</param>
    /// <returns>The matches, in the order Query returns them</returns>
    function QueryMatches(const root : IYAMLValue) : TArray<TYAMLPathMatch>; overload;

    /// <summary>
    /// Executes a JSONPath expression on a document and returns each match with where it is:
    /// the collection it is in (nil for the root), its key or index, and its RFC 9535
    /// normalized path.
    /// </summary>
    /// <param name="root">the document to use the expression on</param>
    /// <param name="AExpression">the JSONPath expression to run</param>
    /// <returns>The matches, in the order Query returns them</returns>
    /// <exception cref="EYAMLPathError">if AExpression is invalid</exception>
    class function QueryMatches(const root : IYAMLValue; const AExpression : string) : TArray<TYAMLPathMatch>; overload; static;

  end;

resourcestring
  RS_YAML_PATH_INVALID_ROOT = 'A YAML path must start with a root ($) operator.';
  RS_YAML_PATH_DUPLICATE_ROOT = 'Multiple root operators ($) in YAML path.';
  RS_YAML_PATH_INVALID_OPERATOR = 'Operator in YAML path must start with dot (.) or bracket ([).';
  RS_YAML_PATH_MISSING_MEMBER_NAME = 'Child operator in YAML path is missing a member name.';
  RS_YAML_PATH_QUOTE_EXPECTED = 'Missing end quote in YAML path.';
  RS_YAML_PATH_QUOTE_MISMATCH = 'Quote mismatch in YAML path.';
  RS_YAML_PATH_MISSING_CLOSE_BRACKET = 'Missing close bracket (]) in YAML path.';
  RS_YAML_PATH_TOO_MANY_SLICE_ARGUMENTS = 'Too many slice arguments in YAML path.';
  RS_YAML_PATH_INVALID_SLICE_END = 'Invalid slice end value in YAML path.';
  RS_YAML_PATH_INVALID_SLICE_STEP = 'Invalid slice step value in YAML path.';
  RS_YAML_PATH_INVALID_BRACKET_OPERATOR = 'Invalid text between brackets in YAML path.';
  RS_YAML_PATH_INVALID_INDEX = 'Invalid index in YAML path.';
  RS_YAML_PATH_NEGATIVE_ARRAY_INDEX = 'Negative array index in YAML path not allowed.';
  RS_YAML_PATH_INVALID_RECURSIVE_DESCENT = 'Recursive descent operator (..) in YAML path must be followed by another operator.';
  RS_YAML_PATH_INVALID_FILTER_EXPRESSION = 'Invalid filter expression in YAML path.';
  RS_YAML_PATH_INVALID_FILTER_OPERATOR = 'Invalid filter operator in YAML path.';
  RS_YAML_PATH_MISSING_FILTER_PARENTHESIS = 'Missing closing parenthesis in filter expression.';
  RS_YAML_PATH_INVALID_OPERAND = 'Invalid operand in filter expression.';
  RS_YAML_PATH_INVALID_REGEX = 'Invalid regular expression in filter expression: %s';

implementation

uses
  System.Character,
  System.Classes,
  System.Math,
  System.StrUtils;

// A name in an RFC 9535 normalized path (section 2.7) goes in single quotes: ' and \ are
// escaped with \, so are backspace, tab, line feed, form feed and carriage return (\b \t \n
// \f \r), and any other control character is \u00 and two lower-case hex digits.
function NormalizedPathName(const name : string) : string;
const
  cHex : array[0..15] of Char = ('0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f');
var
  i : integer;
  ch : Char;
  needsEscape : boolean;
  sb : TStringBuilder;
begin
  needsEscape := false;
  for i := 1 to Length(name) do
  begin
    ch := name[i];
    if (ch < ' ') or (ch = '''') or (ch = '\') then
    begin
      needsEscape := true;
      break;
    end;
  end;
  if not needsEscape then
    exit(name);

  sb := TStringBuilder.Create(Length(name) + 8);
  try
    for i := 1 to Length(name) do
    begin
      ch := name[i];
      case ch of
        '''' : sb.Append('\''');
        '\' : sb.Append('\\');
        #8 : sb.Append('\b');
        #9 : sb.Append('\t');
        #10 : sb.Append('\n');
        #12 : sb.Append('\f');
        #13 : sb.Append('\r');
      else
        if ch < ' ' then
        begin
          sb.Append('\');
          sb.Append('u00');
          sb.Append(cHex[Ord(ch) shr 4]);
          sb.Append(cHex[Ord(ch) and 15]);
        end
        else
          sb.Append(ch);
      end;
    end;
    result := sb.ToString;
  finally
    sb.Free;
  end;
end;

{ TYAMLPathProcessor }

procedure TYAMLPathProcessor.AddMatch(const AMatch : IYAMLValue; const AParent : IYAMLCollection; const AKey : string; AIndex : integer; const APath : string);
begin
  if FTrackLocations then
  begin
    if FMatchCount = Length(FLocations) then
    begin
      if FMatchCount = 0 then
        SetLength(FLocations, 4)
      else
        SetLength(FLocations, FMatchCount * 2);
    end;
    FLocations[FMatchCount].Value := AMatch;
    FLocations[FMatchCount].Parent := AParent;
    FLocations[FMatchCount].Key := AKey;
    FLocations[FMatchCount].Index := AIndex;
    FLocations[FMatchCount].Path := APath;
  end
  else
    // the node as it is - it stays in its own collection, and keeps its Parent
    FMatchList.AddItem(AMatch);
  Inc(FMatchCount);
end;

class function TYAMLPathProcessor.NormalizeIndex(AIndex, ACount : integer) : integer;
begin
  if AIndex < 0 then
    result := ACount + AIndex
  else
    result := AIndex;
end;

function TYAMLPathProcessor.PathTo(const AParentPath, AKey : string; AIndex : integer) : string;
begin
  if not FTrackLocations then
    result := ''
  else if AIndex >= 0 then
    result := AParentPath + '[' + IntToStr(AIndex) + ']'
  else
    result := AParentPath + '[''' + NormalizedPathName(AKey) + ''']';
end;

procedure TYAMLPathProcessor.Select(const ANext : POperator; const AValue : IYAMLValue; const AParent : IYAMLCollection;
  const AParentPath, AKey : string; AIndex : integer);
var
  path : string;
begin
  path := PathTo(AParentPath, AKey, AIndex);
  if ANext = nil then
    AddMatch(AValue, AParent, AKey, AIndex, path)
  else
    VisitOperator(ANext, AValue, path);
end;

procedure TYAMLPathProcessor.AddOperator(const AOperator : TOperator);
var
  i : integer;
begin
  if (FOperatorCount >= Length(FOperators)) then
  begin
    if (FOperatorCount = 0) then
      SetLength(FOperators, 4)
    else
    begin
      SetLength(FOperators, FOperatorCount * 2);
      //adjust the Next pointers after a resize
      for i := 0 to FOperatorCount - 1 do
        FOperators[i].Next := @FOperators[i + 1];
    end;
  end;
  FOperators[FOperatorCount] := AOperator;

  if (FOperatorCount > 0) then
    FOperators[FOperatorCount - 1].Next := @FOperators[FOperatorCount];

  Inc(FOperatorCount);
end;

constructor TYAMLPathProcessor.Create(const expression : string);
var
  reader : IInputReader;
begin
  FInitialized := False;
  FOperators := nil;
  FOperatorCount := 0;

  if (expression = '') then
    raise EYAMLPathError.Create(RS_YAML_PATH_INVALID_ROOT);

  reader := TInputReaderFactory.CreateFromString(expression);
  SkipWhitespace(reader);
  if (reader.Current <> '$') then
    raise EYAMLPathError.Create(RS_YAML_PATH_INVALID_ROOT);
  reader.Read;

  try
    while (reader.Current <> #0) do
    begin
      SkipWhitespace(reader);
      case reader.Current of
        '.' : ParseDotOperator(reader);
        '[' : ParseBracketOperator(reader);
        '$' : raise EYAMLPathError.Create(RS_YAML_PATH_DUPLICATE_ROOT);
      else
        raise EYAMLPathError.Create(RS_YAML_PATH_INVALID_OPERATOR);
      end;
    end;

    if (FOperatorCount > 0) and (FOperators[FOperatorCount - 1].OperatorType = TOperatorType.RecursiveDescent) then
      raise EYAMLPathError.Create(RS_YAML_PATH_INVALID_RECURSIVE_DESCENT);
  except
    // the caller gets no processor to clean up, so the filters parsed so far are freed here
    FInitialized := True;
    Cleanup;
    raise;
  end;

  FInitialized := True;
end;

procedure TYAMLPathProcessor.Cleanup;
var
  i : integer;
begin
  if not FInitialized then
    Exit;

  // Filter operators own a heap allocated TFilterExpression (stored in the record's
  // variant part) that is not released when the FOperators array is finalized.
  for i := 0 to FOperatorCount - 1 do
  begin
    if (FOperators[i].OperatorType = TOperatorType.Filter) and Assigned(FOperators[i].FilterExpression) then
    begin
      FOperators[i].FilterExpression.Free;
      FOperators[i].FilterExpression := nil;
    end;
  end;

  FInitialized := False;
end;

class function TYAMLPathProcessor.IsQuote(const ch : Char) : boolean;
begin
  result := (ch = '''') or (ch = '"');
end;

function TYAMLPathProcessor.Query(const root : IYAMLValue) : IYAMLSequence;
begin
  result := InternalMatch(root, False);
end;

class function TYAMLPathProcessor.Query(const root : IYAMLValue; const AExpression : string) : IYAMLSequence;
var
  path : TYAMLPathProcessor;
begin
  if (AExpression = '') then
  begin
    result := TYAMLSequence.Create(nil, '');
    Exit;
  end;

  path := TYAMLPathProcessor.Create(AExpression);
  try
    result := path.InternalMatch(root, False);
  finally
    path.Cleanup;
  end;
end;

function TYAMLPathProcessor.InternalMatch(const root : IYAMLValue; const AMatchSingle : boolean) : IYAMLSequence;
begin
  FMatchList := TYAMLSequence.Create(root, '');
  FMatches := FMatchList;
  FMatchCount := 0;
  FSingleMatch := AMatchSingle;
  FTrackLocations := False;
  FRootDocument := root;

  if (FOperatorCount = 0) then
  begin
    // Root-only access ($) - return the root node itself
    AddMatch(root, nil, '', -1, '$');
    result := FMatches;
    exit;
  end;

  VisitOperator(@FOperators[0], root, '$');

  result := FMatches;
end;

function TYAMLPathProcessor.InternalMatches(const root : IYAMLValue) : TArray<TYAMLPathMatch>;
begin
  FMatches := nil;
  FMatchList := nil;
  FLocations := nil;
  FMatchCount := 0;
  FSingleMatch := False;
  FTrackLocations := True;
  FRootDocument := root;
  try
    if (FOperatorCount = 0) then
      AddMatch(root, nil, '', -1, '$') // root-only access ($)
    else
      VisitOperator(@FOperators[0], root, '$');
    SetLength(FLocations, FMatchCount);
    result := FLocations;
  finally
    FLocations := nil;
    FTrackLocations := False;
  end;
end;

function TYAMLPathProcessor.QueryMatches(const root : IYAMLValue) : TArray<TYAMLPathMatch>;
begin
  result := InternalMatches(root);
end;

class function TYAMLPathProcessor.QueryMatches(const root : IYAMLValue; const AExpression : string) : TArray<TYAMLPathMatch>;
var
  path : TYAMLPathProcessor;
begin
  if (AExpression = '') then
  begin
    result := nil;
    Exit;
  end;

  path := TYAMLPathProcessor.Create(AExpression);
  try
    result := path.InternalMatches(root);
  finally
    path.Cleanup;
  end;
end;


function TYAMLPathProcessor.QuerySingle(const ADoc : IYAMLValue; out AMatch : IYAMLValue) : boolean;
var
  matches : IYAMLSequence;
begin
  matches := InternalMatch(ADoc, True);
  if (matches.Count = 0) then
  begin
    AMatch := TYAMLValue.Create(nil, TYAMLValueType.vtNull);
    Exit(False);
  end;

  AMatch := matches[0];
  result := True;
end;

class function TYAMLPathProcessor.QuerySingle(const ADoc : IYAMLValue; const AExpression : string; out AMatch : IYAMLValue) : boolean;
var
  yamlPath : TYAMLPathProcessor;
begin
  if (AExpression = '') then
  begin
    AMatch := TYAMLValue.Create(nil, TYAMLValueType.vtNull);
    Exit(False);
  end;

  yamlPath := TYAMLPathProcessor.Create(AExpression);
  try
    result := yamlPath.QuerySingle(ADoc, AMatch);
  finally
    yamlPath.Cleanup;
  end;
end;

//procedure TYAMLPathProcessor.ParseBracketOperator(const reader : IInputReader);
//var
//  current, startPos, stopPos : PChar;
//  quoteChar : Char;
//  op : TOperator;
//  index, count : integer;
//begin
//  // Initial '[' has already been parsed
//  Assert(ACur^ = '[');
//  current := ACur + 1;
//  SkipWhitespace(reader);
//
//  if (reader.Current = '?') then
//  begin
//    // [?(...)] - Filter expression
//    reader.Read;
//    SkipWhitespace(reader);
//    if (reader.Current <> '(') then
//      raise EYAMLPathError.Create(RS_YAML_PATH_INVALID_FILTER_EXPRESSION);
//    reader.Read;
//
//    op.Init(TOperatorType.Filter);
//    op.FilterExpression := ParseFilterExpression();
//
//    SkipWhitespace(reader);
//    if (reader.Current <> ')') then
//      raise EYAMLPathError.Create(RS_YAML_PATH_MISSING_FILTER_PARENTHESIS);
//    reader.Read;
//
//    SkipWhitespace(reader);
//    if (reader.Current <> ']') then
//      raise EYAMLPathError.Create(RS_YAML_PATH_MISSING_CLOSE_BRACKET);
//
//    AddOperator(op);
//    reader.Read;
//  end
//  else if IsQuote(reader.Current) then
//  begin
//    // ['ident'] or ["ident"]
//    quoteChar := reader.Current;
//    reader.Read;
//    if (reader.Current = '*') then
//    begin
//      // ['*'] or ["*"]
//      if (not IsQuote(reader.Peek)) then
//        raise EYAMLPathError.Create(RS_YAML_PATH_QUOTE_EXPECTED);
//
//      if (reader.Peek <> quoteChar) then
//        raise EYAMLPathError.Create(RS_YAML_PATH_QUOTE_MISMATCH);
//
//      reader.Read(2);
//      SkipWhitespace(reader);
//      if (reader.Current <> ']') then
//        raise EYAMLPathError.Create(RS_YAML_PATH_MISSING_CLOSE_BRACKET);
//
//      op.Init(TOperatorType.Wildcard);
//      AddOperator(op);
//      reader.Read;
//    end
//    else
//    begin
//      // ['ident'] or ["ident"]
//      startPos := current;
//
//      // Scan for end quote
//      while (reader.Current <> #0) and (not IsQuote(reader.Current)) do
//        reader.Read;
//
//      if (reader.Current = #0) then
//        raise EYAMLPathError.Create(RS_YAML_PATH_QUOTE_EXPECTED);
//
//      if (current = startPos) then
//        raise EYAMLPathError.Create(RS_YAML_PATH_MISSING_MEMBER_NAME);
//
//      if (reader.Current <> quoteChar) then
//        raise EYAMLPathError.Create(RS_YAML_PATH_QUOTE_MISMATCH);
//
//      stopPos := current;
//      reader.Read;
//      SkipWhitespace(reader);
//      if (reader.Current <> ']') then
//        raise EYAMLPathError.Create(RS_YAML_PATH_MISSING_CLOSE_BRACKET);
//
//      op.Init(TOperatorType.ChildName);
//      SetString(op.Name, startPos, stopPos - startPos);
//      AddOperator(op);
//      reader.Read;
//    end;
//  end
//  else if (reader.Current = '*') then
//  begin
//    // [*]
//    reader.Read;
//    SkipWhitespace(reader);
//    if (reader.Current <> ']') then
//      raise EYAMLPathError.Create(RS_YAML_PATH_MISSING_CLOSE_BRACKET);
//
//    op.Init(TOperatorType.Wildcard);
//    AddOperator(op);
//    reader.Read;
//  end
//  else
//  begin
//    // [index]
//    // [index, index, ...]
//    // [start :end :step]
//    op.Init(TOperatorType.Wildcard); // Temporary
//    if (not ParseInteger(current, index)) then
//    begin
//      // [ :end :step]
//      SkipWhitespace(reader);
//      if (reader.Current <> ':') then
//        raise EYAMLPathError.Create(RS_YAML_PATH_INVALID_BRACKET_OPERATOR);
//
//      op.Init(TOperatorType.Slice);
//    end
//    else
//    begin
//      // [index]
//      // [index, index, ...]
//      SkipWhitespace(reader);
//      if (reader.Current = ']') then
//      begin
//        // [index]
//        if (index < 0) then
//          raise EYAMLPathError.Create(RS_YAML_PATH_NEGATIVE_ARRAY_INDEX);
//        op.Init(TOperatorType.ChildIndex);
//        op.Index := index;
//      end
//      else if (reader.Current = ',') then
//      begin
//        // [index, index, ...]
//        if (index < 0) then
//          raise EYAMLPathError.Create(RS_YAML_PATH_NEGATIVE_ARRAY_INDEX);
//        op.Init(TOperatorType.IndexList);
//        SetLength(op.Indices, 4);
//        op.Indices[0] := index;
//        count := 1;
//
//        while True do
//        begin
//          reader.Read;
//          SkipWhitespace(reader);
//          if (not ParseInteger(current, index)) then
//            raise EYAMLPathError.Create(RS_YAML_PATH_INVALID_INDEX);
//
//          if (index < 0) then
//            raise EYAMLPathError.Create(RS_YAML_PATH_NEGATIVE_ARRAY_INDEX);
//
//          if (count >= Length(op.Indices)) then
//            SetLength(op.Indices, count * 2);
//          op.Indices[count] := index;
//          Inc(count);
//
//          if (reader.Current = ']') then
//            Break;
//
//          if (reader.Current <> ',') then
//            raise EYAMLPathError.Create(RS_YAML_PATH_INVALID_INDEX);
//        end;
//        SetLength(op.Indices, count);
//      end
//      else
//      begin
//        if (reader.Current <> ':') then
//          raise EYAMLPathError.Create(RS_YAML_PATH_INVALID_BRACKET_OPERATOR);
//
//        // [start :end :step]
//        op.Init(TOperatorType.Slice);
//        op.Start := index;
//      end;
//    end;
//
//    if (op.OperatorType = TOperatorType.Slice) and (reader.Current = ':') then
//    begin
//      // Parse :end part of slice
//      reader.Read;
//      SkipWhitespace(reader);
//      if ParseInteger(current, index) then
//      begin
//        op.Stop := index;
//      end
//      else
//      begin
//        if (reader.Current <> ':') and (reader.Current <> ']') then
//          raise EYAMLPathError.Create(RS_YAML_PATH_INVALID_SLICE_END);
//      end;
//
//      if (reader.Current = ':') then
//      begin
//        // Parse :step part of slice
//        reader.Read;
//        SkipWhitespace(reader);
//        if ParseInteger(current, index) then
//          op.Step := index
//        else if (reader.Current <> ']') then
//          raise EYAMLPathError.Create(RS_YAML_PATH_INVALID_SLICE_STEP);
//      end;
//
//      if (reader.Current = ':') then
//        raise EYAMLPathError.Create(RS_YAML_PATH_TOO_MANY_SLICE_ARGUMENTS);
//
//      if (reader.Current <> ']') then
//        raise EYAMLPathError.Create(RS_YAML_PATH_MISSING_CLOSE_BRACKET);
//    end;
//
//    AddOperator(op);
//    reader.Read;
//  end;
//
//  ACur := current;
//end;

procedure TYAMLPathProcessor.ParseBracketOperator(const reader : IInputReader);
var
  quoteChar : Char;
  op : TOperator;
  index, count : integer;
  name : string;
begin
  // Initial '[' has already been parsed
  Assert(reader.Current = '[');
  reader.Read;
  SkipWhitespace(reader);

  if (reader.Current = '?') then
  begin
    // [?(...)] - Filter expression
    reader.Read;
    SkipWhitespace(reader);
    if (reader.Current <> '(') then
      raise EYAMLPathError.Create(RS_YAML_PATH_INVALID_FILTER_EXPRESSION);
    reader.Read;

    op.Init(TOperatorType.Filter);
    op.FilterExpression := ParseFilterExpression(reader);
    // added before the checks below, so that Cleanup frees the expression if one raises
    AddOperator(op);

    SkipWhitespace(reader);
    if (reader.Current <> ')') then
      raise EYAMLPathError.Create(RS_YAML_PATH_MISSING_FILTER_PARENTHESIS);
    reader.Read;

    SkipWhitespace(reader);
    if (reader.Current <> ']') then
      raise EYAMLPathError.Create(RS_YAML_PATH_MISSING_CLOSE_BRACKET);

    reader.Read
  end
  else if IsQuote(reader.Current) then
  begin
    // ['ident'] or ["ident"]
    quoteChar := reader.Current;
    reader.Read;
    if (reader.Current = '*') then
    begin
      // ['*'] or ["*"]
      if (not IsQuote(reader.Peek)) then
        raise EYAMLPathError.Create(RS_YAML_PATH_QUOTE_EXPECTED);

      if (reader.Peek <> quoteChar) then
        raise EYAMLPathError.Create(RS_YAML_PATH_QUOTE_MISMATCH);

      reader.Read(2);
      SkipWhitespace(reader);
      if (reader.Current <> ']') then
        raise EYAMLPathError.Create(RS_YAML_PATH_MISSING_CLOSE_BRACKET);

      op.Init(TOperatorType.Wildcard);
      AddOperator(op);
      reader.Read
    end
    else
    begin
      // ['ident'] or ["ident"]

      // Scan for end quote
      while (reader.Current  <> #0) and (not IsQuote(reader.Current)) do
      begin
        name := name + reader.Current;
        reader.Read;
      end;

      if (reader.Current = #0) then
        raise EYAMLPathError.Create(RS_YAML_PATH_QUOTE_EXPECTED);

      if (name = '') then
        raise EYAMLPathError.Create(RS_YAML_PATH_MISSING_MEMBER_NAME);

      if (reader.Current <> quoteChar) then
        raise EYAMLPathError.Create(RS_YAML_PATH_QUOTE_MISMATCH);

      reader.Read; //skip the quote
      SkipWhitespace(reader);
      if (reader.Current <> ']') then
        raise EYAMLPathError.Create(RS_YAML_PATH_MISSING_CLOSE_BRACKET);

      op.Init(TOperatorType.ChildName);
      op.Name := name;
      AddOperator(op);
      reader.Read;
    end;
  end
  else if (reader.Current = '*') then
  begin
    // [*]
    reader.Read;
    SkipWhitespace(reader);
    if (reader.Current <> ']') then
      raise EYAMLPathError.Create(RS_YAML_PATH_MISSING_CLOSE_BRACKET);

    op.Init(TOperatorType.Wildcard);
    AddOperator(op);
    reader.Read;
  end
  else
  begin
    // [index]
    // [index, index, ...]
    // [start :end :step]
    op.Init(TOperatorType.Wildcard); // Temporary
    if (not ParseInteger(reader, index)) then
    begin
      // [ :end :step]
      SkipWhitespace(reader);
      if (reader.Current <> ':') then
        raise EYAMLPathError.Create(RS_YAML_PATH_INVALID_BRACKET_OPERATOR);

      op.Init(TOperatorType.Slice);
    end
    else
    begin
      // [index]
      // [index, index, ...]
      SkipWhitespace(reader);
      if (reader.Current = ']') then
      begin
        // [index] - a negative index counts from the end (RFC 9535 2.3.3)
        op.Init(TOperatorType.ChildIndex);
        op.Index := index;
      end
      else if (reader.Current = ',') then
      begin
        // [index, index, ...]
        op.Init(TOperatorType.IndexList);
        SetLength(op.Indices, 4);
        op.Indices[0] := index;
        count := 1;

        while True do
        begin
          reader.Read;
          SkipWhitespace(reader);
          if (not ParseInteger(reader, index)) then
            raise EYAMLPathError.Create(RS_YAML_PATH_INVALID_INDEX);

          if (count >= Length(op.Indices)) then
            SetLength(op.Indices, count * 2);
          op.Indices[count] := index;
          Inc(count);
          SkipWhitespace(reader);

          if (reader.Current = ']') then
            Break;

          if (reader.Current <> ',') then
            raise EYAMLPathError.Create(RS_YAML_PATH_INVALID_INDEX);
        end;
        SetLength(op.Indices, count);
      end
      else
      begin
        if (reader.Current <> ':') then
          raise EYAMLPathError.Create(RS_YAML_PATH_INVALID_BRACKET_OPERATOR);

        // [start :end :step]
        op.Init(TOperatorType.Slice);
        op.Start := index;
        op.HasStart := True;
      end;
    end;

    if (op.OperatorType = TOperatorType.Slice) and (reader.Current = ':') then
    begin
      // Parse :end part of slice
      reader.Read;
      SkipWhitespace(reader);
      if ParseInteger(reader, index) then
      begin
        op.Stop := index;
        op.HasStop := True;
      end
      else
      begin
        if (not CharInSet(reader.Current, [':', ']'])) then
          raise EYAMLPathError.Create(RS_YAML_PATH_INVALID_SLICE_END);
      end;

      if (reader.Current = ':') then
      begin
        // Parse :step part of slice
        reader.Read;
        SkipWhitespace(reader);
        if ParseInteger(reader, index) then
          op.Step := index
        else if (reader.Current  <> ']') then
          raise EYAMLPathError.Create(RS_YAML_PATH_INVALID_SLICE_STEP);
      end;

      if (reader.Current = ':') then
        raise EYAMLPathError.Create(RS_YAML_PATH_TOO_MANY_SLICE_ARGUMENTS);

      if (reader.Current <> ']') then
        raise EYAMLPathError.Create(RS_YAML_PATH_MISSING_CLOSE_BRACKET);
    end;

    AddOperator(op);
    reader.Read;
  end;
end;


//procedure TYAMLPathProcessor.ParseDotOperator(const reader : IInputReader);
//var
//  current, startPos : PChar;
//  op : TOperator;
//begin
//  // Initial '.' has already been parsed
//  Assert(ACur^ = '.');
//  current := ACur + 1;
//
//  case reader.Current of
//    '.' :
//    begin
//      // ..
//      op.Init(TOperatorType.RecursiveDescent);
//      AddOperator(op);
//    end;
//    '*' :
//    begin
//      // .*
//      op.Init(TOperatorType.Wildcard);
//      AddOperator(op);
//      reader.Read;
//    end;
//  else
//    // .ident
//    startPos := current;
//
//    // Scan for start of next operator
//    while (reader.Current <> #0) and (reader.Current <> '.') and (reader.Current <> '[') and (reader.Current <> '$') do
//      reader.Read;
//
//    if (current = startPos) then
//      raise EYAMLPathError.Create(RS_YAML_PATH_MISSING_MEMBER_NAME);
//
//    op.Init(TOperatorType.ChildName);
//    SetString(op.Name, startPos, current - startPos);
//    AddOperator(op);
//  end;
//
//  ACur := current;
//end;

procedure TYAMLPathProcessor.ParseDotOperator(const reader : IInputReader);
var
  op : TOperator;
begin
  // Initial '.' has already been parsed
  Assert(reader.Current = '.');
  reader.Read;

  case reader.Current of
    '.' :
    begin
      // .. - the descendant segment: the selector after it (a name, * or a bracketed
      // selector) is applied to the node and to each of its descendants
      reader.Read;
      op.Init(TOperatorType.RecursiveDescent);
      AddOperator(op);
      case reader.Current of
        #0, '.', '$' :
          raise EYAMLPathError.Create(RS_YAML_PATH_INVALID_RECURSIVE_DESCENT);
        '[' :
          ParseBracketOperator(reader);
        '*' :
        begin
          op.Init(TOperatorType.Wildcard);
          AddOperator(op);
          reader.Read;
        end;
      else
        ParseMemberName(reader);
      end;
    end;
    '*' :
    begin
      // .*
      op.Init(TOperatorType.Wildcard);
      AddOperator(op);
      reader.Read;
    end;
  else
    // .ident
    ParseMemberName(reader);
  end;
end;

procedure TYAMLPathProcessor.ParseMemberName(const reader : IInputReader);
var
  op : TOperator;
  name : string;
begin
  // Scan for start of next operator
  while not CharInSet(reader.Current, [#0, '.', '[', '$']) do
  begin
    name := name + reader.Current;
    reader.Read;
  end;

  if (name = '') then
    raise EYAMLPathError.Create(RS_YAML_PATH_MISSING_MEMBER_NAME);

  op.Init(TOperatorType.ChildName);
  op.Name := name;
  AddOperator(op);
end;




class function TYAMLPathProcessor.ParseInteger(const reader : IInputReader; out AValue : integer) : boolean;
var
  ch : Char;
  isNegative : boolean;
  value : integer;
begin
  SkipWhitespace(reader);

  isNegative := False;
  if (reader.Current = '-') then
  begin
    isNegative := True;
    reader.Read;
  end;

  ch := reader.Current;
  if (ch < '0') or (ch > '9') then
    Exit(False);

  value := Ord(ch) - Ord('0');
  reader.Read;

  while True do
  begin
    ch := reader.Current;
    if (ch < '0') or (ch > '9') then
      Break;

    value := (value * 10) + (Ord(ch) - Ord('0'));
    reader.Read;
  end;

  if isNegative then
    value := -value;

  SkipWhitespace(reader);
  AValue := value;
  result := True;
end;



class procedure TYAMLPathProcessor.SkipWhitespace(const reader : IInputReader);
begin
  while (reader.Current <= ' ') and (reader.Current <> #0) do
    reader.Read;
end;


procedure TYAMLPathProcessor.VisitOperator(const AOp : POperator; const ARoot : IYAMLValue; const ARootPath : string);
var
  index, arrayIndex, startIndex, stopIndex, stepValue : integer;
  value : IYAMLValue;
  name : string;
  nextOp : POperator;
  sequence : IYAMLSequence;
  mapping : IYAMLMapping;
  count, lower, upper : integer;
  position : Int64; // a large step cannot overflow it
begin
  Assert(Assigned(AOp));
  if (FSingleMatch) and (FMatchCount <> 0) then
    Exit;

  case AOp.OperatorType of
    TOperatorType.ChildName :
      if ARoot.IsMapping then
      begin
        mapping := ARoot.AsMapping;
        if mapping.TryGetValue(AOp.Name, value) then
          Select(AOp.Next, value, mapping, ARootPath, AOp.Name, -1);
      end;

    TOperatorType.ChildIndex :
      if ARoot.IsSequence then
      begin
        sequence := ARoot.AsSequence;
        // a negative index counts from the end; out of range selects nothing
        arrayIndex := NormalizeIndex(AOp.Index, sequence.Count);
        if (arrayIndex >= 0) and (arrayIndex < sequence.Count) then
          Select(AOp.Next, sequence.Items[arrayIndex], sequence, ARootPath, '', arrayIndex);
      end;

    TOperatorType.RecursiveDescent :
      begin
        // RFC 9535 2.5.2: the selector after '..' is applied to this node, then to each of
        // its descendants in document order - each child, followed by its own descendants
        nextOp := AOp.Next;
        Assert(Assigned(nextOp));
        VisitOperator(nextOp, ARoot, ARootPath);
        if ARoot.IsSequence then
        begin
          sequence := ARoot.AsSequence;
          for index := 0 to sequence.Count - 1 do
            VisitOperator(AOp, sequence.Items[index], PathTo(ARootPath, '', index));
        end
        else if ARoot.IsMapping then
        begin
          mapping := ARoot.AsMapping;
          for index := 0 to mapping.Count - 1 do
          begin
            name := mapping.Keys[index];
            VisitOperator(AOp, mapping.Values[name], PathTo(ARootPath, name, -1));
          end;
        end;
      end;

    TOperatorType.Wildcard :
      case ARoot.ValueType of
        TYAMLValueType.vtSequence :
          begin
            sequence := ARoot.AsSequence;
            for index := 0 to sequence.Count - 1 do
              Select(AOp.Next, sequence.Items[index], sequence, ARootPath, '', index);
          end;

        TYAMLValueType.vtMapping :
          begin
            mapping := ARoot.AsMapping;
            for index := 0 to mapping.Count - 1 do
            begin
              name := mapping.Keys[index];
              Select(AOp.Next, mapping.Values[name], mapping, ARootPath, name, -1);
            end;
          end;
      end;

    TOperatorType.IndexList :
      if ARoot.IsSequence then
      begin
        sequence := ARoot.AsSequence;
        for index := 0 to Length(AOp.Indices) - 1 do
        begin
          // each index as for [index]: negative counts from the end, out of range is skipped
          arrayIndex := NormalizeIndex(AOp.Indices[index], sequence.Count);
          if (arrayIndex >= 0) and (arrayIndex < sequence.Count) then
            Select(AOp.Next, sequence.Items[arrayIndex], sequence, ARootPath, '', arrayIndex);
        end;
      end;

    TOperatorType.Slice :
      if ARoot.IsSequence then
      begin
        sequence := ARoot.AsSequence;
        // RFC 9535 2.3.4.2.2: negative start and end count from the end, the defaults depend
        // on the direction of the step, and a step of 0 selects nothing
        count := sequence.Count;
        stepValue := AOp.Step;
        if stepValue > 0 then
        begin
          if AOp.HasStart then
            startIndex := NormalizeIndex(AOp.Start, count)
          else
            startIndex := 0;
          if AOp.HasStop then
            stopIndex := NormalizeIndex(AOp.Stop, count)
          else
            stopIndex := count;
          lower := Min(Max(startIndex, 0), count);
          upper := Min(Max(stopIndex, 0), count);
          position := lower;
          while position < upper do
          begin
            Select(AOp.Next, sequence.Items[integer(position)], sequence, ARootPath, '', integer(position));
            Inc(position, stepValue);
          end;
        end
        else if stepValue < 0 then
        begin
          if AOp.HasStart then
            startIndex := NormalizeIndex(AOp.Start, count)
          else
            startIndex := count - 1;
          if AOp.HasStop then
            stopIndex := NormalizeIndex(AOp.Stop, count)
          else
            stopIndex := -1; // the default end, -count - 1, normalized
          upper := Min(Max(startIndex, -1), count - 1);
          lower := Min(Max(stopIndex, -1), count - 1);
          position := upper;
          while lower < position do
          begin
            Select(AOp.Next, sequence.Items[integer(position)], sequence, ARootPath, '', integer(position));
            Inc(position, stepValue);
          end;
        end;
      end;
      
    TOperatorType.Filter :
      begin
        if ARoot.IsSequence then
        begin
          sequence := ARoot.AsSequence;
          for index := 0 to sequence.Count - 1 do
          begin
            if (FSingleMatch) and (FMatchCount <> 0) then
              Exit;
            
            value := sequence.Items[index];
            if EvaluateFilterExpression(AOp.FilterExpression,
              TFilterContext.Create(value, FRootDocument)) then
              Select(AOp.Next, value, sequence, ARootPath, '', index);
          end;
        end
        else if ARoot.IsMapping then
        begin
          mapping := ARoot.AsMapping;
          for index := 0 to mapping.Count - 1 do
          begin
            if (FSingleMatch) and (FMatchCount <> 0) then
              Exit;
            
            name := mapping.Keys[index];
            value := mapping.Values[name];
            if EvaluateFilterExpression(AOp.FilterExpression,
              TFilterContext.Create(value, FRootDocument)) then
              Select(AOp.Next, value, mapping, ARootPath, name, -1);
          end;
        end;
      end
  else
    Assert(False);
  end;
end;

function TYAMLPathProcessor.ParseFilterExpression(const reader : IInputReader) : TFilterExpression;
begin
  result := ParseLogicalExpression(reader);
end;

function TYAMLPathProcessor.ParseLogicalExpression(const reader : IInputReader) : TFilterExpression;
begin
  // Parse OR expressions (lowest precedence)
  result := ParseOrExpression(reader);
end;

function TYAMLPathProcessor.ParseOrExpression(const reader : IInputReader) : TFilterExpression;
var
  left, right : TFilterExpression;
  logicalExpr : TFilterLogicalExpression;
begin
  left := ParseAndExpression(reader);

  SkipWhitespace(reader);
  if (reader.Current = '|') and (reader.Peek = '|') then
  begin
    reader.Read(2);
    SkipWhitespace(reader);
    try
      right := ParseOrExpression(reader); // Right-associative OR
    except
      left.Free;
      raise;
    end;

    result := TFilterExpression.Create;
    result.IsComparison := False;
    logicalExpr := TFilterLogicalExpression.Create;
    logicalExpr.LogicalOp := TFilterLogical.flOr;
    logicalExpr.Left := left;
    logicalExpr.Right := right;
    result.LogicalExpr := logicalExpr;
  end
  else
    result := left;

end;

function TYAMLPathProcessor.ParseAndExpression(const reader : IInputReader) : TFilterExpression;
var
  left, right : TFilterExpression;
  logicalExpr : TFilterLogicalExpression;
begin
  left := ParseNotExpression(reader);

  SkipWhitespace(reader);
  if (reader.Current = '&') and (reader.Peek = '&') then
  begin
    reader.Read(2);
    SkipWhitespace(reader);
    try
      right := ParseAndExpression(reader); // Right-associative AND
    except
      left.Free;
      raise;
    end;
    
    result := TFilterExpression.Create;
    result.IsComparison := False;
    logicalExpr := TFilterLogicalExpression.Create;
    logicalExpr.LogicalOp := TFilterLogical.flAnd;
    logicalExpr.Left := left;
    logicalExpr.Right := right;
    result.LogicalExpr := logicalExpr;
  end
  else
    result := left;
end;

function TYAMLPathProcessor.ParseNotExpression(const reader : IInputReader) : TFilterExpression;
var
  logicalExpr : TFilterLogicalExpression;
  operand : TFilterExpression;
begin
  SkipWhitespace(reader);

  if (reader.Current = '!') then
  begin
    reader.Read;
    SkipWhitespace(reader);
    // the operand first, so nothing is left to free if it raises
    operand := ParseNotExpression(reader);
    result := TFilterExpression.Create;
    result.IsComparison := False;
    logicalExpr := TFilterLogicalExpression.Create;
    logicalExpr.LogicalOp := TFilterLogical.flNot;
    logicalExpr.Left := operand;
    logicalExpr.Right := nil;
    result.LogicalExpr := logicalExpr;
  end
  else
    result := ParsePrimaryExpression(reader);

end;

function TYAMLPathProcessor.ParsePrimaryExpression(const reader : IInputReader) : TFilterExpression;
var
  comparison : TFilterComparison;
begin
  SkipWhitespace(reader);
  
  if (reader.Current = '(') then
  begin
    // Handle parenthesized expression
    reader.Read; // Skip '('
    SkipWhitespace(reader);
    result := ParseLogicalExpression(reader);
    SkipWhitespace(reader);
    if (reader.Current <> ')') then
    begin
      result.Free;
      raise EYAMLPathError.Create(RS_YAML_PATH_MISSING_FILTER_PARENTHESIS);
    end;
    reader.Read; // Skip ')'
  end
  else
  begin
    // Handle comparison expression - parsed first, so nothing is left to free if it raises
    comparison := ParseComparisonExpression(reader);
    result := TFilterExpression.Create;
    result.IsComparison := True;
    result.Comparison := comparison;
  end;
end;

function TYAMLPathProcessor.ParseComparisonExpression(const reader : IInputReader) : TFilterComparison;
begin
  result := TFilterComparison.Create;
  // the comparison is freed if parsing it raises
  try

    result.LeftOperand := ParseOperand(reader);
    SkipWhitespace(reader);
  
    // Check if there's an operator - if not, this is a truthiness check
    // Note: We need to check for && and || specifically, not just & or |
    if (reader.Current = ')') or (reader.Current = #0) or
       ((reader.Current = '&') and (reader.Peek = '&')) or
       ((reader.Current = '|') and (reader.Peek = '|')) then
    begin
      // No operator, this is a truthiness check - treat as "== true"
      result.Operator := TFilterOperator.foEquals;
      result.RightOperand.OperandType := TFilterOperandType.fotLiteral;
      result.RightOperand.StringValue := '';
      result.RightOperand.NumericValue := 0;
      result.RightOperand.BoolValue := True;
      result.RightOperand.Path := '';
      result.RightOperand.IsTruthinessCheck := True;
      result.RightOperand.IsNumericLiteral := False;
    end
    else
    begin
      // Has operator, parse normally
      result.Operator := ParseFilterOperator(reader);
      SkipWhitespace(reader);

      // Special case for empty operator - it can be unary (defaults to true)
      if (result.Operator = TFilterOperator.foEmpty) and
         ((reader.Current = ')') or (reader.Current = ']') or (reader.Current = #0) or
          ((reader.Current = '&') and (reader.Peek = '&')) or
          ((reader.Current = '|') and (reader.Peek = '|'))) then
      begin
        // Empty operator without right operand - default to true
        result.RightOperand.OperandType := TFilterOperandType.fotLiteral;
        result.RightOperand.LiteralKind := TFilterLiteralKind.flkBoolean;
        result.RightOperand.StringValue := '';
        result.RightOperand.NumericValue := 0;
        result.RightOperand.BoolValue := True;
        result.RightOperand.Path := '';
        result.RightOperand.IsTruthinessCheck := False;
        result.RightOperand.IsNumericLiteral := False;
      end
      else if (result.Operator = TFilterOperator.foRegexMatch) and (reader.Current = '/') then
      begin
        // =~ /pattern/flags
        result.Regex := ParseRegexLiteral(reader);
        result.HasRegex := True;
      end
      else
      begin
        // size can be compared: @.items size > 5 (size 5 is size == 5)
        result.SizeOperator := TFilterOperator.foEquals;
        if result.Operator = TFilterOperator.foSize then
        begin
          ParseComparisonOperator(reader, result.SizeOperator);
          SkipWhitespace(reader);
        end;
        result.RightOperand := ParseOperand(reader);
        // =~ 'pattern' - a string literal is a pattern too
        if (result.Operator = TFilterOperator.foRegexMatch) and
           (result.RightOperand.OperandType = TFilterOperandType.fotLiteral) and
           (result.RightOperand.LiteralKind = TFilterLiteralKind.flkString) then
        begin
          result.Regex := CompileRegex(result.RightOperand.StringValue, []);
          result.HasRegex := True;
        end;
      end;
    end;
  except
    result.Free;
    raise;
  end;
end;

class function TYAMLPathProcessor.ParseComparisonOperator(const reader : IInputReader; out AOperator : TFilterOperator) : boolean;
begin
  SkipWhitespace(reader);
  result := True;
  if (reader.Current = '=') and (reader.Peek = '=') then
  begin
    AOperator := TFilterOperator.foEquals;
    reader.Read(2);
  end
  else if (reader.Current = '!') and (reader.Peek = '=') then
  begin
    AOperator := TFilterOperator.foNotEquals;
    reader.Read(2);
  end
  else if (reader.Current = '>') and (reader.Peek = '=') then
  begin
    AOperator := TFilterOperator.foGreaterEq;
    reader.Read(2);
  end
  else if (reader.Current = '<') and (reader.Peek = '=') then
  begin
    AOperator := TFilterOperator.foLessEq;
    reader.Read(2);
  end
  else if reader.Current = '>' then
  begin
    AOperator := TFilterOperator.foGreater;
    reader.Read;
  end
  else if reader.Current = '<' then
  begin
    AOperator := TFilterOperator.foLess;
    reader.Read;
  end
  else
  begin
    AOperator := TFilterOperator.foEquals;
    result := False;
  end;
end;

class function TYAMLPathProcessor.CompileRegex(const APattern : string; const AOptions : TRegExOptions) : TRegEx;
begin
  // =~ matches the whole value, as Jayway JsonPath does: \A and \z anchor the pattern
  try
    result := TRegEx.Create('\A(?:' + APattern + ')\z', AOptions);
    result.IsMatch(''); // XE2 compiles the pattern on first use - an invalid one raises here
  except
    on E : Exception do
      raise EYAMLPathError.CreateFmt(RS_YAML_PATH_INVALID_REGEX, [E.Message]);
  end;
end;

class function TYAMLPathProcessor.ParseRegexLiteral(const reader : IInputReader) : TRegEx;
var
  pattern : string;
  options : TRegExOptions;
begin
  // /pattern/flags - a \ keeps the character after it in the pattern (so \/ is a /)
  Assert(reader.Current = '/');
  reader.Read;
  pattern := '';
  while (reader.Current <> '/') do
  begin
    if reader.Current = #0 then
      raise EYAMLPathError.CreateFmt(RS_YAML_PATH_INVALID_REGEX, ['missing the closing /']);
    if (reader.Current = '\') and (reader.Peek = '/') then
    begin
      pattern := pattern + '/';
      reader.Read(2);
      continue;
    end;
    if reader.Current = '\' then
    begin
      pattern := pattern + '\';
      reader.Read;
      if reader.Current = #0 then
        raise EYAMLPathError.CreateFmt(RS_YAML_PATH_INVALID_REGEX, ['missing the closing /']);
    end;
    pattern := pattern + reader.Current;
    reader.Read;
  end;
  reader.Read; // the closing /

  options := [];
  while CharInSet(reader.Current, ['a'..'z']) do
  begin
    case reader.Current of
      'i' : Include(options, roIgnoreCase);
      'm' : Include(options, roMultiLine);
      's' : Include(options, roSingleLine);
      'x' : Include(options, roIgnorePatternSpace);
    else
      raise EYAMLPathError.CreateFmt(RS_YAML_PATH_INVALID_REGEX, ['unknown flag "' + reader.Current + '"']);
    end;
    reader.Read;
  end;
  result := CompileRegex(pattern, options);
end;

function TYAMLPathProcessor.ParseListLiteral(const reader : IInputReader) : IYAMLSequence;
var
  list : TYAMLSequence;
  item : TFilterOperand;
begin
  // [literal, literal, ...] - strings, numbers, true, false and null
  Assert(reader.Current = '[');
  reader.Read;
  list := TYAMLSequence.Create(nil, '');
  result := list;
  SkipWhitespace(reader);
  if reader.Current = ']' then
  begin
    reader.Read;
    exit;
  end;
  while true do
  begin
    item := ParseOperand(reader);
    if item.OperandType <> TFilterOperandType.fotLiteral then
      raise EYAMLPathError.Create(RS_YAML_PATH_INVALID_OPERAND);
    list.AddItem(ResolveOperand(item, TFilterContext.Create(nil, nil)));
    SkipWhitespace(reader);
    if reader.Current = ']' then
    begin
      reader.Read;
      break;
    end;
    if reader.Current <> ',' then
      raise EYAMLPathError.Create(RS_YAML_PATH_INVALID_OPERAND);
    reader.Read;
  end;
end;

function TYAMLPathProcessor.ParseOperand(const reader : IInputReader) : TFilterOperand;
var
  value : string;
  quoteChar : Char;
  int64Value : Int64;
begin
  SkipWhitespace(reader);

  // Additional safety check
  if reader.Current = #0 then
    raise EYAMLPathError.Create(RS_YAML_PATH_INVALID_OPERAND);

  result.OperandType := TFilterOperandType.fotCurrentItem;
  result.LiteralKind := TFilterLiteralKind.flkString;
  result.NumericText := '';
  result.ListValue := nil;
  result.StringValue := '';
  result.NumericValue := 0;
  result.BoolValue := False;
  result.Path := '';
  result.IsTruthinessCheck := False;
  result.IsNumericLiteral := False;
  
  if (reader.Current = '@') then
  begin
    // Current item reference
    reader.Read;
    if (reader.Current = '.') or (reader.Current = '[') then
    begin
      // Property path like @.price or @[0]
      result.OperandType := TFilterOperandType.fotPath;
      // Read property path
      while (reader.Current <> #0) and (reader.Current <> ' ') and (reader.Current <> ')') and
            (reader.Current <> '&') and (reader.Current <> '|') and (reader.Current <> '=') and
            (reader.Current <> '!') and (reader.Current <> '<') and (reader.Current <> '>') do
      begin
        result.Path := result.Path + reader.Current;
        reader.Read;
      end;
    end
    else
    begin
      // Just @ (current item)
      result.OperandType := TFilterOperandType.fotCurrentItem;
    end;
  end
  else if (reader.Current = '$') then
  begin
    // Root reference
    reader.Read;
    result.OperandType := TFilterOperandType.fotRootItem;
    if (reader.Current = '.') or (reader.Current = '[') then
    begin
      // Property path like $.store or $[0]
      result.OperandType := TFilterOperandType.fotPath;
      result.Path := '$';

      while (reader.Current <> #0) and (reader.Current <> ' ') and (reader.Current <> ')') and
            (reader.Current <> '&') and (reader.Current <> '|') and (reader.Current <> '=') and
            (reader.Current <> '!') and (reader.Current <> '<') and (reader.Current <> '>') do
      begin
        value := value + reader.Current;
        reader.Read;
      end;
      result.Path := result.Path + value;
    end;
  end
  else if IsQuote(reader.Current) then
  begin
    // String literal, up to the quote it started with (so "it's" keeps its ')
    result.OperandType := TFilterOperandType.fotLiteral;
    result.LiteralKind := TFilterLiteralKind.flkString;
    result.IsNumericLiteral := False;
    quoteChar := reader.Current;
    reader.Read; // Skip opening quote
    while (reader.Current <> #0) and (reader.Current <> quoteChar) do
    begin
      result.StringValue := result.StringValue + reader.Current;
      reader.Read;
    end;
    if (reader.Current = #0) then
      raise EYAMLPathError.Create(RS_YAML_PATH_QUOTE_EXPECTED);
    reader.Read; // Skip closing quote
  end
  else if ((reader.Current >= '0') and (reader.Current <= '9')) or (reader.Current = '-') then
  begin
    // Numeric literal, with its sign
    result.OperandType := TFilterOperandType.fotLiteral;
    result.LiteralKind := TFilterLiteralKind.flkNumber;
    result.IsNumericLiteral := True;
    value := reader.Current;
    reader.Read;
    while ((reader.Current >= '0') and (reader.Current <= '9')) or (reader.Current = '.') or
          (reader.Current = 'e') or (reader.Current = 'E') or (reader.Current = '+') or (reader.Current = '-') do
    begin
      value := value + reader.Current;
      reader.Read;
    end;

    // an integer unless it has a fraction or an exponent, as in YAML and JSON
    if (Pos('.', value) = 0) and (Pos('e', value) = 0) and (Pos('E', value) = 0) then
    begin
      if not TryStrToInt64(value, int64Value) then
        raise EYAMLPathError.Create(RS_YAML_PATH_INVALID_OPERAND);
      result.NumericValue := int64Value;
    end
    else if not TryStrToFloat(value, result.NumericValue, YAMLFormatSettings) then
      raise EYAMLPathError.Create(RS_YAML_PATH_INVALID_OPERAND);
    result.NumericText := value;
  end
  else if reader.Current = '[' then
  begin
    // a list of literals, for in and nin
    result.OperandType := TFilterOperandType.fotList;
    result.ListValue := ParseListLiteral(reader);
  end
  else if CharInSet(reader.Current, ['a'..'z', 'A'..'Z', '_']) then
  begin
    // true, false and null; any other word is a string, as 'word' is
    result.OperandType := TFilterOperandType.fotLiteral;
    result.IsNumericLiteral := False;
    while TYAMLCharUtils.IsAlphaNumeric(reader.Current) or (reader.Current = '_') do
    begin
      value := value + reader.Current;
      reader.Read;
    end;
    if SameText(value, 'true') or SameText(value, 'false') then
    begin
      result.LiteralKind := TFilterLiteralKind.flkBoolean;
      result.BoolValue := SameText(value, 'true');
    end
    else if SameText(value, 'null') then
      result.LiteralKind := TFilterLiteralKind.flkNull
    else
    begin
      result.LiteralKind := TFilterLiteralKind.flkString;
      result.StringValue := value;
    end;
  end
  else
    raise EYAMLPathError.Create(RS_YAML_PATH_INVALID_OPERAND);
end;

function TYAMLPathProcessor.ParseFilterOperator(const reader : IInputReader) : TFilterOperator;
var
  value : string;
begin
  SkipWhitespace(reader);

  if (reader.Current = '=') and (reader.Peek = '=') then
  begin
    result := TFilterOperator.foEquals;
    reader.Read(2);
  end
  else if (reader.Current = '!') and (reader.Peek = '=') then
  begin
    result := TFilterOperator.foNotEquals;
    reader.Read(2);
  end
  else if (reader.Current = '>') and (reader.Peek = '=') then
  begin
    result := TFilterOperator.foGreaterEq;
    reader.Read(2);
  end
  else if (reader.Current = '<') and (reader.Peek = '=') then
  begin
    result := TFilterOperator.foLessEq;
    reader.Read(2);
  end
  else if (reader.Current = '>') then
  begin
    result := TFilterOperator.foGreater;
    reader.Read;
  end
  else if (reader.Current = '<') then
  begin
    result := TFilterOperator.foLess;
    reader.Read;
  end
  else if (reader.Current = '=') and (reader.Peek = '~') then
  begin
    result := TFilterOperator.foRegexMatch;
    reader.Read(2);
  end
  else
  begin
    // a word operator ends at the first character that is not a letter, so 'size>5' and
    // "in['a']" read as size and in
    while CharInSet(reader.Current, ['a'..'z', 'A'..'Z']) do
    begin
      value := value + reader.Current;
      reader.Read;
    end;
    if SameText(value, 'in') then
      result := TFilterOperator.foIn
    else if SameText(value, 'nin') then
      result := TFilterOperator.foNotIn
    else if SameText(value, 'contains') then
      result := TFilterOperator.foContains
    else if SameText(value, 'size') then
      result := TFilterOperator.foSize
    else if SameText(value, 'empty') then
      result := TFilterOperator.foEmpty
    else
    raise EYAMLPathError.Create(RS_YAML_PATH_INVALID_FILTER_OPERATOR);
  end;

end;

function TYAMLPathProcessor.EvaluateFilterExpression(const Expr : TFilterExpression; const Context : TFilterContext) : Boolean;
begin
  if not Assigned(Expr) then
  begin
    result := False;
    Exit;
  end;
  
  if Expr.IsComparison then
    result := EvaluateComparison(Expr.Comparison, Context)
  else
  begin
    case Expr.LogicalExpr.LogicalOp of
      TFilterLogical.flAnd:
        result := EvaluateFilterExpression(Expr.LogicalExpr.Left, Context) and 
                  EvaluateFilterExpression(Expr.LogicalExpr.Right, Context);
      TFilterLogical.flOr:
        result := EvaluateFilterExpression(Expr.LogicalExpr.Left, Context) or 
                  EvaluateFilterExpression(Expr.LogicalExpr.Right, Context);
      TFilterLogical.flNot:
        result := not EvaluateFilterExpression(Expr.LogicalExpr.Left, Context);
    else
      result := False;
    end;
  end;
end;

function TYAMLPathProcessor.EvaluateComparison(const Comp : TFilterComparison; const Context : TFilterContext) : Boolean;
var
  leftValue, rightValue, sizeValue : IYAMLValue;
  size : integer;
begin
  if not Assigned(Comp) then
  begin
    result := False;
    Exit;
  end;
  
  leftValue := ResolveOperand(Comp.LeftOperand, Context);
  
  // Special case for truthiness checks (when we auto-generated "== true")
  if Comp.RightOperand.IsTruthinessCheck then
  begin
    // This is a truthiness check - evaluate based on YAML value
    if leftValue.IsNull then
      result := False
    else if leftValue.IsBoolean then
      result := leftValue.AsBoolean
    else if leftValue.IsNumeric then
      result := (leftValue.IsInteger and (leftValue.AsInteger <> 0)) or
                (leftValue.IsFloat and (leftValue.AsFloat <> 0.0))
    else if leftValue.IsString then
      result := leftValue.AsString <> ''
    else if leftValue.IsSequence then
      result := leftValue.AsSequence.Count > 0
    else if leftValue.IsMapping then
      result := leftValue.AsMapping.Count > 0
    else
      result := True; // Non-null values are truthy
  end
  else if Comp.Operator = TFilterOperator.foRegexMatch then
  begin
    // the whole of a scalar's text must match; null and collections never do
    if leftValue.IsNull or not leftValue.IsScalar then
      result := False
    else if Comp.HasRegex then
      result := Comp.Regex.IsMatch(leftValue.AsString)
    else
    begin
      // the pattern comes from a path, so it is compiled here
      rightValue := ResolveOperand(Comp.RightOperand, Context);
      result := (not rightValue.IsNull) and rightValue.IsScalar and
                CompileRegex(rightValue.AsString, []).IsMatch(leftValue.AsString);
    end;
  end
  else if Comp.Operator = TFilterOperator.foSize then
  begin
    // the number of items of a collection, or of characters of a scalar's text, compared
    // with the right operand
    if leftValue.IsSequence then
      size := leftValue.AsSequence.Count
    else if leftValue.IsSet then
      size := leftValue.AsSet.Count
    else if leftValue.IsMapping then
      size := leftValue.AsMapping.Count
    else
      size := Length(leftValue.AsString);
    rightValue := ResolveOperand(Comp.RightOperand, Context);
    // held in a variable: a new object passed straight to a const interface parameter is
    // never released
    sizeValue := TYAMLValue.Create(nil, TYAMLValueType.vtInteger, IntToStr(size));
    result := rightValue.IsNumeric and CompareYAMLValues(sizeValue, rightValue, Comp.SizeOperator);
  end
  else
  begin
    // Regular comparison
    rightValue := ResolveOperand(Comp.RightOperand, Context);
    result := CompareYAMLValues(leftValue, rightValue, Comp.Operator);
  end;
end;

function TYAMLPathProcessor.SequenceHas(const collection, value : IYAMLValue) : Boolean;
var
  sequence : IYAMLSequence;
  i : integer;
begin
  result := False;
  if collection.IsSequence then
    sequence := collection.AsSequence
  else if collection.IsSet then
    sequence := collection.AsSet
  else
    exit;
  for i := 0 to sequence.Count - 1 do
  begin
    if CompareYAMLValues(sequence[i], value, TFilterOperator.foEquals) then
      exit(True);
  end;
end;

function TYAMLPathProcessor.ResolveOperand(const Operand : TFilterOperand; const Context : TFilterContext) : IYAMLValue;
var
  pathProcessor : TYAMLPathProcessor;
  matches : IYAMLSequence;
begin
  case Operand.OperandType of
    TFilterOperandType.fotCurrentItem:
      result := Context.CurrentItem;
    TFilterOperandType.fotRootItem:
      result := Context.RootDocument;
    TFilterOperandType.fotLiteral:
      case Operand.LiteralKind of
        TFilterLiteralKind.flkNumber :
          // the number as written, so an integer past what a Double holds stays exact
          if (Pos('.', Operand.NumericText) = 0) and (Pos('e', Operand.NumericText) = 0) and (Pos('E', Operand.NumericText) = 0) then
            result := TYAMLValue.Create(nil, TYAMLValueType.vtInteger, Operand.NumericText)
          else
            result := TYAMLValue.Create(nil, TYAMLValueType.vtFloat, Operand.NumericText);
        TFilterLiteralKind.flkBoolean :
          result := TYAMLValue.Create(nil, TYAMLValueType.vtBoolean, LowerCase(BoolToStr(Operand.BoolValue, True)));
        TFilterLiteralKind.flkNull :
          result := TYAMLValue.Create(nil, TYAMLValueType.vtNull);
      else
        result := TYAMLValue.Create(nil, TYAMLValueType.vtString, Operand.StringValue);
      end;
    TFilterOperandType.fotList:
      result := Operand.ListValue;
    TFilterOperandType.fotPath:
      begin
        // Parse and execute the path expression. A record local does not zero its
        // unmanaged fields, so clear the initialized flag up front - that makes
        // Cleanup a safe no-op if Create below raises before it can run.
        pathProcessor.FInitialized := False;
        try
          try
            if StartsText('$', Operand.Path) then
            begin
              pathProcessor := TYAMLPathProcessor.Create(Operand.Path);
              matches := pathProcessor.Query(Context.RootDocument);
            end
            else if StartsText('.', Operand.Path) or StartsText('[', Operand.Path) then
            begin
              // For paths like .rating or [0], we need to access property of current item
              pathProcessor := TYAMLPathProcessor.Create('$' + Operand.Path);
              matches := pathProcessor.Query(Context.CurrentItem);
            end
            else
            begin
              // For other paths, assume they're relative to current item
              pathProcessor := TYAMLPathProcessor.Create('$.' + Operand.Path);
              matches := pathProcessor.Query(Context.CurrentItem);
            end;

            if matches.Count > 0 then
              result := matches[0]
            else
              result := TYAMLValue.Create(nil, TYAMLValueType.vtNull);
          except
            result := TYAMLValue.Create(nil, TYAMLValueType.vtNull);
          end;
        finally
          pathProcessor.Cleanup;
        end;
      end;
  else
    result := TYAMLValue.Create(nil, TYAMLValueType.vtNull);
  end;
end;

function TYAMLPathProcessor.CompareYAMLValues(const Left, Right : IYAMLValue; const Op : TFilterOperator) : Boolean;
var
  leftStr, rightStr : string;
begin
  result := False;
  
  case Op of
    TFilterOperator.foEquals:
      begin
        if Left.IsNull and Right.IsNull then
          result := True
        else if Left.IsNull or Right.IsNull then
          // null is only equal to null - not to '' (whose text it has)
          result := False
        else if Left.ValueType = Right.ValueType then
        begin
          case Left.ValueType of
            TYAMLValueType.vtString:
              result := Left.AsString = Right.AsString;
            TYAMLValueType.vtInteger:
              result := Left.AsInteger = Right.AsInteger;
            TYAMLValueType.vtFloat:
              result := Abs(Left.AsFloat - Right.AsFloat) < 1E-10;
            TYAMLValueType.vtBoolean:
              result := Left.AsBoolean = Right.AsBoolean;
          end;
        end
        else if Left.IsNumeric and Right.IsNumeric then
        begin
          // Handle mixed numeric types
          if Left.IsInteger and Right.IsFloat then
            result := Abs(Left.AsInteger - Right.AsFloat) < 1E-10
          else if Left.IsFloat and Right.IsInteger then
            result := Abs(Left.AsFloat - Right.AsInteger) < 1E-10
          else
            result := Left.AsString = Right.AsString;
        end
        else
        begin
          // Try string comparison
          result := Left.AsString = Right.AsString;
        end;
      end;
    TFilterOperator.foNotEquals:
      result := not CompareYAMLValues(Left, Right, TFilterOperator.foEquals);
    TFilterOperator.foGreater:
      begin
        if Left.IsNumeric and Right.IsNumeric then
        begin
          if Left.IsInteger and Right.IsInteger then
            result := Left.AsInteger > Right.AsInteger
          else
          begin
            // Handle mixed numeric types by converting both to double
            if Left.IsInteger then
              result := Left.AsInteger > Right.AsFloat
            else if Right.IsInteger then
              result := Left.AsFloat > Right.AsInteger
            else
              result := Left.AsFloat > Right.AsFloat;
          end;
        end
        else
          result := Left.AsString > Right.AsString;
      end;
    TFilterOperator.foGreaterEq:
      result := CompareYAMLValues(Left, Right, TFilterOperator.foGreater) or CompareYAMLValues(Left, Right, TFilterOperator.foEquals);
    TFilterOperator.foLess:
      begin
        if Left.IsNumeric and Right.IsNumeric then
        begin
          if Left.IsInteger and Right.IsInteger then
            result := Left.AsInteger < Right.AsInteger
          else
          begin
            // Handle mixed numeric types by converting both to double
            if Left.IsInteger then
              result := Left.AsInteger < Right.AsFloat
            else if Right.IsInteger then
              result := Left.AsFloat < Right.AsInteger
            else
              result := Left.AsFloat < Right.AsFloat;
          end;
        end
        else
          result := Left.AsString < Right.AsString;
      end;
    TFilterOperator.foLessEq:
      result := CompareYAMLValues(Left, Right, TFilterOperator.foLess) or CompareYAMLValues(Left, Right, TFilterOperator.foEquals);
    TFilterOperator.foContains:
      begin
        // a list contains an item equal to the right operand; text contains it as a substring
        if Left.IsSequence or Left.IsSet then
          result := SequenceHas(Left, Right)
        else if Left.IsMapping then
          result := False
        else
        begin
          leftStr := Left.AsString;
          rightStr := Right.AsString;
          result := Pos(rightStr, leftStr) > 0;
        end;
      end;
    TFilterOperator.foIn:
      // the left operand is equal to an item of the list on the right
      result := SequenceHas(Right, Left);
    TFilterOperator.foNotIn:
      result := not SequenceHas(Right, Left);
    TFilterOperator.foEmpty:
      begin
        if Right.AsBoolean then
        begin
          if Left.IsSequence then
            result := Left.AsSequence.Count = 0
          else if Left.IsMapping then
            result := Left.AsMapping.Count = 0
          else
            result := Left.AsString = '';
        end
        else
        begin
          if Left.IsSequence then
            result := Left.AsSequence.Count > 0
          else if Left.IsMapping then
            result := Left.AsMapping.Count > 0
          else
            result := Left.AsString <> '';
        end;
      end;
    // size and =~ are evaluated by EvaluateComparison
  end;
end;

{ TYAMLPathProcessor.TFilterContext }

class function TYAMLPathProcessor.TFilterContext.Create(const ACurrent, ARoot: IYAMLValue): TFilterContext;
begin
  result.CurrentItem := ACurrent;
  result.RootDocument := ARoot;
end;

{ TYAMLPathProcessor.TFilterComparison }

destructor TYAMLPathProcessor.TFilterComparison.Destroy;
begin
  inherited Destroy;
end;

{ TYAMLPathProcessor.TFilterLogicalExpression }

destructor TYAMLPathProcessor.TFilterLogicalExpression.Destroy;
begin
  if Assigned(Left) then
    Left.Free;
  if Assigned(Right) then
    Right.Free;
  inherited Destroy;
end;

{ TYAMLPathProcessor.TFilterExpression }

destructor TYAMLPathProcessor.TFilterExpression.Destroy;
begin
  if IsComparison and Assigned(Comparison) then
    Comparison.Free
  else if not IsComparison and Assigned(LogicalExpr) then
    LogicalExpr.Free;
  inherited Destroy;
end;

{ TYAMLPathProcessor.TOperator }

procedure TYAMLPathProcessor.TOperator.Init(const AType : TOperatorType);
begin
  OperatorType := AType;
  Next := nil;
  Name := '';
  SetLength(Indices,0);
  // the variant fields overlap, so the pointer goes first and the slice fields after it
  FilterExpression := nil;
  Start := 0;
  Stop := 0;
  Step := 1;
  HasStart := False;
  HasStop := False;
end;

end.

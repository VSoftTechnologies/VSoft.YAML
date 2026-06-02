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
  System.SysUtils;

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
      fotLiteral,        // string, number, boolean
      fotPath            // property path like @.price or $.store.book[0]
    );
    
    TFilterOperand = record
      OperandType: TFilterOperandType;
      StringValue: string;    // For literals and paths
      NumericValue: Double;   // For numeric literals
      BoolValue: Boolean;     // For boolean literals
      Path: string;           // For property paths
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
      Indices : TArray<integer>;          // For IndexList
      case Byte of
        0 : (Index : integer);             // For ChildIndex
        1 : (Start, Stop, Step : integer); // For Slice
        2 : (FilterExpression : TFilterExpression); // For Filter
    end;
  private
    FInitialized : boolean;
    FOperators : TArray<TOperator>;
    FOperatorCount : integer;
    FMatches : IYAMLSequence;
    FMatchCount : integer;
    FSingleMatch : boolean;
    FRootDocument : IYAMLValue;
  private
    class procedure SkipWhitespace(const reader : IInputReader); inline; static;
    class function ParseInteger(const reader : IInputReader; out AValue : integer) : boolean; static;
    class function IsQuote(const ch : Char) : boolean; inline; static;
  private
    procedure AddOperator(const AOperator : TOperator);
    procedure AddMatch(const AMatch : IYAMLValue);
    procedure ParseDotOperator(const reader : IInputReader);
    procedure ParseBracketOperator(const reader : IInputReader);

    function InternalMatch(const root : IYAMLValue; const AMatchSingle : boolean) : IYAMLSequence;
    procedure VisitOperator(const AOp : POperator; const ARoot : IYAMLValue);
    
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
    function EvaluateFilterExpression(const Expr : TFilterExpression; const Context : TFilterContext) : Boolean;
    function EvaluateComparison(const Comp : TFilterComparison; const Context : TFilterContext) : Boolean;
    function ResolveOperand(const Operand : TFilterOperand; const Context : TFilterContext) : IYAMLValue;
    function CompareYAMLValues(const Left, Right : IYAMLValue; const Op : TFilterOperator) : Boolean;
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

implementation

uses
  System.Character,
  System.Classes,
  System.StrUtils,
  VSoft.YAML.Classes;

{ TYAMLPathProcessor }

procedure TYAMLPathProcessor.AddMatch(const AMatch : IYAMLValue);
begin
  FMatches.AddValue(AMatch);
  Inc(FMatchCount);
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
  FMatches := TYAMLSequence.Create(root, '');
  FMatchCount := 0;
  FSingleMatch := AMatchSingle;
  FRootDocument := root;

  if (FOperatorCount = 0) then
  begin
    // Root-only access ($) - return the root node itself
    AddMatch(root);
    result := FMatches;
    exit;
  end;

  VisitOperator(@FOperators[0], root);

  result := FMatches;
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

    SkipWhitespace(reader);
    if (reader.Current <> ')') then
      raise EYAMLPathError.Create(RS_YAML_PATH_MISSING_FILTER_PARENTHESIS);
    reader.Read;

    SkipWhitespace(reader);
    if (reader.Current <> ']') then
      raise EYAMLPathError.Create(RS_YAML_PATH_MISSING_CLOSE_BRACKET);

    AddOperator(op);
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
        // [index]
        if (index < 0) then
          raise EYAMLPathError.Create(RS_YAML_PATH_NEGATIVE_ARRAY_INDEX);
        op.Init(TOperatorType.ChildIndex);
        op.Index := index;
      end
      else if (reader.Current = ',') then
      begin
        // [index, index, ...]
        if (index < 0) then
          raise EYAMLPathError.Create(RS_YAML_PATH_NEGATIVE_ARRAY_INDEX);
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

          if (index < 0) then
            raise EYAMLPathError.Create(RS_YAML_PATH_NEGATIVE_ARRAY_INDEX);
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
  startPos : integer;
  op : TOperator;
  name : string;
begin
  // Initial '.' has already been parsed
  Assert(reader.Current = '.');
  reader.Read;

  case reader.Current of
    '.' :
    begin
      // ..
      op.Init(TOperatorType.RecursiveDescent);
      AddOperator(op);
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
    startPos := reader.Position;
    // Scan for start of next operator
    repeat
    begin
      name := name + reader.Current;
      reader.Read;
    end
    until (CharInSet(reader.Current, [#0, '.', '[', '$']));

    if (reader.Position = startPos) then
      raise EYAMLPathError.Create(RS_YAML_PATH_MISSING_MEMBER_NAME);

    op.Init(TOperatorType.ChildName);
    op.Name := name;
    AddOperator(op);
  end;

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


procedure TYAMLPathProcessor.VisitOperator(const AOp : POperator; const ARoot : IYAMLValue);
var
  index, arrayIndex, startIndex, stopIndex, stepValue : integer;
  value : IYAMLValue;
  name : string;
  nextOp : POperator;
  sequence : IYAMLSequence;
  mapping : IYAMLMapping;
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
        begin
          if (AOp.Next = nil) then
            AddMatch(value)
          else
            VisitOperator(AOp.Next, value);
        end;
      end;

    TOperatorType.ChildIndex :
      if ARoot.IsSequence then
      begin
        sequence := ARoot.AsSequence;
        if (AOp.Index < sequence.Count) then
        begin
          Assert(AOp.Index >= 0);
          value := sequence.Items[AOp.Index];
          if (AOp.Next = nil) then
            AddMatch(value)
          else
            VisitOperator(AOp.Next, value);
        end;
      end;

    TOperatorType.RecursiveDescent :
      begin
        nextOp := AOp.Next;
        Assert(Assigned(nextOp));
        if ARoot.IsSequence then
        begin
          sequence := ARoot.AsSequence;
          for index := 0 to sequence.Count - 1 do
          begin
            if (nextOp.OperatorType = TOperatorType.ChildIndex)
              and (nextOp.Index = index)
            then
              VisitOperator(nextOp, ARoot)
            else
              VisitOperator(AOp, sequence.Items[index]);
          end;
        end;

        if ARoot.IsMapping then
        begin
          mapping := ARoot.AsMapping;
          for index := 0 to mapping.Count - 1 do
          begin
            name := mapping.Keys[index];
            if(nextOp.OperatorType = TOperatorType.ChildName) and (nextOp.Name = name) then
              VisitOperator(nextOp, ARoot)
            else
              VisitOperator(AOp, mapping.Values[name] );
          end;
        end;
      end;

    TOperatorType.Wildcard :
      case ARoot.ValueType of
        TYAMLValueType.vtSequence :
          begin
            sequence := ARoot.AsSequence;
            for index := 0 to sequence.Count - 1 do
            begin
              value := sequence.Items[index];
              if (AOp.Next = nil) then
                AddMatch(value)
              else
                VisitOperator(AOp.Next, value);
            end;
          end;

        TYAMLValueType.vtMapping :
          begin
            mapping := ARoot.AsMapping;
            for index := 0 to mapping.Count - 1 do
            begin
              name := mapping.Keys[index];
              value := mapping.Values[name];
              if (AOp.Next = nil) then
                AddMatch(value)
              else
                VisitOperator(AOp.Next, value);
            end;
          end;
      end;

    TOperatorType.IndexList :
      if ARoot.IsSequence then
      begin
        sequence := ARoot.AsSequence;
        for index := 0 to Length(AOp.Indices) - 1 do
        begin
          arrayIndex := AOp.Indices[index];
          Assert(arrayIndex >= 0);
          if (arrayIndex < sequence.Count) then
          begin
            value := sequence.Items[arrayIndex];
            if (AOp.Next = nil) then
              AddMatch(value)
            else
              VisitOperator(AOp.Next, value);
          end;
        end;
      end;

    TOperatorType.Slice :
      if ARoot.IsSequence then
      begin
        sequence := ARoot.AsSequence;
        
        // DEBUG: Log the parsing values
        // For [7:] we expect: Start=7, Stop=-1, Step=1
        
        if (AOp.Start < 0) then
        begin
          startIndex := sequence.Count + AOp.Start;
          if (AOp.Stop = -1) then
            stopIndex := sequence.Count
          else
            stopIndex := sequence.Count + AOp.Stop;
        end
        else
        begin
          startIndex := AOp.Start;
          stopIndex := AOp.Stop;
          // If Stop was not set (should be -1 for unbounded), set it to sequence length
          if (stopIndex = -1) or (stopIndex <= startIndex) then
            stopIndex := sequence.Count;
        end;

        if (stopIndex > sequence.Count) then
          stopIndex := sequence.Count;
        if (startIndex < 0) then
          startIndex := 0;

        index := startIndex;
        stepValue := AOp.Step;
        if (stepValue <= 0) then
          stepValue := 1;
        
        
        while (index < stopIndex) and (index < sequence.Count) do
        begin
          value := sequence.Items[index];
          if (AOp.Next = nil) then
            AddMatch(value)
          else
            VisitOperator(AOp.Next, value);

          Inc(index, stepValue);
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
            begin
              if (AOp.Next = nil) then
                AddMatch(value)
              else
                VisitOperator(AOp.Next, value);
            end;
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
            begin
              if (AOp.Next = nil) then
                AddMatch(value)
              else
                VisitOperator(AOp.Next, value);
            end;
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
    right := ParseOrExpression(reader); // Right-associative OR
    
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
    right := ParseAndExpression(reader); // Right-associative AND
    
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
begin
  SkipWhitespace(reader);
  
  if (reader.Current = '!') then
  begin
    reader.Read;
    SkipWhitespace(reader);
    result := TFilterExpression.Create;
    result.IsComparison := False;
    logicalExpr := TFilterLogicalExpression.Create;
    logicalExpr.LogicalOp := TFilterLogical.flNot;
    logicalExpr.Left := ParseNotExpression(reader);
    logicalExpr.Right := nil;
    result.LogicalExpr := logicalExpr;
  end
  else
    result := ParsePrimaryExpression(reader);

end;

function TYAMLPathProcessor.ParsePrimaryExpression(const reader : IInputReader) : TFilterExpression;
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
      raise EYAMLPathError.Create(RS_YAML_PATH_MISSING_FILTER_PARENTHESIS);
    reader.Read; // Skip ')'
  end
  else
  begin
    // Handle comparison expression
    result := TFilterExpression.Create;
    result.IsComparison := True;
    result.Comparison := ParseComparisonExpression(reader);
  end;
end;

function TYAMLPathProcessor.ParseComparisonExpression(const reader : IInputReader) : TFilterComparison;
begin
  result := TFilterComparison.Create;

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
      result.RightOperand.StringValue := '';
      result.RightOperand.NumericValue := 0;
      result.RightOperand.BoolValue := True;
      result.RightOperand.Path := '';
      result.RightOperand.IsTruthinessCheck := False;
      result.RightOperand.IsNumericLiteral := False;
    end
    else
    begin
      result.RightOperand := ParseOperand(reader);
    end;
  end;
end;

function TYAMLPathProcessor.ParseOperand(const reader : IInputReader) : TFilterOperand;
var
  value : string;
begin
  SkipWhitespace(reader);
  
  // Additional safety check
  if reader.Current = #0 then
    raise EYAMLPathError.Create(RS_YAML_PATH_INVALID_OPERAND);
  
  result.OperandType := TFilterOperandType.fotCurrentItem;
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
    if (reader.Current = '.') then
    begin
      // Property path like @.price
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
    if (reader.Current = '.') then
    begin
      // Property path like $.store
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
    // String literal
    result.OperandType := TFilterOperandType.fotLiteral;
    result.IsNumericLiteral := False;
    reader.Read; // Skip opening quote
    while (reader.Current <> #0) and not IsQuote(reader.Current) do
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
    // Numeric literal
    result.OperandType := TFilterOperandType.fotLiteral;
    result.IsNumericLiteral := True;
    // Read the numeric value as string first
    if (reader.Current = '-') then
      reader.Read;
    while ((reader.Current >= '0') and (reader.Current <= '9')) or (reader.Current = '.') or
          (reader.Current = 'e') or (reader.Current = 'E') or (reader.Current = '+') or (reader.Current = '-') do
    begin
      value := value + reader.Current;
      reader.Read;
    end;

    // Try to parse as integer first, then as float
    try
      if Pos('.', value) = 0 then
      begin
        // No decimal point, try integer
        result.NumericValue := StrToInt64(value);
      end
      else
      begin
        // Has decimal point, parse as float
        result.NumericValue := StrToFloat(value, YAMLFormatSettings);
      end;
    except
      raise EYAMLPathError.Create(RS_YAML_PATH_INVALID_OPERAND);
    end;
  end
  else if (reader.Current = 't') or (reader.Current = 'f') or (reader.Current = 'T') or (reader.Current = 'F') then
  begin
    // Boolean literal
    result.OperandType := TFilterOperandType.fotLiteral;
    result.IsNumericLiteral := False;

    while (not CharInSet(reader.Current, [#0, #9, ' ', ')', ']'])) do
    begin
      value := value + reader.Current;
      reader.Read;
    end;
    if SameText(value, 'true') then
      result.BoolValue := true
    else if SameText(value, 'false') then
      result.BoolValue := false
    else
      raise EYAMLPathError.Create(RS_YAML_PATH_INVALID_OPERAND);
  end
  else
  begin
    // Fallback - try to parse as a simple identifier or skip unknown characters
    if ((reader.Current >= 'a') and (reader.Current <= 'z')) or ((reader.Current >= 'A') and (reader.Current <= 'Z')) or (reader.Current = '_') then
    begin
      // Try to parse as identifier and treat as string literal
      result.OperandType := TFilterOperandType.fotLiteral;
      result.IsNumericLiteral := False;
      While TYAMLCharUtils.IsAlphaNumeric(reader.Current) do
      begin
        result.StringValue := result.StringValue + reader.Current;
        reader.Read;
      end;
    end
    else
      raise EYAMLPathError.Create(RS_YAML_PATH_INVALID_OPERAND);
  end;
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
    while (not CharInSet(reader.Current,[#0, #9, ']', ')', ' ']))  do
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
  leftValue, rightValue : IYAMLValue;
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
  else
  begin
    // Regular comparison
    rightValue := ResolveOperand(Comp.RightOperand, Context);
    result := CompareYAMLValues(leftValue, rightValue, Comp.Operator);
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
      begin
        if Operand.StringValue <> '' then
          result := TYAMLValue.Create(nil, TYAMLValueType.vtString, Operand.StringValue)
        else if Operand.IsNumericLiteral then
        begin
          if Frac(Operand.NumericValue) = 0 then
            result := TYAMLValue.Create(nil, TYAMLValueType.vtInteger, IntToStr(Trunc(Operand.NumericValue)))
          else
            result := TYAMLValue.Create(nil, TYAMLValueType.vtFloat, YAMLFloatToStr(Operand.NumericValue));
        end
        else
          result := TYAMLValue.Create(nil, TYAMLValueType.vtBoolean, BoolToStr(Operand.BoolValue, True));
      end;
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
            else if StartsText('.', Operand.Path) then
            begin
              // For paths like .rating, we need to access property of current item
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
        leftStr := Left.AsString;
        rightStr := Right.AsString;
        result := Pos(rightStr, leftStr) > 0;
      end;
    TFilterOperator.foSize:
      begin
        if Left.IsSequence then
          result := Left.AsSequence.Count = Right.AsInteger
        else if Left.IsMapping then
          result := Left.AsMapping.Count = Right.AsInteger
        else
          result := Length(Left.AsString) = Right.AsInteger;
      end;
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
    // TODO: Implement TFilterOperator.foRegexMatch, TFilterOperator.foIn, TFilterOperator.foNotIn if needed
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
  Start := 0;
  Stop := -1; // -1 indicates "not set", should use sequence length
  Step := 1;
  FilterExpression := nil;
end;

end.

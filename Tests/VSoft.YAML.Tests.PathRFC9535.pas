unit VSoft.YAML.Tests.PathRFC9535;

// JSONPath as RFC 9535 defines it: the descendant segment (..) followed by any selector,
// array slices with negative bounds and steps, and the filter operators the documentation
// lists (=~, in, nin, size, contains, empty) with string, number, boolean, null and list
// literals.

interface

uses
  DUnitX.TestFramework,
  VSoft.YAML;

type
  [TestFixture]
  TYAMLPathRFC9535Tests = class
  private
    FDoc : IYAMLDocument;
    FItems : IYAMLDocument;
    function Values(const doc : IYAMLDocument; const expression : string) : string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    // descendant segment
    [Test]
    [TestCase('name', '$..j#1,4', '#')]
    [TestCase('index', '$..[0]#5,{j:4}', '#')]
    [TestCase('wildcard', '$..*#{j:1,k:2},[5,3,[{j:4},{k:6}]],1,2,5,3,[{j:4},{k:6}],{j:4},{k:6},4,6', '#')]
    [TestCase('bracketWildcard', '$..[*]#{j:1,k:2},[5,3,[{j:4},{k:6}]],1,2,5,3,[{j:4},{k:6}],{j:4},{k:6},4,6', '#')]
    [TestCase('member', '$..o#{j:1,k:2}', '#')]
    [TestCase('bracketName', '$..[''k'']#2,6', '#')]
    [TestCase('union', '$.a..[0,1]#5,3,{j:4},{k:6}', '#')]
    [TestCase('negative', '$..[-1]#[{j:4},{k:6}],{k:6}', '#')]
    [TestCase('slice', '$.a..[1:]#3,[{j:4},{k:6}],{k:6}', '#')]
    [TestCase('filter', '$..[?(@.j)]#{j:1,k:2},{j:4}', '#')]
    [TestCase('nothing', '$..zz#(none)', '#')]
    procedure Descendant_RFCExamples(const expression, expected : string);
    [Test]
    procedure Descendant_NodeBeforeItsDescendants;
    [Test]
    procedure Descendant_LooksInsideAMatch;
    [Test]
    procedure Descendant_Paths;
    [Test]
    procedure Descendant_InvalidRaises;

    // slices
    [Test]
    [TestCase('range', '$[1:3]#b,c', '#')]
    [TestCase('toEnd', '$[5:]#f,g', '#')]
    [TestCase('step', '$[1:5:2]#b,d', '#')]
    [TestCase('negativeStep', '$[5:1:-2]#f,d', '#')]
    [TestCase('reverse', '$[::-1]#g,f,e,d,c,b,a', '#')]
    [TestCase('negativeEnd', '$[0:-1]#a,b,c,d,e,f', '#')]
    [TestCase('negativeStart', '$[-2:]#f,g', '#')]
    [TestCase('negativeBoth', '$[-4:-2]#d,e', '#')]
    [TestCase('toNegative', '$[:-5]#a,b', '#')]
    [TestCase('backwards', '$[3:1]#(none)', '#')]
    [TestCase('zeroStep', '$[::0]#(none)', '#')]
    [TestCase('clamped', '$[-10:2]#a,b', '#')]
    [TestCase('pastEnd', '$[2:100:2]#c,e,g', '#')]
    [TestCase('reverseFrom', '$[2::-1]#c,b,a', '#')]
    [TestCase('reverseTo', '$[:4:-1]#g,f', '#')]
    [TestCase('all', '$[:]#a,b,c,d,e,f,g', '#')]
    procedure Slice_RFCExamples(const expression, expected : string);
    [Test]
    procedure Slice_ReversePaths;
    [Test]
    procedure Slice_EmptySequence;

    // filters
    [Test]
    [TestCase('wholeValue', '$[?(@.name =~ /app/)]#(none)', '#')]
    [TestCase('pattern', '$[?(@.name =~ /app.*/)]#apple', '#')]
    [TestCase('ignoreCase', '$[?(@.name =~ /APPLE/i)]#apple', '#')]
    [TestCase('stringPattern', '$[?(@.name =~ ''p.*'')]#pear,plum', '#')]
    [TestCase('alternatives', '$[?(@.name =~ /pear|plum/)]#pear,plum', '#')]
    [TestCase('escapedSlash', '$[?(@.path =~ /a\/b/)]#apple', '#')]
    [TestCase('number', '$[?(@.n =~ /1\d/)]#plum', '#')]
    [TestCase('nullNeverMatches', '$[?(@.missing =~ /.*/)]#(none)', '#')]
    procedure Regex_MatchesWholeValue(const expression, expected : string);
    [Test]
    procedure Regex_InvalidRaises;
    [Test]
    [TestCase('in', '$[?(@.name in [''apple'', ''plum''])]#apple,plum', '#')]
    [TestCase('nin', '$[?(@.name nin [''apple'', ''plum''])]#pear,kiwi', '#')]
    [TestCase('numbers', '$[?(@.n in [1, 15])]#apple,plum', '#')]
    [TestCase('null', '$[?(@.colour in [null, ''red''])]#apple,kiwi', '#')]
    [TestCase('noSpace', '$[?(@.name in[''pear''])]#pear', '#')]
    [TestCase('emptyList', '$[?(@.name in [])]#(none)', '#')]
    [TestCase('notAList', '$[?(@.name in ''apple'')]#(none)', '#')]
    [TestCase('ninNotAList', '$[?(@.name nin ''apple'')]#apple,pear,plum,kiwi', '#')]
    [TestCase('rootPath', '$[?(@.colour in $[0].allowed)]#apple', '#')]
    procedure In_AndNin(const expression, expected : string);
    [Test]
    [TestCase('equals', '$[?(@.tags size 2)]#apple', '#')]
    [TestCase('greater', '$[?(@.tags size > 1)]#apple,pear', '#')]
    [TestCase('greaterNoSpace', '$[?(@.tags size>1)]#apple,pear', '#')]
    [TestCase('atLeast', '$[?(@.tags size >= 3)]#pear', '#')]
    [TestCase('less', '$[?(@.tags size < 1)]#plum,kiwi', '#')]
    [TestCase('notEquals', '$[?(@.tags size != 0)]#apple,pear', '#')]
    [TestCase('explicitEquals', '$[?(@.tags size == 3)]#pear', '#')]
    [TestCase('textLength', '$[?(@.name size 4)]#pear,plum,kiwi', '#')]
    procedure Size_Compares(const expression, expected : string);
    [Test]
    [TestCase('listItem', '$[?(@.tags contains ''red'')]#apple,pear', '#')]
    [TestCase('substring', '$[?(@.name contains ''pp'')]#apple', '#')]
    [TestCase('number', '$[?(@.tags contains 3)]#pear', '#')]
    procedure Contains_ListsAndText(const expression, expected : string);
    [Test]
    [TestCase('nullEquals', '$[?(@.colour == null)]#kiwi', '#')]
    [TestCase('nullNotEquals', '$[?(@.colour != null)]#apple,pear,plum', '#')]
    [TestCase('negativeNumber', '$[?(@.n > -5)]#apple,pear,plum', '#')]
    [TestCase('exponent', '$[?(@.n < 1e1)]#apple,pear,kiwi', '#')]
    [TestCase('emptyString', '$[?(@.note == '''')]#pear', '#')]
    [TestCase('quoteInString', '$[?(@.note == "it''s")]#plum', '#')]
    [TestCase('bareWord', '$[?(@.colour == green)]#pear', '#')]
    [TestCase('bareWordStartingWithF', '$[?(@.owner == fred)]#plum', '#')]
    [TestCase('booleanAnyCase', '$[?(@.ripe == TRUE)]#apple', '#')]
    procedure Literals(const expression, expected : string);
    [Test]
    procedure Filter_BracketPaths;
    [Test]
    procedure DocumentationExamples;
  end;

implementation

uses
  System.SysUtils;

// a test case's expected matches: (none) is no match (a test case value cannot be empty)
function Expect(const value : string) : string;
begin
  if value = '(none)' then
    result := ''
  else
    result := value;
end;

// the matches as compact JSON without quotes, joined with commas
function Compact(const value : IYAMLValue) : string;
var
  options : IYAMLEmitOptions;
begin
  if value.IsScalar then
    exit(value.AsString);
  options := TYAML.CreateWriterOptions;
  options.PrettyPrint := false;
  result := StringReplace(TYAML.WriteToJSONString(value, options), '"', '', [rfReplaceAll]);
end;

function TYAMLPathRFC9535Tests.Values(const doc : IYAMLDocument; const expression : string) : string;
var
  matches : IYAMLSequence;
  i : integer;
  item : IYAMLValue;
begin
  result := '';
  matches := doc.Query(expression);
  for i := 0 to matches.Count - 1 do
  begin
    if i > 0 then
      result := result + ',';
    item := matches[i];
    // the fruit filters give the item's name
    if item.IsMapping and item.AsMapping.ContainsKey('name') then
      result := result + item.AsMapping.S['name']
    else
      result := result + Compact(item);
  end;
end;

procedure TYAMLPathRFC9535Tests.Setup;
begin
  // the document of the descendant segment examples in RFC 9535 2.5.2.3
  FDoc := TYAML.LoadFromString('{"o": {"j": 1, "k": 2}, "a": [5, 3, [{"j": 4}, {"k": 6}]]}');
  FItems := TYAML.LoadFromString(
    '- name: apple' + sLineBreak +
    '  path: a/b' + sLineBreak +
    '  n: 1' + sLineBreak +
    '  colour: red' + sLineBreak +
    '  tags: [red, sweet]' + sLineBreak +
    '  ripe: true' + sLineBreak +
    '  allowed: [red, yellow]' + sLineBreak +
    '- name: pear' + sLineBreak +
    '  n: 3' + sLineBreak +
    '  colour: green' + sLineBreak +
    '  tags: [red, 3, soft]' + sLineBreak +
    '  note: ''''' + sLineBreak +
    '- name: plum' + sLineBreak +
    '  n: 15' + sLineBreak +
    '  colour: purple' + sLineBreak +
    '  tags: []' + sLineBreak +
    '  note: it''s' + sLineBreak +
    '  owner: fred' + sLineBreak +
    '- name: kiwi' + sLineBreak +
    '  n: -10' + sLineBreak +
    '  colour: ~');
end;

procedure TYAMLPathRFC9535Tests.TearDown;
begin
  FDoc := nil;
  FItems := nil;
end;

{ descendant segment }

procedure TYAMLPathRFC9535Tests.Descendant_RFCExamples(const expression, expected : string);
begin
  Assert.AreEqual(Expect(expected), Values(FDoc, expression), expression);
end;

procedure TYAMLPathRFC9535Tests.Descendant_NodeBeforeItsDescendants;
var
  doc : IYAMLDocument;
begin
  // the selector runs on a node, then on each of its descendants in document order, so the
  // root's own price comes before the one inside a
  doc := TYAML.LoadFromString('{a: {price: 1}, price: 2, b: [{price: 3}]}');
  Assert.AreEqual('2,1,3', Values(doc, '$..price'));
end;

procedure TYAMLPathRFC9535Tests.Descendant_LooksInsideAMatch;
var
  doc : IYAMLDocument;
begin
  doc := TYAML.LoadFromString('{price: {price: 1}}');
  Assert.AreEqual('{price:1},1', Values(doc, '$..price'));
  doc := TYAML.LoadFromString('[[1, [2, 3]], 4]');
  Assert.AreEqual('[1,[2,3]],1,2', Values(doc, '$..[0]'));
end;

procedure TYAMLPathRFC9535Tests.Descendant_Paths;
var
  matches : TArray<TYAMLPathMatch>;
begin
  matches := FDoc.QueryMatches('$..j');
  Assert.AreEqual(2, Integer(Length(matches)));
  Assert.AreEqual('$[''o''][''j'']', matches[0].Path);
  Assert.AreEqual('$[''a''][2][0][''j'']', matches[1].Path);
  matches := FDoc.QueryMatches('$..[0]');
  Assert.AreEqual('$[''a''][0]', matches[0].Path);
  Assert.AreEqual('$[''a''][2][0]', matches[1].Path);
end;

procedure TYAMLPathRFC9535Tests.Descendant_InvalidRaises;
begin
  Assert.WillRaise(
    procedure
    begin
      FDoc.Query('$..');
    end, EYAMLPathError);
  Assert.WillRaise(
    procedure
    begin
      FDoc.Query('$...a');
    end, EYAMLPathError);
  Assert.WillRaise(
    procedure
    begin
      FDoc.Query('$.a.');
    end, EYAMLPathError);
end;

{ slices }

procedure TYAMLPathRFC9535Tests.Slice_RFCExamples(const expression, expected : string);
var
  doc : IYAMLDocument;
begin
  doc := TYAML.LoadFromString('[a, b, c, d, e, f, g]');
  Assert.AreEqual(Expect(expected), Values(doc, expression), expression);
end;

procedure TYAMLPathRFC9535Tests.Slice_ReversePaths;
var
  doc : IYAMLDocument;
  matches : TArray<TYAMLPathMatch>;
  i : integer;
begin
  doc := TYAML.LoadFromString('[a, b, c]');
  matches := doc.QueryMatches('$[::-1]');
  Assert.AreEqual(3, Integer(Length(matches)));
  for i := 0 to 2 do
  begin
    Assert.AreEqual(2 - i, matches[i].Index);
    Assert.AreEqual('$[' + IntToStr(2 - i) + ']', matches[i].Path);
  end;
end;

procedure TYAMLPathRFC9535Tests.Slice_EmptySequence;
var
  doc : IYAMLDocument;
begin
  doc := TYAML.LoadFromString('[]');
  Assert.AreEqual('', Values(doc, '$[:]'));
  Assert.AreEqual('', Values(doc, '$[::-1]'));
  Assert.AreEqual('', Values(doc, '$[-1:]'));
end;

{ filters }

procedure TYAMLPathRFC9535Tests.Regex_MatchesWholeValue(const expression, expected : string);
begin
  Assert.AreEqual(Expect(expected), Values(FItems, expression), expression);
end;

procedure TYAMLPathRFC9535Tests.Regex_InvalidRaises;
begin
  Assert.WillRaise(
    procedure
    begin
      FItems.Query('$[?(@.name =~ /(/)]');
    end, EYAMLPathError, 'an invalid pattern');
  Assert.WillRaise(
    procedure
    begin
      FItems.Query('$[?(@.name =~ /a/q)]');
    end, EYAMLPathError, 'an unknown flag');
  Assert.WillRaise(
    procedure
    begin
      FItems.Query('$[?(@.name =~ /abc)]');
    end, EYAMLPathError, 'no closing /');
end;

procedure TYAMLPathRFC9535Tests.In_AndNin(const expression, expected : string);
begin
  Assert.AreEqual(Expect(expected), Values(FItems, expression), expression);
end;

procedure TYAMLPathRFC9535Tests.Size_Compares(const expression, expected : string);
begin
  Assert.AreEqual(Expect(expected), Values(FItems, expression), expression);
end;

procedure TYAMLPathRFC9535Tests.Contains_ListsAndText(const expression, expected : string);
begin
  Assert.AreEqual(Expect(expected), Values(FItems, expression), expression);
end;

procedure TYAMLPathRFC9535Tests.Literals(const expression, expected : string);
begin
  Assert.AreEqual(Expect(expected), Values(FItems, expression), expression);
end;

procedure TYAMLPathRFC9535Tests.Filter_BracketPaths;
var
  doc : IYAMLDocument;
begin
  // @[...] and $[...] as well as @. and $.
  doc := TYAML.LoadFromString('[[1, 2], [3, 4], [5, 3]]');
  Assert.AreEqual('[3,4]', Values(doc, '$[?(@[0] == 3)]'));
  Assert.AreEqual('[3,4],[5,3]', Values(doc, '$[?(@[-1] < 5 && @[0] > 1)]'));
  Assert.AreEqual('[5,3]', Values(doc, '$[?(@[1] == $[1][0])]'));
end;

procedure TYAMLPathRFC9535Tests.DocumentationExamples;
var
  doc : IYAMLDocument;
begin
  // the sample document and queries of docs/JSONPath-Syntax.md
  doc := TYAML.LoadFromString(
    'store:' + sLineBreak +
    '  books:' + sLineBreak +
    '    - title: "The Great Gatsby"' + sLineBreak +
    '      price: 12.99' + sLineBreak +
    '      inStock: true' + sLineBreak +
    '      tags: [classic, sale]' + sLineBreak +
    '    - title: "To Kill a Mockingbird"' + sLineBreak +
    '      price: 14.99' + sLineBreak +
    '      inStock: false' + sLineBreak +
    '      tags: [classic]' + sLineBreak +
    '  electronics:' + sLineBreak +
    '    - name: "Laptop"' + sLineBreak +
    '      price: 899.99' + sLineBreak +
    '      inStock: true' + sLineBreak +
    '    - name: "Mouse"' + sLineBreak +
    '      price: 25.50' + sLineBreak +
    '      inStock: true' + sLineBreak +
    'customers:' + sLineBreak +
    '  - name: "John Doe"' + sLineBreak +
    '    active: true' + sLineBreak +
    '    orders:' + sLineBreak +
    '      - id: 1' + sLineBreak +
    '      - id: 2' + sLineBreak +
    '  - name: "Jane Smith"' + sLineBreak +
    '    active: false' + sLineBreak +
    '    orders: []');
  Assert.AreEqual('Laptop', Values(doc, '$.store..*[?(@.price > 100)]'));
  Assert.AreEqual('John Doe', Values(doc, '$.customers[?(@.orders size > 0)].name'));
  Assert.AreEqual('John Doe', Values(doc, '$.customers[?(@.active && @.orders size > 1)].name'));
  Assert.AreEqual('Jane Smith', Values(doc, '$.customers[?(@.orders size 0)].name'));
  Assert.AreEqual('The Great Gatsby', Values(doc, '$.store.books[?(@.tags contains "sale")].title'));
  Assert.AreEqual('Laptop,Mouse', Values(doc, '$.store..[?(@.inStock == true)].name'));
end;

initialization
  TDUnitX.RegisterTestFixture(TYAMLPathRFC9535Tests);

end.

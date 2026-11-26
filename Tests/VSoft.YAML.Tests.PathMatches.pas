unit VSoft.YAML.Tests.PathMatches;

// JSONPath matches with where they are (QueryMatches): the collection a match is in, its key
// or index and its RFC 9535 normalized path. Also negative indexes in index and union
// selectors ($.a[-1], $.a[0,-1]), which count from the end.

interface

uses
  DUnitX.TestFramework,
  VSoft.YAML;

type
  [TestFixture]
  TYAMLPathMatchTests = class
  private
    FDoc : IYAMLDocument;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    // QueryMatches
    [Test]
    procedure Root_HasNoParent;
    [Test]
    procedure Names_GiveParentAndKey;
    [Test]
    procedure Index_GivesParentAndIndex;
    [Test]
    procedure Wildcard_OnMappingAndSequence;
    [Test]
    procedure Slice_GivesEachIndex;
    [Test]
    procedure Filter_OnSequenceAndMapping;
    [Test]
    procedure RecursiveDescent_GivesFullPaths;
    [Test]
    procedure AliasSharedNode_LocationIsWhereTheQueryWent;
    [Test]
    procedure NoMatch_GivesEmptyArray;
    [Test]
    procedure SameOrderAsQuery;
    [Test]
    procedure CompiledProcessor_QueryMatches;
    [Test]
    procedure Collection_PathsStartAtTheCollection;
    [Test]
    procedure Locations_CanEditTheTree;

    // normalized paths
    [Test]
    procedure NormalizedPath_EscapesNames;
    [Test]
    procedure NormalizedPath_OtherCharactersAsTheyAre;

    // negative indexes
    [Test]
    [TestCase('last', '-1,e')]
    [TestCase('middle', '-3,c')]
    [TestCase('first', '-5,a')]
    [TestCase('positive', '1,b')]
    procedure Index_NegativeCountsFromTheEnd(index : integer; const expected : string);
    [Test]
    [TestCase('beforeFirst', '-6')]
    [TestCase('farBefore', '-100')]
    [TestCase('pastEnd', '5')]
    procedure Index_OutOfRange_NoMatch(index : integer);
    [Test]
    procedure Index_EmptySequence_NoMatch;
    [Test]
    procedure Union_MixesPositiveAndNegative;
    [Test]
    procedure Union_OutOfRangeIsSkipped;
    [Test]
    procedure NegativeIndex_ThenChild;
    [Test]
    procedure NegativeIndex_AfterRecursiveDescent;
    [Test]
    procedure NegativeIndex_InFilterPath;
    [Test]
    procedure NegativeIndex_PathIsNormalized;
    [Test]
    procedure NegativeIndex_QuerySingle;
  end;

implementation

uses
  System.SysUtils,
  VSoft.YAML.Path;

const
  BS = '\';

function SameNode(const a, b : IYAMLValue) : boolean;
begin
  result := (a <> nil) and (b <> nil) and ((a as TObject) = (b as TObject));
end;

function PathsOf(const matches : TArray<TYAMLPathMatch>) : string;
var
  i : integer;
begin
  result := '';
  for i := 0 to Length(matches) - 1 do
  begin
    if i > 0 then
      result := result + ' ';
    result := result + matches[i].Path;
  end;
end;

function ValuesOf(const matches : IYAMLSequence) : string;
var
  i : integer;
begin
  result := '';
  for i := 0 to matches.Count - 1 do
  begin
    if i > 0 then
      result := result + ',';
    result := result + matches[i].AsString;
  end;
end;

procedure TYAMLPathMatchTests.Setup;
begin
  FDoc := TYAML.LoadFromString(
    'store:' + sLineBreak +
    '  name: corner shop' + sLineBreak +
    '  book:' + sLineBreak +
    '    - title: A' + sLineBreak +
    '      price: 8' + sLineBreak +
    '    - title: B' + sLineBreak +
    '      price: 12' + sLineBreak +
    '    - title: C' + sLineBreak +
    '      price: 20' + sLineBreak +
    '  bicycle:' + sLineBreak +
    '    color: red' + sLineBreak +
    '    price: 100' + sLineBreak +
    'letters: [a, b, c, d, e]' + sLineBreak +
    'empty: []');
end;

procedure TYAMLPathMatchTests.TearDown;
begin
  FDoc := nil;
end;

{ QueryMatches }

procedure TYAMLPathMatchTests.Root_HasNoParent;
var
  matches : TArray<TYAMLPathMatch>;
  letters : IYAMLSequence;
begin
  matches := FDoc.QueryMatches('$');
  Assert.AreEqual(1, Integer(Length(matches)));
  Assert.IsTrue(SameNode(FDoc.Root, matches[0].Value));
  Assert.IsTrue(matches[0].Parent = nil);
  Assert.AreEqual('', matches[0].Key);
  Assert.AreEqual(-1, matches[0].Index);
  Assert.AreEqual('$', matches[0].Path);

  // the collection a query runs on is its root
  letters := FDoc.AsMapping['letters'].AsSequence;
  matches := letters.QueryMatches('$');
  Assert.AreEqual(1, Integer(Length(matches)));
  Assert.IsTrue(SameNode(letters, matches[0].Value));
  Assert.IsTrue(matches[0].Parent = nil);
  Assert.AreEqual('$', matches[0].Path);
end;

procedure TYAMLPathMatchTests.Names_GiveParentAndKey;
var
  matches : TArray<TYAMLPathMatch>;
  store : IYAMLValue;
begin
  store := FDoc.AsMapping['store'];
  matches := FDoc.QueryMatches('$.store.name');
  Assert.AreEqual(1, Integer(Length(matches)));
  Assert.AreEqual('corner shop', matches[0].Value.AsString);
  Assert.IsTrue(SameNode(store, matches[0].Parent));
  Assert.AreEqual('name', matches[0].Key);
  Assert.AreEqual(-1, matches[0].Index);
  Assert.AreEqual('$[''store''][''name'']', matches[0].Path);

  matches := FDoc.QueryMatches('$[''store''][''bicycle''].color');
  Assert.AreEqual(1, Integer(Length(matches)));
  Assert.AreEqual('red', matches[0].Value.AsString);
  Assert.IsTrue(SameNode(store.AsMapping['bicycle'], matches[0].Parent));
  Assert.AreEqual('color', matches[0].Key);
  Assert.AreEqual('$[''store''][''bicycle''][''color'']', matches[0].Path);
end;

procedure TYAMLPathMatchTests.Index_GivesParentAndIndex;
var
  matches : TArray<TYAMLPathMatch>;
  book : IYAMLSequence;
begin
  book := FDoc.AsMapping['store'].AsMapping['book'].AsSequence;
  matches := FDoc.QueryMatches('$.store.book[1]');
  Assert.AreEqual(1, Integer(Length(matches)));
  Assert.IsTrue(SameNode(book[1], matches[0].Value));
  Assert.IsTrue(SameNode(book, matches[0].Parent));
  Assert.AreEqual('', matches[0].Key);
  Assert.AreEqual(1, matches[0].Index);
  Assert.AreEqual('$[''store''][''book''][1]', matches[0].Path);

  matches := FDoc.QueryMatches('$.store.book[1].title');
  Assert.AreEqual(1, Integer(Length(matches)));
  Assert.AreEqual('B', matches[0].Value.AsString);
  Assert.IsTrue(SameNode(book[1], matches[0].Parent));
  Assert.AreEqual('title', matches[0].Key);
  Assert.AreEqual(-1, matches[0].Index);
  Assert.AreEqual('$[''store''][''book''][1][''title'']', matches[0].Path);
end;

procedure TYAMLPathMatchTests.Wildcard_OnMappingAndSequence;
var
  matches : TArray<TYAMLPathMatch>;
  i : integer;
begin
  matches := FDoc.QueryMatches('$.store.bicycle.*');
  Assert.AreEqual(2, Integer(Length(matches)));
  Assert.AreEqual('color', matches[0].Key);
  Assert.AreEqual('price', matches[1].Key);
  Assert.AreEqual('$[''store''][''bicycle''][''color''] $[''store''][''bicycle''][''price'']', PathsOf(matches));

  matches := FDoc.QueryMatches('$.letters[*]');
  Assert.AreEqual(5, Integer(Length(matches)));
  for i := 0 to 4 do
  begin
    Assert.AreEqual(i, matches[i].Index);
    Assert.AreEqual('', matches[i].Key);
    Assert.IsTrue(SameNode(FDoc.AsMapping['letters'], matches[i].Parent));
    Assert.AreEqual('$[''letters''][' + IntToStr(i) + ']', matches[i].Path);
  end;
end;

procedure TYAMLPathMatchTests.Slice_GivesEachIndex;
var
  matches : TArray<TYAMLPathMatch>;
begin
  matches := FDoc.QueryMatches('$.letters[1:4]');
  Assert.AreEqual('$[''letters''][1] $[''letters''][2] $[''letters''][3]', PathsOf(matches));
  Assert.AreEqual(3, matches[2].Index);
  Assert.AreEqual('d', matches[2].Value.AsString);

  matches := FDoc.QueryMatches('$.letters[0:5:2]');
  Assert.AreEqual('$[''letters''][0] $[''letters''][2] $[''letters''][4]', PathsOf(matches));
end;

procedure TYAMLPathMatchTests.Filter_OnSequenceAndMapping;
var
  matches : TArray<TYAMLPathMatch>;
begin
  matches := FDoc.QueryMatches('$.store.book[?(@.price > 10)]');
  Assert.AreEqual('$[''store''][''book''][1] $[''store''][''book''][2]', PathsOf(matches));
  Assert.AreEqual(1, matches[0].Index);
  Assert.AreEqual(2, matches[1].Index);

  matches := FDoc.QueryMatches('$.store.book[?(@.price > 10)].title');
  Assert.AreEqual('$[''store''][''book''][1][''title''] $[''store''][''book''][2][''title'']', PathsOf(matches));
  Assert.AreEqual('C', matches[1].Value.AsString);

  // a filter on a mapping selects its members
  matches := FDoc.QueryMatches('$.store[?(@.price)]');
  Assert.AreEqual(1, Integer(Length(matches)));
  Assert.AreEqual('bicycle', matches[0].Key);
  Assert.IsTrue(SameNode(FDoc.AsMapping['store'], matches[0].Parent));
  Assert.AreEqual('$[''store''][''bicycle'']', matches[0].Path);
end;

procedure TYAMLPathMatchTests.RecursiveDescent_GivesFullPaths;
var
  matches : TArray<TYAMLPathMatch>;
begin
  matches := FDoc.QueryMatches('$..price');
  Assert.AreEqual(
    '$[''store''][''book''][0][''price''] $[''store''][''book''][1][''price''] ' +
    '$[''store''][''book''][2][''price''] $[''store''][''bicycle''][''price'']', PathsOf(matches));
  Assert.AreEqual('price', matches[3].Key);
  Assert.IsTrue(SameNode(FDoc.AsMapping['store'].AsMapping['bicycle'], matches[3].Parent));
  Assert.IsTrue(SameNode(FDoc.AsMapping['store'].AsMapping['book'].AsSequence[2], matches[2].Parent));

  matches := FDoc.QueryMatches('$..book[0].title');
  Assert.AreEqual('$[''store''][''book''][0][''title'']', PathsOf(matches));
end;

procedure TYAMLPathMatchTests.AliasSharedNode_LocationIsWhereTheQueryWent;
var
  doc : IYAMLDocument;
  matches : TArray<TYAMLPathMatch>;
  defs, shared : IYAMLValue;
begin
  doc := TYAML.LoadFromString(
    'defs:' + sLineBreak +
    '  base: &x {k: 1}' + sLineBreak +
    'use: *x' + sLineBreak +
    'list: [*x]');
  defs := doc.AsMapping['defs'];
  shared := doc.AsMapping['use'];
  Assert.IsTrue(SameNode(defs, shared.Parent), 'the node''s own Parent names only where its anchor is');

  matches := doc.QueryMatches('$.use');
  Assert.AreEqual(1, Integer(Length(matches)));
  Assert.IsTrue(SameNode(shared, matches[0].Value));
  Assert.IsTrue(SameNode(doc.Root, matches[0].Parent));
  Assert.AreEqual('use', matches[0].Key);
  Assert.AreEqual('$[''use'']', matches[0].Path);

  matches := doc.QueryMatches('$.list[0]');
  Assert.IsTrue(SameNode(shared, matches[0].Value));
  Assert.IsTrue(SameNode(doc.AsMapping['list'], matches[0].Parent));
  Assert.AreEqual(0, matches[0].Index);
  Assert.AreEqual('$[''list''][0]', matches[0].Path);

  // one node, three places
  matches := doc.QueryMatches('$..k');
  Assert.AreEqual(3, Integer(Length(matches)));
  Assert.AreEqual('$[''defs''][''base''][''k''] $[''use''][''k''] $[''list''][0][''k'']', PathsOf(matches));
  Assert.IsTrue(SameNode(matches[0].Value, matches[1].Value));
  Assert.IsTrue(SameNode(matches[0].Value, matches[2].Value));
  Assert.IsTrue(SameNode(shared, matches[1].Parent));
end;

procedure TYAMLPathMatchTests.NoMatch_GivesEmptyArray;
begin
  Assert.AreEqual(0, Integer(Length(FDoc.QueryMatches('$.nothing'))));
  Assert.AreEqual(0, Integer(Length(FDoc.QueryMatches('$.letters[10]'))));
  Assert.AreEqual(0, Integer(Length(FDoc.QueryMatches('$.store.name.deeper'))));
  Assert.AreEqual(0, Integer(Length(FDoc.AsMapping.QueryMatches(''))));
  Assert.WillRaise(
    procedure
    begin
      FDoc.QueryMatches('store');
    end, EYAMLPathError);
end;

procedure TYAMLPathMatchTests.SameOrderAsQuery;
const
  cExpressions : array[0..9] of string = (
    '$',
    '$.store.book[*].title',
    '$..price',
    '$.store.*',
    '$.letters[3,0,-1]',
    '$.letters[1:]',
    '$.letters[-2]',
    '$.store.book[?(@.price < 15)]',
    '$[''store''][''book''][0]',
    '$.nothing');
var
  i, j : integer;
  query : IYAMLSequence;
  matches : TArray<TYAMLPathMatch>;
begin
  for i := Low(cExpressions) to High(cExpressions) do
  begin
    query := FDoc.Query(cExpressions[i]);
    matches := FDoc.QueryMatches(cExpressions[i]);
    Assert.AreEqual(query.Count, Integer(Length(matches)), cExpressions[i]);
    for j := 0 to query.Count - 1 do
      Assert.IsTrue(SameNode(query[j], matches[j].Value), cExpressions[i] + ' match ' + IntToStr(j));
  end;
end;

procedure TYAMLPathMatchTests.CompiledProcessor_QueryMatches;
var
  processor : TYAMLPathProcessor;
  matches : TArray<TYAMLPathMatch>;
  query : IYAMLSequence;
  other : IYAMLDocument;
begin
  processor := TYAMLPathProcessor.Create('$.store.book[-1].title');
  try
    matches := processor.QueryMatches(FDoc.Root);
    Assert.AreEqual(1, Integer(Length(matches)));
    Assert.AreEqual('C', matches[0].Value.AsString);
    Assert.AreEqual('$[''store''][''book''][2][''title'']', matches[0].Path);

    // the processor can run again, both ways
    query := processor.Query(FDoc.Root);
    Assert.AreEqual(1, query.Count);
    Assert.IsTrue(SameNode(query[0], matches[0].Value));
    matches := processor.QueryMatches(FDoc.Root);
    Assert.AreEqual(1, Integer(Length(matches)));

    other := TYAML.LoadFromString('store: {book: [{title: X}, {title: Y}]}');
    matches := processor.QueryMatches(other.Root);
    Assert.AreEqual('Y', matches[0].Value.AsString);
    Assert.AreEqual('$[''store''][''book''][1][''title'']', matches[0].Path);
  finally
    processor.Cleanup;
  end;

  matches := TYAMLPathProcessor.QueryMatches(FDoc.Root, '$.letters[0]');
  Assert.AreEqual('$[''letters''][0]', PathsOf(matches));
end;

procedure TYAMLPathMatchTests.Collection_PathsStartAtTheCollection;
var
  store : IYAMLMapping;
  fromStore, fromDoc : TArray<TYAMLPathMatch>;
begin
  store := FDoc.AsMapping['store'].AsMapping;
  fromStore := store.QueryMatches('$.book[0].title');
  fromDoc := FDoc.QueryMatches('$.store.book[0].title');
  Assert.AreEqual(1, Integer(Length(fromStore)));
  Assert.AreEqual('$[''book''][0][''title'']', fromStore[0].Path);
  Assert.AreEqual('$[''store''][''book''][0][''title'']', fromDoc[0].Path);
  Assert.IsTrue(SameNode(fromDoc[0].Value, fromStore[0].Value));
  Assert.IsTrue(SameNode(fromDoc[0].Parent, fromStore[0].Parent));
end;

procedure TYAMLPathMatchTests.Locations_CanEditTheTree;
var
  matches : TArray<TYAMLPathMatch>;
  i : integer;
begin
  // the books over 10, deleted from the last one back so the earlier indexes stay right
  matches := FDoc.QueryMatches('$.store.book[?(@.price > 10)]');
  for i := Length(matches) - 1 downto 0 do
    matches[i].Parent.AsSequence.Delete(matches[i].Index);
  Assert.AreEqual(1, FDoc.AsMapping['store'].AsMapping['book'].AsSequence.Count);
  Assert.AreEqual('A', FDoc.AsMapping['store'].AsMapping['book'].AsSequence[0].AsMapping.S['title']);

  matches := FDoc.QueryMatches('$..color');
  Assert.AreEqual(1, Integer(Length(matches)));
  Assert.IsTrue(matches[0].Parent.AsMapping.Remove(matches[0].Key));
  Assert.IsFalse(FDoc.AsMapping['store'].AsMapping['bicycle'].AsMapping.ContainsKey('color'));
  Assert.IsTrue(matches[0].Value.Parent = nil);
end;

{ normalized paths }

procedure TYAMLPathMatchTests.NormalizedPath_EscapesNames;
var
  doc : IYAMLDocument;
  mapping : IYAMLMapping;
  matches : TArray<TYAMLPathMatch>;
begin
  doc := TYAML.CreateMapping;
  mapping := doc.AsMapping;
  mapping.AddOrSetValue('it''s', 1);
  mapping.AddOrSetValue('back' + BS + 'slash', 2);
  mapping.AddOrSetValue('line' + #10 + 'feed', 3);
  mapping.AddOrSetValue('tab' + #9 + 'cr' + #13 + 'bs' + #8 + 'ff' + #12, 4);
  mapping.AddOrSetValue('ctl' + #1 + #$1F + #0, 5);
  mapping.AddOrSetValue('', 6);

  matches := doc.QueryMatches('$.*');
  Assert.AreEqual(6, Integer(Length(matches)));
  Assert.AreEqual('$[''it' + BS + '''s'']', matches[0].Path);
  Assert.AreEqual('$[''back' + BS + BS + 'slash'']', matches[1].Path);
  Assert.AreEqual('$[''line' + BS + 'nfeed'']', matches[2].Path);
  Assert.AreEqual('$[''tab' + BS + 'tcr' + BS + 'rbs' + BS + 'bff' + BS + 'f'']', matches[3].Path);
  Assert.AreEqual('$[''ctl' + BS + 'u0001' + BS + 'u001f' + BS + 'u0000'']', matches[4].Path);
  Assert.AreEqual('$['''']', matches[5].Path);

  // the key is as it is in the mapping
  Assert.AreEqual('it''s', matches[0].Key);
  Assert.AreEqual('line' + #10 + 'feed', matches[2].Key);
  Assert.AreEqual(Int64(1), matches[0].Value.AsInteger);
end;

procedure TYAMLPathMatchTests.NormalizedPath_OtherCharactersAsTheyAre;
var
  doc : IYAMLDocument;
  mapping : IYAMLMapping;
  matches : TArray<TYAMLPathMatch>;
begin
  doc := TYAML.CreateMapping;
  mapping := doc.AsMapping;
  mapping.AddOrSetValue('a.b [c] "d" $*', 1);
  mapping.AddOrSetValue('caf' + #$00E9, 2);
  mapping.AddOrSetValue(#$D83D#$DE00 + #$7F, 3);
  mapping.AddOrSetValue('42', 4);

  matches := doc.QueryMatches('$.*');
  Assert.AreEqual(4, Integer(Length(matches)));
  Assert.AreEqual('$[''a.b [c] "d" $*'']', matches[0].Path);
  Assert.AreEqual('$[''caf' + #$00E9 + ''']', matches[1].Path);
  Assert.AreEqual('$[''' + #$D83D#$DE00 + #$7F + ''']', matches[2].Path);
  Assert.AreEqual('$[''42'']', matches[3].Path, 'a key that looks like an index is still a name');
end;

{ negative indexes }

procedure TYAMLPathMatchTests.Index_NegativeCountsFromTheEnd(index : integer; const expected : string);
var
  matches : IYAMLSequence;
begin
  matches := FDoc.Query('$.letters[' + IntToStr(index) + ']');
  Assert.AreEqual(1, matches.Count);
  Assert.AreEqual(expected, matches[0].AsString);
end;

procedure TYAMLPathMatchTests.Index_OutOfRange_NoMatch(index : integer);
var
  expression : string;
begin
  expression := '$.letters[' + IntToStr(index) + ']';
  Assert.AreEqual(0, FDoc.Query(expression).Count, expression);
  Assert.AreEqual(0, Integer(Length(FDoc.QueryMatches(expression))), expression);
  Assert.AreEqual(0, FDoc.Query('$.letters[' + IntToStr(index) + '].x').Count);
end;

procedure TYAMLPathMatchTests.Index_EmptySequence_NoMatch;
begin
  Assert.AreEqual(0, FDoc.Query('$.empty[-1]').Count);
  Assert.AreEqual(0, FDoc.Query('$.empty[0]').Count);
  Assert.AreEqual(0, FDoc.Query('$.empty[0,-1]').Count);
end;

procedure TYAMLPathMatchTests.Union_MixesPositiveAndNegative;
var
  matches : TArray<TYAMLPathMatch>;
begin
  Assert.AreEqual('a,e', ValuesOf(FDoc.Query('$.letters[0,-1]')));
  Assert.AreEqual('e,a,e', ValuesOf(FDoc.Query('$.letters[-1, 0, -1]')), 'each index selects, so repeats are kept');
  matches := FDoc.QueryMatches('$.letters[-1,0,-2]');
  Assert.AreEqual('$[''letters''][4] $[''letters''][0] $[''letters''][3]', PathsOf(matches));
  Assert.AreEqual(4, matches[0].Index);
  Assert.AreEqual(3, matches[2].Index);
end;

procedure TYAMLPathMatchTests.Union_OutOfRangeIsSkipped;
begin
  Assert.AreEqual('b,d', ValuesOf(FDoc.Query('$.letters[-10,1,10,-2]')));
  Assert.AreEqual('', ValuesOf(FDoc.Query('$.letters[-6,5]')));
end;

procedure TYAMLPathMatchTests.NegativeIndex_ThenChild;
begin
  Assert.AreEqual('C', ValuesOf(FDoc.Query('$.store.book[-1].title')));
  Assert.AreEqual('12', ValuesOf(FDoc.Query('$.store.book[-2].price')));
  Assert.AreEqual('A,C', ValuesOf(FDoc.Query('$.store.book[0,-1].title')));
end;

procedure TYAMLPathMatchTests.NegativeIndex_AfterRecursiveDescent;
var
  matches : TArray<TYAMLPathMatch>;
begin
  Assert.AreEqual('C', ValuesOf(FDoc.Query('$..book[-1].title')));
  matches := FDoc.QueryMatches('$..book[-1].title');
  Assert.AreEqual('$[''store''][''book''][2][''title'']', PathsOf(matches));
end;

procedure TYAMLPathMatchTests.NegativeIndex_InFilterPath;
var
  doc : IYAMLDocument;
  matches : TArray<TYAMLPathMatch>;
begin
  doc := TYAML.LoadFromString(
    'items:' + sLineBreak +
    '  - tags: [a, z]' + sLineBreak +
    '  - tags: [z, a]');
  matches := doc.QueryMatches('$.items[?(@.tags[-1] == ''z'')]');
  Assert.AreEqual(1, Integer(Length(matches)));
  Assert.AreEqual(0, matches[0].Index);
end;

procedure TYAMLPathMatchTests.NegativeIndex_PathIsNormalized;
var
  matches : TArray<TYAMLPathMatch>;
begin
  matches := FDoc.QueryMatches('$.letters[-2]');
  Assert.AreEqual(1, Integer(Length(matches)));
  Assert.AreEqual(3, matches[0].Index);
  Assert.AreEqual('$[''letters''][3]', matches[0].Path);
  Assert.AreEqual('d', matches[0].Value.AsString);
end;

procedure TYAMLPathMatchTests.NegativeIndex_QuerySingle;
var
  match : IYAMLValue;
begin
  Assert.IsTrue(FDoc.QuerySingle('$.letters[-1]', match));
  Assert.AreEqual('e', match.AsString);
  Assert.IsFalse(FDoc.QuerySingle('$.letters[-9]', match));
  Assert.IsTrue(match.IsNull);
end;

initialization
  TDUnitX.RegisterTestFixture(TYAMLPathMatchTests);

end.

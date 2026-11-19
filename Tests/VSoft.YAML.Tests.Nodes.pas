unit VSoft.YAML.Tests.Nodes;

// The value classes' bookkeeping: the comment lists, a mapping's key index (built once a
// mapping has more than a few keys) and the parent of a node that outlives, or is taken out
// of, its collection.

interface

uses
  DUnitX.TestFramework,
  VSoft.YAML;

type
  [TestFixture]
  TYAMLNodeTests = class
  public
    // comments
    [Test]
    procedure Comments_AddSetClear;
    [Test]
    procedure Comments_ReadingGivesACopy;
    [Test]
    procedure EndComments_CollectionAndDocument;

    // mapping keys
    [Test]
    [TestCase('belowIndex', '5')]
    [TestCase('atIndex', '9')]
    [TestCase('wide', '1000')]
    procedure Mapping_LookupAndOrder(count : integer);
    [Test]
    procedure Mapping_OverwriteKeepsCountAndOrder;
    [Test]
    procedure Mapping_ClearThenReuse;
    [Test]
    procedure Mapping_ParsedDuplicateKeyInWideMapping;

    // parents
    [Test]
    procedure Parent_IsTheCollection;
    [Test]
    procedure Parent_ClearedWhenTheCollectionGoes;
    [Test]
    procedure Parent_ClearedWhenReplacedInMapping;
    [Test]
    procedure Parent_ClearedWhenReplacedInSequence;
    [Test]
    procedure Parent_KeptWhenSetToTheSameValue;
    [Test]
    procedure Parent_ClearedByClear;
    [Test]
    procedure Parent_SharedNodeKeepsItsOwnParent;
  end;

implementation

uses
  System.SysUtils;

{ comments }

procedure TYAMLNodeTests.Comments_AddSetClear;
var
  doc : IYAMLDocument;
  value : IYAMLValue;
  lines : TArray<string>;
begin
  doc := TYAML.CreateMapping;
  value := doc.AsMapping.AddOrSetValue('a', 'x');
  Assert.IsFalse(value.HasComments);
  Assert.AreEqual(0, Integer(Length(value.Comments)));

  value.AddComment('one');
  value.AddComment('two');
  Assert.IsTrue(value.HasComments);
  lines := value.Comments;
  Assert.AreEqual(2, Integer(Length(lines)));
  Assert.AreEqual('one', lines[0]);
  Assert.AreEqual('two', lines[1]);

  SetLength(lines, 1);
  lines[0] := 'only';
  value.Comments := lines;
  Assert.AreEqual(1, Integer(Length(value.Comments)));
  Assert.AreEqual('only', value.Comments[0]);

  value.ClearComments;
  Assert.IsFalse(value.HasComments);
  value.AddComment('again');
  value.Comments := nil;
  Assert.IsFalse(value.HasComments);
end;

procedure TYAMLNodeTests.Comments_ReadingGivesACopy;
var
  doc : IYAMLDocument;
  value : IYAMLValue;
  lines : TArray<string>;
begin
  doc := TYAML.CreateMapping;
  value := doc.AsMapping.AddOrSetValue('a', 'x');
  value.AddComment('kept');
  lines := value.Comments;
  lines[0] := 'changed';
  Assert.AreEqual('kept', value.Comments[0], 'changing what Comments returned must not change the node');

  // and setting takes a copy
  value.Comments := lines;
  lines[0] := 'changed again';
  Assert.AreEqual('changed', value.Comments[0]);
end;

procedure TYAMLNodeTests.EndComments_CollectionAndDocument;
var
  doc : IYAMLDocument;
  lines : TArray<string>;
begin
  doc := TYAML.CreateSequence;
  doc.AsSequence.AddEndComment('end');
  Assert.IsTrue(doc.AsSequence.HasEndComments);
  Assert.AreEqual('end', doc.AsSequence.EndComments[0]);
  doc.AsSequence.ClearEndComments;
  Assert.IsFalse(doc.AsSequence.HasEndComments);

  Assert.IsFalse(doc.HasEndComments);
  doc.AddEndComment('after');
  doc.AddEndComment('the root');
  lines := doc.EndComments;
  Assert.AreEqual(2, Integer(Length(lines)));
  Assert.AreEqual('the root', lines[1]);
  doc.EndComments := nil;
  Assert.IsFalse(doc.HasEndComments);
  doc.EndComments := lines;
  Assert.AreEqual(2, Integer(Length(doc.EndComments)));
  doc.ClearEndComments;
  Assert.IsFalse(doc.HasEndComments);
end;

{ mapping keys }

procedure TYAMLNodeTests.Mapping_LookupAndOrder(count : integer);
var
  doc : IYAMLDocument;
  mapping : IYAMLMapping;
  i : integer;
begin
  doc := TYAML.CreateMapping;
  mapping := doc.AsMapping;
  for i := 0 to count - 1 do
    mapping.AddOrSetValue('key' + IntToStr(i), i);
  Assert.AreEqual(count, mapping.Count);
  for i := 0 to count - 1 do
  begin
    Assert.AreEqual('key' + IntToStr(i), mapping.Keys[i], 'insertion order');
    Assert.IsTrue(mapping.ContainsKey('key' + IntToStr(i)));
    Assert.AreEqual<Int64>(i, mapping.Items['key' + IntToStr(i)].AsInteger);
  end;
  Assert.IsFalse(mapping.ContainsKey('key' + IntToStr(count)));
  Assert.IsFalse(mapping.ContainsKey(''));
  Assert.IsFalse(mapping.ContainsKey('KEY0'), 'keys are case sensitive');
end;

procedure TYAMLNodeTests.Mapping_OverwriteKeepsCountAndOrder;
var
  doc : IYAMLDocument;
  mapping : IYAMLMapping;
  i : integer;
begin
  doc := TYAML.CreateMapping;
  mapping := doc.AsMapping;
  for i := 0 to 99 do
    mapping.AddOrSetValue('k' + IntToStr(i), i);
  for i := 0 to 99 do
    if i mod 3 = 0 then
      mapping.AddOrSetValue('k' + IntToStr(i), 'replaced');
  Assert.AreEqual(100, mapping.Count);
  Assert.AreEqual('k0', mapping.Keys[0]);
  Assert.AreEqual('k99', mapping.Keys[99]);
  Assert.AreEqual('replaced', mapping.Items['k3'].AsString);
  Assert.AreEqual<Int64>(4, mapping.Items['k4'].AsInteger);
end;

procedure TYAMLNodeTests.Mapping_ClearThenReuse;
var
  doc : IYAMLDocument;
  mapping : IYAMLMapping;
  i : integer;
begin
  doc := TYAML.CreateMapping;
  mapping := doc.AsMapping;
  for i := 0 to 49 do
    mapping.AddOrSetValue('k' + IntToStr(i), i);
  mapping.Clear;
  Assert.AreEqual(0, mapping.Count);
  Assert.IsFalse(mapping.ContainsKey('k1'));
  for i := 0 to 19 do
    mapping.AddOrSetValue('n' + IntToStr(i), i);
  Assert.AreEqual(20, mapping.Count);
  Assert.AreEqual<Int64>(19, mapping.Items['n19'].AsInteger);
  Assert.IsFalse(mapping.ContainsKey('k19'));
end;

procedure TYAMLNodeTests.Mapping_ParsedDuplicateKeyInWideMapping;
var
  yamlText : string;
  i : integer;
  options : IYAMLParserOptions;
  doc : IYAMLDocument;
begin
  yamlText := '';
  for i := 0 to 39 do
    yamlText := yamlText + 'key' + IntToStr(i) + ': ' + IntToStr(i) + #10;
  // overwritten by default...
  doc := TYAML.LoadFromString(yamlText + 'key7: last');
  Assert.AreEqual(40, doc.AsMapping.Count);
  Assert.AreEqual('last', doc.AsMapping.Items['key7'].AsString);
  // ...an error when asked for
  options := TYAML.CreateParserOptions;
  options.DuplicateKeyBehavior := TYAMLDuplicateKeyBehavior.dkError;
  Assert.WillRaise(
    procedure
    begin
      TYAML.LoadFromString(yamlText + 'key7: last', options);
    end, EYAMLParseException);
end;

{ parents }

procedure TYAMLNodeTests.Parent_IsTheCollection;
var
  doc : IYAMLDocument;
  item : IYAMLValue;
begin
  doc := TYAML.LoadFromString('a:' + #10 + '  - x');
  item := doc.AsMapping.Items['a'].AsSequence[0];
  Assert.IsTrue(item.Parent.IsSequence);
  Assert.IsTrue(item.Parent.Parent.IsMapping);
  Assert.IsNull(doc.Root.Parent);
end;

// Gets a.b and a.c in a routine of its own: the compiler holds the interfaces that expressions
// such as Items['a'] return in hidden temporaries until the routine ends, which would keep
// mapping a alive.
procedure GetNested(const doc : IYAMLDocument; out kept, keptCollection : IYAMLValue);
begin
  kept := doc.AsMapping.Items['a'].AsMapping.Items['b'];
  keptCollection := doc.AsMapping.Items['a'].AsMapping.Items['c'];
end;

// (in a routine of its own for the same reason)
function HasParent(const value : IYAMLValue) : boolean;
begin
  result := value.Parent <> nil;
end;

procedure TYAMLNodeTests.Parent_ClearedWhenTheCollectionGoes;
var
  doc : IYAMLDocument;
  kept, keptCollection : IYAMLValue;
begin
  doc := TYAML.LoadFromString('a:' + #10 + '  b: x' + #10 + '  c: [1, 2]');
  GetNested(doc, kept, keptCollection);
  Assert.IsTrue(HasParent(kept));
  doc := nil; // the whole tree goes, apart from what is held here
  Assert.IsNull(kept.Parent, 'a scalar that outlives its mapping');
  Assert.IsNull(keptCollection.Parent, 'a collection that outlives its mapping');
  Assert.AreEqual('x', kept.AsString);
  Assert.AreEqual(2, keptCollection.AsSequence.Count);
  Assert.IsNotNull(keptCollection.AsSequence[0].Parent, 'its own items still have it as parent');
end;

procedure TYAMLNodeTests.Parent_ClearedWhenReplacedInMapping;
var
  doc : IYAMLDocument;
  old : IYAMLValue;
begin
  doc := TYAML.CreateMapping;
  old := doc.AsMapping.AddOrSetValue('a', 'first');
  Assert.IsNotNull(old.Parent);
  doc.AsMapping.AddOrSetValue('a', 'second');
  Assert.IsNull(old.Parent);
  doc := nil;
  Assert.AreEqual('first', old.AsString);
end;

procedure TYAMLNodeTests.Parent_ClearedWhenReplacedInSequence;
var
  doc : IYAMLDocument;
  old : IYAMLValue;
begin
  doc := TYAML.CreateSequence;
  old := doc.AsSequence.AddValue('first');
  doc.AsSequence.S[0] := 'second';
  Assert.IsNull(old.Parent);
  Assert.AreEqual('second', doc.AsSequence[0].AsString);
  doc := nil;
  Assert.AreEqual('first', old.AsString);
end;

procedure TYAMLNodeTests.Parent_KeptWhenSetToTheSameValue;
var
  doc : IYAMLDocument;
  child : IYAMLMapping;
begin
  doc := TYAML.CreateMapping;
  child := doc.AsMapping.AddOrSetMapping('m');
  Assert.IsNotNull(child.Parent);
  // setting the key to the node it already holds must not detach it
  doc.AsMapping.O['m'] := child;
  Assert.IsNotNull(child.Parent);
  doc.AsMapping.O['m'] := doc.AsMapping.O['m'];
  Assert.IsNotNull(child.Parent);
end;

procedure TYAMLNodeTests.Parent_ClearedByClear;
var
  doc : IYAMLDocument;
  inMapping, inSequence : IYAMLValue;
  sequence : IYAMLSequence;
begin
  doc := TYAML.CreateMapping;
  inMapping := doc.AsMapping.AddOrSetValue('a', 1);
  sequence := doc.AsMapping.AddOrSetSequence('s');
  inSequence := sequence.AddValue('x');
  sequence.Clear;
  Assert.IsNull(inSequence.Parent);
  Assert.AreEqual(0, sequence.Count);
  doc.AsMapping.Clear;
  Assert.IsNull(inMapping.Parent);
  Assert.IsNull(sequence.Parent);
end;

procedure TYAMLNodeTests.Parent_SharedNodeKeepsItsOwnParent;
var
  doc : IYAMLDocument;
  shared, holder : IYAMLValue;
begin
  // an alias is the anchored node itself, so it is in two collections but has one parent
  doc := TYAML.LoadFromString('a: &x {k: v}' + #10 + 'b:' + #10 + '  - *x');
  shared := doc.AsMapping.Items['a'];
  holder := doc.AsMapping.Items['b'];
  Assert.IsTrue(shared.Parent.IsMapping);
  // taking it out of the sequence it was aliased into leaves its parent alone
  holder.AsSequence.Clear;
  Assert.IsNotNull(shared.Parent);
  Assert.AreEqual('v', shared.Parent.AsMapping.Items['a'].AsMapping.Items['k'].AsString);
end;

initialization
  TDUnitX.RegisterTestFixture(TYAMLNodeTests);

end.

unit VSoft.YAML.Tests.Editing;

// Changing a document in place: removing a mapping key, deleting and inserting sequence
// items, putting an existing node into a collection (IYAMLMapping.AddOrSetValue,
// IYAMLSequence.AddValue and InsertValue with an IYAMLValue), and Clone.

interface

uses
  DUnitX.TestFramework,
  VSoft.YAML;

type
  [TestFixture]
  TYAMLEditingTests = class
  public
    // IYAMLMapping.Remove
    [Test]
    procedure Remove_MissingKey_ReturnsFalse;
    [Test]
    procedure Remove_EmptyMapping_ReturnsFalse;
    [Test]
    [TestCase('first', '0')]
    [TestCase('middle', '2')]
    [TestCase('last', '4')]
    procedure Remove_OtherKeysKeepTheirOrder(index : integer);
    [Test]
    [TestCase('belowIndex', '6')]
    [TestCase('atIndex', '9')]
    [TestCase('wide', '200')]
    procedure Remove_LookupStillWorks(count : integer);
    [Test]
    procedure Remove_ClearsParent;
    [Test]
    procedure Remove_AliasKeepsTheSharedNodesParent;
    [Test]
    procedure Remove_WritesWithoutTheKey;

    // IYAMLMapping.AddOrSetValue(key, IYAMLValue)
    [Test]
    procedure AddOrSetNode_NewKeyGoesLastAndSetsParent;
    [Test]
    procedure AddOrSetNode_ExistingKeyIsReplacedInPlace;
    [Test]
    procedure AddOrSetNode_AttachedNodeRaises;
    [Test]
    procedure AddOrSetNode_NilRaises;
    [Test]
    procedure AddOrSetNode_SelfOrAncestorRaises;
    [Test]
    procedure AddOrSetNode_MoveBetweenDocuments;

    // IYAMLSequence.Delete
    [Test]
    procedure Delete_EmptySequenceRaises;
    [Test]
    [TestCase('negative', '-1')]
    [TestCase('count', '3')]
    procedure Delete_OutOfRangeRaises(index : integer);
    [Test]
    procedure Delete_FirstAndLast;
    [Test]
    procedure Delete_ClearsParent;
    [Test]
    procedure Delete_SetLetsTheValueBeAddedAgain;

    // IYAMLSequence.InsertValue, InsertNull, InsertNumber, InsertMapping, InsertSequence
    [Test]
    procedure Insert_IntoEmptySequence;
    [Test]
    procedure Insert_AtZeroAndAtCount;
    [Test]
    [TestCase('negative', '-1')]
    [TestCase('pastCount', '4')]
    procedure Insert_OutOfRangeRaises(index : integer);
    [Test]
    procedure Insert_TypedOverloads;
    [Test]
    procedure InsertNumber_InvalidTextRaises;
    [Test]
    procedure InsertValue_Node_SetsParent;
    [Test]
    procedure InsertValue_AttachedOrNilRaises;
    [Test]
    procedure Insert_SetKeepsValuesUnique;

    // IYAMLSequence.AddValue(IYAMLValue)
    [Test]
    procedure AddValueNode_SetsParent;
    [Test]
    procedure AddValueNode_AttachedNodeRaises;
    [Test]
    procedure AddValueNode_NilRaises;
    [Test]
    procedure AddValueNode_SelfOrAncestorRaises;
    [Test]
    procedure AddValueNode_SetIgnoresDuplicateAndLeavesItDetached;
    [Test]
    procedure Parse_AliasesStillShareOneNode;

    // IYAMLValue.Clone
    [Test]
    procedure Clone_ScalarKeepsTypeTextAndTag;
    [Test]
    procedure Clone_IsDetached;
    [Test]
    procedure Clone_IsIndependent;
    [Test]
    procedure Clone_WritesTheSameYAMLAndJSON;
    [Test]
    procedure Clone_WritesTheSameJSON5;
    [Test]
    procedure Clone_KeepsComments;
    [Test]
    procedure Clone_AliasSharedNodeGivesTwoCopies;
    [Test]
    procedure Clone_SetStaysASet;
    [Test]
    procedure Clone_EmptyCollections;
    [Test]
    procedure Clone_ThenAttach;

    // the null a missing key or index gives
    [Test]
    procedure MissingKeyOrIndex_GivesADetachedNull;
    // typed Add* and Insert* on a set
    [Test]
    procedure Set_DuplicateGivesADetachedNode;
    // the A[] and O[] setters
    [Test]
    procedure MappingSetters_SetParent;
    [Test]
    procedure MappingSetters_AttachedNodeRaises;
    [Test]
    procedure MappingSetters_NilWritesNull;
    [Test]
    procedure SequenceSetters_SetParent;
    [Test]
    procedure SequenceSetters_AttachedNodeRaises;
    [Test]
    procedure SequenceSetters_NilWritesNull;
    [Test]
    procedure SequenceSetters_SameNodeChangesNothing;
  end;

implementation

uses
  System.SysUtils;

// Nodes are compared as objects - one node can be held through different interfaces.
function SameNode(const a, b : IYAMLValue) : boolean;
begin
  result := (a <> nil) and (b <> nil) and ((a as TObject) = (b as TObject));
end;

function KeysOf(const mapping : IYAMLMapping) : string;
var
  i : integer;
begin
  result := '';
  for i := 0 to mapping.Count - 1 do
  begin
    if i > 0 then
      result := result + ',';
    result := result + mapping.Keys[i];
  end;
end;

function ItemsOf(const sequence : IYAMLSequence) : string;
var
  i : integer;
begin
  result := '';
  for i := 0 to sequence.Count - 1 do
  begin
    if i > 0 then
      result := result + ',';
    result := result + sequence[i].AsString;
  end;
end;

function CompactJSON(const doc : IYAMLDocument) : string;
begin
  doc.Options.PrettyPrint := false;
  result := TYAML.WriteToJSONString(doc);
end;

{ IYAMLMapping.Remove }

procedure TYAMLEditingTests.Remove_MissingKey_ReturnsFalse;
var
  doc : IYAMLDocument;
begin
  doc := TYAML.LoadFromString('a: 1' + sLineBreak + 'b: 2');
  Assert.IsFalse(doc.AsMapping.Remove('c'));
  Assert.IsFalse(doc.AsMapping.Remove('A'), 'keys are case sensitive');
  Assert.AreEqual('a,b', KeysOf(doc.AsMapping));
end;

procedure TYAMLEditingTests.Remove_EmptyMapping_ReturnsFalse;
var
  doc : IYAMLDocument;
begin
  doc := TYAML.CreateMapping;
  Assert.IsFalse(doc.AsMapping.Remove('a'));
  Assert.IsFalse(doc.AsMapping.Remove(''));
  Assert.AreEqual(0, doc.AsMapping.Count);
end;

procedure TYAMLEditingTests.Remove_OtherKeysKeepTheirOrder(index : integer);
var
  doc : IYAMLDocument;
  mapping : IYAMLMapping;
  i : integer;
  expected, removedKey : string;
begin
  doc := TYAML.CreateMapping;
  mapping := doc.AsMapping;
  for i := 0 to 4 do
    mapping.AddOrSetValue('k' + IntToStr(i), i);
  removedKey := 'k' + IntToStr(index);

  Assert.IsTrue(mapping.Remove(removedKey));

  expected := '';
  for i := 0 to 4 do
  begin
    if i = index then
      continue;
    if expected <> '' then
      expected := expected + ',';
    expected := expected + 'k' + IntToStr(i);
  end;
  Assert.AreEqual(expected, KeysOf(mapping));
  Assert.IsFalse(mapping.ContainsKey(removedKey));
  for i := 0 to 4 do
    if i <> index then
      Assert.AreEqual(i, mapping.I['k' + IntToStr(i)]);
  Assert.IsFalse(mapping.Remove(removedKey), 'a second Remove finds nothing');
end;

procedure TYAMLEditingTests.Remove_LookupStillWorks(count : integer);
var
  doc : IYAMLDocument;
  mapping : IYAMLMapping;
  i, removed, position : integer;
  key : string;
begin
  // a mapping of more than 8 keys finds them through an index, which Remove has to keep right
  doc := TYAML.CreateMapping;
  mapping := doc.AsMapping;
  for i := 0 to count - 1 do
    mapping.AddOrSetValue('k' + IntToStr(i), i);

  removed := 0;
  i := 0;
  while i < count do
  begin
    Assert.IsTrue(mapping.Remove('k' + IntToStr(i)));
    Inc(removed);
    Inc(i, 3);
  end;
  Assert.AreEqual(count - removed, mapping.Count);

  position := 0;
  for i := 0 to count - 1 do
  begin
    key := 'k' + IntToStr(i);
    if i mod 3 = 0 then
      Assert.IsFalse(mapping.ContainsKey(key), key)
    else
    begin
      Assert.IsTrue(mapping.ContainsKey(key), key);
      Assert.AreEqual(i, mapping.I[key], key);
      Assert.AreEqual(key, mapping.Keys[position], 'order');
      Inc(position);
    end;
  end;

  // a removed key added again goes last
  mapping.AddOrSetValue('k0', 'again');
  Assert.AreEqual('k0', mapping.Keys[mapping.Count - 1]);
  Assert.AreEqual('again', mapping.S['k0']);

  // all of them, from the front
  while mapping.Count > 0 do
    Assert.IsTrue(mapping.Remove(mapping.Keys[0]));
  Assert.IsFalse(mapping.ContainsKey('k1'));
  mapping.AddOrSetValue('x', 1);
  Assert.IsTrue(mapping.ContainsKey('x'));
  Assert.AreEqual(1, mapping.Count);
end;

procedure TYAMLEditingTests.Remove_ClearsParent;
var
  doc : IYAMLDocument;
  collection, scalar : IYAMLValue;
begin
  doc := TYAML.LoadFromString('a:' + sLineBreak + '  b: 1' + sLineBreak + 'c: 2');
  collection := doc.AsMapping['a'];
  scalar := doc.AsMapping['c'];
  Assert.IsTrue(SameNode(doc.Root, collection.Parent));
  Assert.IsTrue(SameNode(doc.Root, scalar.Parent));

  Assert.IsTrue(doc.AsMapping.Remove('a'));
  Assert.IsTrue(collection.Parent = nil);
  Assert.AreEqual(1, collection.AsMapping.Count, 'the removed node keeps its own items');
  Assert.IsTrue(SameNode(collection, collection.AsMapping['b'].Parent));

  Assert.IsTrue(doc.AsMapping.Remove('c'));
  Assert.IsTrue(scalar.Parent = nil);
  Assert.AreEqual(0, doc.AsMapping.Count);
end;

procedure TYAMLEditingTests.Remove_AliasKeepsTheSharedNodesParent;
var
  doc : IYAMLDocument;
  defs, shared : IYAMLValue;
begin
  doc := TYAML.LoadFromString('defs:' + sLineBreak + '  base: &x {k: 1}' + sLineBreak + 'use: *x');
  defs := doc.AsMapping['defs'];
  shared := doc.AsMapping['use'];
  Assert.IsTrue(SameNode(defs, shared.Parent), 'the node''s parent is where its anchor is');

  Assert.IsTrue(doc.AsMapping.Remove('use'));
  Assert.IsTrue(SameNode(defs, shared.Parent), 'removing the alias leaves the node''s parent alone');
  Assert.IsTrue(SameNode(shared, defs.AsMapping['base']));
end;

procedure TYAMLEditingTests.Remove_WritesWithoutTheKey;
var
  doc : IYAMLDocument;
  yaml : string;
begin
  doc := TYAML.LoadFromString('a: 1' + sLineBreak + 'b: 2' + sLineBreak + 'c: 3');
  doc.AsMapping.Remove('b');
  Assert.AreEqual('{"a":1,"c":3}', CompactJSON(doc));
  yaml := TYAML.WriteToString(doc);
  Assert.Contains(yaml, 'a: 1');
  Assert.Contains(yaml, 'c: 3');
  Assert.DoesNotContain(yaml, 'b:');
end;

{ IYAMLMapping.AddOrSetValue(key, IYAMLValue) }

procedure TYAMLEditingTests.AddOrSetNode_NewKeyGoesLastAndSetsParent;
var
  doc, other : IYAMLDocument;
  node, scalar : IYAMLValue;
begin
  doc := TYAML.LoadFromString('a: 1');
  other := TYAML.LoadFromString('x: [1, 2]');

  node := other.AsMapping['x'].Clone;
  doc.AsMapping.AddOrSetValue('b', node);
  Assert.AreEqual('a,b', KeysOf(doc.AsMapping));
  Assert.IsTrue(SameNode(node, doc.AsMapping['b']));
  Assert.IsTrue(SameNode(doc.Root, node.Parent));

  scalar := other.AsMapping['x'].AsSequence[1].Clone;
  doc.AsMapping.AddOrSetValue('c', scalar);
  Assert.IsTrue(SameNode(doc.Root, scalar.Parent));
  Assert.AreEqual(Int64(2), doc.AsMapping['c'].AsInteger);

  Assert.AreEqual('{"a":1,"b":[1,2],"c":2}', CompactJSON(doc));
  Assert.AreEqual('{"x":[1,2]}', CompactJSON(other), 'the source is unchanged');
end;

procedure TYAMLEditingTests.AddOrSetNode_ExistingKeyIsReplacedInPlace;
var
  doc : IYAMLDocument;
  old, node : IYAMLValue;
begin
  doc := TYAML.LoadFromString('a: 1' + sLineBreak + 'b: 2' + sLineBreak + 'c: 3');
  old := doc.AsMapping['b'];
  // the root of a document is in no collection
  node := TYAML.LoadFromString('[x, y]').Root;
  Assert.IsTrue(node.Parent = nil);

  doc.AsMapping.AddOrSetValue('b', node);
  Assert.AreEqual('a,b,c', KeysOf(doc.AsMapping), 'the key keeps its place');
  Assert.IsTrue(SameNode(node, doc.AsMapping['b']));
  Assert.IsTrue(SameNode(doc.Root, node.Parent));
  Assert.IsTrue(old.Parent = nil, 'the value replaced forgets the mapping');
  Assert.AreEqual('{"a":1,"b":["x","y"],"c":3}', CompactJSON(doc));
end;

procedure TYAMLEditingTests.AddOrSetNode_AttachedNodeRaises;
var
  doc, other : IYAMLDocument;
  mapping : IYAMLMapping;
  attached, item : IYAMLValue;
begin
  doc := TYAML.LoadFromString('a: {k: 1}' + sLineBreak + 'b: [1]');
  other := TYAML.LoadFromString('x: 1');
  mapping := doc.AsMapping;
  attached := mapping['a'];
  item := mapping['b'].AsSequence[0];

  Assert.WillRaise(
    procedure
    begin
      mapping.AddOrSetValue('c', attached);
    end, EArgumentException, 'a node already in this mapping');
  // setting a key to the node it already holds changes nothing, as O['a'] := O['a'] does
  mapping.AddOrSetValue('a', attached);
  Assert.IsTrue(SameNode(mapping, attached.Parent));
  Assert.IsTrue(SameNode(attached, mapping['a']));
  Assert.WillRaise(
    procedure
    begin
      mapping.AddOrSetValue('b', attached);
    end, EArgumentException, 'a node of this mapping under another key');
  Assert.WillRaise(
    procedure
    begin
      other.AsMapping.AddOrSetValue('y', attached);
    end, EArgumentException, 'a node in another document');
  Assert.WillRaise(
    procedure
    begin
      mapping.AddOrSetValue('c', item);
    end, EArgumentException, 'a scalar in a sequence');

  Assert.AreEqual('a,b', KeysOf(mapping), 'nothing was added');
  Assert.AreEqual('x', KeysOf(other.AsMapping));
  Assert.IsTrue(SameNode(mapping, attached.Parent));
end;

procedure TYAMLEditingTests.AddOrSetNode_NilRaises;
var
  doc : IYAMLDocument;
  mapping : IYAMLMapping;
  nothing : IYAMLValue;
begin
  doc := TYAML.LoadFromString('a: 1');
  mapping := doc.AsMapping;
  nothing := nil;
  Assert.WillRaise(
    procedure
    begin
      mapping.AddOrSetValue('b', nothing);
    end, EArgumentNilException);
  Assert.AreEqual(1, mapping.Count);
end;

procedure TYAMLEditingTests.AddOrSetNode_SelfOrAncestorRaises;
var
  doc : IYAMLDocument;
  root, inner : IYAMLMapping;
begin
  doc := TYAML.LoadFromString('a:' + sLineBreak + '  b: {}');
  root := doc.AsMapping;
  inner := root['a'].AsMapping['b'].AsMapping;
  // the root is in no collection, so only the check for a loop stops these
  Assert.WillRaise(
    procedure
    begin
      root.AddOrSetValue('self', root);
    end, EArgumentException);
  Assert.WillRaise(
    procedure
    begin
      inner.AddOrSetValue('loop', root);
    end, EArgumentException);
  Assert.AreEqual(1, root.Count);
  Assert.AreEqual(0, inner.Count);
end;

procedure TYAMLEditingTests.AddOrSetNode_MoveBetweenDocuments;
var
  source, target : IYAMLDocument;
  items : IYAMLSequence;
  item : IYAMLValue;
begin
  source := TYAML.LoadFromString('items:' + sLineBreak + '  - id: 1' + sLineBreak + '  - id: 2');
  target := TYAML.CreateMapping;
  items := source.AsMapping['items'].AsSequence;
  item := items[1];

  items.Delete(1);
  target.AsMapping.AddOrSetValue('moved', item);
  Assert.IsTrue(SameNode(target.Root, item.Parent));
  Assert.AreEqual('{"items":[{"id":1}]}', CompactJSON(source));
  Assert.AreEqual('{"moved":{"id":2}}', CompactJSON(target));

  // and back again, to the front
  Assert.IsTrue(target.AsMapping.Remove('moved'));
  items.InsertValue(0, item);
  Assert.IsTrue(SameNode(items, item.Parent));
  Assert.AreEqual('{"items":[{"id":2},{"id":1}]}', CompactJSON(source));
  Assert.AreEqual('{}', CompactJSON(target));
end;

{ IYAMLSequence.Delete }

procedure TYAMLEditingTests.Delete_EmptySequenceRaises;
var
  doc : IYAMLDocument;
  sequence : IYAMLSequence;
begin
  doc := TYAML.CreateSequence;
  sequence := doc.AsSequence;
  Assert.WillRaise(
    procedure
    begin
      sequence.Delete(0);
    end, EArgumentOutOfRangeException);
end;

procedure TYAMLEditingTests.Delete_OutOfRangeRaises(index : integer);
var
  doc : IYAMLDocument;
  sequence : IYAMLSequence;
begin
  doc := TYAML.LoadFromString('[a, b, c]');
  sequence := doc.AsSequence;
  Assert.WillRaise(
    procedure
    begin
      sequence.Delete(index);
    end, EArgumentOutOfRangeException);
  Assert.AreEqual('a,b,c', ItemsOf(sequence));
end;

procedure TYAMLEditingTests.Delete_FirstAndLast;
var
  doc : IYAMLDocument;
  sequence : IYAMLSequence;
begin
  doc := TYAML.LoadFromString('[a, b, c, d]');
  sequence := doc.AsSequence;
  sequence.Delete(0);
  Assert.AreEqual('b,c,d', ItemsOf(sequence));
  sequence.Delete(sequence.Count - 1);
  Assert.AreEqual('b,c', ItemsOf(sequence));
  sequence.Delete(1);
  Assert.AreEqual('b', ItemsOf(sequence));
  sequence.Delete(0);
  Assert.AreEqual(0, sequence.Count);
  sequence.AddValue('e');
  Assert.AreEqual('e', ItemsOf(sequence));
  Assert.AreEqual('["e"]', CompactJSON(doc));
end;

procedure TYAMLEditingTests.Delete_ClearsParent;
var
  doc : IYAMLDocument;
  sequence : IYAMLSequence;
  collection, scalar : IYAMLValue;
begin
  doc := TYAML.LoadFromString('[{k: 1}, x]');
  sequence := doc.AsSequence;
  collection := sequence[0];
  scalar := sequence[1];
  Assert.IsTrue(SameNode(sequence, collection.Parent));

  sequence.Delete(0);
  Assert.IsTrue(collection.Parent = nil);
  Assert.AreEqual(1, collection.AsMapping.Count, 'the deleted node keeps its own items');
  Assert.IsTrue(SameNode(sequence, scalar.Parent), 'the item that moved down keeps its parent');
  Assert.IsTrue(SameNode(scalar, sequence[0]));

  sequence.Delete(0);
  Assert.IsTrue(scalar.Parent = nil);
end;

procedure TYAMLEditingTests.Delete_SetLetsTheValueBeAddedAgain;
var
  doc : IYAMLDocument;
  aSet : IYAMLSet;
begin
  doc := TYAML.CreateSet;
  aSet := doc.AsSet;
  aSet.AddValue('a');
  aSet.AddValue('b');
  aSet.AddValue('a');
  Assert.AreEqual('a,b', ItemsOf(aSet));

  aSet.Delete(0);
  Assert.AreEqual('b', ItemsOf(aSet));
  aSet.AddValue('a');
  Assert.AreEqual('b,a', ItemsOf(aSet), 'a deleted value can be added again');
  aSet.AddValue('b');
  Assert.AreEqual('b,a', ItemsOf(aSet), 'a value still there is not added twice');
end;

{ IYAMLSequence.Insert* }

procedure TYAMLEditingTests.Insert_IntoEmptySequence;
var
  doc : IYAMLDocument;
  sequence : IYAMLSequence;
  value : IYAMLValue;
begin
  doc := TYAML.CreateSequence;
  sequence := doc.AsSequence;
  value := sequence.InsertValue(0, 'first');
  Assert.AreEqual('first', ItemsOf(sequence));
  Assert.IsTrue(SameNode(sequence, value.Parent));
end;

procedure TYAMLEditingTests.Insert_AtZeroAndAtCount;
var
  doc : IYAMLDocument;
  sequence : IYAMLSequence;
begin
  doc := TYAML.LoadFromString('[b, c]');
  sequence := doc.AsSequence;
  sequence.InsertValue(0, 'a');
  Assert.AreEqual('a,b,c', ItemsOf(sequence));
  sequence.InsertValue(sequence.Count, 'd');
  Assert.AreEqual('a,b,c,d', ItemsOf(sequence), 'index = Count adds at the end');
  sequence.InsertValue(2, 'x');
  Assert.AreEqual('a,b,x,c,d', ItemsOf(sequence));
  Assert.AreEqual('["a","b","x","c","d"]', CompactJSON(doc));
end;

procedure TYAMLEditingTests.Insert_OutOfRangeRaises(index : integer);
var
  doc : IYAMLDocument;
  sequence : IYAMLSequence;
  node : IYAMLValue;
begin
  doc := TYAML.LoadFromString('[a, b, c]');
  sequence := doc.AsSequence;
  node := sequence[0].Clone;
  Assert.WillRaise(
    procedure
    begin
      sequence.InsertValue(index, 'x');
    end, EArgumentOutOfRangeException);
  Assert.WillRaise(
    procedure
    begin
      sequence.InsertValue(index, 42);
    end, EArgumentOutOfRangeException);
  Assert.WillRaise(
    procedure
    begin
      sequence.InsertNull(index);
    end, EArgumentOutOfRangeException);
  Assert.WillRaise(
    procedure
    begin
      sequence.InsertNumber(index, '1');
    end, EArgumentOutOfRangeException);
  Assert.WillRaise(
    procedure
    begin
      sequence.InsertMapping(index);
    end, EArgumentOutOfRangeException);
  Assert.WillRaise(
    procedure
    begin
      sequence.InsertSequence(index);
    end, EArgumentOutOfRangeException);
  Assert.WillRaise(
    procedure
    begin
      sequence.InsertValue(index, node);
    end, EArgumentOutOfRangeException);
  Assert.AreEqual('a,b,c', ItemsOf(sequence));
  Assert.IsTrue(node.Parent = nil, 'a node that was not inserted gets no parent');
end;

procedure TYAMLEditingTests.Insert_TypedOverloads;
var
  doc : IYAMLDocument;
  sequence : IYAMLSequence;
  mapping : IYAMLMapping;
  inner : IYAMLSequence;
  i : integer;
begin
  doc := TYAML.CreateSequence;
  sequence := doc.AsSequence;
  sequence.AddValue('end');
  sequence.InsertValue(0, 'text');
  sequence.InsertValue(1, 42);
  sequence.InsertValue(2, 1.5);
  sequence.InsertValue(3, true);
  sequence.InsertNull(4);
  sequence.InsertNumber(5, '12345678901234567890.5');
  mapping := sequence.InsertMapping(6);
  mapping.AddOrSetValue('k', 'v');
  inner := sequence.InsertSequence(7);
  inner.AddValue(1);
  sequence.InsertValue(0, 'tagged', '!custom');

  Assert.AreEqual(10, sequence.Count);
  Assert.IsTrue(sequence[0].IsString);
  Assert.AreEqual('!custom', sequence[0].Tag);
  Assert.IsTrue(sequence[1].IsString);
  Assert.IsTrue(sequence[2].IsInteger);
  Assert.AreEqual(Int64(42), sequence[2].AsInteger);
  Assert.IsTrue(sequence[3].IsFloat);
  Assert.IsTrue(sequence[3].AsFloat = 1.5);
  Assert.IsTrue(sequence[4].IsBoolean);
  Assert.IsTrue(sequence[4].AsBoolean);
  Assert.IsTrue(sequence[5].IsNull);
  Assert.IsTrue(sequence[6].IsFloat);
  Assert.AreEqual('12345678901234567890.5', sequence[6].RawValue);
  Assert.IsTrue(sequence[7].IsMapping);
  Assert.IsTrue(sequence[8].IsSequence);
  Assert.AreEqual('end', sequence[9].AsString);
  for i := 0 to sequence.Count - 1 do
    Assert.IsTrue(SameNode(sequence, sequence[i].Parent), 'parent of item ' + IntToStr(i));

  Assert.AreEqual('["tagged","text",42,1.5,true,null,12345678901234567890.5,{"k":"v"},[1],"end"]', CompactJSON(doc));
end;

procedure TYAMLEditingTests.InsertNumber_InvalidTextRaises;
var
  doc : IYAMLDocument;
  sequence : IYAMLSequence;
begin
  doc := TYAML.LoadFromString('[a]');
  sequence := doc.AsSequence;
  Assert.WillRaise(
    procedure
    begin
      sequence.InsertNumber(0, '0x1F');
    end, EConvertError);
  Assert.AreEqual('a', ItemsOf(sequence));
end;

procedure TYAMLEditingTests.InsertValue_Node_SetsParent;
var
  doc : IYAMLDocument;
  sequence : IYAMLSequence;
  node : IYAMLValue;
begin
  doc := TYAML.LoadFromString('[a, c, {k: v}]');
  sequence := doc.AsSequence;
  node := sequence[2].Clone;
  sequence.InsertValue(1, node);
  Assert.IsTrue(SameNode(sequence, node.Parent));
  Assert.IsTrue(SameNode(node, sequence[1]));
  Assert.AreEqual('["a",{"k":"v"},"c",{"k":"v"}]', CompactJSON(doc));
end;

procedure TYAMLEditingTests.InsertValue_AttachedOrNilRaises;
var
  doc : IYAMLDocument;
  sequence : IYAMLSequence;
  attached, nothing : IYAMLValue;
begin
  doc := TYAML.LoadFromString('[a, b]');
  sequence := doc.AsSequence;
  attached := sequence[1];
  nothing := nil;
  Assert.WillRaise(
    procedure
    begin
      sequence.InsertValue(0, attached);
    end, EArgumentException);
  Assert.WillRaise(
    procedure
    begin
      sequence.InsertValue(0, nothing);
    end, EArgumentNilException);
  Assert.WillRaise(
    procedure
    begin
      sequence.InsertValue(0, sequence);
    end, EArgumentException);
  Assert.AreEqual('a,b', ItemsOf(sequence));
end;

procedure TYAMLEditingTests.Insert_SetKeepsValuesUnique;
var
  doc : IYAMLDocument;
  aSet : IYAMLSet;
  node, duplicate : IYAMLValue;
begin
  doc := TYAML.CreateSet;
  aSet := doc.AsSet;
  aSet.AddValue('b');
  aSet.InsertValue(0, 'a');
  Assert.AreEqual('a,b', ItemsOf(aSet));
  aSet.InsertValue(0, 'b');
  Assert.AreEqual('a,b', ItemsOf(aSet), 'b is there already');

  node := TYAML.LoadFromString('c').Root;
  aSet.InsertValue(1, node);
  Assert.AreEqual('a,c,b', ItemsOf(aSet));
  Assert.IsTrue(SameNode(aSet, node.Parent));

  duplicate := TYAML.LoadFromString('a').Root;
  aSet.InsertValue(0, duplicate);
  Assert.AreEqual('a,c,b', ItemsOf(aSet));
  Assert.IsTrue(duplicate.Parent = nil, 'a value the set did not take stays detached');
end;

{ IYAMLSequence.AddValue(IYAMLValue) }

procedure TYAMLEditingTests.AddValueNode_SetsParent;
var
  doc, source : IYAMLDocument;
  sequence : IYAMLSequence;
  node : IYAMLValue;
begin
  doc := TYAML.CreateSequence;
  sequence := doc.AsSequence;
  source := TYAML.LoadFromString('{k: [1, 2]}');
  node := source.AsMapping['k'].Clone;
  sequence.AddValue(node);
  Assert.IsTrue(SameNode(sequence, node.Parent));
  Assert.IsTrue(SameNode(node, sequence[0]));
  Assert.AreEqual('[[1,2]]', CompactJSON(doc));
end;

procedure TYAMLEditingTests.AddValueNode_AttachedNodeRaises;
var
  doc, source : IYAMLDocument;
  sequence : IYAMLSequence;
  attached : IYAMLValue;
begin
  doc := TYAML.CreateSequence;
  sequence := doc.AsSequence;
  source := TYAML.LoadFromString('{k: [1, 2]}');
  attached := source.AsMapping['k'];
  Assert.WillRaise(
    procedure
    begin
      sequence.AddValue(attached);
    end, EArgumentException);
  Assert.WillRaise(
    procedure
    begin
      sequence.AddValue(attached.AsSequence[0]);
    end, EArgumentException);
  Assert.WillRaise(
    procedure
    begin
      attached.AsSequence.AddValue(attached.AsSequence[0]);
    end, EArgumentException, 'adding an item to its own sequence again');
  Assert.AreEqual(0, sequence.Count);
  Assert.AreEqual(2, attached.AsSequence.Count);
  Assert.IsTrue(SameNode(source.Root, attached.Parent));
end;

procedure TYAMLEditingTests.AddValueNode_NilRaises;
var
  sequenceDoc, setDoc : IYAMLDocument;
  sequence : IYAMLSequence;
  aSet : IYAMLSet;
  nothing : IYAMLValue;
begin
  sequenceDoc := TYAML.CreateSequence;
  sequence := sequenceDoc.AsSequence;
  setDoc := TYAML.CreateSet;
  aSet := setDoc.AsSet;
  nothing := nil;
  Assert.WillRaise(
    procedure
    begin
      sequence.AddValue(nothing);
    end, EArgumentNilException);
  Assert.WillRaise(
    procedure
    begin
      aSet.AddValue(nothing);
    end, EArgumentNilException);
end;

procedure TYAMLEditingTests.AddValueNode_SelfOrAncestorRaises;
var
  doc : IYAMLDocument;
  sequence, inner : IYAMLSequence;
begin
  doc := TYAML.CreateSequence;
  sequence := doc.AsSequence;
  inner := sequence.AddSequence().AddSequence();
  Assert.WillRaise(
    procedure
    begin
      sequence.AddValue(sequence);
    end, EArgumentException);
  Assert.WillRaise(
    procedure
    begin
      inner.AddValue(sequence);
    end, EArgumentException);
  Assert.AreEqual(1, sequence.Count);
  Assert.AreEqual(0, inner.Count);
end;

procedure TYAMLEditingTests.AddValueNode_SetIgnoresDuplicateAndLeavesItDetached;
var
  doc : IYAMLDocument;
  aSet : IYAMLSet;
  duplicate, fresh : IYAMLValue;
begin
  doc := TYAML.CreateSet;
  aSet := doc.AsSet;
  aSet.AddValue('a');
  duplicate := TYAML.LoadFromString('a').Root;
  aSet.AddValue(duplicate);
  Assert.AreEqual(1, aSet.Count);
  Assert.IsTrue(duplicate.Parent = nil);

  fresh := TYAML.LoadFromString('b').Root;
  aSet.AddValue(fresh);
  Assert.AreEqual('a,b', ItemsOf(aSet));
  Assert.IsTrue(SameNode(aSet, fresh.Parent));
end;

procedure TYAMLEditingTests.Parse_AliasesStillShareOneNode;
var
  doc : IYAMLDocument;
  mapping : IYAMLMapping;
  base, name : IYAMLValue;
begin
  // the parsers add an alias's node itself, which stays in the collection of its anchor
  doc := TYAML.LoadFromString(
    'base: &b {k: 1}' + sLineBreak +
    'name: &s hello' + sLineBreak +
    'flow: [*b, *s]' + sLineBreak +
    'block:' + sLineBreak +
    '  - *b' + sLineBreak +
    'copy: *b' + sLineBreak +
    'tags: !!set' + sLineBreak +
    '  ? *s' + sLineBreak +
    'merged:' + sLineBreak +
    '  <<: *b' + sLineBreak +
    '  z: 2');
  mapping := doc.AsMapping;
  base := mapping['base'];
  name := mapping['name'];
  Assert.IsTrue(SameNode(base, mapping['flow'].AsSequence[0]));
  Assert.IsTrue(SameNode(name, mapping['flow'].AsSequence[1]));
  Assert.IsTrue(SameNode(base, mapping['block'].AsSequence[0]));
  Assert.IsTrue(SameNode(base, mapping['copy']));
  Assert.IsTrue(mapping['tags'].IsSet);
  Assert.IsTrue(SameNode(name, mapping['tags'].AsSet[0]));
  Assert.IsTrue(SameNode(mapping, base.Parent), 'a shared node stays where its anchor is');
  Assert.IsTrue(SameNode(mapping, name.Parent));
  Assert.AreEqual(1, mapping['merged'].AsMapping.I['k']);
  Assert.AreEqual(2, mapping['merged'].AsMapping.I['z']);
end;

{ IYAMLValue.Clone }

procedure TYAMLEditingTests.Clone_ScalarKeepsTypeTextAndTag;
var
  doc : IYAMLDocument;
  mapping : IYAMLMapping;
  original, cloned : IYAMLValue;
  i : integer;
  key : string;
begin
  doc := TYAML.LoadFromString(
    'hex: 0x1F' + sLineBreak +
    'float: 1.50' + sLineBreak +
    'big: 123456789012345678901234567890' + sLineBreak +
    'str: !!str 42' + sLineBreak +
    'local: !thing value' + sLineBreak +
    'when: 2024-01-15T10:30:00Z' + sLineBreak +
    'nothing: ~' + sLineBreak +
    'flag: yes' + sLineBreak +
    'quoted: ''true''');
  mapping := doc.AsMapping;
  for i := 0 to mapping.Count - 1 do
  begin
    key := mapping.Keys[i];
    original := mapping[key];
    cloned := original.Clone;
    Assert.IsFalse(SameNode(original, cloned), key);
    Assert.IsTrue(original.ValueType = cloned.ValueType, key);
    Assert.AreEqual(original.RawValue, cloned.RawValue, key);
    Assert.AreEqual(original.Tag, cloned.Tag, key);
    Assert.AreEqual(original.TagInfo = nil, cloned.TagInfo = nil, key);
    if original.TagInfo <> nil then
      Assert.AreEqual(original.TagInfo.ResolvedTag, cloned.TagInfo.ResolvedTag, key);
  end;
  Assert.AreEqual(Int64(31), mapping['hex'].Clone.AsInteger);
  Assert.AreEqual('1.50', mapping['float'].Clone.RawValue);
  Assert.IsTrue(mapping['str'].Clone.IsString);
  Assert.AreEqual('!thing', mapping['local'].Clone.Tag);
  Assert.IsTrue(mapping['when'].Clone.IsTimeStamp);
  Assert.AreEqual(Double(mapping['when'].AsUTCDateTime), Double(mapping['when'].Clone.AsUTCDateTime), 0);
  Assert.IsTrue(mapping['nothing'].Clone.IsNull);
  Assert.IsTrue(mapping['flag'].Clone.AsBoolean);
  Assert.IsTrue(mapping['quoted'].Clone.IsString);
end;

procedure TYAMLEditingTests.Clone_IsDetached;
var
  doc : IYAMLDocument;
  node, cloned : IYAMLValue;
begin
  doc := TYAML.LoadFromString('a: {b: [1]}');
  node := doc.AsMapping['a'];
  cloned := node.Clone;
  Assert.IsTrue(cloned.Parent = nil);
  Assert.IsTrue(SameNode(cloned, cloned.AsMapping['b'].Parent), 'the copied items are in the copy');
  Assert.IsTrue(SameNode(cloned.AsMapping['b'], cloned.AsMapping['b'].AsSequence[0].Parent));
  Assert.IsTrue(SameNode(doc.Root, node.Parent), 'the original keeps its parent');
  Assert.IsTrue(doc.Root.Clone.Parent = nil);
  Assert.IsTrue(node.AsMapping['b'].AsSequence[0].Clone.Parent = nil);
end;

procedure TYAMLEditingTests.Clone_IsIndependent;
var
  doc : IYAMLDocument;
  original : IYAMLValue;
  cloned : IYAMLMapping;
  before, clonedText : string;
begin
  doc := TYAML.LoadFromString(
    'a: 1' + sLineBreak +
    'list: [x, {k: v}]' + sLineBreak +
    'm: {n: 2}');
  original := doc.Root;
  cloned := original.Clone.AsMapping;
  before := TYAML.WriteToJSONString(original);
  Assert.AreEqual(before, TYAML.WriteToJSONString(cloned));

  // change the copy
  cloned.AddOrSetValue('a', 100);
  cloned['list'].AsSequence.Delete(0);
  cloned['list'].AsSequence[0].AsMapping.AddOrSetValue('k', 'changed');
  cloned['m'].AsMapping.Remove('n');
  cloned.AddOrSetValue('new', true);
  Assert.AreEqual(before, TYAML.WriteToJSONString(original), 'changing the copy leaves the original alone');

  // change the original
  clonedText := TYAML.WriteToJSONString(cloned);
  original.AsMapping['list'].AsSequence.AddValue('y');
  original.AsMapping['list'].AsSequence[1].AsMapping.AddOrSetValue('k', 'also changed');
  original.AsMapping['m'].AsMapping.AddOrSetValue('n', 3);
  original.AsMapping.Remove('a');
  Assert.AreEqual(clonedText, TYAML.WriteToJSONString(cloned), 'changing the original leaves the copy alone');
end;

procedure TYAMLEditingTests.Clone_WritesTheSameYAMLAndJSON;
var
  doc : IYAMLDocument;
  cloned : IYAMLValue;
  flowOptions : IYAMLEmitOptions;
begin
  doc := TYAML.LoadFromString(
    'name: test # same line' + sLineBreak +
    'count: 0x1F' + sLineBreak +
    'ratio: 1.50' + sLineBreak +
    'big: 123456789012345678901234567890' + sLineBreak +
    'tagged: !!str 42' + sLineBreak +
    'local: !thing v' + sLineBreak +
    'when: 2024-01-15T10:30:00Z' + sLineBreak +
    'empty: ~' + sLineBreak +
    '# before the list' + sLineBreak +
    'list:' + sLineBreak +
    '  - a' + sLineBreak +
    '  - {x: 1, y: [true, false]}' + sLineBreak +
    '  - []' + sLineBreak +
    'set: !!set {p, q}' + sLineBreak +
    'base: &b {k: 1}' + sLineBreak +
    'ref: *b' + sLineBreak +
    'text: |' + sLineBreak +
    '  line one' + sLineBreak +
    '  line two' + sLineBreak);
  cloned := doc.Root.Clone;

  Assert.AreEqual(TYAML.WriteToString(doc.Root, doc.Options), TYAML.WriteToString(cloned, doc.Options), 'YAML');
  Assert.AreEqual(TYAML.WriteToJSONString(doc.Root, doc.Options), TYAML.WriteToJSONString(cloned, doc.Options), 'JSON');
  Assert.AreEqual(TYAML.WriteToJSON5String(doc.Root, doc.Options), TYAML.WriteToJSON5String(cloned, doc.Options), 'JSON5');

  flowOptions := TYAML.CreateWriterOptions;
  flowOptions.Format := TYAMLOutputFormat.yofFlow;
  flowOptions.PrettyPrint := false;
  Assert.AreEqual(TYAML.WriteToString(doc.Root, flowOptions), TYAML.WriteToString(cloned, flowOptions), 'flow YAML');
  Assert.AreEqual(TYAML.WriteToJSONString(doc.Root, flowOptions), TYAML.WriteToJSONString(cloned, flowOptions), 'compact JSON');
end;

procedure TYAMLEditingTests.Clone_WritesTheSameJSON5;
var
  options : IYAMLParserOptions;
  doc : IYAMLDocument;
  cloned : IYAMLValue;
begin
  options := TYAML.CreateParserOptions;
  options.InputFormat := TYAMLInputFormat.yifJSON5;
  doc := TYAML.LoadFromString(
    '// about the settings' + sLineBreak +
    '{' + sLineBreak +
    '  // the host' + sLineBreak +
    '  host: ''localhost'',' + sLineBreak +
    '  port: 0x1F90, // 8080' + sLineBreak +
    '  ratio: .5,' + sLineBreak +
    '  limits: [Infinity, -Infinity, NaN, +1],' + sLineBreak +
    '  list: [' + sLineBreak +
    '    1,' + sLineBreak +
    '    // after the last item' + sLineBreak +
    '  ],' + sLineBreak +
    '  // at the end' + sLineBreak +
    '}', options);
  cloned := doc.Root.Clone;

  Assert.AreEqual(TYAML.WriteToJSON5String(doc.Root, doc.Options), TYAML.WriteToJSON5String(cloned, doc.Options), 'JSON5');
  Assert.AreEqual(TYAML.WriteToJSONString(doc.Root, doc.Options), TYAML.WriteToJSONString(cloned, doc.Options), 'JSON');
  Assert.AreEqual(TYAML.WriteToString(doc.Root, doc.Options), TYAML.WriteToString(cloned, doc.Options), 'YAML');
  Assert.Contains(TYAML.WriteToJSON5String(cloned, doc.Options), '0x1F90');
  Assert.Contains(TYAML.WriteToJSON5String(cloned, doc.Options), '// after the last item');
end;

procedure TYAMLEditingTests.Clone_KeepsComments;
var
  doc : IYAMLDocument;
  node : IYAMLSequence;
  cloned : IYAMLValue;
begin
  doc := TYAML.CreateMapping;
  node := doc.AsMapping.AddOrSetSequence('s');
  node.AddComment('before');
  node.Comment := 'after';
  node.AddEndComment('end');
  node.AddValue('x').Comment := 'item';

  cloned := node.Clone;
  Assert.AreEqual('after', cloned.Comment);
  Assert.AreEqual(1, Integer(Length(cloned.Comments)));
  Assert.AreEqual('before', cloned.Comments[0]);
  Assert.AreEqual(1, Integer(Length(cloned.AsSequence.EndComments)));
  Assert.AreEqual('end', cloned.AsSequence.EndComments[0]);
  Assert.AreEqual('item', cloned.AsSequence[0].Comment);

  // the copy's comments are its own
  cloned.AddComment('more');
  cloned.Comment := 'changed';
  cloned.AsSequence.ClearEndComments;
  cloned.AsSequence[0].Comment := '';
  Assert.AreEqual(1, Integer(Length(node.Comments)));
  Assert.AreEqual('after', node.Comment);
  Assert.IsTrue(node.HasEndComments);
  Assert.AreEqual('item', node[0].Comment);
end;

procedure TYAMLEditingTests.Clone_AliasSharedNodeGivesTwoCopies;
var
  doc : IYAMLDocument;
  cloned : IYAMLMapping;
begin
  doc := TYAML.LoadFromString('a: &x {k: 1}' + sLineBreak + 'b: *x' + sLineBreak + 'c: [*x]');
  Assert.IsTrue(SameNode(doc.AsMapping['a'], doc.AsMapping['b']), 'the parser shares the node');

  cloned := doc.Root.Clone.AsMapping;
  Assert.IsFalse(SameNode(cloned['a'], cloned['b']));
  Assert.IsFalse(SameNode(cloned['a'], cloned['c'].AsSequence[0]));
  Assert.IsFalse(SameNode(doc.AsMapping['a'], cloned['a']));
  Assert.IsTrue(SameNode(cloned, cloned['b'].Parent), 'each copy is in the place it was copied to');
  Assert.IsTrue(SameNode(cloned['c'], cloned['c'].AsSequence[0].Parent));

  cloned['b'].AsMapping.AddOrSetValue('k', 2);
  Assert.AreEqual(1, cloned['a'].AsMapping.I['k']);
  Assert.AreEqual(1, cloned['c'].AsSequence[0].AsMapping.I['k']);
  Assert.AreEqual(1, doc.AsMapping['a'].AsMapping.I['k']);
end;

procedure TYAMLEditingTests.Clone_SetStaysASet;
var
  doc : IYAMLDocument;
  cloned : IYAMLValue;
  aSet : IYAMLSet;
begin
  doc := TYAML.LoadFromString('!!set {a, b}');
  Assert.IsTrue(doc.Root.IsSet);
  cloned := doc.Root.Clone;
  Assert.IsTrue(cloned.IsSet);
  aSet := cloned.AsSet;
  Assert.AreEqual('a,b', ItemsOf(aSet));
  aSet.AddValue('a');
  Assert.AreEqual(2, aSet.Count, 'the copy knows the values it has');
  aSet.AddValue('c');
  Assert.AreEqual('a,b,c', ItemsOf(aSet));
  Assert.AreEqual(2, doc.Root.AsSet.Count);
  Assert.AreEqual(doc.Root.Tag, cloned.Tag);
end;

procedure TYAMLEditingTests.Clone_EmptyCollections;
var
  doc, empty : IYAMLDocument;
  cloned : IYAMLMapping;
begin
  doc := TYAML.LoadFromString('m: {}' + sLineBreak + 's: []');
  cloned := doc.Root.Clone.AsMapping;
  Assert.IsTrue(cloned['m'].IsMapping);
  Assert.AreEqual(0, cloned['m'].AsMapping.Count);
  Assert.IsTrue(cloned['s'].IsSequence);
  Assert.AreEqual(0, cloned['s'].AsSequence.Count);
  Assert.AreEqual(TYAML.WriteToJSONString(doc.Root), TYAML.WriteToJSONString(cloned));

  empty := TYAML.CreateSequence;
  Assert.AreEqual(0, empty.Root.Clone.AsSequence.Count);
  empty := TYAML.CreateMapping;
  Assert.AreEqual(0, empty.Root.Clone.AsMapping.Count);
end;

procedure TYAMLEditingTests.Clone_ThenAttach;
var
  doc : IYAMLDocument;
  items : IYAMLSequence;
  item : IYAMLValue;
  i : integer;
begin
  doc := TYAML.LoadFromString('template: {name: x}' + sLineBreak + 'items: []');
  items := doc.AsMapping['items'].AsSequence;
  for i := 1 to 3 do
  begin
    item := doc.AsMapping['template'].Clone;
    item.AsMapping.AddOrSetValue('name', 'item' + IntToStr(i));
    items.AddValue(item);
  end;
  Assert.AreEqual('{"template":{"name":"x"},"items":[{"name":"item1"},{"name":"item2"},{"name":"item3"}]}', CompactJSON(doc));
end;

{ the null a missing key or index gives }

procedure TYAMLEditingTests.MissingKeyOrIndex_GivesADetachedNull;
var
  doc, target : IYAMLDocument;
  missingKey, missingIndex : IYAMLValue;
begin
  doc := TYAML.LoadFromString('m: {a: 1}' + sLineBreak + 's: [x]');
  missingKey := doc.AsMapping['m'].AsMapping['nothing'];
  missingIndex := doc.AsMapping['s'].AsSequence[5];
  Assert.IsTrue(missingKey.IsNull);
  Assert.IsTrue(missingKey.Parent = nil, 'it is in no collection');
  Assert.IsTrue(missingIndex.IsNull);
  Assert.IsTrue(missingIndex.Parent = nil);
  Assert.AreEqual(1, doc.AsMapping['m'].AsMapping.Count, 'reading a missing key adds nothing');

  // so it can be added like any detached node
  target := TYAML.CreateSequence;
  target.AsSequence.AddValue(missingKey);
  target.AsSequence.AddValue(missingIndex);
  Assert.AreEqual('[null,null]', CompactJSON(target));
end;

{ typed Add* and Insert* on a set }

procedure TYAMLEditingTests.Set_DuplicateGivesADetachedNode;
var
  doc : IYAMLDocument;
  aSet : IYAMLSet;
  added, duplicate, inserted : IYAMLValue;
begin
  doc := TYAML.CreateSet;
  aSet := doc.AsSet;
  added := aSet.AddValue('a');
  Assert.IsTrue(SameNode(aSet, added.Parent));

  duplicate := aSet.AddValue('a');
  Assert.AreEqual(1, aSet.Count);
  Assert.IsFalse(SameNode(added, duplicate));
  Assert.IsTrue(duplicate.Parent = nil, 'the set did not take it');

  inserted := aSet.InsertValue(0, 'a');
  Assert.AreEqual(1, aSet.Count);
  Assert.IsTrue(inserted.Parent = nil);

  // a detached node can go elsewhere
  doc := TYAML.CreateSequence;
  doc.AsSequence.AddValue(duplicate);
  Assert.IsTrue(SameNode(doc.Root, duplicate.Parent));
end;

{ the A[] and O[] setters }

procedure TYAMLEditingTests.MappingSetters_SetParent;
var
  doc, other : IYAMLDocument;
  list : IYAMLSequence;
  map : IYAMLMapping;
begin
  doc := TYAML.CreateMapping;
  other := TYAML.LoadFromString('l: [1, 2]' + sLineBreak + 'm: {k: v}');
  list := other.AsMapping['l'].Clone.AsSequence;
  map := other.AsMapping['m'].Clone.AsMapping;
  doc.AsMapping.A['list'] := list;
  doc.AsMapping.O['map'] := map;
  Assert.IsTrue(SameNode(doc.Root, list.Parent));
  Assert.IsTrue(SameNode(doc.Root, map.Parent));
  Assert.AreEqual('{"list":[1,2],"map":{"k":"v"}}', CompactJSON(doc));
end;

procedure TYAMLEditingTests.MappingSetters_AttachedNodeRaises;
var
  doc, other : IYAMLDocument;
  mapping : IYAMLMapping;
begin
  doc := TYAML.CreateMapping;
  mapping := doc.AsMapping;
  other := TYAML.LoadFromString('l: [1, 2]' + sLineBreak + 'm: {k: v}');
  Assert.WillRaise(
    procedure
    begin
      mapping.A['list'] := other.AsMapping['l'].AsSequence;
    end, EArgumentException);
  Assert.WillRaise(
    procedure
    begin
      mapping.O['map'] := other.AsMapping['m'].AsMapping;
    end, EArgumentException);
  Assert.WillRaise(
    procedure
    begin
      mapping.O['self'] := mapping;
    end, EArgumentException);
  Assert.AreEqual(0, mapping.Count);
end;

procedure TYAMLEditingTests.MappingSetters_NilWritesNull;
var
  doc : IYAMLDocument;
  list : IYAMLSequence;
  map : IYAMLMapping;
begin
  doc := TYAML.CreateMapping;
  list := nil;
  map := nil;
  doc.AsMapping.A['list'] := list;
  doc.AsMapping.O['map'] := map;
  Assert.IsTrue(doc.AsMapping['list'].IsNull);
  Assert.IsTrue(doc.AsMapping['map'].IsNull);
  Assert.AreEqual('{"list":null,"map":null}', CompactJSON(doc));
end;

procedure TYAMLEditingTests.SequenceSetters_SetParent;
var
  doc : IYAMLDocument;
  sequence : IYAMLSequence;
  list : IYAMLSequence;
  map : IYAMLMapping;
  old : IYAMLValue;
begin
  doc := TYAML.LoadFromString('[a, b]');
  sequence := doc.AsSequence;
  old := sequence[0];
  list := TYAML.LoadFromString('[1]').Root.AsSequence;
  map := TYAML.LoadFromString('{k: v}').Root.AsMapping;
  sequence.A[0] := list;
  sequence.O[1] := map;
  Assert.IsTrue(SameNode(sequence, list.Parent));
  Assert.IsTrue(SameNode(sequence, map.Parent));
  Assert.IsTrue(old.Parent = nil, 'the item replaced forgets the sequence');
  Assert.AreEqual('[[1],{"k":"v"}]', CompactJSON(doc));
end;

procedure TYAMLEditingTests.SequenceSetters_AttachedNodeRaises;
var
  doc, other : IYAMLDocument;
  sequence : IYAMLSequence;
begin
  doc := TYAML.LoadFromString('[a, b]');
  sequence := doc.AsSequence;
  other := TYAML.LoadFromString('l: [1, 2]' + sLineBreak + 'm: {k: v}');
  Assert.WillRaise(
    procedure
    begin
      sequence.A[0] := other.AsMapping['l'].AsSequence;
    end, EArgumentException);
  Assert.WillRaise(
    procedure
    begin
      sequence.O[1] := other.AsMapping['m'].AsMapping;
    end, EArgumentException);
  Assert.WillRaise(
    procedure
    begin
      sequence.A[0] := sequence;
    end, EArgumentException);
  Assert.AreEqual('a,b', ItemsOf(sequence));
end;

procedure TYAMLEditingTests.SequenceSetters_NilWritesNull;
var
  doc : IYAMLDocument;
  list : IYAMLSequence;
  map : IYAMLMapping;
begin
  doc := TYAML.LoadFromString('[a, b]');
  list := nil;
  map := nil;
  doc.AsSequence.A[0] := list;
  doc.AsSequence.O[1] := map;
  Assert.AreEqual('[null,null]', CompactJSON(doc));
  Assert.IsTrue(SameNode(doc.Root, doc.AsSequence[0].Parent));
end;

procedure TYAMLEditingTests.SequenceSetters_SameNodeChangesNothing;
var
  doc : IYAMLDocument;
  sequence : IYAMLSequence;
  child : IYAMLSequence;
begin
  doc := TYAML.LoadFromString('[[1], x]');
  sequence := doc.AsSequence;
  child := sequence.A[0];
  sequence.A[0] := child;
  Assert.IsTrue(SameNode(sequence, child.Parent));
  Assert.IsTrue(SameNode(child, sequence[0]));
  Assert.AreEqual('[[1],"x"]', CompactJSON(doc));
end;

initialization
  TDUnitX.RegisterTestFixture(TYAMLEditingTests);

end.

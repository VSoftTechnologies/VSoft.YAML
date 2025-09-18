unit VSoft.YAML.Tests.Basics;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TBasicYAMLTests = class

  public

    [Test]
    procedure TestBasicParsing;

    [Test]
    procedure TestSequenceParsing;

    [Test]
    procedure TestNestedStructures;

    [Test]
    procedure TestTimeStamps;

    [Test]
    procedure TestValuewithPeriod;

  end;


implementation


{ TBasicYAMLTests }

uses VSoft.YAML;

procedure TBasicYAMLTests.TestBasicParsing;
var
  YAMLText: string;
  doc : IYAMLDocument;
begin
  YAMLText :=
    '# comment'  + sLineBreak +
    '---' + sLineBreak +
    '# comment'  + sLineBreak +
    'name: John Doe' + sLineBreak +
    'age: 30' + sLineBreak +
    'city: New York';

  doc := TYAML.LoadFromString(YAMLText);
  Assert.IsNotNull(doc.Root, 'LoadFromString returned null');
  Assert.AreNotEqual(doc.Root.ValueType, TYAMLValueType.vtNull);

  //check the values
  Assert.AreEqual('John Doe', doc.Root.Values['name'].AsString );
  Assert.AreEqual<Int64>(30, doc.Root.Values['age'].AsInteger);
  Assert.AreEqual('New York', doc.Root.Values['city'].AsString);

end;

procedure TBasicYAMLTests.TestNestedStructures;
var
  YAMLText : string;
  doc : IYAMLDocument;
begin
  YAMLText :=
    '---'  + sLineBreak +
    '# comment'  + sLineBreak +
    'person:' + sLineBreak +
    '  name: Jane Smith' + sLineBreak +
    '  age: 25' + sLineBreak +
    '  hobbies:' + sLineBreak +
    '    - reading' + sLineBreak +
    '    - swimming' + sLineBreak +
    '    - coding' + sLineBreak +
    'company: ACME Corp' + sLineBreak +
    'employees:' + sLineBreak +
    '  - name: Alice' + sLineBreak +
    '    role: Developer' + sLineBreak +
    '  - name: Bob' + sLineBreak +
    '    role: Designer';

  doc := TYAML.LoadFromString(YAMLText);
  Assert.IsNotNull(doc.Root, 'LoadFromString returned null');
  Assert.AreNotEqual(doc.Root.ValueType, TYAMLValueType.vtNull);

  Assert.AreEqual('Jane Smith',doc.Root.Values['person'].Values['name'].AsString);
  Assert.AreEqual<Int64>(25, doc.Root.Values['person'].Values['age'].AsInteger);
  Assert.AreEqual('ACME Corp', doc.Root.Values['company'].AsString);
  Assert.AreEqual(2,doc.Root.Values['employees'].AsSequence.Count);
  Assert.AreEqual(3, doc.Root.Values['person'].Values['hobbies'].AsSequence.Count);


end;

procedure TBasicYAMLTests.TestSequenceParsing;
var
  YAMLText: string;
  doc: IYAMLDocument;
  FruitsSequence: IYAMLSequence;
begin
  YAMLText :=
    'fruits:' + sLineBreak +
    '  - apple' + sLineBreak +
    '  - banana' + sLineBreak +
    '  - orange';

    doc := TYAML.LoadFromString(YAMLText);
    Assert.IsNotNull(doc.Root, 'LoadFromString returned null');
    Assert.AreNotEqual(doc.Root.ValueType, TYAMLValueType.vtNull);

    FruitsSequence := doc.Root.Values['fruits'].AsSequence;
    Assert.AreNotEqual(FruitsSequence.ValueType, TYAMLValueType.vtNull);
    Assert.AreEqual(3, FruitsSequence.Count);

    Assert.AreEqual('apple', FruitsSequence.Items[0].AsString);
    Assert.AreEqual('banana', FruitsSequence.Items[1].AsString);
    Assert.AreEqual('orange', FruitsSequence.Items[2].AsString);


end;

procedure TBasicYAMLTests.TestTimeStamps;
var
  YAMLText: string;
  doc : IYAMLDocument;
begin
  YAMLText :=
    'timestamp1: 2025-05-04' + sLineBreak +
    'timestamp2: 2023-01-01T08:45:30:' + sLineBreak +
    'timestamp3: 2023-12-25T14:30:15+05:30';

  doc := TYAML.LoadFromString(YAMLText);
  Assert.IsTrue(doc.Root.Values['timestamp1'].IsTimeStamp);
  Assert.IsTrue(doc.Root.Values['timestamp2'].IsTimeStamp);
  Assert.IsTrue(doc.Root.Values['timestamp2'].IsTimeStamp);

end;

procedure TBasicYAMLTests.TestValuewithPeriod;
var
  YAMLText: string;
  doc : IYAMLDocument;
  expected : string;
  actual : string;
begin
  YAMLText :=
    'path: ./LICENSE.txt';

  doc := TYAML.LoadFromString(YAMLText);
  Assert.IsNotNull(doc.Root, 'LoadFromString returned null');

  expected := './LICENSE.txt';
  actual := doc.Root.AsMapping['path'].AsString;
  Assert.AreEqual(expected, actual);

end;

initialization
  TDUnitX.RegisterTestFixture(TBasicYAMLTests);


end.

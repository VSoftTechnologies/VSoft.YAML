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

    [Test]
    procedure TestUnquotedStringStartingWithNumber;

    [Test]
    procedure TestCommaInUnquotedString;

    [Test]
    procedure TestNestedUnquotedStringStartingWithNumber;

    [Test]
    procedure TestNumberPrefixFollowedByTokenIsString;

    [Test]
    procedure TestFilenameWithDigitSeparatorsIsString;

    [Test]
    procedure TestRadixNumberPrefixFollowedByContentIsString;

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

procedure TBasicYAMLTests.TestUnquotedStringStartingWithNumber;
var
  yamlText : string;
  doc : IYAMLDocument;
begin
  // Unquoted values that start with a digit but are not valid numbers must
  // be parsed as strings without splitting or inserting extra spaces.
  yamlText :=
    'name: John Doe' + sLineBreak +
    'SHA: 4B599A8C9';

  doc := TYAML.LoadFromString(yamlText);
  Assert.AreEqual('John Doe', doc.Root.Values['name'].AsString, 'name value incorrect');
  Assert.AreEqual('4B599A8C9', doc.Root.Values['SHA'].AsString,
    'SHA value must be the full unquoted string, not split by spaces');
end;

procedure TBasicYAMLTests.TestCommaInUnquotedString;
var
  yamlText : string;
  doc : IYAMLDocument;
begin
  // Commas are only special inside flow collections ([..], {..}).
  // In a block scalar value, a comma must be treated as plain text.
  yamlText :=
    'name: John, Doe' + sLineBreak +
    'age: 30';

  doc := TYAML.LoadFromString(yamlText);
  Assert.AreEqual('John, Doe', doc.Root.Values['name'].AsString,
    'Comma in block scalar value must not split the string');
  Assert.AreEqual<Int64>(30, doc.Root.Values['age'].AsInteger,
    'age value should still parse correctly');
end;

procedure TBasicYAMLTests.TestNestedUnquotedStringStartingWithNumber;
var
  yamlText : string;
  doc : IYAMLDocument;
begin
  // Unquoted value inside a nested mapping that starts with digits but is
  // not a valid number must be parsed as a plain string.
  yamlText :=
    'variables:' + sLineBreak +
    '  packageSource: 11AndAbove';

  doc := TYAML.LoadFromString(yamlText);
  Assert.IsNotNull(doc.Root, 'LoadFromString returned null');
  Assert.AreEqual('11AndAbove',
    doc.Root.Values['variables'].Values['packageSource'].AsString,
    'packageSource value must be the full unquoted string');
end;

procedure TBasicYAMLTests.TestNumberPrefixFollowedByTokenIsString;
var
  yamlText : string;
  doc : IYAMLDocument;
begin
  // A plain scalar whose numeric prefix is immediately followed by a non
  // alphanumeric content character (here a '$' beginning a DPM token) is not a
  // number - it must be read whole. Previously the lexer read the digits as a
  // number token and rejoined the remainder with a spurious space, turning
  // '10$compilerCodeName$' into '10 $compilerCodeName$' (-> '10 Seattle').
  yamlText :=
    'a: 10$compilerCodeName$' + sLineBreak +
    'b: 10.0$compilerCodeName$' + sLineBreak +
    'c: 1$compilerCodeName$';

  doc := TYAML.LoadFromString(yamlText);
  Assert.AreEqual('10$compilerCodeName$', doc.Root.Values['a'].AsString,
    'integer prefix before a token must not split the scalar');
  Assert.AreEqual('10.0$compilerCodeName$', doc.Root.Values['b'].AsString,
    'float prefix before a token must not split the scalar');
  Assert.AreEqual('1$compilerCodeName$', doc.Root.Values['c'].AsString,
    'single-digit prefix before a token must not split the scalar');
end;

procedure TBasicYAMLTests.TestFilenameWithDigitSeparatorsIsString;
var
  yamlText : string;
  doc : IYAMLDocument;
  resources : IYAMLSequence;
  flowSeq : IYAMLSequence;
begin
  // Issue #7 - Hugo front matter listing image filenames. '001_0466.JPG' begins with
  // what looks like a number using '_' digit separators, but the '.JPG' means it is
  // a plain scalar. The lexer dropped the separators while reading the numeric
  // prefix and then read the remainder onto the same (now separator-less) text,
  // so the value came back as '0010466.JPG'.
  yamlText :=
    '---' + sLineBreak +
    'title: "Back Yard, 2010"' + sLineBreak +
    'description: "Our back yard in 2010"' + sLineBreak +
    'draft: false' + sLineBreak +
    'albumthumb: misc/back-yard-2010/001_0467.JPG' + sLineBreak +
    'resources:' + sLineBreak +
    '- BackYard.jpg' + sLineBreak +
    '- 001_0466.JPG' + sLineBreak +
    '- 001_0467.JPG' + sLineBreak +
    '- 001_0468.JPG' + sLineBreak +
    '- 001_0469.JPG' + sLineBreak +
    '- 001_0470.JPG' + sLineBreak +
    '- 001_0471.JPG' + sLineBreak +
    'date: 2010-06-28T09:43:40.000-07:00' + sLineBreak +
    '---';

  doc := TYAML.LoadFromString(yamlText);
  Assert.AreEqual('misc/back-yard-2010/001_0467.JPG', doc.Root.Values['albumthumb'].AsString);

  resources := doc.Root.Values['resources'].AsSequence;
  Assert.AreEqual(7, resources.Count);
  Assert.AreEqual('BackYard.jpg', resources.Items[0].AsString);
  Assert.IsTrue(resources.Items[1].IsString, '001_0466.JPG must be a string');
  Assert.AreEqual('001_0466.JPG', resources.Items[1].AsString);
  Assert.AreEqual('001_0467.JPG', resources.Items[2].AsString);
  Assert.AreEqual('001_0471.JPG', resources.Items[6].AsString);
  Assert.IsTrue(doc.Root.Values['date'].IsTimeStamp, 'date should still be a timestamp');

  // Same in other positions: a float-like prefix, a mapping value and a flow sequence.
  yamlText :=
    'a: 1_000.5_x' + sLineBreak +
    'b: 1_0.2.3' + sLineBreak +
    'c: [001_0466.JPG, 2_0b]' + sLineBreak +
    'd: 4_200';

  doc := TYAML.LoadFromString(yamlText);
  Assert.AreEqual('1_000.5_x', doc.Root.Values['a'].AsString);
  Assert.AreEqual('1_0.2.3', doc.Root.Values['b'].AsString);
  flowSeq := doc.Root.Values['c'].AsSequence;
  Assert.AreEqual(2, flowSeq.Count);
  Assert.AreEqual('001_0466.JPG', flowSeq.Items[0].AsString);
  Assert.AreEqual('2_0b', flowSeq.Items[1].AsString);
  // A real number with digit separators is still a number.
  Assert.IsTrue(doc.Root.Values['d'].IsInteger, '4_200 should still be an integer');
  Assert.AreEqual<Int64>(4200, doc.Root.Values['d'].AsInteger);
end;

procedure TBasicYAMLTests.TestRadixNumberPrefixFollowedByContentIsString;
var
  yamlText : string;
  doc : IYAMLDocument;
begin
  // A hex, octal or binary prefix followed by plain-scalar content is not a number.
  // The lexer returned the radix digits as a token of their own, and the parser then
  // rejoined the remainder with a spurious space ('0x1F.png' -> '0x1F .png').
  yamlText :=
    'hex: 0x1F.png' + sLineBreak +
    'oct: 0o17.dat' + sLineBreak +
    'bin: 0b101.txt' + sLineBreak +
    'hexWord: 0xFFzz' + sLineBreak +
    'flow: [0x1F.png, 0xFF]' + sLineBreak +
    'num: 0x1F';

  doc := TYAML.LoadFromString(yamlText);
  Assert.AreEqual('0x1F.png', doc.Root.Values['hex'].AsString);
  Assert.AreEqual('0o17.dat', doc.Root.Values['oct'].AsString);
  Assert.AreEqual('0b101.txt', doc.Root.Values['bin'].AsString);
  Assert.AreEqual('0xFFzz', doc.Root.Values['hexWord'].AsString);
  Assert.AreEqual('0x1F.png', doc.Root.Values['flow'].AsSequence.Items[0].AsString);
  Assert.AreEqual<Int64>(255, doc.Root.Values['flow'].AsSequence.Items[1].AsInteger);
  // A real hex number is still a number.
  Assert.AreEqual<Int64>(31, doc.Root.Values['num'].AsInteger);
end;

initialization
  TDUnitX.RegisterTestFixture(TBasicYAMLTests);


end.

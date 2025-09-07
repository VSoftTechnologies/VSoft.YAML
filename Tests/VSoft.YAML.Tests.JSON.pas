unit VSoft.YAML.Tests.JSON;

interface

uses
  DUnitX.TestFramework,
  VSoft.YAML;

type
  [TestFixture]
  TJSONParsingTests = class

  public

    [Test]
    procedure TestSimpleJSONObject;

    [Test]
    procedure TestJSONArray;

    [Test]
    procedure TestNestedJSONStructure;

    [Test]
    procedure TestJSONDataTypes;

    [Test]
    procedure TestJSONStringsWithEscapes;

    [Test]
    procedure TestJSONNumbers;

    [Test]
    procedure TestJSONBooleanAndNull;

    [Test]
    procedure TestComplexJSONExample;

    [Test]
    procedure TestJSONArrayOfObjects;

    [Test]
    procedure TestJSONEmptyContainers;

    [Test]
    procedure TestJSONNestedArrays;

    [Test]
    procedure TestJSONMixedTypes;

    [Test]
    procedure TestJSONLargeNumbers;

    [Test]
    procedure TestJSONWhitespaceHandling;

    [Test]
    procedure TestJSONSpecialStringValues;

    [Test]
    procedure TestJSONDeepNesting;

  end;


implementation

uses 
  System.SysUtils;

{ TJSONParsingTests }

procedure TJSONParsingTests.TestSimpleJSONObject;
var
  jsonText: string;
  doc: IYAMLDocument;
begin
  jsonText := '{"name": "John Doe", "age": 30, "city": "New York"}';
  
  doc := TYAML.LoadFromString(jsonText);
  Assert.IsNotNull(doc.Root, 'LoadFromString returned null');
  Assert.AreEqual(TYAMLValueType.vtMapping, doc.Root.ValueType);
  
  Assert.AreEqual('John Doe', doc.Root.Values['name'].AsString);
  Assert.AreEqual<Int64>(30, doc.Root.Values['age'].AsInteger);
  Assert.AreEqual('New York', doc.Root.Values['city'].AsString);
end;

procedure TJSONParsingTests.TestJSONArray;
var
  jsonText: string;
  doc: IYAMLDocument;
  arrayValue: IYAMLSequence;
begin
  jsonText := '["apple", "banana", "cherry"]';
  
  doc := TYAML.LoadFromString(jsonText);
  Assert.IsNotNull(doc.Root, 'LoadFromString returned null');
  Assert.AreEqual(TYAMLValueType.vtSequence, doc.Root.ValueType);
  
  arrayValue := doc.Root.AsSequence;
  Assert.AreEqual(3, arrayValue.Count);
  Assert.AreEqual('apple', arrayValue.Items[0].AsString);
  Assert.AreEqual('banana', arrayValue.Items[1].AsString);
  Assert.AreEqual('cherry', arrayValue.Items[2].AsString);
end;

procedure TJSONParsingTests.TestNestedJSONStructure;
var
  jsonText: string;
  doc: IYAMLDocument;
begin
  jsonText := '{' +
    '"person": {' +
      '"name": "Jane Smith",' +
      '"age": 25,' +
      '"hobbies": ["reading", "swimming", "coding"]' +
    '},' +
    '"company": "ACME Corp",' +
    '"employees": [' +
      '{"name": "Alice", "role": "Developer"},' +
      '{"name": "Bob", "role": "Designer"}' +
    ']' +
  '}';
  
  doc := TYAML.LoadFromString(jsonText);
  Assert.IsNotNull(doc.Root, 'LoadFromString returned null');
  Assert.AreEqual(TYAMLValueType.vtMapping, doc.Root.ValueType);
  
  Assert.AreEqual('Jane Smith', doc.Root.Values['person'].Values['name'].AsString);
  Assert.AreEqual<Int64>(25, doc.Root.Values['person'].Values['age'].AsInteger);
  Assert.AreEqual('ACME Corp', doc.Root.Values['company'].AsString);
  Assert.AreEqual(2, doc.Root.Values['employees'].AsSequence.Count);
  Assert.AreEqual(3, doc.Root.Values['person'].Values['hobbies'].AsSequence.Count);
end;

procedure TJSONParsingTests.TestJSONDataTypes;
var
  jsonText: string;
  doc: IYAMLDocument;
begin
  jsonText := '{' +
    '"nullValue": null,' +
    '"boolTrue": true,' +
    '"boolFalse": false,' +
    '"intValue": 42,' +
    '"floatValue": 3.14159,' +
    '"stringValue": "Hello World"' +
  '}';
  
  doc := TYAML.LoadFromString(jsonText);
  Assert.IsNotNull(doc.Root, 'LoadFromString returned null');
  
  Assert.IsTrue(doc.Root.Values['nullValue'].IsNull);
  Assert.AreEqual(true, doc.Root.Values['boolTrue'].AsBoolean);
  Assert.AreEqual(false, doc.Root.Values['boolFalse'].AsBoolean);
  Assert.AreEqual<Int64>(42, doc.Root.Values['intValue'].AsInteger);
  Assert.AreEqual(3.14159, doc.Root.Values['floatValue'].AsFloat, 0.00001);
  Assert.AreEqual('Hello World', doc.Root.Values['stringValue'].AsString);
end;

procedure TJSONParsingTests.TestJSONStringsWithEscapes;
var
  jsonText: string;
  doc: IYAMLDocument;
begin
  jsonText := '{' +
    '"escaped": "Line 1\nLine 2\tTabbed",' +
    '"quotes": "She said, \"Hello!\"",' +
    '"unicode": "Caf\u00e9"' +
  '}';

  doc := TYAML.LoadFromString(jsonText);
  Assert.IsNotNull(doc.Root, 'LoadFromString returned null');

  // YAML parser preserves JSON escape sequences as literal strings
  Assert.AreEqual('Line 1' + #10 + 'Line 2' + #9 + 'Tabbed', doc.Root.Values['escaped'].AsString);
  Assert.AreEqual('She said, "Hello!"', doc.Root.Values['quotes'].AsString);
  Assert.AreEqual('Café', doc.Root.Values['unicode'].AsString);
end;

procedure TJSONParsingTests.TestJSONNumbers;
var
  jsonText: string;
  doc: IYAMLDocument;
begin
  jsonText := '{' +
    '"positiveInt": 123,' +
    '"negativeInt": -456,' +
    '"positiveFloat": 12.34,' +
    '"negativeFloat": -56.78,' +
    '"scientificNotation": 1.23e4,' +
    '"zero": 0' +
  '}';
  
  doc := TYAML.LoadFromString(jsonText);
  Assert.IsNotNull(doc.Root, 'LoadFromString returned null');
  
  Assert.AreEqual<Int64>(123, doc.Root.Values['positiveInt'].AsInteger);
  Assert.AreEqual<Int64>(-456, doc.Root.Values['negativeInt'].AsInteger);
  Assert.AreEqual(12.34, doc.Root.Values['positiveFloat'].AsFloat, 0.01);
  Assert.AreEqual(-56.78, doc.Root.Values['negativeFloat'].AsFloat, 0.01);
  Assert.AreEqual(12300.0, doc.Root.Values['scientificNotation'].AsFloat, 0.1);
  Assert.AreEqual<Int64>(0, doc.Root.Values['zero'].AsInteger);
end;

procedure TJSONParsingTests.TestJSONBooleanAndNull;
var
  jsonText: string;
  doc: IYAMLDocument;
begin
  jsonText := '{' +
    '"isTrue": true,' +
    '"isFalse": false,' +
    '"isNull": null' +
  '}';
  
  doc := TYAML.LoadFromString(jsonText);
  Assert.IsNotNull(doc.Root, 'LoadFromString returned null');
  
  Assert.AreEqual(true, doc.Root.Values['isTrue'].AsBoolean);
  Assert.AreEqual(false, doc.Root.Values['isFalse'].AsBoolean);
  Assert.IsTrue(doc.Root.Values['isNull'].IsNull);
end;

procedure TJSONParsingTests.TestComplexJSONExample;
var
  jsonText: string;
  doc: IYAMLDocument;
  addressValue: IYAMLMapping;
  phoneNumbers: IYAMLSequence;
begin
  jsonText := '{' +
    '"firstName": "John",' +
    '"lastName": "Smith",' +
    '"age": 35,' +
    '"address": {' +
      '"streetAddress": "123 Main St",' +
      '"city": "Anytown",' +
      '"state": "NY",' +
      '"postalCode": "12345"' +
    '},' +
    '"phoneNumbers": [' +
      '{"type": "home", "number": "555-1234"},' +
      '{"type": "work", "number": "555-5678"}' +
    '],' +
    '"isMarried": true,' +
    '"spouse": null' +
  '}';
  
  doc := TYAML.LoadFromString(jsonText);
  Assert.IsNotNull(doc.Root, 'LoadFromString returned null');
  
  Assert.AreEqual('John', doc.Root.Values['firstName'].AsString);
  Assert.AreEqual('Smith', doc.Root.Values['lastName'].AsString);
  Assert.AreEqual<Int64>(35, doc.Root.Values['age'].AsInteger);
  
  addressValue := doc.Root.Values['address'].AsMapping;
  Assert.AreEqual('123 Main St', addressValue.Values['streetAddress'].AsString);
  Assert.AreEqual('Anytown', addressValue.Values['city'].AsString);
  Assert.AreEqual('NY', addressValue.Values['state'].AsString);
  Assert.AreEqual('12345', addressValue.Values['postalCode'].AsString);
  
  phoneNumbers := doc.Root.Values['phoneNumbers'].AsSequence;
  Assert.AreEqual(2, phoneNumbers.Count);
  Assert.AreEqual('home', phoneNumbers.Items[0].Values['type'].AsString);
  Assert.AreEqual('555-1234', phoneNumbers.Items[0].Values['number'].AsString);
  Assert.AreEqual('work', phoneNumbers.Items[1].Values['type'].AsString);
  Assert.AreEqual('555-5678', phoneNumbers.Items[1].Values['number'].AsString);
  
  Assert.AreEqual(true, doc.Root.Values['isMarried'].AsBoolean);
  Assert.IsTrue(doc.Root.Values['spouse'].IsNull);
end;

procedure TJSONParsingTests.TestJSONArrayOfObjects;
var
  jsonText: string;
  doc: IYAMLDocument;
  products: IYAMLSequence;
begin
  jsonText := '[' +
    '{"id": 1, "name": "Laptop", "price": 999.99, "inStock": true},' +
    '{"id": 2, "name": "Mouse", "price": 29.99, "inStock": false},' +
    '{"id": 3, "name": "Keyboard", "price": 79.99, "inStock": true}' +
  ']';
  
  doc := TYAML.LoadFromString(jsonText);
  Assert.IsNotNull(doc.Root, 'LoadFromString returned null');
  Assert.AreEqual(TYAMLValueType.vtSequence, doc.Root.ValueType);
  
  products := doc.Root.AsSequence;
  Assert.AreEqual(3, products.Count);
  
  Assert.AreEqual<Int64>(1, products.Items[0].Values['id'].AsInteger);
  Assert.AreEqual('Laptop', products.Items[0].Values['name'].AsString);
  Assert.AreEqual(999.99, products.Items[0].Values['price'].AsFloat, 0.01);
  Assert.AreEqual(true, products.Items[0].Values['inStock'].AsBoolean);
  
  Assert.AreEqual<Int64>(2, products.Items[1].Values['id'].AsInteger);
  Assert.AreEqual(false, products.Items[1].Values['inStock'].AsBoolean);
end;

procedure TJSONParsingTests.TestJSONEmptyContainers;
var
  jsonText: string;
  doc: IYAMLDocument;
begin
  jsonText := '{' +
    '"emptyObject": {},' +
    '"emptyArray": [],' +
    '"emptyString": ""' +
  '}';
  
  doc := TYAML.LoadFromString(jsonText);
  Assert.IsNotNull(doc.Root, 'LoadFromString returned null');
  
  Assert.AreEqual(TYAMLValueType.vtMapping, doc.Root.Values['emptyObject'].ValueType);
  Assert.AreEqual(0, doc.Root.Values['emptyObject'].AsMapping.Count);
  
  Assert.AreEqual(TYAMLValueType.vtSequence, doc.Root.Values['emptyArray'].ValueType);
  Assert.AreEqual(0, doc.Root.Values['emptyArray'].AsSequence.Count);
  
  Assert.AreEqual('', doc.Root.Values['emptyString'].AsString);
end;

procedure TJSONParsingTests.TestJSONNestedArrays;
var
  jsonText: string;
  doc: IYAMLDocument;
  matrix: IYAMLSequence;
  row1: IYAMLSequence;
begin
  jsonText := '{' +
    '"matrix": [[1, 2, 3], [4, 5, 6], [7, 8, 9]],' +
    '"tags": [["red", "blue"], ["green", "yellow"]]' +
  '}';
  
  doc := TYAML.LoadFromString(jsonText);
  Assert.IsNotNull(doc.Root, 'LoadFromString returned null');
  
  matrix := doc.Root.Values['matrix'].AsSequence;
  Assert.AreEqual(3, matrix.Count);
  
  row1 := matrix.Items[0].AsSequence;
  Assert.AreEqual(3, row1.Count);
  Assert.AreEqual<Int64>(1, row1.Items[0].AsInteger);
  Assert.AreEqual<Int64>(2, row1.Items[1].AsInteger);
  Assert.AreEqual<Int64>(3, row1.Items[2].AsInteger);
  
  Assert.AreEqual(2, doc.Root.Values['tags'].AsSequence.Count);
  Assert.AreEqual('red', doc.Root.Values['tags'].AsSequence.Items[0].AsSequence.Items[0].AsString);
end;

procedure TJSONParsingTests.TestJSONMixedTypes;
var
  jsonText: string;
  doc: IYAMLDocument;
  mixedArray: IYAMLSequence;
begin
  jsonText := '{' +
    '"mixed": [42, "hello", true, null, {"nested": "value"}, [1, 2, 3]]' +
  '}';
  
  doc := TYAML.LoadFromString(jsonText);
  Assert.IsNotNull(doc.Root, 'LoadFromString returned null');
  
  mixedArray := doc.Root.Values['mixed'].AsSequence;
  Assert.AreEqual(6, mixedArray.Count);
  
  Assert.AreEqual<Int64>(42, mixedArray.Items[0].AsInteger);
  Assert.AreEqual('hello', mixedArray.Items[1].AsString);
  Assert.AreEqual(true, mixedArray.Items[2].AsBoolean);
  Assert.IsTrue(mixedArray.Items[3].IsNull);
  Assert.AreEqual(TYAMLValueType.vtMapping, mixedArray.Items[4].ValueType);
  Assert.AreEqual('value', mixedArray.Items[4].Values['nested'].AsString);
  Assert.AreEqual(TYAMLValueType.vtSequence, mixedArray.Items[5].ValueType);
  Assert.AreEqual(3, mixedArray.Items[5].AsSequence.Count);
end;

procedure TJSONParsingTests.TestJSONLargeNumbers;
var
  jsonText: string;
  doc: IYAMLDocument;
begin
  jsonText := '{' +
    '"maxInt": 9223372036854775807,' +
    '"minInt": -9223372036854775808,' +
    '"largeFloat": 1.7976931348623157e308,' +
    '"smallFloat": 2.2250738585072014e-308,' +
    '"precision": 0.123456789012345' +
  '}';
  
  doc := TYAML.LoadFromString(jsonText);
  Assert.IsNotNull(doc.Root, 'LoadFromString returned null');
  
  Assert.AreEqual<Int64>(9223372036854775807, doc.Root.Values['maxInt'].AsInteger);
  Assert.AreEqual<Int64>(-9223372036854775808, doc.Root.Values['minInt'].AsInteger);
  Assert.IsTrue(doc.Root.Values['largeFloat'].AsFloat > 1e308);
  Assert.IsTrue(doc.Root.Values['smallFloat'].AsFloat > 0);
  Assert.AreEqual(0.123456789012345, doc.Root.Values['precision'].AsFloat, 0.000000000000001);
end;

procedure TJSONParsingTests.TestJSONWhitespaceHandling;
var
  jsonText: string;
  doc: IYAMLDocument;
begin
  jsonText := '  {  ' + sLineBreak +
    '    "key1"  :  "value1"  ,  ' + sLineBreak +
    '    "key2"  :  [  1  ,  2  ,  3  ]  ' + sLineBreak +
    '  }  ';
  
  doc := TYAML.LoadFromString(jsonText);
  Assert.IsNotNull(doc.Root, 'LoadFromString returned null');
  
  Assert.AreEqual('value1', doc.Root.Values['key1'].AsString);
  Assert.AreEqual(3, doc.Root.Values['key2'].AsSequence.Count);
  Assert.AreEqual<Int64>(2, doc.Root.Values['key2'].AsSequence.Items[1].AsInteger);
end;

procedure TJSONParsingTests.TestJSONSpecialStringValues;
var
  jsonText: string;
  doc: IYAMLDocument;
begin
  jsonText := '{' +
    '"numericString": "123",' +
    '"boolString": "true",' +
    '"nullString": "null",' +
    '"specialChars": "!@#$%^&*()_+-={}[]|\\:;\"''<>?,./",' +
    '"spaces": "  leading and trailing  "' +
  '}';
  
  doc := TYAML.LoadFromString(jsonText);
  Assert.IsNotNull(doc.Root, 'LoadFromString returned null');
  
  Assert.AreEqual('123', doc.Root.Values['numericString'].AsString);
  Assert.AreEqual('true', doc.Root.Values['boolString'].AsString);
  Assert.AreEqual('null', doc.Root.Values['nullString'].AsString);
  Assert.AreEqual('!@#$%^&*()_+-={}[]|\:;"''<>?,./', doc.Root.Values['specialChars'].AsString);
  Assert.AreEqual('  leading and trailing  ', doc.Root.Values['spaces'].AsString);
end;

procedure TJSONParsingTests.TestJSONDeepNesting;
var
  jsonText: string;
  doc: IYAMLDocument;
  level1, level2, level3: IYAMLMapping;
begin
  jsonText := '{' +
    '"level1": {' +
      '"level2": {' +
        '"level3": {' +
          '"level4": {' +
            '"level5": {' +
              '"deepValue": "found it!"' +
            '}' +
          '}' +
        '}' +
      '}' +
    '}' +
  '}';
  
  doc := TYAML.LoadFromString(jsonText);
  Assert.IsNotNull(doc.Root, 'LoadFromString returned null');
  
  level1 := doc.Root.Values['level1'].AsMapping;
  level2 := level1.Values['level2'].AsMapping;
  level3 := level2.Values['level3'].AsMapping;
  
  Assert.AreEqual('found it!', 
    level3.Values['level4'].Values['level5'].Values['deepValue'].AsString);
end;



initialization
  TDUnitX.RegisterTestFixture(TJSONParsingTests);

end.
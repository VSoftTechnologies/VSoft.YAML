unit VSoft.YAML.Tests.JSON.Writer;

interface

uses
  DUnitX.TestFramework,
  VSoft.YAML;

type
  [TestFixture]
  TJSONWritingTests = class

  public

    [Test]
    procedure TestWriteSimpleMapping;

    [Test]
    procedure TestWriteSimpleSequence;

    [Test]
    procedure TestWriteDataTypes;

    [Test]
    procedure TestWriteStringEscaping;

    [Test]
    procedure TestWriteNestedStructures;

    [Test]
    procedure TestWriteEmptyContainers;

    [Test]
    procedure TestWriteComplexDocument;

    [Test]
    procedure TestWriteSet;

    [Test]
    procedure TestWriteMultipleDocuments;

    // Edge case tests
    [Test]
    procedure TestWriteNullValues;

    [Test]
    procedure TestWriteSpecialNumbers;

    [Test]
    procedure TestWriteUnicodeStrings;

    [Test]
    procedure TestWriteMathSymbols;


    [Test]
    procedure TestWriteVeryLongStrings;

    [Test]
    procedure TestWriteDeepNesting;

    [Test]
    procedure TestWriteLargeArrays;

    [Test]
    procedure TestWriteSpecialCharacterKeys;

    [Test]
    procedure TestWriteMixedValueTypes;

    [Test]
    procedure TestWriteEdgeStringValues;

    [Test]
    procedure TestWriteNumberEdgeCases;

    [Test]
    procedure TestPrettyPrintFormatting;

  end;


implementation

uses
  System.SysUtils,
  System.StrUtils;

{ TJSONWritingTests }

procedure TJSONWritingTests.TestWriteSimpleMapping;
var
  doc: IYAMLDocument;
  jsonOutput: string;
  expectedJson: string;
begin
  doc := TYAML.CreateMapping;
  doc.Options.PrettyPrint := false;
  doc.AsMapping.AddOrSetValue('name', 'John Doe');
  doc.AsMapping.AddOrSetValue('age', 30);
  doc.AsMapping.AddOrSetValue('active', true);

  jsonOutput := TYAML.WriteToJSONString(doc);
  expectedJson := '{"name":"John Doe","age":30,"active":true}';

  Assert.AreEqual(expectedJson, jsonOutput);
end;

procedure TJSONWritingTests.TestWriteSimpleSequence;
var
  doc: IYAMLDocument;
  jsonOutput: string;
  expectedJson: string;
begin
  doc := TYAML.CreateSequence;
  doc.Options.PrettyPrint := false;
  doc.AsSequence.AddValue('apple');
  doc.AsSequence.AddValue('banana');
  doc.AsSequence.AddValue('cherry');

  jsonOutput := TYAML.WriteToJSONString(doc);
  expectedJson := '["apple","banana","cherry"]';

  Assert.AreEqual(expectedJson, jsonOutput);
end;

procedure TJSONWritingTests.TestWriteDataTypes;
var
  doc: IYAMLDocument;
  jsonOutput: string;
begin
  doc := TYAML.CreateMapping;
  doc.Options.PrettyPrint := false;
  doc.AsMapping.AddOrSetValue('boolTrue', true);
  doc.AsMapping.AddOrSetValue('boolFalse', false);
  doc.AsMapping.AddOrSetValue('intValue', 42);
  doc.AsMapping.AddOrSetValue('floatValue', 3.14159);
  doc.AsMapping.AddOrSetValue('stringValue', 'Hello World');

  jsonOutput := TYAML.WriteToJSONString(doc);

  // Check that all expected parts are in the output
  Assert.Contains(jsonOutput, '"boolTrue":true');
  Assert.Contains(jsonOutput, '"boolFalse":false');
  Assert.Contains(jsonOutput, '"intValue":42');
  Assert.Contains(jsonOutput, '"floatValue":');
  Assert.Contains(jsonOutput, '"stringValue":"Hello World"');
end;

procedure TJSONWritingTests.TestWriteStringEscaping;
var
  doc: IYAMLDocument;
  jsonOutput: string;
begin
  doc := TYAML.CreateMapping;
  doc.Options.PrettyPrint := false;
  doc.AsMapping.AddOrSetValue('quotes', 'She said "Hello!"');
  doc.AsMapping.AddOrSetValue('newlines', 'Line 1' + #10 + 'Line 2');
  doc.AsMapping.AddOrSetValue('tabs', 'Col1' + #9 + 'Col2');
  doc.AsMapping.AddOrSetValue('backslash', 'Path\File');
  doc.AsMapping.AddOrSetValue('control', 'Bell' + #7 + 'End');

  jsonOutput := TYAML.WriteToJSONString(doc);

  // Check that strings are properly escaped
  Assert.Contains(jsonOutput, '"She said \"Hello!\""');
  Assert.Contains(jsonOutput, '"Line 1\nLine 2"');
  Assert.Contains(jsonOutput, '"Col1\tCol2"');
  Assert.Contains(jsonOutput, '"Path\\File"');
end;

procedure TJSONWritingTests.TestWriteNestedStructures;
var
  doc: IYAMLDocument;
  person: IYAMLMapping;
  hobbies: IYAMLSequence;
  jsonOutput: string;
begin
  doc := TYAML.CreateMapping;
  doc.Options.PrettyPrint := false;
  person := doc.AsMapping.AddOrSetMapping('person');
  person.AddOrSetValue('name', 'Jane Smith');
  person.AddOrSetValue('age', 25);

  hobbies := person.AddOrSetSequence('hobbies');
  hobbies.AddValue('reading');
  hobbies.AddValue('swimming');
  hobbies.AddValue('coding');

  doc.AsMapping.AddOrSetValue('company', 'ACME Corp');

  jsonOutput := TYAML.WriteToJSONString(doc);

  // Verify the structure is correct
  Assert.Contains(jsonOutput, '"person":{');
  Assert.Contains(jsonOutput, '"hobbies":["reading","swimming","coding"]');
  Assert.Contains(jsonOutput, '"company":"ACME Corp"');
end;

procedure TJSONWritingTests.TestWriteEmptyContainers;
var
  doc: IYAMLDocument;
  jsonOutput: string;
begin
  doc := TYAML.CreateMapping;
  doc.Options.PrettyPrint := false;
  doc.AsMapping.AddOrSetMapping('emptyObject');
  doc.AsMapping.AddOrSetSequence('emptyArray');
  doc.AsMapping.AddOrSetValue('emptyString', '');

  jsonOutput := TYAML.WriteToJSONString(doc);

  Assert.Contains(jsonOutput, '"emptyObject":{}');
  Assert.Contains(jsonOutput, '"emptyArray":[]');
  // Empty string may be converted to null, so check for the key presence
  Assert.Contains(jsonOutput, '"emptyString":');
end;

procedure TJSONWritingTests.TestWriteComplexDocument;
var
  doc: IYAMLDocument;
  address: IYAMLMapping;
  phoneNumbers: IYAMLSequence;
  homePhone, workPhone: IYAMLMapping;
  jsonOutput: string;
begin
  doc := TYAML.CreateMapping;
  doc.Options.PrettyPrint := false;
  doc.AsMapping.AddOrSetValue('firstName', 'John');
  doc.AsMapping.AddOrSetValue('lastName', 'Smith');
  doc.AsMapping.AddOrSetValue('age', 35);

  address := doc.AsMapping.AddOrSetMapping('address');
  address.AddOrSetValue('streetAddress', '123 Main St');
  address.AddOrSetValue('city', 'Anytown');
  address.AddOrSetValue('state', 'NY');
  address.AddOrSetValue('postalCode', '12345');

  phoneNumbers := doc.AsMapping.AddOrSetSequence('phoneNumbers');
  homePhone := phoneNumbers.AddMapping;
  homePhone.AddOrSetValue('type', 'home');
  homePhone.AddOrSetValue('number', '555-1234');

  workPhone := phoneNumbers.AddMapping;
  workPhone.AddOrSetValue('type', 'work');
  workPhone.AddOrSetValue('number', '555-5678');

  doc.AsMapping.AddOrSetValue('isMarried', true);

  jsonOutput := TYAML.WriteToJSONString(doc);

  // Verify the complex structure
  Assert.Contains(jsonOutput, '"firstName":"John"');
  Assert.Contains(jsonOutput, '"address":{');
  Assert.Contains(jsonOutput, '"phoneNumbers":[');
  Assert.Contains(jsonOutput, '"type":"home"');
  Assert.Contains(jsonOutput, '"isMarried":true');
end;

procedure TJSONWritingTests.TestWriteSet;
var
  doc: IYAMLDocument;
  jsonOutput: string;
begin
  doc := TYAML.CreateSet;
  doc.Options.PrettyPrint := false;
  doc.AsSet.AddValue('apple');
  doc.AsSet.AddValue('banana');
  doc.AsSet.AddValue('cherry');

  jsonOutput := TYAML.WriteToJSONString(doc);

  // Sets should be written as JSON arrays
  Assert.IsTrue(Copy(jsonOutput, 1, 1) = '[');
  Assert.IsTrue(Copy(jsonOutput, Length(jsonOutput), 1) = ']');
  Assert.Contains(jsonOutput, '"apple"');
  Assert.Contains(jsonOutput, '"banana"');
  Assert.Contains(jsonOutput, '"cherry"');
end;

procedure TJSONWritingTests.TestWriteMultipleDocuments;
var
  doc1, doc2, doc3: IYAMLDocument;
  docs: TArray<IYAMLDocument>;
  jsonOutput: string;
begin
  doc1 := TYAML.CreateMapping;
  doc1.AsMapping.AddOrSetValue('id', 1);
  doc1.AsMapping.AddOrSetValue('name', 'First');

  doc2 := TYAML.CreateMapping;
  doc2.AsMapping.AddOrSetValue('id', 2);
  doc2.AsMapping.AddOrSetValue('name', 'Second');

  doc3 := TYAML.CreateSequence;
  doc3.AsSequence.AddValue('item1');
  doc3.AsSequence.AddValue('item2');

  SetLength(docs, 3);
  docs[0] := doc1;
  docs[1] := doc2;
  docs[2] := doc3;

  //first document's options are used
  docs[0].Options.PrettyPrint := false;
  jsonOutput := TYAML.WriteToJSONString(docs);

  // Multiple documents should be wrapped in a JSON array
  Assert.IsTrue(Copy(jsonOutput, 1, 1) = '[');
  Assert.IsTrue(Copy(jsonOutput, Length(jsonOutput), 1) = ']');
  Assert.Contains(jsonOutput, '{"id":1,"name":"First"}');
  Assert.Contains(jsonOutput, '{"id":2,"name":"Second"}');
  Assert.Contains(jsonOutput, '["item1","item2"]');
end;

// Edge case tests

procedure TJSONWritingTests.TestWriteNullValues;
var
  doc: IYAMLDocument;
  jsonOutput: string;
  yamlText: string;
begin
  // Create document from YAML with explicit nulls
  yamlText := 'explicitNull: null' + sLineBreak +
              'tilde: ~' + sLineBreak +
              'emptyValue: ';
  
  doc := TYAML.LoadFromString(yamlText);
  doc.Options.PrettyPrint := false;
  jsonOutput := TYAML.WriteToJSONString(doc);
  
  // All null variants should be written as JSON null
  Assert.Contains(jsonOutput, '"explicitNull":null');
  Assert.Contains(jsonOutput, '"tilde":null');
  Assert.Contains(jsonOutput, '"emptyValue":null');
end;

procedure TJSONWritingTests.TestWriteSpecialNumbers;
var
  doc: IYAMLDocument;
  jsonOutput: string;
begin
  doc := TYAML.CreateMapping;
  doc.Options.PrettyPrint := false;
  doc.AsMapping.AddOrSetValue('zero', 0);
  doc.AsMapping.AddOrSetValue('negativeZero', -0);
  doc.AsMapping.AddOrSetValue('maxInt', High(Int64));
  doc.AsMapping.AddOrSetValue('minInt', Low(Int64));
  doc.AsMapping.AddOrSetValue('largeFloat', 1.23456789012345E+15);
  doc.AsMapping.AddOrSetValue('smallFloat', 1.23456789012345E-15);
  doc.AsMapping.AddOrSetValue('pi', 3.141592653589793);

  jsonOutput := TYAML.WriteToJSONString(doc);
  
  // Check that numbers are properly formatted
  Assert.Contains(jsonOutput, '"zero":0');
  Assert.Contains(jsonOutput, '"maxInt":9223372036854775807');
  Assert.Contains(jsonOutput, '"minInt":-9223372036854775808');
  Assert.Contains(jsonOutput, '"pi":');
end;

procedure TJSONWritingTests.TestWriteUnicodeStrings;
var
  doc: IYAMLDocument;
  jsonOutput: string;
begin
  doc := TYAML.CreateMapping;
  doc.Options.PrettyPrint := false;
  // Test characters that should work in UTF-16 (Delphi XE2)
  doc.AsMapping.AddOrSetValue('european', 'Café résumé naïve');
  doc.AsMapping.AddOrSetValue('symbols', '©™®€£¥');
  doc.AsMapping.AddOrSetValue('quotes', 'He said "Hello" and she replied');
  doc.AsMapping.AddOrSetValue('accents', 'àáâãäåæçèéêë');
  doc.AsMapping.AddOrSetValue('currency', '$¢£¥€');
  doc.AsMapping.AddOrSetValue('math', '±×÷≈≠≤≥');

  jsonOutput := TYAML.WriteToJSONString(doc);

  // Test that Unicode characters are preserved (UTF-16 should handle these)
  Assert.Contains(jsonOutput, '"european":"Café résumé naïve"');
  Assert.Contains(jsonOutput, '"symbols":"©™®€£¥"');
  Assert.Contains(jsonOutput, '"quotes":"He said \"Hello\" and she replied"');
  Assert.Contains(jsonOutput, '"accents":"àáâãäåæçèéêë"');
  Assert.Contains(jsonOutput, '"currency":"$¢£¥€"');
  // Math symbols should be preserved as-is in UTF-16
  Assert.Contains(jsonOutput, '"math":"±×÷≈≠≤≥"');

  // Ensure the JSON is well-formed with proper structure
  Assert.IsTrue(Copy(jsonOutput, 1, 1) = '{');
  Assert.IsTrue(Copy(jsonOutput, Length(jsonOutput), 1) = '}');
end;

procedure TJSONWritingTests.TestWriteVeryLongStrings;
var
  doc: IYAMLDocument;
  jsonOutput: string;
  longString: string;
  i: integer;
begin
  // Create a very long string
  longString := '';
  for i := 1 to 1000 do
    longString := longString + 'This is a very long string segment ' + IntToStr(i) + '. ';

  doc := TYAML.CreateMapping;
  doc.Options.PrettyPrint := false;
  doc.AsMapping.AddOrSetValue('longString', longString);
  doc.AsMapping.AddOrSetValue('shortString', 'short');

  jsonOutput := TYAML.WriteToJSONString(doc);
  
  // Should contain the long string properly escaped
  Assert.Contains(jsonOutput, '"longString":"This is a very long string segment 1.');
  Assert.Contains(jsonOutput, 'segment 1000.');
  Assert.Contains(jsonOutput, '"shortString":"short"');
end;

procedure TJSONWritingTests.TestWriteDeepNesting;
var
  doc: IYAMLDocument;
  current: IYAMLMapping;
  jsonOutput: string;
  i: integer;
begin
  doc := TYAML.CreateMapping;
  doc.Options.PrettyPrint := false;
  current := doc.AsMapping;
  
  // Create deeply nested structure (20 levels)
  for i := 1 to 20 do
  begin
    current.AddOrSetValue('level', i);
    current := current.AddOrSetMapping('nested');
  end;
  current.AddOrSetValue('deepValue', 'found at bottom');

  jsonOutput := TYAML.WriteToJSONString(doc);
  
  // Should contain nested structure
  Assert.Contains(jsonOutput, '"level":1');
  Assert.Contains(jsonOutput, '"level":20');
  Assert.Contains(jsonOutput, '"deepValue":"found at bottom"');
  
  // Verify substantial nesting occurred
  Assert.IsTrue(Length(jsonOutput) > 200); // Should be a substantial size with deep nesting
end;

procedure TJSONWritingTests.TestWriteLargeArrays;
var
  doc: IYAMLDocument;
  jsonOutput: string;
  i: integer;
begin
  doc := TYAML.CreateSequence;
  doc.Options.PrettyPrint := false;
  
  // Create large array with 100 elements
  for i := 1 to 100 do
    doc.AsSequence.AddValue('item' + IntToStr(i));

  jsonOutput := TYAML.WriteToJSONString(doc);
  
  // Should be a JSON array with all elements
  Assert.IsTrue(Copy(jsonOutput, 1, 1) = '[');
  Assert.IsTrue(Copy(jsonOutput, Length(jsonOutput), 1) = ']');
  Assert.Contains(jsonOutput, '"item1"');
  Assert.Contains(jsonOutput, '"item50"');
  Assert.Contains(jsonOutput, '"item100"');
end;

procedure TJSONWritingTests.TestWriteSpecialCharacterKeys;
var
  doc: IYAMLDocument;
  jsonOutput: string;
begin
  doc := TYAML.CreateMapping;
  doc.Options.PrettyPrint := false;
  doc.AsMapping.AddOrSetValue('normal-key', 'value1');
  doc.AsMapping.AddOrSetValue('key with spaces', 'value2');
  doc.AsMapping.AddOrSetValue('key"with"quotes', 'value3');
  doc.AsMapping.AddOrSetValue('key\with\backslashes', 'value4');
  doc.AsMapping.AddOrSetValue('key' + #10 + 'with' + #10 + 'newlines', 'value5');
  doc.AsMapping.AddOrSetValue('!@#$%^&*()', 'value6');

  jsonOutput := TYAML.WriteToJSONString(doc);
  
  // All keys should be properly escaped
  Assert.Contains(jsonOutput, '"normal-key":"value1"');
  Assert.Contains(jsonOutput, '"key with spaces":"value2"');
  Assert.Contains(jsonOutput, '"key\"with\"quotes":"value3"');
  Assert.Contains(jsonOutput, '"key\\with\\backslashes":"value4"');
  Assert.Contains(jsonOutput, '"!@#$%^&*()":"value6"');
end;

procedure TJSONWritingTests.TestWriteMathSymbols;
var
  doc: IYAMLDocument;
  jsonOutput: string;
begin
  doc := TYAML.CreateMapping;
  doc.Options.PrettyPrint := false;
  doc.AsMapping.AddOrSetValue('math', '±×÷≈≠≤≥');

  jsonOutput := TYAML.WriteToJSONString(doc);

  Assert.Contains(jsonOutput, '"math":"±×÷≈≠≤≥"');
end;

procedure TJSONWritingTests.TestWriteMixedValueTypes;
var
  doc: IYAMLDocument;
  innerArray: IYAMLSequence;
  innerObject: IYAMLMapping;
  jsonOutput: string;
begin
  doc := TYAML.CreateMapping;
  doc.Options.PrettyPrint := false;
  doc.AsMapping.AddOrSetValue('nullVal', ''); // Will be converted to null
  doc.AsMapping.AddOrSetValue('boolVal', true);
  doc.AsMapping.AddOrSetValue('intVal', 42);
  doc.AsMapping.AddOrSetValue('floatVal', 3.14);
  doc.AsMapping.AddOrSetValue('stringVal', 'hello');
  
  innerArray := doc.AsMapping.AddOrSetSequence('arrayVal');
  innerArray.AddValue(1);
  innerArray.AddValue('two');
  innerArray.AddValue(false);
  
  innerObject := doc.AsMapping.AddOrSetMapping('objectVal');
  innerObject.AddOrSetValue('nested', 'value');

  jsonOutput := TYAML.WriteToJSONString(doc);
  
  // All types should be represented correctly
  Assert.Contains(jsonOutput, '"boolVal":true');
  Assert.Contains(jsonOutput, '"intVal":42');
  Assert.Contains(jsonOutput, '"stringVal":"hello"');
  Assert.Contains(jsonOutput, '"arrayVal":[');
  Assert.Contains(jsonOutput, '"objectVal":{');
  Assert.Contains(jsonOutput, '"nested":"value"');
end;

procedure TJSONWritingTests.TestWriteEdgeStringValues;
var
  doc: IYAMLDocument;
  jsonOutput: string;
begin
  doc := TYAML.CreateMapping;
  doc.Options.PrettyPrint := false;
  doc.AsMapping.AddOrSetValue('onlySpaces', '   ');
  doc.AsMapping.AddOrSetValue('onlyTabs', #9#9#9);
  doc.AsMapping.AddOrSetValue('onlyNewlines', #10#10#10);
  doc.AsMapping.AddOrSetValue('mixedWhitespace', ' ' + #9 + #10 + #13);
  doc.AsMapping.AddOrSetValue('numberLike', '123.45');
  doc.AsMapping.AddOrSetValue('booleanLike', 'true');
  doc.AsMapping.AddOrSetValue('nullLike', 'null');

  jsonOutput := TYAML.WriteToJSONString(doc);
  
  // All should be treated as strings and properly escaped
  Assert.Contains(jsonOutput, '"onlySpaces":"   "');
  Assert.Contains(jsonOutput, '"onlyTabs":"\t\t\t"'); // JSON uses single backslash for tab
  Assert.Contains(jsonOutput, '"numberLike":"123.45"');
  Assert.Contains(jsonOutput, '"booleanLike":"true"');
  Assert.Contains(jsonOutput, '"nullLike":"null"');
end;

procedure TJSONWritingTests.TestWriteNumberEdgeCases;
var
  doc: IYAMLDocument;
  jsonOutput: string;
  yamlText: string;
begin
  // Create document with various number formats from YAML
  yamlText := 'binary: 0b1010' + sLineBreak +
              'octal: 0o755' + sLineBreak +
              'hex: 0xFF' + sLineBreak +
              'scientific: 1.23e4' + sLineBreak +
              'negScientific: -4.56E-3';
              
  doc := TYAML.LoadFromString(yamlText);
  doc.Options.PrettyPrint := false;
  jsonOutput := TYAML.WriteToJSONString(doc);
  
  // All should be converted to standard decimal JSON numbers
  Assert.Contains(jsonOutput, '"binary":10');        // 0b1010 = 10
  Assert.Contains(jsonOutput, '"octal":493');        // 0o755 = 493
  Assert.Contains(jsonOutput, '"hex":255');          // 0xFF = 255
  Assert.Contains(jsonOutput, '"scientific":12300'); // 1.23e4 = 12300
  Assert.Contains(jsonOutput, '"negScientific":-0.00456'); // -4.56E-3 = -0.00456
end;

procedure TJSONWritingTests.TestPrettyPrintFormatting;
var
  doc: IYAMLDocument;
  address: IYAMLMapping;
  hobbies: IYAMLSequence;
  compactOutput, prettyOutput: string;
begin
  // Create a nested document
  doc := TYAML.CreateMapping;
  doc.AsMapping.AddOrSetValue('name', 'John Doe');
  doc.AsMapping.AddOrSetValue('age', 30);

  address := doc.AsMapping.AddOrSetMapping('address');
  address.AddOrSetValue('street', '123 Main St');
  address.AddOrSetValue('city', 'Anytown');

  hobbies := doc.AsMapping.AddOrSetSequence('hobbies');
  hobbies.AddValue('reading');
  hobbies.AddValue('coding');
  hobbies.AddValue('hiking');

  doc.options.PrettyPrint := false;

  // Test compact output (default)
  compactOutput := TYAML.WriteToJSONString(doc);


  // Compact should be single line
  Assert.IsFalse(compactOutput.Contains(sLineBreak), 'Compact output should not contain line breaks');

  // Test pretty printed output

  doc.options.PrettyPrint := true;
  doc.options.IndentSize := 2;
  prettyOutput := TYAML.WriteToJSONString(doc);


  // Pretty print should have line breaks and indentation
  Assert.IsTrue(prettyOutput.Contains(sLineBreak), 'Pretty output should contain line breaks');
  Assert.IsTrue(prettyOutput.Contains('  '), 'Pretty output should contain indentation');
  
  // Check structure - pretty print should have proper formatting
  Assert.Contains(prettyOutput, '{' + sLineBreak + '  "name": "John Doe"');
  Assert.Contains(prettyOutput, '  "hobbies": [' + sLineBreak + '    "reading"');
  
  // Both should contain the same data
  Assert.Contains(compactOutput, '"name":"John Doe"');
  Assert.Contains(prettyOutput, '"name": "John Doe"');
  Assert.Contains(compactOutput, '"hobbies":["reading","coding","hiking"]');
  Assert.Contains(prettyOutput, '"reading"');
  Assert.Contains(prettyOutput, '"coding"');
  Assert.Contains(prettyOutput, '"hiking"');
end;

initialization
  TDUnitX.RegisterTestFixture(TJSONWritingTests);

end.

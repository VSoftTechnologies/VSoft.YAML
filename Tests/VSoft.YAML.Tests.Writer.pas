unit VSoft.YAML.Tests.Writer;

interface

uses
  DUnitX.TestFramework,
  VSoft.YAML,
  {$IFDEF POSIX}
  Posix.Unistd,
  {$ENDIF}
  System.SysUtils,
  System.Classes,
  System.DateUtils;

type
  [TestFixture]
  TYAMLWriterTests = class
  private
    procedure ValidateRoundTrip(const originalYAML: string);
    function CreateTestDateTime: TDateTime;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    // Document creation tests
    [Test]
    procedure Test_CreateMapping_EmptyDocument;
    [Test]
    procedure Test_CreateSequence_EmptyDocument;
    [Test]
    procedure Test_WriteToString_EmptyMapping;
    [Test]
    procedure Test_WriteToString_EmptySequence;

    // Basic value writing tests
    [Test]
    procedure Test_WriteMapping_ScalarValues;
    [Test]
    procedure Test_WriteSequence_ScalarValues;
    [Test]
    procedure Test_WriteMapping_AllTypes;
    [Test]
    procedure Test_WriteSequence_AllTypes;

    // Complex structure writing tests
    [Test]
    procedure Test_WriteMapping_NestedStructures;
    [Test]
    procedure Test_WriteSequence_NestedStructures;
    [Test]
    procedure Test_WriteMixedStructures;
    [Test]
    procedure Test_WriteDeepNesting;

    // Output format tests
    [Test]
    procedure Test_OutputFormat_Block;
    [Test]
    procedure Test_OutputFormat_Flow;
    [Test]
    procedure Test_OutputFormat_Mixed;

    // Document options tests
    [Test]
    procedure Test_DocumentOptions_IndentSize;
    [Test]
    procedure Test_DocumentOptions_QuoteStrings;
    [Test]
    procedure Test_DocumentOptions_EmitDocumentMarkers;
    [Test]
    procedure Test_DocumentOptions_WriteTags;
    [Test]
    procedure Test_DocumentOptions_WriteExplicitNull;

    // String handling tests
    [Test]
    procedure Test_WriteString_PlainStrings;
    [Test]
    procedure Test_WriteString_QuotedStrings;
    [Test]
    procedure Test_WriteString_MultilineStrings;
    [Test]
    procedure Test_WriteString_SpecialCharacters;
    [Test]
    procedure Test_WriteString_EscapeSequences;

    // Numeric value tests
    [Test]
    procedure Test_WriteInteger_Various;
    [Test]
    procedure Test_WriteFloat_Various;
    [Test]
    procedure Test_WriteFloat_SpecialValues;

    // Boolean and null tests
    [Test]
    procedure Test_WriteBoolean_Values;
    [Test]
    procedure Test_WriteNull_Values;

    // DateTime tests
    [Test]
    procedure Test_WriteDateTime_LocalTime;
    [Test]
    procedure Test_WriteDateTime_UTC;
    [Test]
    procedure Test_WriteDateTime_Various_Formats;

    // File operations tests
    [Test]
    procedure Test_WriteToFile_SimpleDocument;
    [Test]
    procedure Test_WriteToFile_ComplexDocument;
    [Test]
    procedure Test_WriteToFile_WithEncoding;

    // Round-trip tests
    [Test]
    procedure Test_RoundTrip_SimpleMapping;
    [Test]
    procedure Test_RoundTrip_SimpleSequence;
    [Test]
    procedure Test_RoundTrip_ComplexStructure;
    [Test]
    procedure Test_RoundTrip_AllTypes;

    // Dynamic modification tests
    [Test]
    procedure Test_DynamicModification_AddToMapping;
    [Test]
    procedure Test_DynamicModification_AddToSequence;
    [Test]
    procedure Test_DynamicModification_UpdateValues;
    [Test]
    procedure Test_DynamicModification_NestedStructures;

    // Performance and edge cases
    [Test]
    procedure Test_WriteLargeDocument;
    [Test]
    procedure Test_WriteDeepNesting_Performance;
    [Test]
    procedure Test_WriteManyItems;

    // TYAML.WriteAllToString comprehensive tests
    [Test]
    procedure Test_WriteAllToString_EmptyArray;
    [Test]
    procedure Test_WriteAllToString_SingleDocument;
    [Test]
    procedure Test_WriteAllToString_MultipleDocuments;
    [Test]
    procedure Test_WriteAllToString_DocumentMarkers;
    [Test]
    procedure Test_WriteAllToString_DifferentRootTypes;
    [Test]
    procedure Test_WriteAllToString_DifferentOptions;
    [Test]
    procedure Test_WriteAllToString_ComplexDocuments;
    [Test]
    procedure Test_WriteAllToString_ManyDocuments;
    [Test]
    procedure Test_WriteAllToString_RoundTrip;

    // Error handling
    [Test]
    procedure Test_WriteToFile_InvalidPath;
    [Test]
    procedure Test_WriteToString_InvalidOptions;
  end;

implementation

uses
  System.IOUtils,
  VSoft.YAML.Classes;

{ TYAMLWriterTests }

procedure TYAMLWriterTests.Setup;
begin
  // Setup if needed
end;

procedure TYAMLWriterTests.TearDown;
begin
  // Cleanup if needed
end;

function TYAMLWriterTests.CreateTestDateTime: TDateTime;
begin
  Result := EncodeDateTime(2023, 12, 25, 10, 30, 45, 123);
end;


procedure TYAMLWriterTests.ValidateRoundTrip(const originalYAML: string);
var
  doc: IYAMLDocument;
  serializedYAML: string;
  doc2: IYAMLDocument;
begin
  // Load original
  doc := TYAML.LoadFromString(originalYAML);
  
  // Serialize to string
  serializedYAML := TYAML.WriteToString(doc);
  
  // Load serialized version
  doc2 := TYAML.LoadFromString(serializedYAML);
  
  // Both documents should be structurally equivalent
  Assert.AreEqual(doc.Root.ValueType, doc2.Root.ValueType);
end;

// Document creation tests

procedure TYAMLWriterTests.Test_CreateMapping_EmptyDocument;
var
  doc: IYAMLDocument;
  yamlStr: string;
begin
  doc := TYAML.CreateMapping;
  Assert.IsNotNull(doc);
  Assert.IsTrue(doc.IsMapping);
  
  yamlStr := TYAML.WriteToString(doc);
  Assert.IsNotEmpty(yamlStr);
end;

procedure TYAMLWriterTests.Test_CreateSequence_EmptyDocument;
var
  doc: IYAMLDocument;
  yamlStr: string;
begin
  doc := TYAML.CreateSequence;
  Assert.IsNotNull(doc);
  Assert.IsTrue(doc.IsSequence);
  
  yamlStr := TYAML.WriteToString(doc);
  Assert.IsNotEmpty(yamlStr);
end;

procedure TYAMLWriterTests.Test_WriteToString_EmptyMapping;
var
  doc: IYAMLDocument;
  yamlStr: string;
begin
  doc := TYAML.CreateMapping;
  yamlStr := TYAML.WriteToString(doc);
  
  Assert.IsNotEmpty(yamlStr);
  Assert.Contains(yamlStr, '{}'); // Should contain empty mapping notation
end;

procedure TYAMLWriterTests.Test_WriteToString_EmptySequence;
var
  doc: IYAMLDocument;
  yamlStr: string;
begin
  doc := TYAML.CreateSequence;
  yamlStr := TYAML.WriteToString(doc);
  
  Assert.IsNotEmpty(yamlStr);
  Assert.Contains(yamlStr, '[]'); // Should contain empty sequence notation
end;

// Basic value writing tests

procedure TYAMLWriterTests.Test_WriteMapping_ScalarValues;
var
  doc: IYAMLDocument;
  root: IYAMLMapping;
  yamlStr: string;
begin
  doc := TYAML.CreateMapping;
  root := doc.AsMapping;
  
  root.AddOrSetValue('string_key', 'Hello World');
  root.AddOrSetValue('integer_key', 42);
  root.AddOrSetValue('float_key', 3.14159);
  root.AddOrSetValue('boolean_key', True);
  
  yamlStr := TYAML.WriteToString(doc);
  
  Assert.Contains(yamlStr, 'string_key');
  Assert.Contains(yamlStr, 'Hello World');
  Assert.Contains(yamlStr, 'integer_key');
  Assert.Contains(yamlStr, '42');
  Assert.Contains(yamlStr, 'boolean_key');
  Assert.Contains(yamlStr, 'true');
end;

procedure TYAMLWriterTests.Test_WriteSequence_ScalarValues;
var
  doc: IYAMLDocument;
  root: IYAMLSequence;
  yamlStr: string;
begin
  doc := TYAML.CreateSequence;
  root := doc.AsSequence;
  
  root.AddValue('First Item');
  root.AddValue(42);
  root.AddValue(3.14159);
  root.AddValue(True);
  
  yamlStr := TYAML.WriteToString(doc);
  
  Assert.Contains(yamlStr, 'First Item');
  Assert.Contains(yamlStr, '42');
  Assert.Contains(yamlStr, '3.14159');
  Assert.Contains(yamlStr, 'true');
end;

procedure TYAMLWriterTests.Test_WriteMapping_AllTypes;
var
  doc: IYAMLDocument;
  root: IYAMLMapping;
  testDate: TDateTime;
  yamlStr: string;
begin
  doc := TYAML.CreateMapping;
  root := doc.AsMapping;
  testDate := CreateTestDateTime;
  
  root.AddOrSetValue('string_val', 'Test String');
  root.AddOrSetValue('int32_val', Int32(42));
  root.AddOrSetValue('uint32_val', UInt32(42));
  root.AddOrSetValue('int64_val', Int64(123456789));
  root.AddOrSetValue('uint64_val', UInt64(123456789));
  root.AddOrSetValue('single_val', Single(3.14));
  root.AddOrSetValue('double_val', Double(3.141592653589793));
  root.AddOrSetValue('bool_val', True);
  root.AddOrSetValue('date_utc', testDate, True);
  root.AddOrSetValue('date_local', testDate, False);
  
  yamlStr := TYAML.WriteToString(doc);
  
  Assert.Contains(yamlStr, 'string_val');
  Assert.Contains(yamlStr, 'Test String');
  Assert.Contains(yamlStr, 'bool_val');
  Assert.Contains(yamlStr, 'true');
end;

procedure TYAMLWriterTests.Test_WriteSequence_AllTypes;
var
  doc: IYAMLDocument;
  root: IYAMLSequence;
  testDate: TDateTime;
  yamlStr: string;
begin
  doc := TYAML.CreateSequence;
  root := doc.AsSequence;
  testDate := CreateTestDateTime;
  
  root.AddValue('Test String');
  root.AddValue(Int32(42));
  root.AddValue(UInt32(42));
  root.AddValue(Int64(123456789));
  root.AddValue(UInt64(123456789));
  root.AddValue(Single(3.14));
  root.AddValue(Double(3.141592653589793));
  root.AddValue(True);
  root.AddValue(testDate, True);
  root.AddValue(testDate, False);
  
  yamlStr := TYAML.WriteToString(doc);
  
  Assert.Contains(yamlStr, 'Test String');
  Assert.Contains(yamlStr, '42');
  Assert.Contains(yamlStr, 'true');
end;

// Complex structure writing tests

procedure TYAMLWriterTests.Test_WriteMapping_NestedStructures;
var
  doc: IYAMLDocument;
  root, person, address: IYAMLMapping;
  hobbies: IYAMLSequence;
  yamlStr: string;
begin
  doc := TYAML.CreateMapping;
  root := doc.AsMapping;
  
  person := root.AddOrSetMapping('person');
  person.AddOrSetValue('name', 'John Doe');
  person.AddOrSetValue('age', 30);
  
  address := person.AddOrSetMapping('address');
  address.AddOrSetValue('street', '123 Main St');
  address.AddOrSetValue('city', 'Springfield');
  address.AddOrSetValue('zip', 12345);
  
  hobbies := person.AddOrSetSequence('hobbies');
  hobbies.AddValue('reading');
  hobbies.AddValue('coding');
  hobbies.AddValue('hiking');
  
  yamlStr := TYAML.WriteToString(doc);
  
  Assert.Contains(yamlStr, 'person');
  Assert.Contains(yamlStr, 'John Doe');
  Assert.Contains(yamlStr, 'address');
  Assert.Contains(yamlStr, '123 Main St');
  Assert.Contains(yamlStr, 'hobbies');
  Assert.Contains(yamlStr, 'reading');
end;

procedure TYAMLWriterTests.Test_WriteSequence_NestedStructures;
var
  doc: IYAMLDocument;
  root: IYAMLSequence;
  person1, person2: IYAMLMapping;
  yamlStr: string;
begin
  doc := TYAML.CreateSequence;
  root := doc.AsSequence;
  
  person1 := root.AddMapping;
  person1.AddOrSetValue('name', 'Alice');
  person1.AddOrSetValue('age', 25);
  
  person2 := root.AddMapping;
  person2.AddOrSetValue('name', 'Bob');
  person2.AddOrSetValue('age', 30);
  
  yamlStr := TYAML.WriteToString(doc);
  
  Assert.Contains(yamlStr, 'Alice');
  Assert.Contains(yamlStr, '25');
  Assert.Contains(yamlStr, 'Bob');
  Assert.Contains(yamlStr, '30');
end;

procedure TYAMLWriterTests.Test_WriteMixedStructures;
var
  doc: IYAMLDocument;
  root: IYAMLMapping;
  users: IYAMLSequence;
  user1: IYAMLMapping;
  roles: IYAMLSequence;
  config: IYAMLMapping;
  yamlStr: string;
begin
  doc := TYAML.CreateMapping;
  root := doc.AsMapping;
  
  // Create users array
  users := root.AddOrSetSequence('users');
  user1 := users.AddMapping;
  user1.AddOrSetValue('name', 'Alice');
  user1.AddOrSetValue('email', 'alice@example.com');
  
  roles := user1.AddOrSetSequence('roles');
  roles.AddValue('admin');
  roles.AddValue('user');
  
  // Create config object
  config := root.AddOrSetMapping('config');
  config.AddOrSetValue('debug', True);
  config.AddOrSetValue('timeout', 30);
  config.AddOrSetValue('host', 'localhost');
  
  yamlStr := TYAML.WriteToString(doc);
  
  Assert.Contains(yamlStr, 'users');
  Assert.Contains(yamlStr, 'Alice');
  Assert.Contains(yamlStr, 'alice@example.com');
  Assert.Contains(yamlStr, 'roles');
  Assert.Contains(yamlStr, 'admin');
  Assert.Contains(yamlStr, 'config');
  Assert.Contains(yamlStr, 'localhost');
end;

procedure TYAMLWriterTests.Test_WriteDeepNesting;
var
  doc: IYAMLDocument;
  root, level1, level2, level3: IYAMLMapping;
  yamlStr: string;
begin
  doc := TYAML.CreateMapping;
  root := doc.AsMapping;
  
  level1 := root.AddOrSetMapping('level1');
  level1.AddOrSetValue('value1', 'First Level');
  
  level2 := level1.AddOrSetMapping('level2');
  level2.AddOrSetValue('value2', 'Second Level');
  
  level3 := level2.AddOrSetMapping('level3');
  level3.AddOrSetValue('value3', 'Third Level');
  level3.AddOrSetValue('deep_value', 42);
  
  yamlStr := TYAML.WriteToString(doc);
  
  Assert.Contains(yamlStr, 'level1');
  Assert.Contains(yamlStr, 'level2');
  Assert.Contains(yamlStr, 'level3');
  Assert.Contains(yamlStr, 'Third Level');
  Assert.Contains(yamlStr, '42');
end;

// Output format tests

procedure TYAMLWriterTests.Test_OutputFormat_Block;
var
  doc: IYAMLDocument;
  root: IYAMLMapping;
  yamlStr: string;
begin
  doc := TYAML.CreateMapping;
  root := doc.AsMapping;
  
  root.AddOrSetValue('name', 'John');
  root.AddOrSetValue('age', 30);
  
  doc.Options.Format := TYAMLOutputFormat.yofBlock;
  
  yamlStr := TYAML.WriteToString(doc);
  
  // Block format should use line breaks and indentation
  Assert.Contains(yamlStr, 'name');
  Assert.Contains(yamlStr, 'age');
end;

procedure TYAMLWriterTests.Test_OutputFormat_Flow;
var
  doc: IYAMLDocument;
  root: IYAMLMapping;
  yamlStr: string;
begin
  doc := TYAML.CreateMapping;
  root := doc.AsMapping;
  
  root.AddOrSetValue('name', 'John');
  root.AddOrSetValue('age', 30);
  
  doc.Options.Format := TYAMLOutputFormat.yofFlow;
  
  yamlStr := TYAML.WriteToString(doc);
  
  // Flow format should use braces and commas
  Assert.Contains(yamlStr, '{');
  Assert.Contains(yamlStr, '}');
end;

procedure TYAMLWriterTests.Test_OutputFormat_Mixed;
var
  doc: IYAMLDocument;
  root: IYAMLMapping;
  yamlStr: string;
begin
  doc := TYAML.CreateMapping;
  root := doc.AsMapping;
  
  root.AddOrSetValue('name', 'John');
  root.AddOrSetValue('age', 30);
  
  doc.Options.Format := TYAMLOutputFormat.yofMixed;
  
  yamlStr := TYAML.WriteToString(doc);
  
  Assert.Contains(yamlStr, 'name');
  Assert.Contains(yamlStr, 'John');
end;

// Document options tests

procedure TYAMLWriterTests.Test_DocumentOptions_IndentSize;
var
  doc: IYAMLDocument;
  root, nested: IYAMLMapping;
  yamlStr: string;
begin
  doc := TYAML.CreateMapping;
  root := doc.AsMapping;
  
  root.AddOrSetValue('top_level', 'value');
  nested := root.AddOrSetMapping('nested');
  nested.AddOrSetValue('nested_key', 'nested_value');
  
  doc.Options.IndentSize := 4;
  
  yamlStr := TYAML.WriteToString(doc);
  
  Assert.Contains(yamlStr, 'nested');
  Assert.Contains(yamlStr, 'nested_value');
end;

procedure TYAMLWriterTests.Test_DocumentOptions_QuoteStrings;
var
  doc: IYAMLDocument;
  root: IYAMLMapping;
  yamlStr: string;
begin
  doc := TYAML.CreateMapping;
  root := doc.AsMapping;
  
  root.AddOrSetValue('simple_string', 'hello');
  root.AddOrSetValue('complex_string', 'hello: world');
  
  doc.Options.QuoteStrings := True;

  yamlStr := TYAML.WriteToString(doc);

  // When QuoteStrings is true, strings should be quoted
  Assert.Contains(yamlStr, '''hello''');
end;

procedure TYAMLWriterTests.Test_DocumentOptions_EmitDocumentMarkers;
var
  doc: IYAMLDocument;
  root: IYAMLMapping;
  yamlStr: string;
begin
  doc := TYAML.CreateMapping;
  root := doc.AsMapping;
  
  root.AddOrSetValue('key', 'value');
  
  doc.Options.EmitDocumentMarkers := True;
  
  yamlStr := TYAML.WriteToString(doc);
  
  // Should contain document markers
  Assert.Contains(yamlStr, '---');
end;

procedure TYAMLWriterTests.Test_DocumentOptions_WriteTags;
var
  doc: IYAMLDocument;
  root: IYAMLMapping;
  yamlStr: string;
begin
  doc := TYAML.CreateMapping;
  root := doc.AsMapping;
  
  root.AddOrSetValue('key', 'value', '!!str');
  
  doc.Options.EmitTags := True;
  
  yamlStr := TYAML.WriteToString(doc);
  
  // Implementation specific - should handle tags if supported
  Assert.Contains(yamlStr, '!!str');
end;

procedure TYAMLWriterTests.Test_DocumentOptions_WriteExplicitNull;
var
  doc: IYAMLDocument;
  root: IYAMLMapping;
  yamlStr: string;
begin
  doc := TYAML.CreateMapping;
  root := doc.AsMapping;
  
  // Add a null value somehow - this might need adjustment based on API
  root.AddOrSetValue('empty_key', ''); // This might represent null

  doc.Options.EmitExplicitNull := True;

  yamlStr := TYAML.WriteToString(doc);

  Assert.Contains(yamlStr, 'null');
end;

// String handling tests

procedure TYAMLWriterTests.Test_WriteString_PlainStrings;
var
  doc: IYAMLDocument;
  root: IYAMLMapping;
  yamlStr: string;
begin
  doc := TYAML.CreateMapping;
  root := doc.AsMapping;
  
  root.AddOrSetValue('simple', 'hello');
  root.AddOrSetValue('with_spaces', 'hello world');
  root.AddOrSetValue('with_numbers', 'test123');
  
  yamlStr := TYAML.WriteToString(doc);
  
  Assert.Contains(yamlStr, 'hello');
  Assert.Contains(yamlStr, 'hello world');
  Assert.Contains(yamlStr, 'test123');
end;

procedure TYAMLWriterTests.Test_WriteString_QuotedStrings;
var
  doc: IYAMLDocument;
  root: IYAMLMapping;
  yamlStr: string;
begin
  doc := TYAML.CreateMapping;
  root := doc.AsMapping;
  
  root.AddOrSetValue('colon_string', 'key: value');
  root.AddOrSetValue('bracket_string', '[array]');
  root.AddOrSetValue('brace_string', '{object}');
  root.AddOrSetValue('quote_string', 'say "hello"');
  
  yamlStr := TYAML.WriteToString(doc);
  
  // These strings should be handled properly (quoted if necessary)
  Assert.Contains(yamlStr, 'key: value');
  Assert.Contains(yamlStr, '[array]');
  Assert.Contains(yamlStr, '{object}');
end;

procedure TYAMLWriterTests.Test_WriteString_MultilineStrings;
var
  doc: IYAMLDocument;
  root: IYAMLMapping;
  multilineText: string;
  yamlStr: string;
begin
  doc := TYAML.CreateMapping;
  root := doc.AsMapping;
  
  multilineText := 'Line 1' + sLineBreak + 'Line 2' + sLineBreak + 'Line 3';
  root.AddOrSetValue('multiline', multilineText);
  
  yamlStr := TYAML.WriteToString(doc);
  
  Assert.Contains(yamlStr, 'multiline');
  Assert.Contains(yamlStr, 'Line 1');
end;

procedure TYAMLWriterTests.Test_WriteString_SpecialCharacters;
var
  doc: IYAMLDocument;
  root: IYAMLMapping;
  yamlStr: string;
begin
  doc := TYAML.CreateMapping;
  root := doc.AsMapping;
  
  root.AddOrSetValue('unicode', 'Hëllö Wörld');
  root.AddOrSetValue('symbols', '@#$%^&*()');
  root.AddOrSetValue('path', 'C:\Users\Name');
  
  yamlStr := TYAML.WriteToString(doc);
  
  Assert.Contains(yamlStr, 'unicode');
  Assert.Contains(yamlStr, 'symbols');
  Assert.Contains(yamlStr, 'path');
end;

procedure TYAMLWriterTests.Test_WriteString_EscapeSequences;
var
  doc: IYAMLDocument;
  root: IYAMLMapping;
  yamlStr: string;
begin
  doc := TYAML.CreateMapping;
  root := doc.AsMapping;
  
  root.AddOrSetValue('tab_string', 'col1' + #9 + 'col2');
  root.AddOrSetValue('newline_string', 'line1' + #10 + 'line2');
  root.AddOrSetValue('quote_string', 'He said "Hello"');
  
  yamlStr := TYAML.WriteToString(doc);
  
  Assert.Contains(yamlStr, 'tab_string');
  Assert.Contains(yamlStr, 'newline_string');
  Assert.Contains(yamlStr, 'quote_string');
end;

// Numeric value tests

procedure TYAMLWriterTests.Test_WriteInteger_Various;
var
  doc: IYAMLDocument;
  root: IYAMLMapping;
  yamlStr: string;
begin
  doc := TYAML.CreateMapping;
  root := doc.AsMapping;
  
  root.AddOrSetValue('zero', 0);
  root.AddOrSetValue('positive', 42);
  root.AddOrSetValue('negative', -17);
  root.AddOrSetValue('large', 123456789);
  root.AddOrSetValue('int64_val', Int64(9223372036854775807));
  
  yamlStr := TYAML.WriteToString(doc);
  
  Assert.Contains(yamlStr, '0');
  Assert.Contains(yamlStr, '42');
  Assert.Contains(yamlStr, '-17');
  Assert.Contains(yamlStr, '123456789');
end;

procedure TYAMLWriterTests.Test_WriteFloat_Various;
var
  doc: IYAMLDocument;
  root: IYAMLMapping;
  yamlStr: string;
begin
  doc := TYAML.CreateMapping;
  root := doc.AsMapping;
  
  root.AddOrSetValue('zero_float', 0.0);
  root.AddOrSetValue('pi', 3.14159);
  root.AddOrSetValue('negative', -2.71828);
  root.AddOrSetValue('small', 0.00001);
  root.AddOrSetValue('large', 1234567.89);
  
  yamlStr := TYAML.WriteToString(doc);
  
  Assert.Contains(yamlStr, '3.14159');
  Assert.Contains(yamlStr, '-2.71828');
  Assert.Contains(yamlStr, '1234567.89');
end;

procedure TYAMLWriterTests.Test_WriteFloat_SpecialValues;
var
  doc: IYAMLDocument;
  root: IYAMLMapping;
  yamlStr: string;
begin
  doc := TYAML.CreateMapping;
  root := doc.AsMapping;
  
  root.AddOrSetValue('pos_infinity', Double.PositiveInfinity);
  root.AddOrSetValue('neg_infinity', Double.NegativeInfinity);
  root.AddOrSetValue('nan_value', Double.NaN);
  
  yamlStr := TYAML.WriteToString(doc);
  
  // Should handle special float values appropriately
  Assert.IsNotEmpty(yamlStr);
end;

// Boolean and null tests

procedure TYAMLWriterTests.Test_WriteBoolean_Values;
var
  doc: IYAMLDocument;
  root: IYAMLMapping;
  yamlStr: string;
begin
  doc := TYAML.CreateMapping;
  root := doc.AsMapping;
  
  root.AddOrSetValue('bool_true', True);
  root.AddOrSetValue('bool_false', False);
  
  yamlStr := TYAML.WriteToString(doc);
  
  Assert.Contains(yamlStr, 'true');
  Assert.Contains(yamlStr, 'false');
end;

procedure TYAMLWriterTests.Test_WriteNull_Values;
var
  doc: IYAMLDocument;
  root: IYAMLMapping;
  yamlStr: string;
begin
  doc := TYAML.CreateMapping;
  root := doc.AsMapping;
  
  // Note: Adding null values might need adjustment based on actual API
  // This is a placeholder for null value testing
  
  yamlStr := TYAML.WriteToString(doc);
  
  Assert.IsNotEmpty(yamlStr);
end;

// DateTime tests

procedure TYAMLWriterTests.Test_WriteDateTime_LocalTime;
var
  doc: IYAMLDocument;
  root: IYAMLMapping;
  testDate: TDateTime;
  yamlStr: string;
begin
  doc := TYAML.CreateMapping;
  root := doc.AsMapping;
  testDate := CreateTestDateTime;
  
  root.AddOrSetValue('local_time', testDate, False);
  
  yamlStr := TYAML.WriteToString(doc);
  
  Assert.Contains(yamlStr, 'local_time');
  Assert.Contains(yamlStr, '2023');
end;

procedure TYAMLWriterTests.Test_WriteDateTime_UTC;
var
  doc: IYAMLDocument;
  root: IYAMLMapping;
  testDate: TDateTime;
  yamlStr: string;
begin
  doc := TYAML.CreateMapping;
  root := doc.AsMapping;
  testDate := CreateTestDateTime;
  
  root.AddOrSetValue('utc_time', testDate, True);
  
  yamlStr := TYAML.WriteToString(doc);
  
  Assert.Contains(yamlStr, 'utc_time');
  Assert.Contains(yamlStr, '2023');
end;

procedure TYAMLWriterTests.Test_WriteDateTime_Various_Formats;
var
  doc: IYAMLDocument;
  root: IYAMLMapping;
  yamlStr: string;
begin
  doc := TYAML.CreateMapping;
  root := doc.AsMapping;
  
  root.AddOrSetValue('date1', EncodeDate(2023, 1, 1), True);
  root.AddOrSetValue('date2', EncodeDate(2023, 12, 31), False);
  root.AddOrSetValue('datetime1', EncodeDateTime(2023, 6, 15, 12, 30, 45, 0), True);
  
  yamlStr := TYAML.WriteToString(doc);
  
  Assert.Contains(yamlStr, '2023');
end;

// File operations tests

procedure TYAMLWriterTests.Test_WriteToFile_SimpleDocument;
var
  doc: IYAMLDocument;
  root: IYAMLMapping;
  fileName: string;
  loadedDoc: IYAMLDocument;
begin
  doc := TYAML.CreateMapping;
  root := doc.AsMapping;

  root.AddOrSetValue('name', 'Test');
  root.AddOrSetValue('value', 42);

  fileName := TPath.GetTempFileName;
  try
    TYAML.WriteToFile(doc, fileName);
    Assert.IsTrue(FileExists(fileName));
    
    // Verify by loading back
    loadedDoc := TYAML.LoadFromFile(fileName);
    Assert.AreEqual('Test', loadedDoc.Root.Values['name'].AsString);
    Assert.AreEqual<Int64>(42, loadedDoc.Root.Values['value'].AsInteger);
  finally
    if FileExists(fileName) then
      DeleteFile(fileName);
  end;
end;

procedure TYAMLWriterTests.Test_WriteToFile_ComplexDocument;
var
  doc: IYAMLDocument;
  root, person: IYAMLMapping;
  hobbies: IYAMLSequence;
  fileName: string;
  loadedDoc: IYAMLDocument;
begin
  doc := TYAML.CreateMapping;
  root := doc.AsMapping;
  
  person := root.AddOrSetMapping('person');
  person.AddOrSetValue('name', 'Alice');
  person.AddOrSetValue('age', 28);
  
  hobbies := person.AddOrSetSequence('hobbies');
  hobbies.AddValue('reading');
  hobbies.AddValue('hiking');
  
  fileName := TPath.GetTempFileName;
  try
    TYAML.WriteToFile(doc, fileName);
    Assert.IsTrue(FileExists(fileName));
    
    // Verify by loading back
    loadedDoc := TYAML.LoadFromFile(fileName);
    Assert.AreEqual('Alice', loadedDoc.Root.Values['person'].Values['name'].AsString);
    Assert.AreEqual(2, loadedDoc.Root.Values['person'].Values['hobbies'].AsSequence.Count);
  finally
    if FileExists(fileName) then
      DeleteFile(fileName);
  end;
end;

procedure TYAMLWriterTests.Test_WriteToFile_WithEncoding;
var
  doc: IYAMLDocument;
  root: IYAMLMapping;
  fileName: string;
begin
  doc := TYAML.CreateMapping;
  root := doc.AsMapping;
  
  root.AddOrSetValue('unicode_text', 'Hëllö Wörld Ñiño');
  root.AddOrSetValue('emoji', '👋 🌍');
  
  doc.Options.Encoding := TEncoding.UTF8;
  doc.Options.WriteByteOrderMark := True;
  
  fileName := 'test_encoding.yml';
  try
    TYAML.WriteToFile(doc, fileName);
    Assert.IsTrue(FileExists(fileName));
  finally
    if FileExists(fileName) then
      DeleteFile(fileName);
  end;
end;

// Round-trip tests

procedure TYAMLWriterTests.Test_RoundTrip_SimpleMapping;
var
  originalYAML: string;
begin
  originalYAML := 'name: John Doe' + sLineBreak +
                 'age: 30' + sLineBreak +
                 'active: true';
  
  ValidateRoundTrip(originalYAML);
end;

procedure TYAMLWriterTests.Test_RoundTrip_SimpleSequence;
var
  originalYAML: string;
begin
  originalYAML := '- apple' + sLineBreak +
                 '- banana' + sLineBreak +
                 '- cherry';
  
  ValidateRoundTrip(originalYAML);
end;

procedure TYAMLWriterTests.Test_RoundTrip_ComplexStructure;
var
  originalYAML: string;
begin
  originalYAML := 'person:' + sLineBreak +
                 '  name: Jane Smith' + sLineBreak +
                 '  age: 28' + sLineBreak +
                 '  hobbies:' + sLineBreak +
                 '    - reading' + sLineBreak +
                 '    - hiking';
  
  ValidateRoundTrip(originalYAML);
end;

procedure TYAMLWriterTests.Test_RoundTrip_AllTypes;
var
  originalYAML: string;
begin
  originalYAML := 'null_value: null' + sLineBreak +
                 'bool_true: true' + sLineBreak +
                 'bool_false: false' + sLineBreak +
                 'integer: 42' + sLineBreak +
                 'float: 3.14' + sLineBreak +
                 'string: "hello world"' + sLineBreak +
                 'timestamp: 2023-12-25T10:30:00Z';
  
  ValidateRoundTrip(originalYAML);
end;

// Dynamic modification tests

procedure TYAMLWriterTests.Test_DynamicModification_AddToMapping;
var
  doc: IYAMLDocument;
  root: IYAMLMapping;
  yamlStr1, yamlStr2: string;
begin
  doc := TYAML.CreateMapping;
  root := doc.AsMapping;
  
  root.AddOrSetValue('initial_key', 'initial_value');
  yamlStr1 := TYAML.WriteToString(doc);
  
  root.AddOrSetValue('added_key', 'added_value');
  yamlStr2 := TYAML.WriteToString(doc);
  
  Assert.Contains(yamlStr1, 'initial_key');
  Assert.AreNotEqual(yamlStr1, yamlStr2);
  Assert.Contains(yamlStr2, 'added_key');
end;

procedure TYAMLWriterTests.Test_DynamicModification_AddToSequence;
var
  doc: IYAMLDocument;
  root: IYAMLSequence;
  yamlStr1, yamlStr2: string;
begin
  doc := TYAML.CreateSequence;
  root := doc.AsSequence;
  
  root.AddValue('first_item');
  yamlStr1 := TYAML.WriteToString(doc);
  
  root.AddValue('second_item');
  yamlStr2 := TYAML.WriteToString(doc);
  
  Assert.Contains(yamlStr1, 'first_item');
  Assert.AreNotEqual(yamlStr1, yamlStr2);
  Assert.Contains(yamlStr2, 'second_item');
end;

procedure TYAMLWriterTests.Test_DynamicModification_UpdateValues;
var
  doc: IYAMLDocument;
  root: IYAMLMapping;
  yamlStr1, yamlStr2: string;
begin
  doc := TYAML.CreateMapping;
  root := doc.AsMapping;
  
  root.AddOrSetValue('key', 'original_value');
  yamlStr1 := TYAML.WriteToString(doc);
  
  root.AddOrSetValue('key', 'updated_value');
  yamlStr2 := TYAML.WriteToString(doc);
  
  Assert.Contains(yamlStr1, 'original_value');
  Assert.Contains(yamlStr2, 'updated_value');
  Assert.AreNotEqual(yamlStr1, yamlStr2);
end;

procedure TYAMLWriterTests.Test_DynamicModification_NestedStructures;
var
  doc: IYAMLDocument;
  root, nested: IYAMLMapping;
  yamlStr: string;
begin
  doc := TYAML.CreateMapping;
  root := doc.AsMapping;
  
  nested := root.AddOrSetMapping('nested');
  nested.AddOrSetValue('initial', 'value');
  
  nested.AddOrSetValue('added', 'new_value');
  
  yamlStr := TYAML.WriteToString(doc);
  
  Assert.Contains(yamlStr, 'nested');
  Assert.Contains(yamlStr, 'initial');
  Assert.Contains(yamlStr, 'added');
end;

// Performance and edge cases

procedure TYAMLWriterTests.Test_WriteLargeDocument;
var
  doc: IYAMLDocument;
  root: IYAMLMapping;
  items: IYAMLSequence;
  i: Integer;
  yamlStr: string;
begin
  doc := TYAML.CreateMapping;
  root := doc.AsMapping;
  
  items := root.AddOrSetSequence('items');
  
  for i := 1 to 100 do
  begin
    items.AddValue(Format('Item %d', [i], YAMLFormatSettings));
  end;
  
  yamlStr := TYAML.WriteToString(doc);
  
  Assert.Contains(yamlStr, 'Item 1');
  Assert.Contains(yamlStr, 'Item 100');
end;

procedure TYAMLWriterTests.Test_WriteDeepNesting_Performance;
var
  doc: IYAMLDocument;
  current: IYAMLMapping;
  i: Integer;
  yamlStr: string;
begin
  doc := TYAML.CreateMapping;
  current := doc.AsMapping;
  
  for i := 1 to 10 do
  begin
    current.AddOrSetValue(Format('value_%d', [i], YAMLFormatSettings), i);
    current := current.AddOrSetMapping(Format('level_%d', [i], YAMLFormatSettings));
  end;
  
  yamlStr := TYAML.WriteToString(doc);
  
  Assert.Contains(yamlStr, 'level_1');
  Assert.Contains(yamlStr, 'level_10');
end;

procedure TYAMLWriterTests.Test_WriteManyItems;
var
  doc: IYAMLDocument;
  root: IYAMLMapping;
  i: Integer;
  yamlStr: string;
begin
  doc := TYAML.CreateMapping;
  root := doc.AsMapping;
  
  for i := 1 to 50 do
  begin
    root.AddOrSetValue(Format('key_%d', [i]), Format('value_%d', [i], YAMLFormatSettings));
  end;
  
  yamlStr := TYAML.WriteToString(doc);
  
  Assert.Contains(yamlStr, 'key_1');
  Assert.Contains(yamlStr, 'key_50');
  Assert.Contains(yamlStr, 'value_1');
  Assert.Contains(yamlStr, 'value_50');
end;

// Error handling

procedure TYAMLWriterTests.Test_WriteToFile_InvalidPath;
var
  doc: IYAMLDocument;
  root: IYAMLMapping;
begin
  doc := TYAML.CreateMapping;
  root := doc.AsMapping;
  
  root.AddOrSetValue('key', 'value');

  Assert.WillRaise(
    procedure
    begin
      // Try to write to invalid path
      TYAML.WriteToFile(doc, '/invalid/path/file.yml');
    end,
    EFCreateError);

end;

procedure TYAMLWriterTests.Test_WriteToString_InvalidOptions;
var
  doc: IYAMLDocument;
  root: IYAMLMapping;
  yamlStr: string;
begin
  doc := TYAML.CreateMapping;
  root := doc.AsMapping;
  
  root.AddOrSetValue('key', 'value');
  
  // Test with extreme values
  doc.Options.IndentSize := 0;
  doc.Options.MaxLineLength := 1;
  
  yamlStr := TYAML.WriteToString(doc);
  
  // Should still produce valid output
  Assert.IsNotEmpty(yamlStr);
end;

// TYAML.WriteAllToString comprehensive tests

procedure TYAMLWriterTests.Test_WriteAllToString_EmptyArray;
var
  docs: TArray<IYAMLDocument>;
  yamlStr: string;
begin
  SetLength(docs, 0);
  yamlStr := TYAML.WriteToString(docs);
  
  Assert.AreEqual('', yamlStr, 'WriteAllToString should return empty string for empty array');
end;

procedure TYAMLWriterTests.Test_WriteAllToString_SingleDocument;
var
  docs: TArray<IYAMLDocument>;
  doc: IYAMLDocument;
  root: IYAMLMapping;
  yamlStr, singleStr: string;
begin
  doc := TYAML.CreateMapping;
  root := doc.AsMapping;
  root.AddOrSetValue('name', 'John Doe');
  root.AddOrSetValue('age', 30);
  
  SetLength(docs, 1);
  docs[0] := doc;
  
  yamlStr := TYAML.WriteToString(docs);
  singleStr := TYAML.WriteToString(doc);
  
  Assert.IsNotEmpty(yamlStr, 'WriteAllToString should return non-empty string for single document');
  Assert.AreEqual(singleStr, yamlStr, 'Single document output should match WriteToString output');
  Assert.Contains(yamlStr, 'John Doe');
  Assert.Contains(yamlStr, '30');
end;

procedure TYAMLWriterTests.Test_WriteAllToString_MultipleDocuments;
var
  docs: TArray<IYAMLDocument>;
  doc1, doc2, doc3: IYAMLDocument;
  root1, root2: IYAMLMapping;
  root3: IYAMLSequence;
  yamlStr: string;
  lineCount: integer;
  i: integer;
begin
  doc1 := TYAML.CreateMapping;
  root1 := doc1.AsMapping;
  root1.AddOrSetValue('document', 1);
  root1.AddOrSetValue('type', 'mapping');
  
  doc2 := TYAML.CreateMapping;
  root2 := doc2.AsMapping;
  root2.AddOrSetValue('document', 2);
  root2.AddOrSetValue('type', 'mapping');
  
  doc3 := TYAML.CreateSequence;
  root3 := doc3.AsSequence;
  root3.AddValue('item1');
  root3.AddValue('item2');
  root3.AddValue('item3');
  
  SetLength(docs, 3);
  docs[0] := doc1;
  docs[1] := doc2;
  docs[2] := doc3;
  
  yamlStr := TYAML.WriteToString(docs);
  
  Assert.IsNotEmpty(yamlStr, 'WriteAllToString should return non-empty string for multiple documents');
  Assert.Contains(yamlStr, 'document: 1');
  Assert.Contains(yamlStr, 'document: 2');
  Assert.Contains(yamlStr, 'item1');
  Assert.Contains(yamlStr, 'item2');
  Assert.Contains(yamlStr, 'item3');
  
  lineCount := 0;
  for i := 1 to Length(yamlStr) do
    if yamlStr[i] = #10 then
      Inc(lineCount);
  
  Assert.IsTrue(lineCount > 5, 'Multiple documents should produce multiple lines of output');
end;

procedure TYAMLWriterTests.Test_WriteAllToString_DocumentMarkers;
var
  docs: TArray<IYAMLDocument>;
  doc1, doc2: IYAMLDocument;
  root1, root2: IYAMLMapping;
  yamlStr: string;
begin
  doc1 := TYAML.CreateMapping;
  root1 := doc1.AsMapping;
  root1.AddOrSetValue('first', 'document');
  doc1.Options.EmitDocumentMarkers := false;
  
  doc2 := TYAML.CreateMapping;
  root2 := doc2.AsMapping;
  root2.AddOrSetValue('second', 'document');
  doc2.Options.EmitDocumentMarkers := false;
  
  SetLength(docs, 2);
  docs[0] := doc1;
  docs[1] := doc2;
  
  yamlStr := TYAML.WriteToString(docs);
  
  Assert.IsNotEmpty(yamlStr, 'WriteAllToString should return non-empty string');
  Assert.Contains(yamlStr, '---', 'Multiple documents should force document markers even if individual options disable them');
  Assert.Contains(yamlStr, 'first');
  Assert.Contains(yamlStr, 'second');
end;

procedure TYAMLWriterTests.Test_WriteAllToString_DifferentRootTypes;
var
  docs: TArray<IYAMLDocument>;
  mappingDoc, sequenceDoc, setDoc: IYAMLDocument;
  mapping: IYAMLMapping;
  sequence: IYAMLSequence;
  setRoot: IYAMLSet;
  yamlStr: string;
begin
  mappingDoc := TYAML.CreateMapping;
  mapping := mappingDoc.AsMapping;
  mapping.AddOrSetValue('type', 'mapping');
  mapping.AddOrSetValue('key', 'value');
  
  sequenceDoc := TYAML.CreateSequence;
  sequence := sequenceDoc.AsSequence;
  sequence.AddValue('first');
  sequence.AddValue('second');
  sequence.AddValue('third');
  
  setDoc := TYAML.CreateSet;
  setRoot := setDoc.AsSet;
  setRoot.AddValue('unique1');
  setRoot.AddValue('unique2');
  
  SetLength(docs, 3);
  docs[0] := mappingDoc;
  docs[1] := sequenceDoc;
  docs[2] := setDoc;
  
  yamlStr := TYAML.WriteToString(docs);
  
  Assert.IsNotEmpty(yamlStr, 'WriteAllToString should handle different root types');
  Assert.Contains(yamlStr, 'type: mapping');
  Assert.Contains(yamlStr, '- first');
  Assert.Contains(yamlStr, 'unique1');
  Assert.Contains(yamlStr, '---', 'Should contain document markers');
end;

procedure TYAMLWriterTests.Test_WriteAllToString_DifferentOptions;
var
  docs: TArray<IYAMLDocument>;
  doc1, doc2, doc3: IYAMLDocument;
  root1, root2, root3: IYAMLMapping;
  yamlStr: string;
begin
  doc1 := TYAML.CreateMapping;
  root1 := doc1.AsMapping;
  root1.AddOrSetValue('string_value', 'hello world');
  root1.AddOrSetValue('number', 42);
  doc1.Options.IndentSize := 2;
  doc1.Options.QuoteStrings := false;
  
  doc2 := TYAML.CreateMapping;
  root2 := doc2.AsMapping;
  root2.AddOrSetValue('quoted_string', 'needs quotes: yes');
  root2.AddOrSetValue('another_number', 84);
  doc2.Options.IndentSize := 4;
  doc2.Options.QuoteStrings := true;
  
  doc3 := TYAML.CreateMapping;
  root3 := doc3.AsMapping;
  root3.AddOrSetValue('format_test', 'flow style');
  doc3.Options.Format := TYAMLOutputFormat.yofFlow;
  
  SetLength(docs, 3);
  docs[0] := doc1;
  docs[1] := doc2;
  docs[2] := doc3;
  
  yamlStr := TYAML.WriteToString(docs);
  
  Assert.IsNotEmpty(yamlStr, 'WriteAllToString should handle documents with different options');
  Assert.Contains(yamlStr, 'hello world');
  Assert.Contains(yamlStr, '42');
  Assert.Contains(yamlStr, 'needs quotes: yes');
  Assert.Contains(yamlStr, '84');
  Assert.Contains(yamlStr, 'format_test');
end;

procedure TYAMLWriterTests.Test_WriteAllToString_ComplexDocuments;
var
  docs: TArray<IYAMLDocument>;
  doc1, doc2: IYAMLDocument;
  root1, root2, person, config: IYAMLMapping;
  hobbies, servers: IYAMLSequence;
  yamlStr: string;
begin
  doc1 := TYAML.CreateMapping;
  root1 := doc1.AsMapping;
  
  person := root1.AddOrSetMapping('person');
  person.AddOrSetValue('name', 'Alice Johnson');
  person.AddOrSetValue('age', 28);
  person.AddOrSetValue('email', 'alice@example.com');
  
  hobbies := person.AddOrSetSequence('hobbies');
  hobbies.AddValue('photography');
  hobbies.AddValue('hiking');
  hobbies.AddValue('cooking');
  
  doc2 := TYAML.CreateMapping;
  root2 := doc2.AsMapping;
  
  config := root2.AddOrSetMapping('server_config');
  config.AddOrSetValue('version', '2.1.0');
  config.AddOrSetValue('debug_mode', true);
  config.AddOrSetValue('max_connections', 100);
  
  servers := config.AddOrSetSequence('servers');
  servers.AddValue('web01.example.com');
  servers.AddValue('web02.example.com');
  servers.AddValue('db01.example.com');
  
  SetLength(docs, 2);
  docs[0] := doc1;
  docs[1] := doc2;
  
  yamlStr := TYAML.WriteToString(docs);
  
  Assert.IsNotEmpty(yamlStr, 'WriteAllToString should handle complex nested documents');
  Assert.Contains(yamlStr, 'Alice Johnson');
  Assert.Contains(yamlStr, 'photography');
  Assert.Contains(yamlStr, 'server_config');
  Assert.Contains(yamlStr, '2.1.0');
  Assert.Contains(yamlStr, 'web01.example.com');
  Assert.Contains(yamlStr, 'true');
  Assert.Contains(yamlStr, '100');
  Assert.Contains(yamlStr, '---', 'Should contain document markers');
end;

procedure TYAMLWriterTests.Test_WriteAllToString_ManyDocuments;
var
  docs: TArray<IYAMLDocument>;
  i: integer;
  doc: IYAMLDocument;
  root: IYAMLMapping;
  yamlStr: string;
  markerCount: integer;
  p : integer;
begin
  SetLength(docs, 10);

  for i := 0 to 9 do
  begin
    doc := TYAML.CreateMapping;
    root := doc.AsMapping;
    root.AddOrSetValue('document_id', i + 1);
    root.AddOrSetValue('title', Format('Document Number %d', [i + 1], YAMLFormatSettings));
    root.AddOrSetValue('active', (i mod 2) = 0);
    docs[i] := doc;
  end;

  yamlStr := TYAML.WriteToString(docs);

  Assert.IsNotEmpty(yamlStr, 'WriteAllToString should handle many documents');
  Assert.Contains(yamlStr, 'document_id: 1');
  Assert.Contains(yamlStr, 'document_id: 10');
  Assert.Contains(yamlStr, 'Document Number 1');
  Assert.Contains(yamlStr, 'Document Number 10');

  markerCount := 0;
  p := 1;
  while p <= Length(yamlStr) do
  begin
    p := Pos('---', yamlStr, p);

    if p > 0 then
    begin
      Inc(markerCount);
      Inc(p,3);
    end
    else
      exit;
  end;
  
  Assert.AreEqual(10, markerCount, 'Should have document markers for each of the 10 documents');
end;

procedure TYAMLWriterTests.Test_WriteAllToString_RoundTrip;
var
  originalDocs, loadedDocs: TArray<IYAMLDocument>;
  doc1, doc2: IYAMLDocument;
  root1, root2: IYAMLMapping;
  yamlStr: string;
begin
  doc1 := TYAML.CreateMapping;
  root1 := doc1.AsMapping;
  root1.AddOrSetValue('name', 'Test Document 1');
  root1.AddOrSetValue('version', 1);
  root1.AddOrSetValue('enabled', true);
  
  doc2 := TYAML.CreateMapping;
  root2 := doc2.AsMapping;
  root2.AddOrSetValue('name', 'Test Document 2');
  root2.AddOrSetValue('version', 2);
  root2.AddOrSetValue('enabled', false);
  
  SetLength(originalDocs, 2);
  originalDocs[0] := doc1;
  originalDocs[1] := doc2;
  
  yamlStr := TYAML.WriteToString(originalDocs);
  
  Assert.IsNotEmpty(yamlStr, 'WriteAllToString should produce non-empty output');
  
  loadedDocs := TYAML.LoadAllFromString(yamlStr);
  
  Assert.AreEqual<Int64>(2, Length(loadedDocs), 'Should load back the same number of documents');
  
  Assert.IsTrue(loadedDocs[0].IsMapping, 'First loaded document should be a mapping');
  Assert.IsTrue(loadedDocs[1].IsMapping, 'Second loaded document should be a mapping');
  
  Assert.AreEqual('Test Document 1', loadedDocs[0].Root.Values['name'].AsString);
  Assert.AreEqual<Int64>(1, loadedDocs[0].Root.Values['version'].AsInteger);
  Assert.AreEqual(true, loadedDocs[0].Root.Values['enabled'].AsBoolean);
  
  Assert.AreEqual('Test Document 2', loadedDocs[1].Root.Values['name'].AsString);
  Assert.AreEqual<Int64>(2, loadedDocs[1].Root.Values['version'].AsInteger);
  Assert.AreEqual(false, loadedDocs[1].Root.Values['enabled'].AsBoolean);
end;

initialization
  TDUnitX.RegisterTestFixture(TYAMLWriterTests);

end.
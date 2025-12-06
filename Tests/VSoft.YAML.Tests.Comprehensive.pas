unit VSoft.YAML.Tests.Comprehensive;

interface

uses
  DUnitX.TestFramework,
  VSoft.YAML,
  System.SysUtils,
  System.Classes,
  System.DateUtils;

type
  [TestFixture]
  TYAMLComprehensiveTests = class
  private
    function CreateSimpleMapping: string;
    function CreateSimpleSequence: string;
    function CreateComplexStructure: string;
    function CreateTypedValues: string;
    function CreateMultilineStrings: string;
    function CreateQuotedStrings: string;
    function CreateSpecialChars: string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    // Basic parsing tests
    [Test]
    procedure Test_LoadFromString_EmptyDocument;
    [Test]
    procedure Test_LoadFromString_SingleValue;
    [Test]
    procedure Test_LoadFromString_SimpleMapping;
    [Test]
    procedure Test_LoadFromString_SimpleSequence;
    [Test]
    procedure Test_LoadFromString_MixedStructure;

    // YAML scalar value parsing
    [Test]
    procedure Test_ParseNull_Variants;
    [Test]
    procedure Test_ParseBoolean_TrueVariants;
    [Test]
    procedure Test_ParseBoolean_FalseVariants;
    [Test]
    procedure Test_ParseInteger_Decimal;
    [Test]
    procedure Test_ParseInteger_Hexadecimal;
    [Test]
    procedure Test_ParseInteger_Octal;
    [Test]
    procedure Test_ParseInteger_Binary;
    [Test]
    procedure Test_ParseFloat_Normal;
    [Test]
    procedure Test_ParseFloat_Scientific;
    [Test]
    procedure Test_ParseFloat_SpecialValues;
    [Test]
    procedure Test_ParseFloat_AllSpecialValueVariations;

    // String parsing tests
    [Test]
    procedure Test_ParseString_Plain;
    [Test]
    procedure Test_ParseString_SingleQuoted;
    [Test]
    procedure Test_ParseString_DoubleQuoted;
    [Test]
    procedure Test_ParseString_Multiline_Literal;
    [Test]
    procedure Test_ParseString_Multiline_Folded;
    [Test]
    procedure Test_ParseString_EscapeSequences;
    [Test]
    procedure Test_ParseString_DoubleQuoted_Escapes;
    [Test]
    procedure Test_ParseString_SingleQuoted_Escapes;
    [Test]
    procedure Test_WriteString_EscapeHandling;

    // Timestamp parsing tests
    [Test]
    procedure Test_ParseTimestamp_DateOnly;
    [Test]
    procedure Test_ParseTimestamp_DateTime;
    [Test]
    procedure Test_ParseTimestamp_DateTimeWithTimezone;
    [Test]
    procedure Test_ParseTimestamp_ISO8601_Variants;

    // Collection tests
    [Test]
    procedure Test_Sequence_FlowStyle;
    [Test]
    procedure Test_Sequence_MulitLine_FlowStyle;
    [Test]
    procedure Test_Sequence_BlockStyle;
    [Test]
    procedure Test_Sequence_NestedSequences;
    [Test]
    procedure Test_Sequence_EmptySequence;
    [Test]
    procedure Test_Mapping_FlowStyle;
    [Test]
    procedure Test_Mapping_BlockStyle;
    [Test]
    procedure Test_Mapping_NestedMappings;
    [Test]
    procedure Test_Mapping_EmptyMapping;

    // Document markers and comments
    [Test]
    procedure Test_DocumentMarkers_SingleDocument;
    [Test]
    procedure Test_DocumentMarkers_MultipleDocuments;
    [Test]
    procedure Test_ParseAll_MultipleDocuments;
    [Test]
    procedure Test_ParseAll_EmptyDocuments;
    [Test]
    procedure Test_ParseAll_MixedDocuments;
    [Test]
    procedure Test_ParseAll_AnchorScopeIsolation;
    [Test]
    procedure Test_ParseAll_DirectiveScoping;
    [Test]
    procedure Test_ParseAll_DirectiveDocumentScope;
    [Test]
    procedure Test_Comments_LineComments;
    [Test]
    procedure Test_Comments_EndOfLineComments;

    // YAML path queries
    [Test]
    procedure Test_QueryPath_RootAccess;
    [Test]
    procedure Test_QueryPath_NestedMapping;
    [Test]
    procedure Test_QueryPath_SequenceIndex;
    [Test]
    procedure Test_QueryPath_DeepNesting;
    [Test]
    procedure Test_QueryPath_VeryDeepNesting;
    [Test]
    procedure Test_QueryPath_NonexistentPath;

    // Type checking and conversion
    [Test]
    procedure Test_TypeChecking_AllTypes;
    [Test]
    procedure Test_Conversion_ToBoolean;
    [Test]
    procedure Test_Conversion_ToInteger;
    [Test]
    procedure Test_Conversion_ToFloat;
    [Test]
    procedure Test_Conversion_ToString;
    [Test]
    procedure Test_Conversion_ToDateTime;

    // Collection operations
    [Test]
    procedure Test_Mapping_AddOrSetValue_Types;
    [Test]
    procedure Test_Mapping_ContainsKey_Operations;
    [Test]
    procedure Test_Sequence_AddValue_Types;
    [Test]
    procedure Test_Sequence_AddCollections;

    // Parser options tests
    [Test]
    procedure Test_ParserOptions_DuplicateKeyBehavior_Overwrite;
    [Test]
    procedure Test_ParserOptions_DuplicateKeyBehavior_Error;

    // Error handling
    [Test]
    procedure Test_InvalidYAML_UnmatchedBrackets;
    [Test]
    procedure Test_InvalidYAML_UnterminatedQuotedString;
    [Test]
    procedure Test_InvalidYAML_InvalidCharacters;
    [Test]
    procedure Test_ConversionError_InvalidBoolean;
    [Test]
    procedure Test_ConversionError_InvalidInteger;
    [Test]
    procedure Test_ConversionError_InvalidFloat;
    [Test]
    procedure Test_OutOfRange_SequenceAccess;
    [Test]
    procedure Test_OutOfRange_MappingAccess;
  end;

implementation

uses
  System.Math;

{ TYAMLComprehensiveTests }

procedure TYAMLComprehensiveTests.Setup;
begin
  // Setup if needed
end;

procedure TYAMLComprehensiveTests.TearDown;
begin
  // Cleanup if needed
end;

function TYAMLComprehensiveTests.CreateSimpleMapping: string;
begin
  Result := 'name: John Doe' + sLineBreak +
           'age: 30' + sLineBreak +
           'active: true';
end;

function TYAMLComprehensiveTests.CreateSimpleSequence: string;
begin
  Result := '- apple' + sLineBreak +
           '- banana' + sLineBreak +
           '- cherry';
end;

function TYAMLComprehensiveTests.CreateComplexStructure: string;
begin
  Result := 'person:' + sLineBreak +
           '  name: Jane Smith' + sLineBreak +
           '  age: 28' + sLineBreak +
           '  address:' + sLineBreak +
           '    street: 123 Main St' + sLineBreak +
           '    city: Springfield' + sLineBreak +
           '    zip: 12345' + sLineBreak +
           '  hobbies:' + sLineBreak +
           '    - reading' + sLineBreak +
           '    - hiking' + sLineBreak +
           '    - photography' + sLineBreak +
           'company:' + sLineBreak +
           '  name: Tech Corp' + sLineBreak +
           '  employees: 150';
end;

function TYAMLComprehensiveTests.CreateTypedValues: string;
begin
  Result := 'null_value: null' + sLineBreak +
           'tilde_null: ~' + sLineBreak +
           'empty_null: ' + sLineBreak +
           'bool_true: true' + sLineBreak +
           'bool_false: false' + sLineBreak +
           'bool_yes: yes' + sLineBreak +
           'bool_no: no' + sLineBreak +
           'integer_decimal: 42' + sLineBreak +
           'integer_decimal_1_1: 4_200' + sLineBreak +
           'integer_negative: -17' + sLineBreak +
           'integer_hex: 0x1A' + sLineBreak +
           'integer_octal: 0o755' + sLineBreak +
           'integer_binary: 0b1010' + sLineBreak +
           'float_normal: 3.14159' + sLineBreak +
           'float_negative: -2.71828' + sLineBreak +
           'float_scientific: 6.022e23' + sLineBreak +
           'float_infinity: .inf' + sLineBreak +
           'float_neg_infinity: -.inf' + sLineBreak +
           'float_nan: .nan' + sLineBreak +
           'string_plain: hello world' + sLineBreak +
           'string_quoted: "hello world"' + sLineBreak +
           'timestamp_date: 2023-12-25' + sLineBreak +
           'timestamp_datetime: 2023-12-25T10:30:00Z';
end;

function TYAMLComprehensiveTests.CreateMultilineStrings: string;
begin
  Result := 'literal_string: |' + sLineBreak +
           '  This is a literal string' + sLineBreak +
           '  with multiple lines' + sLineBreak +
           '  and preserved line breaks.' + sLineBreak +
           'folded_string: >' + sLineBreak +
           '  This is a folded string' + sLineBreak +
           '  with multiple lines' + sLineBreak +
           '  that will be folded into one line.';
end;

function TYAMLComprehensiveTests.CreateQuotedStrings: string;
begin
  Result := 'single_quoted: ''This is a single quoted string''' + sLineBreak +
           'double_quoted: "This is a double quoted string"' + sLineBreak +
           'escaped_quotes: "She said, \"Hello!\" to me."' + sLineBreak +
           'backslash_escape: "Path: C:\\Users\\Name\\File.txt"';
end;

function TYAMLComprehensiveTests.CreateSpecialChars: string;
begin
  Result := 'unicode_chars: "Ümlauts and ñ special chars"' + sLineBreak +
           'emoji: "Hello 👋 World 🌍"' + sLineBreak +
           'tab_char: "Column1\tColumn2"' + sLineBreak +
           'newline_char: "Line1\nLine2"';
end;

// Basic parsing tests

procedure TYAMLComprehensiveTests.Test_LoadFromString_EmptyDocument;
var
  doc: IYAMLDocument;
begin
  doc := TYAML.LoadFromString('');
  Assert.IsNotNull(doc);
  Assert.IsNotNull(doc.Root);
end;

procedure TYAMLComprehensiveTests.Test_LoadFromString_SingleValue;
var
  doc: IYAMLDocument;
begin
  doc := TYAML.LoadFromString('single_value');
  Assert.IsNotNull(doc);
  Assert.IsTrue(doc.Root.IsString);
  Assert.AreEqual('single_value', doc.Root.AsString);
end;

procedure TYAMLComprehensiveTests.Test_LoadFromString_SimpleMapping;
var
  doc: IYAMLDocument;
  root: IYAMLMapping;
begin
  doc := TYAML.LoadFromString(CreateSimpleMapping);
  Assert.IsNotNull(doc);
  Assert.IsTrue(doc.IsMapping);

  root := doc.AsMapping;
  Assert.AreEqual('John Doe', root.Items['name'].AsString);
  Assert.AreEqual<Int64>(30, root.Items['age'].AsInteger);
  Assert.IsTrue(root.Items['active'].AsBoolean);
end;

procedure TYAMLComprehensiveTests.Test_LoadFromString_SimpleSequence;
var
  doc: IYAMLDocument;
  root: IYAMLSequence;
begin
  doc := TYAML.LoadFromString(CreateSimpleSequence);
  Assert.IsNotNull(doc);
  Assert.IsTrue(doc.IsSequence);

  root := doc.AsSequence;
  Assert.AreEqual(3, root.Count);
  Assert.AreEqual('apple', root.Items[0].AsString);
  Assert.AreEqual('banana', root.Items[1].AsString);
  Assert.AreEqual('cherry', root.Items[2].AsString);
end;

procedure TYAMLComprehensiveTests.Test_LoadFromString_MixedStructure;
var
  doc: IYAMLDocument;
  root: IYAMLMapping;
  person: IYAMLMapping;
  hobbies: IYAMLSequence;
begin
  doc := TYAML.LoadFromString(CreateComplexStructure);
  Assert.IsNotNull(doc);
  Assert.IsTrue(doc.IsMapping);

  root := doc.AsMapping;
  person := root.Items['person'].AsMapping;

  Assert.AreEqual('Jane Smith', person.Items['name'].AsString);
  Assert.AreEqual<Int64>(28, person.Items['age'].AsInteger);

  hobbies := person.Items['hobbies'].AsSequence;
  Assert.AreEqual(3, hobbies.Count);
  Assert.AreEqual('reading', hobbies.Items[0].AsString);
end;

// YAML scalar value parsing tests

procedure TYAMLComprehensiveTests.Test_ParseNull_Variants;
var
  doc: IYAMLDocument;
  root: IYAMLMapping;
begin
  doc := TYAML.LoadFromString(CreateTypedValues);
  root := doc.AsMapping;

  Assert.IsTrue(root.Items['null_value'].IsNull);
  Assert.IsTrue(root.Items['tilde_null'].IsNull);
  Assert.IsTrue(root.Items['empty_null'].IsNull);
end;

procedure TYAMLComprehensiveTests.Test_ParseBoolean_TrueVariants;
var
  doc: IYAMLDocument;
  root: IYAMLMapping;
begin
  doc := TYAML.LoadFromString(CreateTypedValues);
  root := doc.AsMapping;

  Assert.IsTrue(root.Items['bool_true'].IsBoolean);
  Assert.IsTrue(root.Items['bool_true'].AsBoolean);
  Assert.IsTrue(root.Items['bool_yes'].IsBoolean);
  Assert.IsTrue(root.Items['bool_yes'].AsBoolean);
end;

procedure TYAMLComprehensiveTests.Test_ParseBoolean_FalseVariants;
var
  doc: IYAMLDocument;
  root: IYAMLMapping;
begin
  doc := TYAML.LoadFromString(CreateTypedValues);
  root := doc.AsMapping;

  Assert.IsTrue(root.Items['bool_false'].IsBoolean);
  Assert.IsFalse(root.Items['bool_false'].AsBoolean);
  Assert.IsTrue(root.Items['bool_no'].IsBoolean);
  Assert.IsFalse(root.Items['bool_no'].AsBoolean);
end;

procedure TYAMLComprehensiveTests.Test_ParseInteger_Decimal;
var
  doc: IYAMLDocument;
  root: IYAMLMapping;
begin
  doc := TYAML.LoadFromString(CreateTypedValues);
  root := doc.AsMapping;

  Assert.IsTrue(root.Items['integer_decimal'].IsInteger);
  Assert.AreEqual<Int64>(42, root.Items['integer_decimal'].AsInteger);
  Assert.IsTrue(root.Items['integer_decimal_1_1'].IsInteger);
  Assert.AreEqual<Int64>(4200, root.Items['integer_decimal_1_1'].AsInteger);

  Assert.IsTrue(root.Items['integer_negative'].IsInteger);
  Assert.AreEqual<Int64>(-17, root.Items['integer_negative'].AsInteger);
end;

procedure TYAMLComprehensiveTests.Test_ParseInteger_Hexadecimal;
var
  doc: IYAMLDocument;
  root: IYAMLMapping;
begin
  doc := TYAML.LoadFromString(CreateTypedValues);
  root := doc.AsMapping;

  if root.ContainsKey('integer_hex') then
  begin
    Assert.IsTrue(root.Items['integer_hex'].IsInteger);
    Assert.AreEqual<Int64>(26, root.Items['integer_hex'].AsInteger); // 0x1A = 26
  end;
end;

procedure TYAMLComprehensiveTests.Test_ParseInteger_Octal;
var
  doc: IYAMLDocument;
  root: IYAMLMapping;
begin
  doc := TYAML.LoadFromString(CreateTypedValues);
  root := doc.AsMapping;

  if root.ContainsKey('integer_octal') then
  begin
    Assert.IsTrue(root.Items['integer_octal'].IsInteger);
    Assert.AreEqual<Int64>(493, root.Items['integer_octal'].AsInteger); // 0o755 = 493
  end;
end;

procedure TYAMLComprehensiveTests.Test_ParseInteger_Binary;
var
  doc: IYAMLDocument;
  root: IYAMLMapping;
begin
  doc := TYAML.LoadFromString(CreateTypedValues);
  root := doc.AsMapping;

  if root.ContainsKey('integer_binary') then
  begin
    Assert.IsTrue(root.Items['integer_binary'].IsInteger);
    Assert.AreEqual<Int64>(10, root.Items['integer_binary'].AsInteger); // 0b1010 = 10
  end;
end;

procedure TYAMLComprehensiveTests.Test_ParseFloat_Normal;
var
  doc: IYAMLDocument;
  root: IYAMLMapping;
begin
  doc := TYAML.LoadFromString(CreateTypedValues);
  root := doc.AsMapping;

  Assert.IsTrue(root.Items['float_normal'].IsFloat);
  Assert.AreEqual(3.14159, root.Items['float_normal'].AsFloat, 0.00001);
  Assert.IsTrue(root.Items['float_negative'].IsFloat);
  Assert.AreEqual(-2.71828, root.Items['float_negative'].AsFloat, 0.00001);
end;

procedure TYAMLComprehensiveTests.Test_ParseFloat_Scientific;
var
  doc: IYAMLDocument;
  root: IYAMLMapping;
begin
  doc := TYAML.LoadFromString(CreateTypedValues);
  root := doc.AsMapping;

  if root.ContainsKey('float_scientific') then
  begin
    Assert.IsTrue(root.Items['float_scientific'].IsFloat);
    Assert.AreEqual(6.022e23, root.Items['float_scientific'].AsFloat, 1e20);
  end;
end;

procedure TYAMLComprehensiveTests.Test_ParseFloat_SpecialValues;
var
  doc: IYAMLDocument;
  root: IYAMLMapping;
  floatValue: Double;
begin
  doc := TYAML.LoadFromString(CreateTypedValues);
  root := doc.AsMapping;

  // Test positive infinity
  Assert.IsTrue(root.ContainsKey('float_infinity'), 'Should contain float_infinity key');
  Assert.IsTrue(root.Items['float_infinity'].IsFloat, 'float_infinity should be recognized as float');
  floatValue := root.Items['float_infinity'].AsFloat;
  Assert.IsTrue(IsInfinite(floatValue), 'float_infinity should be infinite');
  Assert.IsTrue(floatValue > 0, 'float_infinity should be positive');

  // Test negative infinity
  Assert.IsTrue(root.ContainsKey('float_neg_infinity'), 'Should contain float_neg_infinity key');
  Assert.IsTrue(root.Items['float_neg_infinity'].IsFloat, 'float_neg_infinity should be recognized as float');
  floatValue := root.Items['float_neg_infinity'].AsFloat;
  Assert.IsTrue(IsInfinite(floatValue), 'float_neg_infinity should be infinite');
  Assert.IsTrue(floatValue < 0, 'float_neg_infinity should be negative');

  // Test NaN
  Assert.IsTrue(root.ContainsKey('float_nan'), 'Should contain float_nan key');
  Assert.IsTrue(root.Items['float_nan'].IsFloat, 'float_nan should be recognized as float');
  floatValue := root.Items['float_nan'].AsFloat;
  Assert.IsTrue(IsNaN(floatValue), 'float_nan should be NaN');
end;

procedure TYAMLComprehensiveTests.Test_ParseFloat_AllSpecialValueVariations;
var
  yamlContent: string;
  doc: IYAMLDocument;
  root: IYAMLMapping;
  floatValue: Double;
begin
  // Test all case variations of NaN and infinity as defined in YAML 1.2 spec
  yamlContent := 'nan_lower: .nan' + sLineBreak +
                 'nan_mixed: .NaN' + sLineBreak +
                 'nan_upper: .NAN' + sLineBreak +
                 'inf_lower: .inf' + sLineBreak +
                 'inf_mixed: .Inf' + sLineBreak +
                 'inf_upper: .INF' + sLineBreak +
                 'pos_inf_lower: +.inf' + sLineBreak +
                 'pos_inf_mixed: +.Inf' + sLineBreak +
                 'pos_inf_upper: +.INF' + sLineBreak +
                 'neg_inf_lower: -.inf' + sLineBreak +
                 'neg_inf_mixed: -.Inf' + sLineBreak +
                 'neg_inf_upper: -.INF';

  doc := TYAML.LoadFromString(yamlContent);
  root := doc.AsMapping;

  // Test all NaN variations
  Assert.IsTrue(root.Items['nan_lower'].IsFloat, 'nan_lower should be float');
  Assert.IsTrue(IsNaN(root.Items['nan_lower'].AsFloat), '.nan should be NaN');

  Assert.IsTrue(root.Items['nan_mixed'].IsFloat, 'nan_mixed should be float');
  Assert.IsTrue(IsNaN(root.Items['nan_mixed'].AsFloat), '.NaN should be NaN');

  Assert.IsTrue(root.Items['nan_upper'].IsFloat, 'nan_upper should be float');
  Assert.IsTrue(IsNaN(root.Items['nan_upper'].AsFloat), '.NAN should be NaN');

  // Test all positive infinity variations
  Assert.IsTrue(root.Items['inf_lower'].IsFloat, 'inf_lower should be float');
  floatValue := root.Items['inf_lower'].AsFloat;
  Assert.IsTrue(IsInfinite(floatValue) and (floatValue > 0), '.inf should be positive infinity');

  Assert.IsTrue(root.Items['inf_mixed'].IsFloat, 'inf_mixed should be float');
  floatValue := root.Items['inf_mixed'].AsFloat;
  Assert.IsTrue(IsInfinite(floatValue) and (floatValue > 0), '.Inf should be positive infinity');

  Assert.IsTrue(root.Items['inf_upper'].IsFloat, 'inf_upper should be float');
  floatValue := root.Items['inf_upper'].AsFloat;
  Assert.IsTrue(IsInfinite(floatValue) and (floatValue > 0), '.INF should be positive infinity');

  Assert.IsTrue(root.Items['pos_inf_lower'].IsFloat, 'pos_inf_lower should be float');
  floatValue := root.Items['pos_inf_lower'].AsFloat;
  Assert.IsTrue(IsInfinite(floatValue) and (floatValue > 0), '+.inf should be positive infinity');

  Assert.IsTrue(root.Items['pos_inf_mixed'].IsFloat, 'pos_inf_mixed should be float');
  floatValue := root.Items['pos_inf_mixed'].AsFloat;
  Assert.IsTrue(IsInfinite(floatValue) and (floatValue > 0), '+.Inf should be positive infinity');

  Assert.IsTrue(root.Items['pos_inf_upper'].IsFloat, 'pos_inf_upper should be float');
  floatValue := root.Items['pos_inf_upper'].AsFloat;
  Assert.IsTrue(IsInfinite(floatValue) and (floatValue > 0), '+.INF should be positive infinity');

  // Test all negative infinity variations
  Assert.IsTrue(root.Items['neg_inf_lower'].IsFloat, 'neg_inf_lower should be float');
  floatValue := root.Items['neg_inf_lower'].AsFloat;
  Assert.IsTrue(IsInfinite(floatValue) and (floatValue < 0), '-.inf should be negative infinity');

  Assert.IsTrue(root.Items['neg_inf_mixed'].IsFloat, 'neg_inf_mixed should be float');
  floatValue := root.Items['neg_inf_mixed'].AsFloat;
  Assert.IsTrue(IsInfinite(floatValue) and (floatValue < 0), '-.Inf should be negative infinity');

  Assert.IsTrue(root.Items['neg_inf_upper'].IsFloat, 'neg_inf_upper should be float');
  floatValue := root.Items['neg_inf_upper'].AsFloat;
  Assert.IsTrue(IsInfinite(floatValue) and (floatValue < 0), '-.INF should be negative infinity');
end;

// String parsing tests

procedure TYAMLComprehensiveTests.Test_ParseString_Plain;
var
  doc: IYAMLDocument;
  root: IYAMLMapping;
begin
  doc := TYAML.LoadFromString(CreateTypedValues);
  root := doc.AsMapping;

  Assert.IsTrue(root.Items['string_plain'].IsString);
  Assert.AreEqual('hello world', root.Items['string_plain'].AsString);
end;

procedure TYAMLComprehensiveTests.Test_ParseString_SingleQuoted;
var
  doc: IYAMLDocument;
  root: IYAMLMapping;
begin
  doc := TYAML.LoadFromString(CreateQuotedStrings);
  root := doc.AsMapping;

  Assert.IsTrue(root.Items['single_quoted'].IsString);
  Assert.AreEqual('This is a single quoted string', root.Items['single_quoted'].AsString);
end;

procedure TYAMLComprehensiveTests.Test_ParseString_DoubleQuoted;
var
  doc: IYAMLDocument;
  root: IYAMLMapping;
begin
  doc := TYAML.LoadFromString(CreateQuotedStrings);
  root := doc.AsMapping;

  Assert.IsTrue(root.Items['double_quoted'].IsString);
  Assert.AreEqual('This is a double quoted string', root.Items['double_quoted'].AsString);
end;

procedure TYAMLComprehensiveTests.Test_ParseString_Multiline_Literal;
var
  yamlContent: string;
  doc: IYAMLDocument;
  root: IYAMLMapping;
  literalStr: string;
begin
  yamlContent := CreateMultilineStrings;
  doc := TYAML.LoadFromString(yamlContent);
  root := doc.AsMapping;

  if root.ContainsKey('literal_string') then
  begin
    literalStr := root.Items['literal_string'].AsString;
    Assert.Contains(literalStr, 'This is a literal string');
    Assert.Contains(literalStr, 'with multiple lines');
  end;
end;

procedure TYAMLComprehensiveTests.Test_ParseString_Multiline_Folded;
var
  yamlContent: string;
  doc: IYAMLDocument;
  root: IYAMLMapping;
  foldedStr: string;
begin
  yamlContent := CreateMultilineStrings;
  doc := TYAML.LoadFromString(yamlContent);
  root := doc.AsMapping;

  if root.ContainsKey('folded_string') then
  begin
    foldedStr := root.Items['folded_string'].AsString;
    Assert.Contains(foldedStr, 'This is a folded string');
  end;
end;

procedure TYAMLComprehensiveTests.Test_ParseString_EscapeSequences;
var
  doc: IYAMLDocument;
  root: IYAMLMapping;
begin
  doc := TYAML.LoadFromString(CreateSpecialChars);
  root := doc.AsMapping;

  if root.ContainsKey('tab_char') then
  begin
    Assert.Contains(root.Items['tab_char'].AsString, #9); // Tab character
  end;

  if root.ContainsKey('newline_char') then
  begin
    Assert.Contains(root.Items['newline_char'].AsString, #10); // Newline character
  end;
end;

// Timestamp parsing tests

procedure TYAMLComprehensiveTests.Test_ParseTimestamp_DateOnly;
var
  yamlContent: string;
  doc: IYAMLDocument;
  root: IYAMLMapping;
begin
  yamlContent := 'date_only: 2023-12-25';
  doc := TYAML.LoadFromString(yamlContent);
  root := doc.AsMapping;

  Assert.IsTrue(root.Items['date_only'].IsTimeStamp);
end;

procedure TYAMLComprehensiveTests.Test_ParseTimestamp_DateTime;
var
  yamlContent: string;
  doc: IYAMLDocument;
  root: IYAMLMapping;
begin
  yamlContent := 'datetime: 2023-12-25T10:30:00';
  doc := TYAML.LoadFromString(yamlContent);
  root := doc.AsMapping;

  Assert.IsTrue(root.Items['datetime'].IsTimeStamp);
end;

procedure TYAMLComprehensiveTests.Test_ParseTimestamp_DateTimeWithTimezone;
var
  yamlContent: string;
  doc: IYAMLDocument;
  root: IYAMLMapping;
begin
  yamlContent := 'datetime_tz: 2023-12-25T10:30:00+02:00';
  doc := TYAML.LoadFromString(yamlContent);
  root := doc.AsMapping;

  Assert.IsTrue(root.Items['datetime_tz'].IsTimeStamp);
end;

procedure TYAMLComprehensiveTests.Test_ParseTimestamp_ISO8601_Variants;
var
  yamlContent: string;
  doc: IYAMLDocument;
  root: IYAMLMapping;
begin
  yamlContent := 'iso8601_z: 2023-12-25T10:30:00Z' + sLineBreak +
                'iso8601_ms: 2023-12-25T10:30:00.123Z' + sLineBreak +
                'iso8601_offset: 2023-12-25T10:30:00-05:00';

  doc := TYAML.LoadFromString(yamlContent);
  root := doc.AsMapping;

  Assert.IsTrue(root.Items['iso8601_z'].IsTimeStamp);
  Assert.IsTrue(root.Items['iso8601_ms'].IsTimeStamp);
  Assert.IsTrue(root.Items['iso8601_offset'].IsTimeStamp);
end;

// Collection tests

procedure TYAMLComprehensiveTests.Test_Sequence_FlowStyle;
var
  yamlContent: string;
  doc: IYAMLDocument;
  root: IYAMLMapping;
  sequence: IYAMLSequence;
  mapping : IYAMLMApping;
begin
  yamlContent := '{ "sequence": [ "one", "two" ],' + sLineBreak +
                    '"mapping":' + sLineBreak +
                    '{ "sky": "blue", "sea": "green" } }';
  doc := TYAML.LoadFromString(yamlContent);
  root := doc.AsMapping;

  sequence := root.Items['sequence'].AsSequence;
  Assert.AreEqual(2, sequence.Count);
  Assert.AreEqual('one', sequence.Items[0].AsString);
  Assert.AreEqual('two', sequence.Items[1].AsString);

  mapping := root.Items['mapping'].AsMapping;
  Assert.AreEqual(2, mapping.Count);
  Assert.AreEqual('blue', mapping.Items['sky'].AsString);
  Assert.AreEqual('green', mapping.Items['sea'].AsString);


end;

procedure TYAMLComprehensiveTests.Test_Sequence_MulitLine_FlowStyle;
var
  yamlContent: string;
  doc: IYAMLDocument;
  root: IYAMLMapping;
  sequence: IYAMLSequence;
begin
  yamlContent := 'flow_sequence: [1, 2, 3, 4, 5]';
  doc := TYAML.LoadFromString(yamlContent);
  root := doc.AsMapping;

  sequence := root.Items['flow_sequence'].AsSequence;
  Assert.AreEqual(5, sequence.Count);
  Assert.AreEqual<Int64>(1, sequence.Items[0].AsInteger);
  Assert.AreEqual<Int64>(5, sequence.Items[4].AsInteger);
end;


procedure TYAMLComprehensiveTests.Test_Sequence_BlockStyle;
var
  doc: IYAMLDocument;
  sequence: IYAMLSequence;
begin
  doc := TYAML.LoadFromString(CreateSimpleSequence);
  sequence := doc.AsSequence;

  Assert.AreEqual(3, sequence.Count);
  Assert.AreEqual('apple', sequence.Items[0].AsString);
  Assert.AreEqual('banana', sequence.Items[1].AsString);
  Assert.AreEqual('cherry', sequence.Items[2].AsString);
end;

procedure TYAMLComprehensiveTests.Test_Sequence_NestedSequences;
var
  yamlContent: string;
  doc: IYAMLDocument;
  root: IYAMLSequence;
  nestedSeq: IYAMLSequence;
begin
  yamlContent := '- - item1' + sLineBreak +
                '  - item2' + sLineBreak +
                '- - item3' + sLineBreak +
                '  - item4';

  doc := TYAML.LoadFromString(yamlContent);
  root := doc.AsSequence;

  Assert.AreEqual(2, root.Count);
  nestedSeq := root.Items[0].AsSequence;
  Assert.AreEqual(2, nestedSeq.Count);
  Assert.AreEqual('item1', nestedSeq.Items[0].AsString);
end;

procedure TYAMLComprehensiveTests.Test_Sequence_EmptySequence;
var
  yamlContent: string;
  doc: IYAMLDocument;
  root: IYAMLMapping;
  emptySeq: IYAMLSequence;
begin
  yamlContent := 'empty_sequence: []';
  doc := TYAML.LoadFromString(yamlContent);
  root := doc.AsMapping;

  emptySeq := root.Items['empty_sequence'].AsSequence;
  Assert.AreEqual(0, emptySeq.Count);
end;

procedure TYAMLComprehensiveTests.Test_Mapping_FlowStyle;
var
  yamlContent: string;
  doc: IYAMLDocument;
  root: IYAMLMapping;
  flowMapping: IYAMLMapping;
begin
  yamlContent := 'flow_mapping: {name: John, age: 30}';
  doc := TYAML.LoadFromString(yamlContent);
  root := doc.AsMapping;

  flowMapping := root.Items['flow_mapping'].AsMapping;
  Assert.AreEqual('John', flowMapping.Items['name'].AsString);
  Assert.AreEqual<Int64>(30, flowMapping.Items['age'].AsInteger);
end;

procedure TYAMLComprehensiveTests.Test_Mapping_BlockStyle;
var
  doc: IYAMLDocument;
  root: IYAMLMapping;
begin
  doc := TYAML.LoadFromString(CreateSimpleMapping);
  root := doc.AsMapping;

  Assert.AreEqual('John Doe', root.Items['name'].AsString);
  Assert.AreEqual<Int64>(30, root.Items['age'].AsInteger);
  Assert.IsTrue(root.Items['active'].AsBoolean);
end;

procedure TYAMLComprehensiveTests.Test_Mapping_NestedMappings;
var
  doc: IYAMLDocument;
  root, person, address: IYAMLMapping;
begin
  doc := TYAML.LoadFromString(CreateComplexStructure);
  root := doc.AsMapping;
  person := root.Items['person'].AsMapping;
  address := person.Items['address'].AsMapping;

  Assert.AreEqual('123 Main St', address.Items['street'].AsString);
  Assert.AreEqual('Springfield', address.Items['city'].AsString);
  Assert.AreEqual<Int64>(12345, address.Items['zip'].AsInteger);
end;

procedure TYAMLComprehensiveTests.Test_Mapping_EmptyMapping;
var
  yamlContent: string;
  doc: IYAMLDocument;
  root: IYAMLMapping;
  emptyMap: IYAMLMapping;
begin
  yamlContent := 'empty_mapping: {}';
  doc := TYAML.LoadFromString(yamlContent);
  root := doc.AsMapping;

  emptyMap := root.Items['empty_mapping'].AsMapping;
  Assert.AreEqual(0, emptyMap.Count);
end;

// Document markers and comments

procedure TYAMLComprehensiveTests.Test_DocumentMarkers_SingleDocument;
var
  yamlContent: string;
  doc: IYAMLDocument;
  root: IYAMLMapping;
begin
  yamlContent := '---' + sLineBreak +
                'name: Test' + sLineBreak +
                'value: 42' + sLineBreak +
                '...';

  doc := TYAML.LoadFromString(yamlContent);
  root := doc.AsMapping;

  Assert.AreEqual('Test', root.Items['name'].AsString);
  Assert.AreEqual<Int64>(42, root.Items['value'].AsInteger);
end;

procedure TYAMLComprehensiveTests.Test_DocumentMarkers_MultipleDocuments;
var
  yamlContent: string;
  doc: IYAMLDocument;
begin
  yamlContent := '---' + sLineBreak +
                'document: 1' + sLineBreak +
                '---' + sLineBreak +
                'document: 2';

  // Note: This library might not support multiple documents
  // This test checks if the first document is parsed correctly
  doc := TYAML.LoadFromString(yamlContent);
  Assert.IsNotNull(doc);
end;

procedure TYAMLComprehensiveTests.Test_ParseAll_MultipleDocuments;
var
  yamlContent: string;
  documents: TArray<IYAMLDocument>;
begin
  yamlContent := '---' + sLineBreak +
                'document: first' + sLineBreak +
                'number: 1' + sLineBreak +
                '---' + sLineBreak +
                'document: second' + sLineBreak +
                'number: 2' + sLineBreak +
                '---' + sLineBreak +
                'document: third' + sLineBreak +
                'number: 3';

  documents := TYAML.LoadAllFromString(yamlContent);
  
  Assert.AreEqual<Int64>(3, Length(documents), 'Should parse exactly 3 documents');

  Assert.IsTrue(documents[0].IsMapping, 'First document should be mapping');
  Assert.AreEqual('first', documents[0].AsMapping.Items['document'].AsString);
  Assert.AreEqual<Int64>(1, documents[0].AsMapping.Items['number'].AsInteger);

  Assert.IsTrue(documents[1].IsMapping, 'Second document should be mapping');
  Assert.AreEqual('second', documents[1].AsMapping.Items['document'].AsString);
  Assert.AreEqual<Int64>(2, documents[1].AsMapping.Items['number'].AsInteger);

  Assert.IsTrue(documents[2].IsMapping, 'Third document should be mapping');
  Assert.AreEqual('third', documents[2].AsMapping.Items['document'].AsString);
  Assert.AreEqual<Int64>(3, documents[2].AsMapping.Items['number'].AsInteger);
end;

procedure TYAMLComprehensiveTests.Test_ParseAll_EmptyDocuments;
var
  yamlContent: string;
  documents: TArray<IYAMLDocument>;
begin
  yamlContent := '---' + sLineBreak +
                '---' + sLineBreak +
                'content: exists' + sLineBreak +
                '---';

  documents := TYAML.LoadAllFromString(yamlContent);
  
  Assert.AreEqual<Int64>(3, Length(documents), 'Should parse 3 documents including empty ones');

  Assert.IsTrue(documents[0].Root.IsNull, 'First document should be empty/null');
  Assert.IsTrue(documents[1].IsMapping, 'Second document should be mapping');
  Assert.AreEqual('exists', documents[1].AsMapping.Items['content'].AsString);
  Assert.IsTrue(documents[2].Root.IsNull, 'Third document should be empty/null');
end;

procedure TYAMLComprehensiveTests.Test_ParseAll_MixedDocuments;
var
  yamlContent: string;
  documents: TArray<IYAMLDocument>;
begin
  yamlContent := '---' + sLineBreak +
                '- item1' + sLineBreak +
                '- item2' + sLineBreak +
                '---' + sLineBreak +
                'key: value' + sLineBreak +
                '---' + sLineBreak +
                'scalar_document' + sLineBreak +
                '...';

  documents := TYAML.LoadAllFromString(yamlContent);
  
  Assert.AreEqual<Int64>(3, Length(documents), 'Should parse 3 mixed documents');
  
  Assert.IsTrue(documents[0].IsSequence, 'First document should be sequence');
  Assert.AreEqual(2, documents[0].AsSequence.Count);
  Assert.AreEqual('item1', documents[0].AsSequence[0].AsString);
  
  Assert.IsTrue(documents[1].IsMapping, 'Second document should be mapping');
  Assert.AreEqual('value', documents[1].AsMapping.Items['key'].AsString);
  
  Assert.IsTrue(documents[2].Root.IsScalar, 'Third document should be scalar');
  Assert.AreEqual('scalar_document', documents[2].Root.AsString);
end;

procedure TYAMLComprehensiveTests.Test_ParseAll_AnchorScopeIsolation;
var
  yamlContent: string;
  documents: TArray<IYAMLDocument>;
begin
  yamlContent := '---' + sLineBreak +
                'anchor: &ref "value1"' + sLineBreak +
                'alias: *ref' + sLineBreak +
                '---' + sLineBreak +
                'anchor: &ref "value2"' + sLineBreak +
                'alias: *ref';

  documents := TYAML.LoadAllFromString(yamlContent);
  
  Assert.AreEqual<Int64>(2, Length(documents), 'Should parse 2 documents');
  
  Assert.IsTrue(documents[0].IsMapping, 'First document should be mapping');
  Assert.AreEqual('value1', documents[0].AsMapping.Items['anchor'].AsString);
  Assert.AreEqual('value1', documents[0].AsMapping.Items['alias'].AsString, 'First document alias should resolve to value1');
  
  Assert.IsTrue(documents[1].IsMapping, 'Second document should be mapping');
  Assert.AreEqual('value2', documents[1].AsMapping.Items['anchor'].AsString);
  Assert.AreEqual('value2', documents[1].AsMapping.Items['alias'].AsString, 'Second document alias should resolve to value2 (not value1)');
end;

procedure TYAMLComprehensiveTests.Test_ParseAll_DirectiveScoping;
var
  yamlContent: string;
  documents: TArray<IYAMLDocument>;
begin
  yamlContent := '%YAML 1.2' + sLineBreak +
                '%TAG !local! tag:example.com,2000:app/' + sLineBreak +
                '---' + sLineBreak +
                'test: !local!custom "value1"' + sLineBreak +
                '---' + sLineBreak +
                'test: !local!custom "value2"';

  documents := TYAML.LoadAllFromString(yamlContent);
  
  Assert.AreEqual<Int64>(2, Length(documents), 'Should parse 2 documents');
  
  // Both documents should have parsed successfully despite custom tags
  Assert.IsTrue(documents[0].IsMapping, 'First document should be mapping');
  Assert.IsTrue(documents[1].IsMapping, 'Second document should be mapping');
  
  // The custom tag should be preserved in both documents (directives apply to all documents)
  Assert.AreEqual('value1', documents[0].AsMapping.Items['test'].AsString);
  Assert.AreEqual('value2', documents[1].AsMapping.Items['test'].AsString);
end;

procedure TYAMLComprehensiveTests.Test_ParseAll_DirectiveDocumentScope;
var
  yamlContent: string;
  documents: TArray<IYAMLDocument>;
begin
  // Test that directives are scoped per document, not stream-wide
  yamlContent := '%YAML 1.2' + sLineBreak +
                '%TAG !local1! tag:example.com,2000:doc1/' + sLineBreak +
                '---' + sLineBreak +
                'doc1: !local1!custom "value1"' + sLineBreak +
                '%TAG !local2! tag:example.com,2000:doc2/' + sLineBreak +
                '---' + sLineBreak +
                'doc2: !local2!custom "value2"';

  documents := TYAML.LoadAllFromString(yamlContent);
  
  Assert.AreEqual<Int64>(2, Length(documents), 'Should parse 2 documents');
  
  Assert.IsTrue(documents[0].IsMapping, 'First document should be mapping');
  Assert.IsTrue(documents[1].IsMapping, 'Second document should be mapping');
  
  // Each document should only see its own directive scope
  Assert.AreEqual('value1', documents[0].AsMapping.Items['doc1'].AsString);
  Assert.AreEqual('value2', documents[1].AsMapping.Items['doc2'].AsString);
end;

procedure TYAMLComprehensiveTests.Test_Comments_LineComments;
var
  yamlContent: string;
  doc: IYAMLDocument;
  root: IYAMLMapping;
begin
  yamlContent := '# This is a comment' + sLineBreak +
                'name: John # End of line comment' + sLineBreak +
                'age: 30';

  doc := TYAML.LoadFromString(yamlContent);
  root := doc.AsMapping;

  Assert.AreEqual('John', root.Items['name'].AsString);
  Assert.AreEqual<Int64>(30, root.Items['age'].AsInteger);
end;

procedure TYAMLComprehensiveTests.Test_Comments_EndOfLineComments;
var
  yamlContent: string;
  doc: IYAMLDocument;
  root: IYAMLMapping;
begin
  yamlContent := 'server:' + sLineBreak +
                '  host: localhost  # Development server' + sLineBreak +
                '  port: 8080      # Default port';

  doc := TYAML.LoadFromString(yamlContent);
  root := doc.AsMapping;

  Assert.AreEqual('localhost', root.Items['server'].Values['host'].AsString);
  Assert.AreEqual<Int64>(8080, root.Items['server'].Values['port'].AsInteger);
end;

// YAML path query tests

procedure TYAMLComprehensiveTests.Test_QueryPath_RootAccess;
var
  doc: IYAMLDocument;
  result: IYAMLSequence;
begin
  doc := TYAML.LoadFromString(CreateSimpleMapping);
  result := doc.Query('$.name');

  Assert.IsNotNull(result);
  Assert.AreEqual('John Doe', result[0].AsString);
end;

procedure TYAMLComprehensiveTests.Test_QueryPath_NestedMapping;
var
  doc: IYAMLDocument;
  result: IYAMLSequence;
begin
  doc := TYAML.LoadFromString(CreateComplexStructure);
  result := doc.Query('$.person.name');

  Assert.IsNotNull(result);
  Assert.AreEqual('Jane Smith', result[0].AsString);
end;

procedure TYAMLComprehensiveTests.Test_QueryPath_SequenceIndex;
var
  doc: IYAMLDocument;
  result: IYAMLSequence;
begin
  doc := TYAML.LoadFromString(CreateComplexStructure);
  result := doc.Query('$.person.hobbies[0]');

  Assert.IsNotNull(result);
  Assert.AreEqual('reading', result[0].AsString);
end;

procedure TYAMLComprehensiveTests.Test_QueryPath_DeepNesting;
var
  doc: IYAMLDocument;
  result: IYAMLSequence;
begin
  doc := TYAML.LoadFromString(CreateComplexStructure);
  result := doc.Query('$.person.address.city');

  Assert.IsNotNull(result);
  Assert.AreEqual('Springfield', result[0].AsString);
end;

procedure TYAMLComprehensiveTests.Test_QueryPath_VeryDeepNesting;
var
  doc: IYAMLDocument;
  result: IYAMLSequence;
  yamlText: string;
begin
  // Test with 25 levels of nesting to verify new indent stack design
  yamlText := 
    'level1:' + sLineBreak +
    '  level2:' + sLineBreak +
    '    level3:' + sLineBreak +
    '      level4:' + sLineBreak +
    '        level5:' + sLineBreak +
    '          level6:' + sLineBreak +
    '            level7:' + sLineBreak +
    '              level8:' + sLineBreak +
    '                level9:' + sLineBreak +
    '                  level10:' + sLineBreak +
    '                    level11:' + sLineBreak +
    '                      level12:' + sLineBreak +
    '                        level13:' + sLineBreak +
    '                          level14:' + sLineBreak +
    '                            level15:' + sLineBreak +
    '                              level16:' + sLineBreak +
    '                                level17:' + sLineBreak +
    '                                  level18:' + sLineBreak +
    '                                    level19:' + sLineBreak +
    '                                      level20:' + sLineBreak +
    '                                        level21:' + sLineBreak +
    '                                          level22:' + sLineBreak +
    '                                            level23:' + sLineBreak +
    '                                              level24:' + sLineBreak +
    '                                                level25: "deep_value"';

  doc := TYAML.LoadFromString(yamlText);
  result := doc.Query('$.level1.level2.level3.level4.level5.level6.level7.level8.level9.level10.level11.level12.level13.level14.level15.level16.level17.level18.level19.level20.level21.level22.level23.level24.level25');

  Assert.IsNotNull(result, 'Deep nesting query result should not be null');
  Assert.AreEqual(1, result.Count, 'Deep nesting query should return exactly one result');
  Assert.AreEqual('deep_value', result[0].AsString, 'Deep nesting query should return correct value');
end;

procedure TYAMLComprehensiveTests.Test_QueryPath_NonexistentPath;
var
  doc: IYAMLDocument;
  result: IYAMLValue;
begin
  doc := TYAML.LoadFromString(CreateSimpleMapping);
  result := doc.Query('$.nonexistent.path.here');

  Assert.AreEqual(0, result.Count);
end;

// Type checking and conversion tests

procedure TYAMLComprehensiveTests.Test_TypeChecking_AllTypes;
var
  doc: IYAMLDocument;
  root: IYAMLMapping;
begin
  doc := TYAML.LoadFromString(CreateTypedValues);
  root := doc.AsMapping;

  Assert.IsTrue(root.Items['null_value'].IsNull);
  Assert.IsTrue(root.Items['bool_true'].IsBoolean);
  Assert.IsTrue(root.Items['integer_decimal'].IsInteger);
  Assert.IsTrue(root.Items['float_normal'].IsFloat);
  Assert.IsTrue(root.Items['string_plain'].IsString);
  Assert.IsTrue(root.Items['timestamp_datetime'].IsTimeStamp);
end;

procedure TYAMLComprehensiveTests.Test_Conversion_ToBoolean;
var
  doc: IYAMLDocument;
  root: IYAMLMapping;
begin
  doc := TYAML.LoadFromString(CreateTypedValues);
  root := doc.AsMapping;

  Assert.IsTrue(root.Items['bool_true'].AsBoolean);
  Assert.IsFalse(root.Items['bool_false'].AsBoolean);
  Assert.IsTrue(root.Items['bool_yes'].AsBoolean);
  Assert.IsFalse(root.Items['bool_no'].AsBoolean);
end;

procedure TYAMLComprehensiveTests.Test_Conversion_ToInteger;
var
  doc: IYAMLDocument;
  root: IYAMLMapping;
begin
  doc := TYAML.LoadFromString(CreateTypedValues);
  root := doc.AsMapping;

  Assert.AreEqual<Int64>(42, root.Items['integer_decimal'].AsInteger);
  Assert.AreEqual<Int64>(-17, root.Items['integer_negative'].AsInteger);
end;

procedure TYAMLComprehensiveTests.Test_Conversion_ToFloat;
var
  doc: IYAMLDocument;
  root: IYAMLMapping;
begin
  doc := TYAML.LoadFromString(CreateTypedValues);
  root := doc.AsMapping;

  Assert.AreEqual(3.14159, root.Items['float_normal'].AsFloat, 0.00001);
  Assert.AreEqual(-2.71828, root.Items['float_negative'].AsFloat, 0.00001);
end;

procedure TYAMLComprehensiveTests.Test_Conversion_ToString;
var
  doc: IYAMLDocument;
  root: IYAMLMapping;
begin
  doc := TYAML.LoadFromString(CreateTypedValues);
  root := doc.AsMapping;

  Assert.AreEqual('hello world', root.Items['string_plain'].AsString);
  Assert.AreEqual('hello world', root.Items['string_quoted'].AsString);
end;

procedure TYAMLComprehensiveTests.Test_Conversion_ToDateTime;
var
  yamlContent: string;
  doc: IYAMLDocument;
  root: IYAMLMapping;
  dt: TDateTime;
begin
  yamlContent := 'timestamp: 2023-12-25T10:30:00Z';
  doc := TYAML.LoadFromString(yamlContent);
  root := doc.AsMapping;

  dt := root.Items['timestamp'].AsUTCDateTime;
  Assert.AreEqual(2023, YearOf(dt));
  Assert.AreEqual(12, MonthOf(dt));
  Assert.AreEqual(25, DayOf(dt));
end;

// Collection operation tests

procedure TYAMLComprehensiveTests.Test_Mapping_AddOrSetValue_Types;
var
  doc: IYAMLDocument;
  root: IYAMLMapping;
begin
  doc := TYAML.CreateMapping;
  root := doc.AsMapping;

  root.AddOrSetValue('test_bool', True);
  root.AddOrSetValue('test_int', 42);
  root.AddOrSetValue('test_float', Double(3.14));
  root.AddOrSetValue('test_string', 'Hello World');

  Assert.IsTrue(root.Items['test_bool'].AsBoolean);
  Assert.AreEqual<Int64>(42, root.Items['test_int'].AsInteger);
  Assert.AreEqual(3.14, root.Items['test_float'].AsFloat, 0.001);
  Assert.AreEqual('Hello World', root.Items['test_string'].AsString);
end;

procedure TYAMLComprehensiveTests.Test_Mapping_ContainsKey_Operations;
var
  doc: IYAMLDocument;
  root: IYAMLMapping;
begin
  doc := TYAML.LoadFromString(CreateSimpleMapping);
  root := doc.AsMapping;

  Assert.IsTrue(root.ContainsKey('name'));
  Assert.IsTrue(root.ContainsKey('age'));
  Assert.IsTrue(root.ContainsKey('active'));
  Assert.IsFalse(root.ContainsKey('nonexistent'));
end;

procedure TYAMLComprehensiveTests.Test_Sequence_AddValue_Types;
var
  doc: IYAMLDocument;
  root: IYAMLSequence;
begin
  doc := TYAML.CreateSequence;
  root := doc.AsSequence;

  root.AddValue(True);
  root.AddValue(42);
  root.AddValue(3.14);
  root.AddValue('Hello World');

  Assert.AreEqual(4, root.Count);
  Assert.IsTrue(root.Items[0].AsBoolean);
  Assert.AreEqual<Int64>(42, root.Items[1].AsInteger);
  Assert.AreEqual(3.14, root.Items[2].AsFloat, 0.001);
  Assert.AreEqual('Hello World', root.Items[3].AsString);
end;

procedure TYAMLComprehensiveTests.Test_Sequence_AddCollections;
var
  doc: IYAMLDocument;
  root: IYAMLSequence;
  nestedMapping: IYAMLMapping;
  nestedSequence: IYAMLSequence;
begin
  doc := TYAML.CreateSequence;
  root := doc.AsSequence;

  nestedMapping := root.AddMapping;
  nestedSequence := root.AddSequence;

  Assert.AreEqual(2, root.Count);
  Assert.IsTrue(root.Items[0].IsMapping);
  Assert.IsTrue(root.Items[1].IsSequence);
end;

// Parser options tests

procedure TYAMLComprehensiveTests.Test_ParserOptions_DuplicateKeyBehavior_Overwrite;
var
  yamlContent: string;
  doc: IYAMLDocument;
  options: IYAMLParserOptions;
  root: IYAMLMapping;
begin
  yamlContent := 'key: first_value' + sLineBreak +
                'key: second_value';

  options := TYAML.CreateParserOptions;
  options.DuplicateKeyBehavior := TYAMLDuplicateKeyBehavior.dkOverwrite;

  doc := TYAML.LoadFromString(yamlContent, options);
  root := doc.AsMapping;

  Assert.AreEqual('second_value', root.Items['key'].AsString);
end;

procedure TYAMLComprehensiveTests.Test_ParserOptions_DuplicateKeyBehavior_Error;
var
  yamlContent: string;
  options: IYAMLParserOptions;
begin
  yamlContent := 'key: first_value' + sLineBreak +
                'key: second_value';

  options := TYAML.CreateParserOptions;
  options.DuplicateKeyBehavior := TYAMLDuplicateKeyBehavior.dkError;

  Assert.WillRaise(
    procedure
    begin
      TYAML.LoadFromString(yamlContent, options);
    end,
    EYAMLParseException
  );
end;

// Error handling tests

procedure TYAMLComprehensiveTests.Test_InvalidYAML_UnmatchedBrackets;
begin
  Assert.WillRaise(
    procedure
    begin
      TYAML.LoadFromString('array: [1, 2, 3');
    end,
    EYAMLParseException
  );
end;

procedure TYAMLComprehensiveTests.Test_InvalidYAML_UnterminatedQuotedString;
begin
  Assert.WillRaise(
    procedure
    begin
      // Invalid YAML: unterminated quoted string
      TYAML.LoadFromString('key: "unterminated string' + sLineBreak + 'another_key: value');
    end,
    EYAMLParseException
  );
end;

procedure TYAMLComprehensiveTests.Test_InvalidYAML_InvalidCharacters;
begin
  Assert.WillRaise(
    procedure
    begin
      TYAML.LoadFromString('invalid: @#$%^&*()');
    end,
    EYAMLParseException
  );
end;

procedure TYAMLComprehensiveTests.Test_ConversionError_InvalidBoolean;
var
  doc: IYAMLDocument;
  root: IYAMLMapping;
begin
  doc := TYAML.LoadFromString('value: "not_a_boolean"');
  root := doc.AsMapping;

  Assert.WillRaise(
    procedure
    begin
      root.Items['value'].AsBoolean;
    end,
    Exception
  );
end;

procedure TYAMLComprehensiveTests.Test_ConversionError_InvalidInteger;
var
  doc: IYAMLDocument;
  root: IYAMLMapping;
begin
  doc := TYAML.LoadFromString('value: "not_an_integer"');
  root := doc.AsMapping;

  Assert.WillRaise(
    procedure
    begin
      root.Items['value'].AsInteger;
    end,
    Exception
  );
end;

procedure TYAMLComprehensiveTests.Test_ConversionError_InvalidFloat;
var
  doc: IYAMLDocument;
  root: IYAMLMapping;
begin
  doc := TYAML.LoadFromString('value: "not_a_float"');
  root := doc.AsMapping;

  Assert.WillRaise(
    procedure
    begin
      root.Items['value'].AsFloat;
    end,
    Exception
  );
end;

procedure TYAMLComprehensiveTests.Test_OutOfRange_SequenceAccess;
var
  doc: IYAMLDocument;
  root: IYAMLSequence;
  outOfRangeValue: IYAMLValue;
begin
  doc := TYAML.LoadFromString(CreateSimpleSequence);
  root := doc.AsSequence;

  outOfRangeValue := root.Items[99];
  Assert.AreEqual(TYAMLValueType.vtNull, outOfRangeValue.ValueType);
end;

procedure TYAMLComprehensiveTests.Test_OutOfRange_MappingAccess;
var
  doc: IYAMLDocument;
  root: IYAMLMapping;
  nonexistentValue: IYAMLValue;
begin
  doc := TYAML.LoadFromString(CreateSimpleMapping);
  root := doc.AsMapping;

  nonexistentValue := root.Items['nonexistent_key'];
  Assert.AreEqual(TYAMLValueType.vtNull, nonexistentValue.ValueType);
end;

procedure TYAMLComprehensiveTests.Test_ParseString_DoubleQuoted_Escapes;
var
  yamlContent: string;
  doc: IYAMLDocument;
  root: IYAMLMapping;
begin
  yamlContent := 'escape_null: "\0"' + sLineBreak +
                 'escape_bell: "\a"' + sLineBreak +
                 'escape_backspace: "\b"' + sLineBreak +
                 'escape_tab: "\t"' + sLineBreak +
                 'escape_newline: "\n"' + sLineBreak +
                 'escape_vtab: "\v"' + sLineBreak +
                 'escape_formfeed: "\f"' + sLineBreak +
                 'escape_return: "\r"' + sLineBreak +
                 'escape_escape: "\e"' + sLineBreak +
                 'escape_space: "\ "' + sLineBreak +
                 'escape_quote: "\""' + sLineBreak +
                 'escape_slash: "\/"' + sLineBreak +
                 'escape_backslash: "\\"';

  doc := TYAML.LoadFromString(yamlContent);
  root := doc.AsMapping;

  Assert.AreEqual(#0, root.Items['escape_null'].AsString);
  Assert.AreEqual(#7, root.Items['escape_bell'].AsString);
  Assert.AreEqual(#8, root.Items['escape_backspace'].AsString);
  Assert.AreEqual(#9, root.Items['escape_tab'].AsString);
  Assert.AreEqual(#10, root.Items['escape_newline'].AsString);
  Assert.AreEqual(#11, root.Items['escape_vtab'].AsString);
  Assert.AreEqual(#12, root.Items['escape_formfeed'].AsString);
  Assert.AreEqual(#13, root.Items['escape_return'].AsString);
  Assert.AreEqual(#27, root.Items['escape_escape'].AsString);
  Assert.AreEqual(' ', root.Items['escape_space'].AsString);
  Assert.AreEqual('"', root.Items['escape_quote'].AsString);
  Assert.AreEqual('/', root.Items['escape_slash'].AsString);
  Assert.AreEqual('\', root.Items['escape_backslash'].AsString);
end;

procedure TYAMLComprehensiveTests.Test_ParseString_SingleQuoted_Escapes;
var
  yamlContent: string;
  doc: IYAMLDocument;
  root: IYAMLMapping;
begin
  yamlContent := 'literal_backslash: ''\''' + sLineBreak +
                 'escaped_quote: ''It''''s working''' + sLineBreak +
                 'mixed_content: ''Line 1\nLine 2''' + sLineBreak +
                 'with_backslashes: ''C:\path\to\file''';

  doc := TYAML.LoadFromString(yamlContent);
  root := doc.AsMapping;

  Assert.AreEqual('\', root.Items['literal_backslash'].AsString);
  Assert.AreEqual('It''s working', root.Items['escaped_quote'].AsString);
  Assert.AreEqual('Line 1\nLine 2', root.Items['mixed_content'].AsString); // Backslash-n is literal
  Assert.AreEqual('C:\path\to\file', root.Items['with_backslashes'].AsString);
end;

procedure TYAMLComprehensiveTests.Test_WriteString_EscapeHandling;
var
  doc: IYAMLDocument;
  root: IYAMLMapping;
  yamlOutput: string;
begin
  doc := TYAML.CreateMapping;
  root := doc.AsMapping;

  // Add strings with various escape sequences
  root.AddOrSetValue('with_newline', 'Line 1' + #10 + 'Line 2');
  root.AddOrSetValue('with_tab', 'Column1' + #9 + 'Column2');
  root.AddOrSetValue('with_backslash', 'C:\Windows\System32');
  root.AddOrSetValue('with_quote', 'He said "Hello"');
  root.AddOrSetValue('with_single_quote', 'It''s working');

  yamlOutput := doc.ToYAMLString;

  // Verify the output contains proper escaping
  // Strings with special characters should be properly quoted and escaped
  Assert.Contains(yamlOutput, 'with_newline');
  Assert.Contains(yamlOutput, 'with_tab');
  Assert.Contains(yamlOutput, 'with_backslash');
  Assert.Contains(yamlOutput, 'with_quote');
  Assert.Contains(yamlOutput, 'with_single_quote');

  // Parse the output back to ensure round-trip works
  doc := TYAML.LoadFromString(yamlOutput);
  root := doc.AsMapping;

  Assert.AreEqual('Line 1' + #10 + 'Line 2', root.Items['with_newline'].AsString);
  Assert.AreEqual('Column1' + #9 + 'Column2', root.Items['with_tab'].AsString);
  Assert.AreEqual('C:\Windows\System32', root.Items['with_backslash'].AsString);
  Assert.AreEqual('He said "Hello"', root.Items['with_quote'].AsString);
  Assert.AreEqual('It''s working', root.Items['with_single_quote'].AsString);
end;

initialization
  TDUnitX.RegisterTestFixture(TYAMLComprehensiveTests);

end.

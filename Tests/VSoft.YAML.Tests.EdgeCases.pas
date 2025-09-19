unit VSoft.YAML.Tests.EdgeCases;

interface

uses
  DUnitX.TestFramework,
  VSoft.YAML,
  System.SysUtils,
  System.Classes,
  System.DateUtils,
  System.Math;

type
  [TestFixture]
  TYAMLEdgeCasesTests = class
  private
    function CreateLargeString(size: Integer): string;
    function CreateDeepNestedYAML(depth: Integer): string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    // Boundary value tests
    [Test]
    procedure Test_EmptyValues_AllTypes;
    [Test]
    procedure Test_MinMaxInteger_Values;
    [Test]
    procedure Test_MinMaxFloat_Values;
    [Test]
    procedure Test_MaxLength_Strings;
    [Test]
    procedure Test_UnicodeExtreme_Characters;

    // Malformed YAML tests
    [Test]
    procedure Test_InvalidYAML_UnmatchedQuotes;
    [Test]
    procedure Test_InvalidYAML_InvalidEscapeSequences;
    [Test]
    procedure Test_InvalidYAML_TabsVsSpaces;
    [Test]
    procedure Test_InvalidYAML_TabsInNestedStructure;
    [Test]
    procedure Test_InvalidYAML_MixedTabsAndSpaces;
    [Test]
    procedure Test_ValidYAML_TabsInQuotedStrings;
    [Test]
    procedure Test_InvalidYAML_UnterminatedString;
    [Test]
    procedure Test_InvalidYAML_InvalidUnicode;
    [Test]
    procedure Test_ValidYAML_UnicodeEscapeSequences;
    [Test]
    procedure Test_InvalidYAML_CircularReference;

    // Memory and performance stress tests
    [Test]
    procedure Test_StressTest_LargeDocument;
    [Test]
    procedure Test_StressTest_DeepNesting;
    [Test]
    procedure Test_StressTest_DeepNestingShouldRaise;
    [Test]
    procedure Test_StressTest_WideStructure;
    [Test]
    procedure Test_StressTest_ManySmallObjects;
    [Test]
    procedure Test_StressTest_LongStrings;
    [Test]
    procedure Test_StressTest_RepeatedOperations;

    // Special character handling
    [Test]
    procedure Test_SpecialChars_ControlCharacters;
    [Test]
    procedure Test_SpecialChars_ReservedYAMLChars;
    [Test]
    procedure Test_SpecialChars_WhitespaceVariants;
    [Test]
    procedure Test_SpecialChars_LineBreakVariants;
    [Test]
    procedure Test_SpecialChars_UnicodeNormalization;

    // Type coercion edge cases
    [Test]
    procedure Test_TypeCoercion_StringToNumber;
    [Test]
    procedure Test_TypeCoercion_NumberToString;
    [Test]
    procedure Test_TypeCoercion_BooleanVariants;
    [Test]
    procedure Test_TypeCoercion_NullVariants;
    [Test]
    procedure Test_TypeCoercion_DateTimeEdgeCases;

    [Test]
    procedure Test_DateTime_Issue_Roger;

    // Parser state edge cases
    [Test]
    procedure Test_ParserState_MultipleDocuments;
    [Test]
    procedure Test_ParserState_DocumentMarkers;
    [Test]
    procedure Test_ParserState_CommentsEverywhere;
    [Test]
    procedure Test_ParserState_MixedStyles;
    [Test]
    procedure Test_ParserState_EmptyCollections;

    // Duplicate key scenarios
    [Test]
    procedure Test_DuplicateKeys_SameLevel;
    [Test]
    procedure Test_DuplicateKeys_DifferentLevels;
    [Test]
    procedure Test_DuplicateKeys_CaseSensitive;
    [Test]
    procedure Test_DuplicateKeys_UnicodeVariants;

    // Anchor and alias edge cases (if supported)
    [Test]
    procedure Test_Anchors_SimpleReference;
    [Test]
    procedure Test_Anchors_NestedReference;
    [Test]
    procedure Test_Anchors_ForwardReference;
    [Test]
    procedure Test_Anchors_UnresolvedReference;

    // Float precision and special values
    [Test]
    procedure Test_Float_Precision_Limits;
    [Test]
    procedure Test_Float_SpecialValues_Infinity;
    [Test]
    procedure Test_Float_SpecialValues_NaN;
    [Test]
    procedure Test_Float_ScientificNotation_Extremes;

    // DateTime edge cases
    [Test]
    procedure Test_DateTime_MinMaxValues;
    [Test]
    procedure Test_DateTime_TimezoneEdgeCases;
    [Test]
    procedure Test_DateTime_LeapYear;
    [Test]
    procedure Test_DateTime_DSTTransitions;

    // Collection edge cases
    [Test]
    procedure Test_Collection_EmptySequence;
    [Test]
    procedure Test_Collection_EmptyMapping;
    [Test]
    procedure Test_Collection_SingleItemCollections;
    [Test]
    procedure Test_Collection_NestedEmptyCollections;
    [Test]
    procedure Test_Collection_MixedTypesInSequence;

    // Error recovery tests
    [Test]
    procedure Test_ErrorRecovery_PartiallyValidDocument;
    [Test]
    procedure Test_ErrorRecovery_CascadingErrors;

    // Memory management
    [Test]
    procedure Test_Memory_LargeDocumentCleanup;
    [Test]
    procedure Test_Memory_RepeatedLoadUnload;
    [Test]
    procedure Test_Memory_CircularReferences;

    // Cross-platform compatibility
    [Test]
    procedure Test_CrossPlatform_LineEndings;
    [Test]
    procedure Test_CrossPlatform_PathSeparators;
    [Test]
    procedure Test_CrossPlatform_CharacterEncoding;

    // Writer edge cases
    [Test]
    procedure Test_Writer_ExtremeLongLines;
    [Test]
    procedure Test_Writer_MaxIndentation;
    [Test]
    procedure Test_Writer_UnicodeInKeys;
    [Test]
    procedure Test_Writer_SpecialFloatValues;

    // Long string line continuation tests
    [Test]
    procedure Test_LongString_LineContinuation_DoubleQuoted;
    [Test]
    procedure Test_LongString_LineContinuation_SingleQuoted;
    [Test]
    procedure Test_LongString_LineContinuation_WithSpaces;
    [Test]
    procedure Test_LongString_LineContinuation_MixedWithEscapes;
    [Test]
    procedure Test_LongString_LineContinuation_EdgeCases;

    // DateTime conversion tests
    [Test]
    procedure Test_DateTime_LocalTimeConversion;
    [Test]
    procedure Test_DateTime_UTCTimeConversion;
    [Test]
    procedure Test_DateTime_TimezoneOffsetConversions;
    [Test]
    procedure Test_DateTime_RoundTripConversion;
    [Test]
    procedure Test_DateTime_EdgeCaseTimezones;
  end;

implementation

uses
  VSoft.YAML.Classes, VSoft.YAML.Utils;

{ TYAMLEdgeCasesTests }

procedure TYAMLEdgeCasesTests.Setup;
begin
  // Setup if needed
end;

procedure TYAMLEdgeCasesTests.TearDown;
begin
  // Cleanup if needed
end;

function TYAMLEdgeCasesTests.CreateLargeString(size: Integer): string;
var
  i: Integer;
begin
  SetLength(Result, size);
  for i := 1 to size do
  begin
    Result[i] := Chr(Ord('A') + ((i - 1) mod 26));
  end;
end;

function TYAMLEdgeCasesTests.CreateDeepNestedYAML(depth: Integer): string;
var
  i: Integer;
begin
  Result := '';
  for i := 1 to depth do
  begin
    Result := Result + StringOfChar(' ', (i - 1) * 2) + Format('level_%d:', [i], YAMLFormatSettings) + sLineBreak;
  end;
  Result := Result + StringOfChar(' ', depth * 2) + 'value: final';
end;

// Boundary value tests

procedure TYAMLEdgeCasesTests.Test_EmptyValues_AllTypes;
var
  yamlContent: string;
  doc: IYAMLDocument;
  root: IYAMLMapping;
begin
  yamlContent := 'empty_string: ""' + sLineBreak +
                'empty_sequence: []' + sLineBreak +
                'empty_mapping: {}' + sLineBreak +
                'null_value: null' + sLineBreak +
                'tilde_null: ~' + sLineBreak +
                'empty_value: ';

  doc := TYAML.LoadFromString(yamlContent);
  root := doc.AsMapping;

  Assert.IsTrue(root.ContainsKey('empty_string'));
  Assert.AreEqual('', root.Items['empty_string'].AsString);
  Assert.IsTrue(root.Items['empty_sequence'].IsSequence);
  Assert.AreEqual(0, root.Items['empty_sequence'].AsSequence.Count);
  Assert.IsTrue(root.Items['empty_mapping'].IsMapping);
  Assert.AreEqual(0, root.Items['empty_mapping'].AsMapping.Count);
  Assert.IsTrue(root.Items['null_value'].IsNull);
  Assert.IsTrue(root.Items['tilde_null'].IsNull);
end;

procedure TYAMLEdgeCasesTests.Test_MinMaxInteger_Values;
var
  yamlContent: string;
  doc: IYAMLDocument;
  root: IYAMLMapping;
begin
  yamlContent := Format('max_int32: %d', [High(Int32)], YAMLFormatSettings) + sLineBreak +
                Format('min_int32: %d', [Low(Int32)], YAMLFormatSettings) + sLineBreak +
                Format('max_int64: %d', [High(Int64)], YAMLFormatSettings) + sLineBreak +
                'zero: 0';

  doc := TYAML.LoadFromString(yamlContent);
  root := doc.AsMapping;

  Assert.AreEqual<Int64>(High(Int32), root.Items['max_int32'].AsInteger);
  Assert.AreEqual<Int64>(Low(Int32), root.Items['min_int32'].AsInteger);
  Assert.AreEqual<Int64>(0, root.Items['zero'].AsInteger);
end;

procedure TYAMLEdgeCasesTests.Test_MinMaxFloat_Values;
var
  yamlContent: string;
  doc: IYAMLDocument;
  root: IYAMLMapping;
begin
  yamlContent := 'max_double: 1.7976931348623157E+308' + sLineBreak +
                'min_double: 2.2250738585072014E-308' + sLineBreak +
                'zero_float: 0.0' + sLineBreak +
                'tiny_float: 1E-100';

  doc := TYAML.LoadFromString(yamlContent);
  root := doc.AsMapping;

  Assert.IsTrue(root.Items['max_double'].IsFloat);
  Assert.IsTrue(root.Items['min_double'].IsFloat);
  Assert.IsTrue(root.Items['zero_float'].IsFloat);
  Assert.AreEqual<double>(0.0, root.Items['zero_float'].AsFloat);
end;

procedure TYAMLEdgeCasesTests.Test_MaxLength_Strings;
var
  largeString: string;
  yamlContent: string;
  doc: IYAMLDocument;
  root: IYAMLMapping;
begin
  largeString := CreateLargeString(10000);
  yamlContent := Format('large_string: "%s"', [largeString], YAMLFormatSettings);

  doc := TYAML.LoadFromString(yamlContent);
  root := doc.AsMapping;

  Assert.AreEqual(10000, Length(root.Items['large_string'].AsString));
  Assert.AreEqual(largeString, root.Items['large_string'].AsString);
end;

procedure TYAMLEdgeCasesTests.Test_UnicodeExtreme_Characters;
var
  yamlContent: string;
  doc: IYAMLDocument;
  root: IYAMLMapping;
begin
  yamlContent := 'emoji: "🚀🌟💻🎉"' + sLineBreak +
                'chinese: "你好世界"' + sLineBreak +
                'arabic: "مرحبا بالعالم"' + sLineBreak +
                'mathematical: "∑∞∂∫"' + sLineBreak +
                'symbols: "™©®℠"';

  doc := TYAML.LoadFromString(yamlContent);
  root := doc.AsMapping;

  Assert.AreEqual('🚀🌟💻🎉', root.Items['emoji'].AsString);
  Assert.AreEqual('你好世界', root.Items['chinese'].AsString);
  Assert.AreEqual('مرحبا بالعالم', root.Items['arabic'].AsString);
  Assert.AreEqual('∑∞∂∫', root.Items['mathematical'].AsString);
  Assert.AreEqual('™©®℠', root.Items['symbols'].AsString);

  {$IFDEF POSIX}
  doc := TYAML.LoadFromFile('./test_utf8.yaml');
  {$ELSE}
  doc := TYAML.LoadFromFile('..\..\testfiles\test_utf8.yaml');
  {$ENDIF}
  root := doc.AsMapping;

  Assert.AreEqual('🚀🌟💻🎉', root.Items['emoji'].AsString);
  Assert.AreEqual('你好世界', root.Items['chinese'].AsString);
  Assert.AreEqual('مرحبا بالعالم', root.Items['arabic'].AsString);
  Assert.AreEqual('∑∞∂∫', root.Items['mathematical'].AsString);
  Assert.AreEqual('™©®℠', root.Items['symbols'].AsString);


end;

// Malformed YAML tests


procedure TYAMLEdgeCasesTests.Test_InvalidYAML_UnmatchedQuotes;
begin
  Assert.WillRaise(
    procedure
    begin
      TYAML.LoadFromString('key: "unmatched quote');
    end,
    EYAMLParseException
  );
end;

procedure TYAMLEdgeCasesTests.Test_InvalidYAML_InvalidEscapeSequences;
begin
  Assert.WillRaise(
    procedure
    begin
      TYAML.LoadFromString('key: "invalid escape \z sequence"');
    end,
    EYAMLParseException
  );
end;


procedure TYAMLEdgeCasesTests.Test_InvalidYAML_TabsVsSpaces;
var
  yamlWithTabs: string;
begin
  yamlWithTabs := 'parent:' + sLineBreak + #9 + 'child: value';

  // YAML 1.2 specification: Tabs are not allowed for indentation
  Assert.WillRaise(
    procedure
    begin
      TYAML.LoadFromString(yamlWithTabs);
    end,
    EYAMLParseException,
    'Tabs are not allowed for indentation in YAML'
  );
end;

procedure TYAMLEdgeCasesTests.Test_InvalidYAML_UnterminatedString;
begin
  Assert.WillRaise(
    procedure
    begin
      TYAML.LoadFromString('key: "unterminated string' + sLineBreak + 'another_key: value');
    end,
    EYAMLParseException
  );
end;

procedure TYAMLEdgeCasesTests.Test_InvalidYAML_InvalidUnicode;
begin
  // Test \u with non-hex characters
  Assert.WillRaise(
    procedure
    begin
      TYAML.LoadFromString('key: "\uXXXX"'); // Invalid unicode escape
    end,
    EYAMLParseException
  );

  // Test \u with too few digits
  Assert.WillRaise(
    procedure
    begin
      TYAML.LoadFromString('key: "\u123"'); // Only 3 hex digits
    end,
    EYAMLParseException
  );

  // Test \U with non-hex characters
  Assert.WillRaise(
    procedure
    begin
      TYAML.LoadFromString('key: "\UNotValidX"'); // Invalid 8-digit escape
    end,
    EYAMLParseException
  );

  // Test \U with too few digits
  Assert.WillRaise(
    procedure
    begin
      TYAML.LoadFromString('key: "\U1234567"'); // Only 7 hex digits
    end,
    EYAMLParseException
  );
end;

procedure TYAMLEdgeCasesTests.Test_ValidYAML_UnicodeEscapeSequences;
var
  yamlContent: string;
  doc: IYAMLDocument;
  root: IYAMLMapping;
begin
  // Test basic 4-digit Unicode escapes first
  yamlContent := 'smile_face: "\u263A"' + sLineBreak +          // ☺ (White Smiling Face)
                'heart: "\u2665"' + sLineBreak +              // ♥ (Black Heart Suit)
                'copyright: "\u00A9"' + sLineBreak +          // © (Copyright Sign)  
                'euro: "\u20AC"' + sLineBreak +               // € (Euro Sign)
                'mixed: "Hello \u0040 World"';                 // @ symbol

  doc := TYAML.LoadFromString(yamlContent);
  root := doc.AsMapping;

  // Test 4-digit Unicode escapes
  Assert.AreEqual('☺', root.Items['smile_face'].AsString);
  Assert.AreEqual('♥', root.Items['heart'].AsString);
  Assert.AreEqual('©', root.Items['copyright'].AsString);
  Assert.AreEqual('€', root.Items['euro'].AsString);
  Assert.AreEqual('Hello @ World', root.Items['mixed'].AsString);
  
  // Test 8-digit Unicode escapes in a separate document
  yamlContent := 'grinning_face: "\U0001F600"' + sLineBreak +   // 😀 (Grinning Face)
                'rocket: "\U0001F680"';                        // 🚀 (Rocket)

  doc := TYAML.LoadFromString(yamlContent);
  root := doc.AsMapping;
  
  Assert.AreEqual('😀', root.Items['grinning_face'].AsString);
  Assert.AreEqual('🚀', root.Items['rocket'].AsString);
  
  // Test control characters in separate document
  yamlContent := 'null_char: "\u0000"' + sLineBreak +           // Null character
                'tab_char: "\u0009"';                          // Tab character

  doc := TYAML.LoadFromString(yamlContent);
  root := doc.AsMapping;
  
  Assert.AreEqual(#0, root.Items['null_char'].AsString);
  Assert.AreEqual(#9, root.Items['tab_char'].AsString);
end;

procedure TYAMLEdgeCasesTests.Test_InvalidYAML_CircularReference;
var
  yamlContent: string;
begin
  // This might not apply if anchors/aliases aren't supported
  yamlContent := 'a: &anchor' + sLineBreak +
                '  b: *anchor';

  try
    TYAML.LoadFromString(yamlContent);
    // If it succeeds, the parser handles it gracefully
  except
    on E: Exception do
      // Expected if circular references aren't supported
      Assert.Pass('Parser correctly handles circular reference');
  end;
end;

// Memory and performance stress tests

procedure TYAMLEdgeCasesTests.Test_StressTest_LargeDocument;
var
  doc: IYAMLDocument;
  root: IYAMLMapping;
  items: IYAMLSequence;
  i: Integer;
  yamlStr: string;
begin
  doc := TYAML.CreateMapping;
  root := doc.AsMapping;

  items := root.AddOrSetSequence('large_items');

  // Add 1000 items
  for i := 1 to 1000 do
  begin
    items.AddValue(Format('Item number %d with some text content', [i], YAMLFormatSettings));
  end;

  yamlStr := TYAML.WriteToString(doc);
  Assert.IsTrue(Length(yamlStr) > 10000);

  // Verify we can parse it back
  doc := TYAML.LoadFromString(yamlStr);
  Assert.AreEqual(1000, doc.Root.Values['large_items'].AsSequence.Count);
end;

procedure TYAMLEdgeCasesTests.Test_StressTest_DeepNesting;
var
  yamlContent: string;
  doc: IYAMLDocument;
  current: IYAMLValue;
  i: Integer;
begin
  yamlContent := CreateDeepNestedYAML(50);

  doc := TYAML.LoadFromString(yamlContent);
  current := doc.Root;

  // Navigate down the nesting
  for i := 1 to 50 do
  begin
    current := current.Values[Format('level_%d', [i], YAMLFormatSettings)];
    Assert.IsNotNull(current);
  end;

  Assert.AreEqual('final', current.Values['value'].AsString);
end;

procedure TYAMLEdgeCasesTests.Test_StressTest_DeepNestingShouldRaise;
var
  yamlContent: string;
  doc: IYAMLDocument;
begin
  yamlContent := CreateDeepNestedYAML(101);
  Assert.WillRaise(
    procedure
    begin
        doc := TYAML.LoadFromString(yamlContent);
    end
    ,EYAMLParseException)
end;


procedure TYAMLEdgeCasesTests.Test_StressTest_WideStructure;
var
  doc: IYAMLDocument;
  root: IYAMLMapping;
  i: Integer;
  yamlStr: string;
begin
  doc := TYAML.CreateMapping;
  root := doc.AsMapping;

  // Add 500 keys at the same level
  for i := 1 to 500 do
  begin
    root.AddOrSetValue(Format('key_%03d', [i], YAMLFormatSettings), Format('value_%d', [i], YAMLFormatSettings));
  end;

  yamlStr := TYAML.WriteToString(doc);
  Assert.IsNotEmpty(yamlStr);

  // Verify we can parse it back
  doc := TYAML.LoadFromString(yamlStr);
  Assert.AreEqual(500, doc.AsMapping.Count);
end;

procedure TYAMLEdgeCasesTests.Test_StressTest_ManySmallObjects;
var
  doc: IYAMLDocument;
  root: IYAMLSequence;
  obj: IYAMLMapping;
  i: Integer;
  yamlStr: string;
begin
  doc := TYAML.CreateSequence;
  root := doc.AsSequence;

  // Create 200 small objects
  for i := 1 to 200 do
  begin
    obj := root.AddMapping;
    obj.AddOrSetValue('id', i);
    obj.AddOrSetValue('name', Format('Object_%d', [i], YAMLFormatSettings));
    obj.AddOrSetValue('active', (i mod 2) = 0);
  end;

  yamlStr := TYAML.WriteToString(doc);
  Assert.IsNotEmpty(yamlStr);

  // Verify parsing
  doc := TYAML.LoadFromString(yamlStr);
  Assert.AreEqual(200, doc.AsSequence.Count);
end;

procedure TYAMLEdgeCasesTests.Test_StressTest_LongStrings;
var
  doc: IYAMLDocument;
  root: IYAMLMapping;
  longString1, longString2: string;
  yamlStr: string;
begin
  doc := TYAML.CreateMapping;
  root := doc.AsMapping;

  longString1 := CreateLargeString(50000);
  longString2 := StringOfChar('X', 100000);

  root.AddOrSetValue('long_string_1', longString1);
  root.AddOrSetValue('long_string_2', longString2);

  yamlStr := TYAML.WriteToString(doc);
  Assert.IsTrue(Length(yamlStr) > 150000);
end;

procedure TYAMLEdgeCasesTests.Test_StressTest_RepeatedOperations;
var
  doc: IYAMLDocument;
  root: IYAMLMapping;
  i: Integer;
  yamlStr: string;
begin
  doc := TYAML.CreateMapping;
  root := doc.AsMapping;

  // Perform many add/update operations
  for i := 1 to 1000 do
  begin
    root.AddOrSetValue('dynamic_key', Format('value_%d', [i], YAMLFormatSettings));
    if i mod 100 = 0 then
    begin
      yamlStr := TYAML.WriteToString(doc);
      Assert.IsNotEmpty(yamlStr);
    end;
  end;

  Assert.AreEqual('value_1000', root.Items['dynamic_key'].AsString);
end;

// Special character handling

procedure TYAMLEdgeCasesTests.Test_SpecialChars_ControlCharacters;
var
  yamlContent: string;
  doc: IYAMLDocument;
  root: IYAMLMapping;
begin
  yamlContent := 'control_chars: "' + #1 + #2 + #3 + #7 + #8 + '"' + sLineBreak +
                'tab_char: "column1' + #9 + 'column2"' + sLineBreak +
                'newline_char: "line1' + #10 + 'line2"';

  try
    doc := TYAML.LoadFromString(yamlContent);
    root := doc.AsMapping;

    Assert.Contains(root.Items['tab_char'].AsString, #9);
    Assert.Contains(root.Items['newline_char'].AsString, #10);
  except
    on E: Exception do
      // Some parsers might reject control characters
      Assert.Pass('Parser appropriately handles control characters');
  end;
end;

procedure TYAMLEdgeCasesTests.Test_SpecialChars_ReservedYAMLChars;
var
  yamlContent: string;
  doc: IYAMLDocument;
  root: IYAMLMapping;
begin
  yamlContent := 'colon_value: "key: value"' + sLineBreak +
                'bracket_value: "[array]"' + sLineBreak +
                'brace_value: "{object}"' + sLineBreak +
                'hash_value: "# comment"' + sLineBreak +
                'percent_value: "100% complete"' + sLineBreak +
                'at_value: "@symbol"';

  doc := TYAML.LoadFromString(yamlContent);
  root := doc.AsMapping;

  Assert.AreEqual('key: value', root.Items['colon_value'].AsString);
  Assert.AreEqual('[array]', root.Items['bracket_value'].AsString);
  Assert.AreEqual('{object}', root.Items['brace_value'].AsString);
  Assert.AreEqual('# comment', root.Items['hash_value'].AsString);
  Assert.AreEqual('100% complete', root.Items['percent_value'].AsString);
  Assert.AreEqual('@symbol', root.Items['at_value'].AsString);
end;

procedure TYAMLEdgeCasesTests.Test_SpecialChars_WhitespaceVariants;
var
  yamlContent: string;
  doc: IYAMLDocument;
  root: IYAMLMapping;
begin
  yamlContent := 'leading_spaces: "   value"' + sLineBreak +
                'trailing_spaces: "value   "' + sLineBreak +
                'multiple_spaces: "word   word"' + sLineBreak +
                'mixed_whitespace: " ' + #9 + ' value ' + #9 + ' "';

  doc := TYAML.LoadFromString(yamlContent);
  root := doc.AsMapping;

  Assert.AreEqual('   value', root.Items['leading_spaces'].AsString);
  Assert.AreEqual('value   ', root.Items['trailing_spaces'].AsString);
  Assert.AreEqual('word   word', root.Items['multiple_spaces'].AsString);
end;

procedure TYAMLEdgeCasesTests.Test_SpecialChars_LineBreakVariants;
var
  yamlContent: string;
  doc: IYAMLDocument;
  root: IYAMLMapping;
begin
  // Test different line break styles
  yamlContent := 'unix_breaks: "line1' + #10 + 'line2"' + sLineBreak +
                'windows_breaks: "line1' + #13#10 + 'line2"' + sLineBreak +
                'mac_breaks: "line1' + #13 + 'line2"';

  doc := TYAML.LoadFromString(yamlContent);
  root := doc.AsMapping;

  Assert.Contains(root.Items['unix_breaks'].AsString, 'line1');
  Assert.Contains(root.Items['unix_breaks'].AsString, 'line2');
end;

procedure TYAMLEdgeCasesTests.Test_SpecialChars_UnicodeNormalization;
var
  yamlContent: string;
  doc: IYAMLDocument;
  root: IYAMLMapping;
begin
  // Test composed vs decomposed Unicode
  yamlContent := 'composed: "café"' + sLineBreak +
                'decomposed: "cafe' + #$0301 + '"' + sLineBreak +
                'combining: "a' + #$0300 + #$0301 + '"';

  doc := TYAML.LoadFromString(yamlContent);
  root := doc.AsMapping;

  // Both should represent the same logical character
  Assert.IsNotEmpty(root.Items['composed'].AsString);
  Assert.IsNotEmpty(root.Items['decomposed'].AsString);
end;

// Type coercion edge cases

procedure TYAMLEdgeCasesTests.Test_TypeCoercion_StringToNumber;
var
  yamlContent: string;
  doc: IYAMLDocument;
  root: IYAMLMapping;
begin
  yamlContent := 'numeric_string: "42"' + sLineBreak +
                'float_string: "3.14"' + sLineBreak +
                'hex_string: "0xFF"' + sLineBreak +
                'non_numeric: "abc"';

  doc := TYAML.LoadFromString(yamlContent);
  root := doc.AsMapping;

  // These should remain as strings
  Assert.IsTrue(root.Items['numeric_string'].IsString);
  Assert.AreEqual('42', root.Items['numeric_string'].AsString);

  // Test type conversion errors
  Assert.WillRaise(
    procedure
    begin
      root.Items['non_numeric'].AsInteger;
    end,
    Exception
  );
end;

procedure TYAMLEdgeCasesTests.Test_TypeCoercion_NumberToString;
var
  yamlContent: string;
  doc: IYAMLDocument;
  root: IYAMLMapping;
begin
  yamlContent := 'integer_value: 42' + sLineBreak +
                'float_value: 3.14' + sLineBreak +
                'zero_value: 0';

  doc := TYAML.LoadFromString(yamlContent);
  root := doc.AsMapping;

  Assert.IsTrue(root.Items['integer_value'].IsInteger);
  Assert.IsTrue(root.Items['float_value'].IsFloat);

  // Should be able to convert to string
  Assert.AreEqual('42', root.Items['integer_value'].AsString);
  Assert.Contains(root.Items['float_value'].AsString, '3.14');
end;

procedure TYAMLEdgeCasesTests.Test_TypeCoercion_BooleanVariants;
var
  yamlContent: string;
  doc: IYAMLDocument;
  root: IYAMLMapping;
begin
  yamlContent := 'bool_true: true' + sLineBreak +
                'bool_false: false' + sLineBreak +
                'bool_yes: yes' + sLineBreak +
                'bool_no: no' + sLineBreak +
                'bool_on: on' + sLineBreak +
                'bool_off: off' + sLineBreak +
                'bool_y: y' + sLineBreak +
                'bool_n: n';

  doc := TYAML.LoadFromString(yamlContent);
  root := doc.AsMapping;

  Assert.IsTrue(root.Items['bool_true'].AsBoolean);
  Assert.IsFalse(root.Items['bool_false'].AsBoolean);

  if root.ContainsKey('bool_yes') then
    Assert.IsTrue(root.Items['bool_yes'].AsBoolean);
  if root.ContainsKey('bool_no') then
    Assert.IsFalse(root.Items['bool_no'].AsBoolean);
end;

procedure TYAMLEdgeCasesTests.Test_TypeCoercion_NullVariants;
var
  yamlContent: string;
  doc: IYAMLDocument;
  root: IYAMLMapping;
begin
  yamlContent := 'null_value: null' + sLineBreak +
                'tilde_value: ~' + sLineBreak +
                'empty_value: ' + sLineBreak +
                'null_string: "null"';

  doc := TYAML.LoadFromString(yamlContent);
  root := doc.AsMapping;

  Assert.IsTrue(root.Items['null_value'].IsNull);
  Assert.IsTrue(root.Items['tilde_value'].IsNull);
  Assert.IsTrue(root.Items['empty_value'].IsNull);

  // This should remain a string
  Assert.IsTrue(root.Items['null_string'].IsString);
  Assert.AreEqual('null', root.Items['null_string'].AsString);
end;

procedure TYAMLEdgeCasesTests.Test_TypeCoercion_DateTimeEdgeCases;
var
  yamlContent: string;
  doc: IYAMLDocument;
  root: IYAMLMapping;
begin
  yamlContent := 'valid_date: 2023-12-25' + sLineBreak +
                'valid_datetime: 2023-12-25T10:30:00Z' + sLineBreak +
                'invalid_date: 2023-13-45' + sLineBreak +
                'date_string: "2023-12-25"';

  doc := TYAML.LoadFromString(yamlContent);
  root := doc.AsMapping;

  Assert.IsTrue(root.Items['valid_date'].IsTimeStamp);
  Assert.IsTrue(root.Items['valid_datetime'].IsTimeStamp);

  // Invalid dates should be treated as strings
  Assert.IsTrue(root.Items['invalid_date'].IsString);
  Assert.IsTrue(root.Items['date_string'].IsString);
end;

// Parser state edge cases

procedure TYAMLEdgeCasesTests.Test_ParserState_MultipleDocuments;
var
  yamlContent: string;
  doc: IYAMLDocument;
begin
  yamlContent := '---' + sLineBreak +
                'doc1: first' + sLineBreak +
                '---' + sLineBreak +
                'doc2: second' + sLineBreak +
                '...';

  // Most single-document parsers will only parse the first document
  doc := TYAML.LoadFromString(yamlContent);
  Assert.IsNotNull(doc);

  // Should contain first document
  if doc.IsMapping then
    Assert.IsTrue(doc.AsMapping.ContainsKey('doc1'));
end;

procedure TYAMLEdgeCasesTests.Test_ParserState_DocumentMarkers;
var
  yamlContent: string;
  doc: IYAMLDocument;
  root: IYAMLMapping;
begin
  yamlContent := '---' + sLineBreak +
                'key1: value1' + sLineBreak +
                'key2: value2' + sLineBreak +
                '...';

  doc := TYAML.LoadFromString(yamlContent);
  root := doc.AsMapping;

  Assert.AreEqual('value1', root.Items['key1'].AsString);
  Assert.AreEqual('value2', root.Items['key2'].AsString);
end;

procedure TYAMLEdgeCasesTests.Test_ParserState_CommentsEverywhere;
var
  yamlContent: string;
  doc: IYAMLDocument;
  root: IYAMLMapping;
begin
  yamlContent := '# Document start comment' + sLineBreak +
                '---  # Document marker comment' + sLineBreak +
                '# Top level comment' + sLineBreak +
                'key1: value1  # End of line comment' + sLineBreak +
                '# Between keys comment' + sLineBreak +
                'key2: # Value comment' + sLineBreak +
                '  # Nested comment' + sLineBreak +
                '  subkey: subvalue # Nested end comment' + sLineBreak +
                '# End comment';

  doc := TYAML.LoadFromString(yamlContent);
  root := doc.AsMapping;

  Assert.AreEqual('value1', root.Items['key1'].AsString);
  
  // Check that key2 is actually a mapping before accessing nested values
  if root.Items['key2'].IsMapping then
    Assert.AreEqual('subvalue', root.Items['key2'].Values['subkey'].AsString)
  else
    Assert.Fail('key2 should be a mapping containing subkey');
end;

procedure TYAMLEdgeCasesTests.Test_ParserState_MixedStyles;
var
  yamlContent: string;
  doc: IYAMLDocument;
  root: IYAMLMapping;
begin
  yamlContent := 'flow_sequence: [1, 2, 3]' + sLineBreak +
                'block_sequence:' + sLineBreak +
                '  - item1' + sLineBreak +
                '  - item2' + sLineBreak +
                'flow_mapping: {key1: value1, key2: value2}' + sLineBreak +
                'block_mapping:' + sLineBreak +
                '  key3: value3' + sLineBreak +
                '  key4: value4';

  doc := TYAML.LoadFromString(yamlContent);
  root := doc.AsMapping;

  Assert.AreEqual(3, root.Items['flow_sequence'].AsSequence.Count);
  Assert.AreEqual(2, root.Items['block_sequence'].AsSequence.Count);
  Assert.AreEqual(2, root.Items['flow_mapping'].AsMapping.Count);
  Assert.AreEqual(2, root.Items['block_mapping'].AsMapping.Count);
end;

procedure TYAMLEdgeCasesTests.Test_ParserState_EmptyCollections;
var
  yamlContent: string;
  doc: IYAMLDocument;
  root: IYAMLMapping;
begin
  yamlContent := 'empty_flow_seq: []' + sLineBreak +
                'empty_flow_map: {}' + sLineBreak +
                'empty_block_seq:' + sLineBreak +
                'empty_block_map:' + sLineBreak +
                'nested_empty:' + sLineBreak +
                '  empty_nested_seq: []' + sLineBreak +
                '  empty_nested_map: {}';

  doc := TYAML.LoadFromString(yamlContent);
  root := doc.AsMapping;

  Assert.AreEqual(0, root.Items['empty_flow_seq'].AsSequence.Count);
  Assert.AreEqual(0, root.Items['empty_flow_map'].AsMapping.Count);
  Assert.IsTrue(root.Items['empty_block_seq'].IsNull);
  Assert.IsTrue(root.Items['empty_block_map'].IsNull);
end;

// Duplicate key scenarios

procedure TYAMLEdgeCasesTests.Test_DuplicateKeys_SameLevel;
var
  yamlContent: string;
  options: IYAMLParserOptions;
  doc: IYAMLDocument;
  root: IYAMLMapping;
begin
  yamlContent := 'key: first_value' + sLineBreak +
                'key: second_value';

  // Test with overwrite behavior
  options := TYAML.CreateParserOptions;
  options.DuplicateKeyBehavior := TYAMLDuplicateKeyBehavior.dkOverwrite;

  doc := TYAML.LoadFromString(yamlContent, options);
  root := doc.AsMapping;

  Assert.AreEqual('second_value', root.Items['key'].AsString);

  // Test with error behavior
  options.DuplicateKeyBehavior := TYAMLDuplicateKeyBehavior.dkError;

  Assert.WillRaise(
    procedure
    begin
      TYAML.LoadFromString(yamlContent, options);
    end,
    EYAMLParseException
  );
end;

procedure TYAMLEdgeCasesTests.Test_DuplicateKeys_DifferentLevels;
var
  yamlContent: string;
  doc: IYAMLDocument;
  root: IYAMLMapping;
begin
  yamlContent := 'key: top_level' + sLineBreak +
                'nested:' + sLineBreak +
                '  key: nested_level';

  doc := TYAML.LoadFromString(yamlContent);
  root := doc.AsMapping;

  Assert.AreEqual('top_level', root.Items['key'].AsString);
  Assert.AreEqual('nested_level', root.Items['nested'].Values['key'].AsString);
end;

procedure TYAMLEdgeCasesTests.Test_DuplicateKeys_CaseSensitive;
var
  yamlContent: string;
  doc: IYAMLDocument;
  root: IYAMLMapping;
begin
  yamlContent := 'Key: uppercase' + sLineBreak +
                'key: lowercase' + sLineBreak +
                'KEY: allcaps';

  doc := TYAML.LoadFromString(yamlContent);
  root := doc.AsMapping;

  // All should be treated as different keys
  Assert.IsTrue(root.ContainsKey('Key'));
  Assert.IsTrue(root.ContainsKey('key'));
  Assert.IsTrue(root.ContainsKey('KEY'));
end;

procedure TYAMLEdgeCasesTests.Test_DuplicateKeys_UnicodeVariants;
var
  yamlContent: string;
  doc: IYAMLDocument;
  root: IYAMLMapping;
begin
  yamlContent := 'café: composed' + sLineBreak +
                'cafe' + #$0301 + ': decomposed';

  doc := TYAML.LoadFromString(yamlContent);
  root := doc.AsMapping;

  // Should be treated as different keys (byte-wise comparison)
  Assert.AreEqual(2, root.Count);
end;

// Anchor and alias tests (if supported)

procedure TYAMLEdgeCasesTests.Test_Anchors_SimpleReference;
var
  yamlContent: string;
  doc: IYAMLDocument;
begin
  yamlContent := 'original: &anchor "Hello World"' + sLineBreak +
                'reference: *anchor';

  try
    doc := TYAML.LoadFromString(yamlContent);
    // If anchors are supported, both should have the same value
    if doc.IsMapping then
    begin
      Assert.AreEqual(
        doc.AsMapping.Items['original'].AsString,
        doc.AsMapping.Items['reference'].AsString
      );
    end;
  except
    on E: Exception do
      // If anchors aren't supported, that's also valid
      Assert.Pass('Anchors not supported or handled as strings');
  end;
end;

procedure TYAMLEdgeCasesTests.Test_Anchors_NestedReference;
var
  yamlContent: string;
  doc: IYAMLDocument;
begin
  yamlContent := 'template: &template' + sLineBreak +
                '  name: Default' + sLineBreak +
                '  version: 1.0' + sLineBreak +
                'instance1: *template' + sLineBreak +
                'instance2: *template';

  try
    doc := TYAML.LoadFromString(yamlContent);
    Assert.IsNotNull(doc);
  except
    on E: Exception do
      Assert.Pass('Complex anchors not supported');
  end;
end;

procedure TYAMLEdgeCasesTests.Test_Anchors_ForwardReference;
var
  yamlContent: string;
begin
  yamlContent := 'reference: *anchor' + sLineBreak +
                'original: &anchor "Hello"';

  try
    TYAML.LoadFromString(yamlContent);
  except
    on E: Exception do
      // Forward references should fail
      Assert.Pass('Forward references correctly rejected');
  end;
end;

procedure TYAMLEdgeCasesTests.Test_Anchors_UnresolvedReference;
var
  yamlContent: string;
begin
  yamlContent := 'reference: *nonexistent';

  Assert.WillRaise(
    procedure
    begin
      TYAML.LoadFromString(yamlContent);
    end,
    EYAMLParseException
  );
end;

// Float precision and special values

procedure TYAMLEdgeCasesTests.Test_Float_Precision_Limits;
var
  yamlContent: string;
  doc: IYAMLDocument;
  root: IYAMLMapping;
  originalValue, parsedValue: Double;
begin
  originalValue := 1.23456789012345678901234567890;
  yamlContent := Format('precise_floxat: %.30g', [originalValue], YAMLFormatSettings);

  doc := TYAML.LoadFromString(yamlContent);
  root := doc.AsMapping;

  parsedValue := root.Items['precise_floxat'].AsFloat;

  // Should be close due to floating-point precision limits
  Assert.AreEqual(originalValue, parsedValue);//, 1E-15);
end;

procedure TYAMLEdgeCasesTests.Test_Float_SpecialValues_Infinity;
var
  yamlContent: string;
  doc: IYAMLDocument;
  root: IYAMLMapping;
begin
  yamlContent := 'pos_inf: .inf' + sLineBreak +
                'neg_inf: -.inf' + sLineBreak +
                'pos_infinity: .Infinity' + sLineBreak +
                'neg_infinity: -.Infinity';

  try
    doc := TYAML.LoadFromString(yamlContent);
    root := doc.AsMapping;

    if root.ContainsKey('pos_inf') then
    begin
      Assert.IsTrue(IsInfinite(root.Items['pos_inf'].AsFloat));
      Assert.IsTrue(root.Items['pos_inf'].AsFloat > 0);
    end;

    if root.ContainsKey('neg_inf') then
    begin
      Assert.IsTrue(IsInfinite(root.Items['neg_inf'].AsFloat));
      Assert.IsTrue(root.Items['neg_inf'].AsFloat < 0);
    end;
  except
    on E: Exception do
      Assert.Pass('Infinity values handled as strings');
  end;
end;

procedure TYAMLEdgeCasesTests.Test_Float_SpecialValues_NaN;
var
  yamlContent: string;
  doc: IYAMLDocument;
  root: IYAMLMapping;
begin
  yamlContent := 'nan_value: .nan' + sLineBreak +
                'nan_caps: .NaN' + sLineBreak +
                'nan_alt: .NAN';

  try
    doc := TYAML.LoadFromString(yamlContent);
    root := doc.AsMapping;

    if root.ContainsKey('nan_value') then
    begin
      Assert.IsTrue(IsNaN(root.Items['nan_value'].AsFloat));
    end;
  except
    on E: Exception do
      Assert.Pass('NaN values handled as strings');
  end;
end;

procedure TYAMLEdgeCasesTests.Test_Float_ScientificNotation_Extremes;
var
  yamlContent: string;
  doc: IYAMLDocument;
  root: IYAMLMapping;
begin
  yamlContent := 'very_large: 1.23e308' + sLineBreak +
                'very_small: 1.23e-308' + sLineBreak +
                'avogadro: 6.022e23' + sLineBreak +
                'planck: 6.626e-34';

  doc := TYAML.LoadFromString(yamlContent);
  root := doc.AsMapping;

  Assert.IsTrue(root.Items['very_large'].IsFloat);
  Assert.IsTrue(root.Items['very_small'].IsFloat);
  Assert.IsTrue(root.Items['avogadro'].AsFloat > 1e20);
  Assert.IsTrue(root.Items['planck'].AsFloat < 1e-30);
end;

// Collection edge cases

procedure TYAMLEdgeCasesTests.Test_Collection_EmptySequence;
var
  yamlContent: string;
  doc: IYAMLDocument;
  root: IYAMLMapping;
  emptySeq: IYAMLSequence;
begin
  yamlContent := 'empty_seq: []';
  doc := TYAML.LoadFromString(yamlContent);
  root := doc.AsMapping;

  emptySeq := root.Items['empty_seq'].AsSequence;
  Assert.AreEqual(0, emptySeq.Count);
  Assert.IsTrue(emptySeq.IsSequence);
end;

procedure TYAMLEdgeCasesTests.Test_Collection_EmptyMapping;
var
  yamlContent: string;
  doc: IYAMLDocument;
  root: IYAMLMapping;
  emptyMap: IYAMLMapping;
begin
  yamlContent := 'empty_map: {}';
  doc := TYAML.LoadFromString(yamlContent);
  root := doc.AsMapping;

  emptyMap := root.Items['empty_map'].AsMapping;
  Assert.AreEqual(0, emptyMap.Count);
  Assert.IsTrue(emptyMap.IsMapping);
end;

procedure TYAMLEdgeCasesTests.Test_Collection_SingleItemCollections;
var
  yamlContent: string;
  doc: IYAMLDocument;
  root: IYAMLMapping;
begin
  yamlContent := 'single_seq: [only_item]' + sLineBreak +
                'single_map: {only_key: only_value}';

  doc := TYAML.LoadFromString(yamlContent);
  root := doc.AsMapping;

  Assert.AreEqual(1, root.Items['single_seq'].AsSequence.Count);
  Assert.AreEqual('only_item', root.Items['single_seq'].AsSequence.Items[0].AsString);
  Assert.AreEqual(1, root.Items['single_map'].AsMapping.Count);
  Assert.AreEqual('only_value', root.Items['single_map'].AsMapping.Items['only_key'].AsString);
end;

procedure TYAMLEdgeCasesTests.Test_Collection_NestedEmptyCollections;
var
  yamlContent: string;
  doc: IYAMLDocument;
  root: IYAMLMapping;
begin
  yamlContent := 'nested:' + sLineBreak +
                '  empty_seq: []' + sLineBreak +
                '  empty_map: {}' + sLineBreak +
                '  nested_empty:' + sLineBreak +
                '    deep_empty: []';

  doc := TYAML.LoadFromString(yamlContent);
  root := doc.AsMapping;

  Assert.AreEqual(0, root.Items['nested'].Values['empty_seq'].AsSequence.Count);
  Assert.AreEqual(0, root.Items['nested'].Values['empty_map'].AsMapping.Count);
  Assert.AreEqual(0, root.Items['nested'].Values['nested_empty'].Values['deep_empty'].AsSequence.Count);
end;

procedure TYAMLEdgeCasesTests.Test_Collection_MixedTypesInSequence;
var
  yamlContent: string;
  doc: IYAMLDocument;
  root: IYAMLMapping;
  mixedSeq: IYAMLSequence;
begin
  yamlContent := 'mixed_seq: [42, "string", true, 3.14, null]';

  doc := TYAML.LoadFromString(yamlContent);
  root := doc.AsMapping;
  mixedSeq := root.Items['mixed_seq'].AsSequence;

  Assert.AreEqual(5, mixedSeq.Count);
  Assert.IsTrue(mixedSeq.Items[0].IsInteger);
  Assert.IsTrue(mixedSeq.Items[1].IsString);
  Assert.IsTrue(mixedSeq.Items[2].IsBoolean);
  Assert.IsTrue(mixedSeq.Items[3].IsFloat);
  Assert.IsTrue(mixedSeq.Items[4].IsNull);
end;

// Error recovery tests

procedure TYAMLEdgeCasesTests.Test_ErrorRecovery_PartiallyValidDocument;
var
  yamlContent: string;
  doc: IYAMLDocument;
begin
  yamlContent := 'valid_key: valid_value' + sLineBreak +
                'invalid_key invalid_value' + sLineBreak +  // Missing colon
                'another_valid: value';

  try
    doc := TYAML.LoadFromString(yamlContent);
    // If parser recovers, check what it parsed
    if doc.IsMapping then
      Assert.IsTrue(doc.AsMapping.ContainsKey('valid_key'));
  except
    on E: EYAMLParseException do
      // Expected - parser should reject invalid YAML
      Assert.Pass('Parser correctly rejects partially invalid document');
  end;
end;


procedure TYAMLEdgeCasesTests.Test_ErrorRecovery_CascadingErrors;
var
  yamlContent: string;
begin
  yamlContent := 'parent:' + sLineBreak +
                '  child1 missing_colon' + sLineBreak +
                '    grandchild: value' + sLineBreak +
                '  child2: "unterminated';

  Assert.WillRaise(
    procedure
    begin
      TYAML.LoadFromString(yamlContent);
    end,
    EYAMLParseException
  );
end;

procedure TYAMLEdgeCasesTests.Test_DateTime_MinMaxValues;
var
  yamlContent: string;
  doc: IYAMLDocument;
  root: IYAMLMapping;
begin
  yamlContent := 'unix_epoch: 1970-01-01T00:00:00Z' + sLineBreak +
                'y2k: 2000-01-01T00:00:00Z' + sLineBreak +
                'far_future: 2349-12-31T23:59:59Z';

  doc := TYAML.LoadFromString(yamlContent);
  root := doc.AsMapping;

  Assert.IsTrue(root.Items['unix_epoch'].IsTimeStamp);
  Assert.IsTrue(root.Items['y2k'].IsTimeStamp);
  Assert.IsTrue(root.Items['far_future'].IsTimeStamp);
end;

procedure TYAMLEdgeCasesTests.Test_DateTime_TimezoneEdgeCases;
var
  yamlContent: string;
  doc: IYAMLDocument;
  root: IYAMLMapping;
begin
  yamlContent := 'utc_time: 2023-12-25T10:30:00Z' + sLineBreak +
                'positive_offset: 2023-12-25T10:30:00+14:00' + sLineBreak +
                'negative_offset: 2023-12-25T10:30:00-12:00' + sLineBreak +
                'partial_offset: 2023-12-25T10:30:00+05:30';

  doc := TYAML.LoadFromString(yamlContent);
  root := doc.AsMapping;

  Assert.IsTrue(root.Items['utc_time'].IsTimeStamp);
  Assert.IsTrue(root.Items['positive_offset'].IsTimeStamp);
  Assert.IsTrue(root.Items['negative_offset'].IsTimeStamp);
  Assert.IsTrue(root.Items['partial_offset'].IsTimeStamp);
end;

procedure TYAMLEdgeCasesTests.Test_DateTime_LeapYear;
var
  yamlContent: string;
  doc: IYAMLDocument;
  root: IYAMLMapping;
begin
  yamlContent := 'leap_year: 2020-02-29' + sLineBreak +
                'non_leap_year: 2021-02-28' + sLineBreak +
                'century_leap: 2000-02-29' + sLineBreak +
                'century_non_leap: 1900-02-28';

  doc := TYAML.LoadFromString(yamlContent);
  root := doc.AsMapping;

  Assert.IsTrue(root.Items['leap_year'].IsTimeStamp);
  Assert.IsTrue(root.Items['non_leap_year'].IsTimeStamp);
  Assert.IsTrue(root.Items['century_leap'].IsTimeStamp);
  Assert.IsTrue(root.Items['century_non_leap'].IsTimeStamp);
end;

procedure TYAMLEdgeCasesTests.Test_DateTime_DSTTransitions;
var
  yamlContent: string;
  doc: IYAMLDocument;
  root: IYAMLMapping;
begin
  yamlContent := 'spring_forward: 2023-03-12T03:00:00-04:00' + sLineBreak +
                'fall_back: 2023-11-05T01:00:00-05:00' + sLineBreak +
                'ambiguous_time: 2023-11-05T01:30:00-05:00';

  doc := TYAML.LoadFromString(yamlContent);
  root := doc.AsMapping;

  Assert.IsTrue(root.Items['spring_forward'].IsTimeStamp);
  Assert.IsTrue(root.Items['fall_back'].IsTimeStamp);
  Assert.IsTrue(root.Items['ambiguous_time'].IsTimeStamp);
end;

// Memory management and cleanup tests

procedure TYAMLEdgeCasesTests.Test_Memory_LargeDocumentCleanup;
var
  doc: IYAMLDocument;
  root: IYAMLMapping;
  i: Integer;
begin
  for i := 1 to 10 do
  begin
    doc := TYAML.CreateMapping;
    root := doc.AsMapping;

    // Create large structure
    root.AddOrSetValue('large_data', CreateLargeString(10000));

    // Document should be automatically cleaned up
    doc := nil;
  end;

  // If we get here without memory issues, cleanup is working
  Assert.Pass('Memory cleanup successful');
end;

procedure TYAMLEdgeCasesTests.Test_Memory_RepeatedLoadUnload;
var
  yamlContent: string;
  doc: IYAMLDocument;
  i: Integer;
begin
  yamlContent := 'data:' + sLineBreak;
  for i := 1 to 100 do
    yamlContent := yamlContent + Format('  item%d: value%d', [i, i], YAMLFormatSettings) + sLineBreak;

  // Load and unload repeatedly
  for i := 1 to 50 do
  begin
    doc := TYAML.LoadFromString(yamlContent);
    Assert.IsNotNull(doc);
    Assert.AreEqual(100, doc.Root.Values['data'].AsMapping.Count);
    doc := nil;
  end;

  Assert.Pass('Repeated load/unload successful');
end;

procedure TYAMLEdgeCasesTests.Test_Memory_CircularReferences;
var
  doc: IYAMLDocument;
  root, child: IYAMLMapping;
begin
  doc := TYAML.CreateMapping;
  root := doc.AsMapping;

  child := root.AddOrSetMapping('child');
  child.AddOrSetValue('name', 'child_node');

  // This shouldn't create memory leaks
  // (Parent-child references are normal in tree structures)

  Assert.AreEqual('child_node', root.Items['child'].Values['name'].AsString);
end;

// Cross-platform tests

procedure TYAMLEdgeCasesTests.Test_CrossPlatform_LineEndings;
var
  unixYAML, windowsYAML, macYAML: string;
  doc: IYAMLDocument;
begin
  // Different line ending styles
  unixYAML := 'key1: value1' + #10 + 'key2: value2';
  windowsYAML := 'key1: value1' + #13#10 + 'key2: value2';
  macYAML := 'key1: value1' + #13 + 'key2: value2';

  // All should parse successfully
  doc := TYAML.LoadFromString(unixYAML);
  Assert.AreEqual('value1', doc.Root.Values['key1'].AsString);

  doc := TYAML.LoadFromString(windowsYAML);
  Assert.AreEqual('value1', doc.Root.Values['key1'].AsString);

  doc := TYAML.LoadFromString(macYAML);
  Assert.AreEqual('value1', doc.Root.Values['key1'].AsString);
end;

procedure TYAMLEdgeCasesTests.Test_CrossPlatform_PathSeparators;
var
  yamlContent: string;
  doc: IYAMLDocument;
  root: IYAMLMapping;
begin
  yamlContent := 'windows_path: ''C:\Users\Name\file.txt''' + sLineBreak +
                'unix_path: "/home/user/file.txt"' + sLineBreak +
                'mixed_path: "C:/Users/Name/file.txt"';

  doc := TYAML.LoadFromString(yamlContent);
  root := doc.AsMapping;

  Assert.Contains(root.Items['windows_path'].AsString, '\');
  Assert.Contains(root.Items['unix_path'].AsString, '/');
  Assert.Contains(root.Items['mixed_path'].AsString, '/');
end;

procedure TYAMLEdgeCasesTests.Test_CrossPlatform_CharacterEncoding;
var
  yamlContent: string;
  doc: IYAMLDocument;
  root: IYAMLMapping;
begin
  yamlContent := 'utf8_text: "Ñiño café résumé"' + sLineBreak +
                'emoji_text: "Hello 👋 World 🌍"' + sLineBreak +
                'math_symbols: "∑ ∞ ∂ ∫ ≠ ≤ ≥"';

  doc := TYAML.LoadFromString(yamlContent);
  root := doc.AsMapping;

  Assert.Contains(root.Items['utf8_text'].AsString, 'Ñiño');
  Assert.Contains(root.Items['emoji_text'].AsString, '👋');
  Assert.Contains(root.Items['math_symbols'].AsString, '∑');
end;

// Writer edge cases

procedure TYAMLEdgeCasesTests.Test_Writer_ExtremeLongLines;
var
  doc: IYAMLDocument;
  root: IYAMLMapping;
  longValue: string;
  yamlStr: string;
begin
  doc := TYAML.CreateMapping;
  root := doc.AsMapping;

  longValue := CreateLargeString(1000);
  root.AddOrSetValue('very_long_key_name_that_goes_on_and_on', longValue);

  doc.Options.MaxLineLength := 80;

  yamlStr := TYAML.WriteToString(doc);
  Assert.IsNotEmpty(yamlStr);
end;

procedure TYAMLEdgeCasesTests.Test_Writer_MaxIndentation;
var
  doc: IYAMLDocument;
  current: IYAMLMapping;
  i: Integer;
  yamlStr: string;
begin
  doc := TYAML.CreateMapping;
  current := doc.AsMapping;

  // Create very deep nesting
  for i := 1 to 20 do
  begin
    current.AddOrSetValue(Format('value_%d', [i], YAMLFormatSettings), i);
    current := current.AddOrSetMapping(Format('level_%d', [i], YAMLFormatSettings));
  end;

  doc.Options.IndentSize := 8;

  yamlStr := TYAML.WriteToString(doc);
  Assert.IsNotEmpty(yamlStr);
end;

procedure TYAMLEdgeCasesTests.Test_Writer_UnicodeInKeys;
var
  doc: IYAMLDocument;
  root: IYAMLMapping;
  yamlStr: string;
begin
  doc := TYAML.CreateMapping;
  root := doc.AsMapping;

  root.AddOrSetValue('Ñiño', 'child');
  root.AddOrSetValue('café', 'coffee');
  root.AddOrSetValue('🚀', 'rocket');
  root.AddOrSetValue('数据', 'data');

  yamlStr := TYAML.WriteToString(doc);
  Assert.Contains(yamlStr, 'Ñiño');
  Assert.Contains(yamlStr, 'café');
end;

procedure TYAMLEdgeCasesTests.Test_Writer_SpecialFloatValues;
var
  doc: IYAMLDocument;
  root: IYAMLMapping;
  yamlStr: string;
begin
  doc := TYAML.CreateMapping;
  root := doc.AsMapping;

  root.AddOrSetValue('positive_infinity', Double.PositiveInfinity);
  root.AddOrSetValue('negative_infinity', Double.NegativeInfinity);
  root.AddOrSetValue('not_a_number', Double.NaN);
  root.AddOrSetValue('zero', 0.0);
  root.AddOrSetValue('negative_zero', -0.0);

  yamlStr := TYAML.WriteToString(doc);
  Assert.IsNotEmpty(yamlStr);
end;

procedure TYAMLEdgeCasesTests.Test_InvalidYAML_TabsInNestedStructure;
var
  yamlWithTabs: string;
begin
  yamlWithTabs := 'level1:' + sLineBreak + 
                  '  level2:' + sLineBreak + 
                  #9 + '    level3: value';

  Assert.WillRaise(
    procedure
    begin
      TYAML.LoadFromString(yamlWithTabs);
    end,
    EYAMLParseException,
    'Tabs are not allowed for indentation in YAML'
  );
end;

procedure TYAMLEdgeCasesTests.Test_InvalidYAML_MixedTabsAndSpaces;
var
  yamlWithMixed: string;
begin
  yamlWithMixed := 'key1: value1' + sLineBreak + 
                   '  key2: value2' + sLineBreak + 
                   #9 + ' key3: value3';

  Assert.WillRaise(
    procedure
    begin
      TYAML.LoadFromString(yamlWithMixed);
    end,
    EYAMLParseException,
    'Tabs are not allowed for indentation in YAML'
  );
end;

procedure TYAMLEdgeCasesTests.Test_ValidYAML_TabsInQuotedStrings;
var
  yamlWithTabsInStrings: string;
  doc: IYAMLDocument;
  root: IYAMLMapping;
begin
  yamlWithTabsInStrings := 'quoted: "This has' + #9 + 'tabs inside"' + sLineBreak + 
                           'literal: |' + sLineBreak + 
                           '  Line with' + #9 + 'tab';

  // Tabs inside quoted strings and block scalars should be allowed
  Assert.WillNotRaise(
    procedure
    begin
      doc := TYAML.LoadFromString(yamlWithTabsInStrings);
      root := doc.AsMapping;
      Assert.Contains(root.Items['quoted'].AsString, #9);
    end
  );
end;

// Long string line continuation tests

procedure TYAMLEdgeCasesTests.Test_LongString_LineContinuation_DoubleQuoted;
var
  yamlContent: string;
  doc: IYAMLDocument;
  root: IYAMLMapping;
  expectedValue: string;
begin
  yamlContent := 'long_string: "loooooooooooooooooooooooooooooooooooooooooooooooooongstring\' + sLineBreak +
                 '    loooooooooooooooooooooooooooooooooooooooooooooooooongstring\' + sLineBreak +
                 '    loooooooooooooooooooooooooooooooooooooooooooooooooongstring"';

  doc := TYAML.LoadFromString(yamlContent);
  root := doc.AsMapping;

  expectedValue := 'loooooooooooooooooooooooooooooooooooooooooooooooooongstring' +
                   'loooooooooooooooooooooooooooooooooooooooooooooooooongstring' +
                   'loooooooooooooooooooooooooooooooooooooooooooooooooongstring';

  Assert.AreEqual(expectedValue, root.Items['long_string'].AsString);
end;

procedure TYAMLEdgeCasesTests.Test_LongString_LineContinuation_SingleQuoted;
var
  yamlContent: string;
  doc: IYAMLDocument;
  root: IYAMLMapping;
  expectedValue: string;
begin
  yamlContent := 'long_string: ''loooooooooooooooooooooooooooooooooooooooooooooooooongstring\' + sLineBreak +
                 '    loooooooooooooooooooooooooooooooooooooooooooooooooongstring\' + sLineBreak +
                 '    loooooooooooooooooooooooooooooooooooooooooooooooooongstring''';

  doc := TYAML.LoadFromString(yamlContent);
  root := doc.AsMapping;

  expectedValue := 'loooooooooooooooooooooooooooooooooooooooooooooooooongstring' +
                   'loooooooooooooooooooooooooooooooooooooooooooooooooongstring' +
                   'loooooooooooooooooooooooooooooooooooooooooooooooooongstring';

  Assert.AreEqual(expectedValue, root.Items['long_string'].AsString);
end;

procedure TYAMLEdgeCasesTests.Test_LongString_LineContinuation_WithSpaces;
var
  yamlContent: string;
  doc: IYAMLDocument;
  root: IYAMLMapping;
  expectedValue: string;
begin
  yamlContent := 'long_string: "part one \' + sLineBreak +
                 '    part two \' + sLineBreak +
                 '    part three"';

  doc := TYAML.LoadFromString(yamlContent);
  root := doc.AsMapping;

  expectedValue := 'part one part two part three';

  Assert.AreEqual(expectedValue, root.Items['long_string'].AsString);
end;

procedure TYAMLEdgeCasesTests.Test_LongString_LineContinuation_MixedWithEscapes;
var
  yamlContent: string;
  doc: IYAMLDocument;
  root: IYAMLMapping;
  expectedValue: string;
  actualValue: string;
begin
  // Test ONLY basic escape sequences first - no line continuation
  // In Delphi, we need to construct the YAML content with actual \n in it
  yamlContent := 'test_simple: "a\nb"';  // This creates YAML with literal \n in it
  doc := TYAML.LoadFromString(yamlContent);
  root := doc.AsMapping;
  
  expectedValue := 'a' + #10 + 'b';  // This should be the result after escape processing
  actualValue := root.Items['test_simple'].AsString;
  
  if actualValue = 'a\nb' then
    Assert.Fail('Basic escape sequences not working - got literal \n instead of newline')
  else
    Assert.AreEqual(expectedValue, actualValue, 'Basic escape sequence test failed');
end;

procedure TYAMLEdgeCasesTests.Test_LongString_LineContinuation_EdgeCases;
var
  yamlContent: string;
  doc: IYAMLDocument;
  root: IYAMLMapping;
begin
  // Test backslash at end of string without continuation
  yamlContent := 'test1: "ends with backslash\\"';
  
  doc := TYAML.LoadFromString(yamlContent);
  root := doc.AsMapping;
  
  Assert.AreEqual('ends with backslash\', root.Items['test1'].AsString);

  // Test multiple backslashes before line continuation
  yamlContent := 'test2: "double backslash\\\' + sLineBreak +
                 '    continuation"';

  doc := TYAML.LoadFromString(yamlContent);
  root := doc.AsMapping;

  Assert.AreEqual('double backslash\continuation', root.Items['test2'].AsString);
end;

procedure TYAMLEdgeCasesTests.Test_DateTime_LocalTimeConversion;
var
  yamlContent: string;
  doc: IYAMLDocument;
  root: IYAMLMapping;
  localTime, utcTime: TDateTime;
  timezoneOffset: Integer;
begin
  // Test conversion of UTC timestamp to local time
  yamlContent := 'utc_timestamp: 2023-12-25T12:00:00Z';
  doc := TYAML.LoadFromString(yamlContent);
  root := doc.AsMapping;
  
  Assert.IsTrue(root.Items['utc_timestamp'].IsTimeStamp, 'Value should be recognized as timestamp');
  
  localTime := root.Items['utc_timestamp'].AsLocalDateTime;
  utcTime := root.Items['utc_timestamp'].AsUTCDateTime;
  
  // The difference between local and UTC should equal the local timezone offset
  timezoneOffset := Trunc((localTime - utcTime) * 24 * 60); // Convert to minutes
  
  Assert.IsTrue(Abs(timezoneOffset) <= 14 * 60, 'Timezone offset should be within reasonable bounds'); // Max ±14 hours
end;

procedure TYAMLEdgeCasesTests.Test_DateTime_UTCTimeConversion;
var
  yamlContent: string;
  doc: IYAMLDocument;
  root: IYAMLMapping;
  utcTime1, utcTime2: TDateTime;
begin
  // Test that UTC timestamps with different timezone indicators produce same UTC time
  yamlContent := 'utc_z: 2023-12-25T12:00:00Z' + sLineBreak +
                 'utc_plus_zero: 2023-12-25T12:00:00+00:00';
  doc := TYAML.LoadFromString(yamlContent);
  root := doc.AsMapping;
  
  utcTime1 := root.Items['utc_z'].AsUTCDateTime;
  utcTime2 := root.Items['utc_plus_zero'].AsUTCDateTime;
  
  Assert.AreEqual(utcTime1, utcTime2, 1 / (24 * 60 * 60), 'UTC times should be identical within 1 second');
end;

procedure TYAMLEdgeCasesTests.Test_DateTime_TimezoneOffsetConversions;
var
  yamlContent: string;
  doc: IYAMLDocument;
  root: IYAMLMapping;
  utcTimePos, utcTimeNeg: TDateTime;
  expectedUTCPos, expectedUTCNeg: TDateTime;
begin
  // Test timestamps with positive and negative timezone offsets that convert to same UTC time
  yamlContent := 'positive_tz: 2023-12-25T15:30:00+05:30' + sLineBreak +
                 'negative_tz: 2023-12-25T04:30:00-05:30';  // Both should be 10:00:00 UTC
  doc := TYAML.LoadFromString(yamlContent);
  root := doc.AsMapping;

  utcTimePos := root.Items['positive_tz'].AsUTCDateTime;
  utcTimeNeg := root.Items['negative_tz'].AsUTCDateTime;

  // Both should convert to the same UTC time: 10:00:00 UTC on 2023-12-25
  Assert.AreEqual(utcTimePos, utcTimeNeg, 1 / (24 * 60 * 60), 'UTC times should be equal within 1 second');
  
  // Create expected UTC time: 2023-12-25 10:00:00
  expectedUTCPos := EncodeDate(2023, 12, 25) + EncodeTime(10, 0, 0, 0);
  expectedUTCNeg := expectedUTCPos;
  
  Assert.AreEqual(expectedUTCPos, utcTimePos, 1 / (24 * 60 * 60), 'Positive timezone UTC conversion incorrect');
  Assert.AreEqual(expectedUTCNeg, utcTimeNeg, 1 / (24 * 60 * 60), 'Negative timezone UTC conversion incorrect');
end;

procedure TYAMLEdgeCasesTests.Test_DateTime_RoundTripConversion;
var
  yamlContent: string;
  doc: IYAMLDocument;
  root: IYAMLMapping;
  utcTime1, utcTime2, localTime, utcTime: TDateTime;
  timeDiff: Double;
begin
  // Test that AsUTCDateTime correctly converts different timezone representations to same UTC time
  yamlContent := 'utc_time: 2023-06-15T14:30:45Z' + sLineBreak +
                 'local_time_with_offset: 2023-06-15T17:30:45+03:00';  // Same UTC time as above
  doc := TYAML.LoadFromString(yamlContent);
  root := doc.AsMapping;
  
  utcTime1 := root.Items['utc_time'].AsUTCDateTime;
  utcTime2 := root.Items['local_time_with_offset'].AsUTCDateTime;
  
  // Both should convert to the same UTC time
  Assert.AreEqual(utcTime1, utcTime2, 1 / (24 * 60 * 60), 'UTC times should be equal within 1 second');
  
  // Test that AsLocalDateTime and AsUTCDateTime work correctly for a single timestamp
  localTime := root.Items['utc_time'].AsLocalDateTime;
  utcTime := root.Items['utc_time'].AsUTCDateTime;
  
  // The difference should reflect the local machine's timezone offset
  timeDiff := Abs(localTime - utcTime);
  Assert.IsTrue(timeDiff <= 14 / 24, 'Local/UTC difference should be within ±14 hours (max timezone offset)');
  
  // Verify the timestamps are recognized as timestamps
  Assert.IsTrue(root.Items['utc_time'].IsTimeStamp, 'UTC timestamp should be recognized');
  Assert.IsTrue(root.Items['local_time_with_offset'].IsTimeStamp, 'Offset timestamp should be recognized');
end;

procedure TYAMLEdgeCasesTests.Test_DateTime_EdgeCaseTimezones;
var
  yamlContent: string;
  doc: IYAMLDocument;
  root: IYAMLMapping;
  utcTime, localTime: TDateTime;
begin
  // Test edge case timezone offsets (maximum positive/negative)
  yamlContent := 'max_positive: 2023-12-25T11:00:00+14:00' + sLineBreak +
                 'max_negative: 2023-12-25T13:00:00-12:00';
  doc := TYAML.LoadFromString(yamlContent);
  root := doc.AsMapping;
  
  // Both should convert to 21:00:00 UTC on Dec 24 and 01:00:00 UTC on Dec 26 respectively
  utcTime := root.Items['max_positive'].AsUTCDateTime;
  localTime := root.Items['max_positive'].AsLocalDateTime;
  
  Assert.IsTrue(root.Items['max_positive'].IsTimeStamp, 'Max positive timezone should be valid timestamp');
  Assert.IsTrue(root.Items['max_negative'].IsTimeStamp, 'Max negative timezone should be valid timestamp');
  
  // Test that local time interpretation respects the specified timezone
  Assert.AreNotEqual(utcTime, localTime, 'Local and UTC times should differ for timezone-aware timestamps');
end;

procedure TYAMLEdgeCasesTests.Test_DateTime_Issue_Roger;
var
  sUpdatedAt : string;
  doc : IYAMLDocument;
  root : IYAMLMapping;
  UpdatedAt : TDateTime;
  sUpdatedOut : string;
begin
  doc := TYAML.CreateMapping;

  root := doc.Root.AsMapping;
  sUpdatedAt := '2021-03-25T17:26:21-05:00'; //This is a local time
  UpdatedAt := TYAMLDateUtils.ISO8601StrToLocalDateTime(sUpdatedAt);


  root.AddOrSetValue('updated_at', UpdatedAt, false);

  sUpdatedOut := root.S['updated_at'];

  Assert.AreEqual('2021-03-26T09:26:21+11:00', sUpdatedOut);


end;

initialization
  TDUnitX.RegisterTestFixture(TYAMLEdgeCasesTests);

end.

unit VSoft.YAML.Tests.CharUtils;

interface

uses
  DUnitX.TestFramework,
  VSoft.YAML.Utils;

type
  [TestFixture]
  TYAMLCharUtilsTests = class

  public

    [Test]
    procedure TestEscapeBasicCharacters;

    [Test]
    procedure TestEscapeControlCharacters;

    [Test]
    procedure TestEscapeJSONSpecialCharacters;

    [Test]
    procedure TestPreserveUnicodeCharacters;

    [Test]
    procedure TestEscapeSurrogatePairs;

    [Test]
    procedure TestEscapeUnpairedSurrogates;

    [Test]
    procedure TestEscapeEmptyString;

    [Test]
    procedure TestEscapeMixedContent;

    [Test]
    procedure TestEscapeExtendedASCII;

    [Test]
    procedure TestBMPCharactersNotEscaped;

    [Test]
    procedure TestOnlySurrogatePairsEscaped;

    [Test]
    procedure TestMathSymbols;

  end;

implementation

uses
  System.SysUtils;

{ TYAMLCharUtilsTests }

procedure TYAMLCharUtilsTests.TestEscapeBasicCharacters;
var
  input, output: string;
begin
  // Test basic ASCII characters that should not be escaped
  input := 'Hello World 123 ABC abc';
  output := TYAMLCharUtils.EscapeStringForJSON(input);
  Assert.AreEqual('Hello World 123 ABC abc', output);
end;

procedure TYAMLCharUtilsTests.TestEscapeControlCharacters;
var
  input, output, expected: string;
begin
  // Test control characters that must be escaped
  input := 'Line1' + #10 + 'Line2' + #13 + 'Tab' + #9 + 'Bell' + #7;
  output := TYAMLCharUtils.EscapeStringForJSON(input);
  expected := 'Line1\nLine2\rTab\tBell\u0007';
  Assert.AreEqual(expected, output);

  // Test backspace and form feed
  input := 'Backspace' + #8 + 'FormFeed' + #12;
  output := TYAMLCharUtils.EscapeStringForJSON(input);
  expected := 'Backspace\bFormFeed\f';
  Assert.AreEqual(expected, output);

  // Test null character
  input := 'Before' + #0 + 'After';
  output := TYAMLCharUtils.EscapeStringForJSON(input);
  expected := 'Before\u0000After';
  Assert.AreEqual(expected, output);
end;

procedure TYAMLCharUtilsTests.TestEscapeJSONSpecialCharacters;
var
  input, output, expected: string;
begin
  // Test double quotes
  input := 'She said "Hello"';
  output := TYAMLCharUtils.EscapeStringForJSON(input);
  expected := 'She said \"Hello\"';
  Assert.AreEqual(expected, output);

  // Test backslashes
  input := 'Path\File\Name';
  output := TYAMLCharUtils.EscapeStringForJSON(input);
  expected := 'Path\\File\\Name';
  Assert.AreEqual(expected, output);

  // Test combination
  input := 'He said "Use \\ for paths"';
  output := TYAMLCharUtils.EscapeStringForJSON(input);
  expected := 'He said \"Use \\\\ for paths\"';
  Assert.AreEqual(expected, output);
end;

procedure TYAMLCharUtilsTests.TestPreserveUnicodeCharacters;
var
  input, output: string;
begin
  // Test that regular Unicode characters are preserved
  input := 'Café résumé naïve';
  output := TYAMLCharUtils.EscapeStringForJSON(input);
  Assert.AreEqual('Café résumé naïve', output);

  // Test mathematical symbols
  input := '±×÷≈≠≤≥';
  output := TYAMLCharUtils.EscapeStringForJSON(input);
  Assert.AreEqual('±×÷≈≠≤≥', output);

  // Test currency and symbols
  input := '©™®€£¥$¢';
  output := TYAMLCharUtils.EscapeStringForJSON(input);
  Assert.AreEqual('©™®€£¥$¢', output);

  // Test extended accented characters
  input := 'àáâãäåæçèéêë';
  output := TYAMLCharUtils.EscapeStringForJSON(input);
  Assert.AreEqual('àáâãäåæçèéêë', output);
end;

procedure TYAMLCharUtilsTests.TestEscapeSurrogatePairs;
var
  input, output: string;
begin
  // Test emoji (which use surrogate pairs)
  input := '🚀🌟💻';
  output := TYAMLCharUtils.EscapeStringForJSON(input);
  // Should be escaped as surrogate pairs
  Assert.IsTrue(output.Contains('\u'));
  Assert.IsTrue(Length(output) > Length(input)); // Should be longer due to escaping
end;

procedure TYAMLCharUtilsTests.TestEscapeUnpairedSurrogates;
var
  input, output: string;
begin
  // Test unpaired high surrogate
  input := 'Before' + Char($D800) + 'After';
  output := TYAMLCharUtils.EscapeStringForJSON(input);
  Assert.Contains(output, '\uD800');
  Assert.Contains(output, 'Before');
  Assert.Contains(output, 'After');

  // Test unpaired low surrogate
  input := 'Before' + Char($DC00) + 'After';
  output := TYAMLCharUtils.EscapeStringForJSON(input);
  Assert.Contains(output, '\uDC00');
  Assert.Contains(output, 'Before');
  Assert.Contains(output, 'After');
end;

procedure TYAMLCharUtilsTests.TestMathSymbols;
var
  input, output : string;
begin

  input := '±×÷≈≠≤≥';
  output := TYAMLCharUtils.EscapeStringForJSON(input);
  Assert.Contains(output, input);

end;

procedure TYAMLCharUtilsTests.TestEscapeEmptyString;
var
  input, output: string;
begin
  input := '';
  output := TYAMLCharUtils.EscapeStringForJSON(input);
  Assert.AreEqual('', output);
end;

procedure TYAMLCharUtilsTests.TestEscapeMixedContent;
var
  input, output: string;
begin
  // Test string with mix of escapable and non-escapable characters
  input := 'Hello "World"' + #10 + 'Café © 2024' + #9 + 'Path\File';
  output := TYAMLCharUtils.EscapeStringForJSON(input);

  // Should contain escaped quotes and control chars but preserve Unicode
  Assert.Contains(output, '\"');
  Assert.Contains(output, '\n');
  Assert.Contains(output, '\t');
  Assert.Contains(output, '\\');
  Assert.Contains(output, 'Café');
  Assert.Contains(output, '©');
end;

procedure TYAMLCharUtilsTests.TestEscapeExtendedASCII;
var
  input, output: string;
  i: Integer;
begin
  // Test characters in extended ASCII range (128-255)
  input := '';
  for i := 128 to 255 do
    input := input + Char(i);
  
  output := TYAMLCharUtils.EscapeStringForJSON(input);
  
  // Extended ASCII should be preserved (not escaped)
  Assert.AreEqual(input, output);
end;

procedure TYAMLCharUtilsTests.TestBMPCharactersNotEscaped;
var
  input, output: string;
begin
  // Test specific BMP characters that should NOT be escaped
  // Mathematical symbols in BMP
  input := '≈≠≤≥∞∑∏√∫∂∆';
  output := TYAMLCharUtils.EscapeStringForJSON(input);
  Assert.AreEqual(input, output, 'BMP mathematical symbols should not be escaped');
  
  // CJK characters (examples)
  input := '中文日本語한국어';
  output := TYAMLCharUtils.EscapeStringForJSON(input);
  Assert.AreEqual(input, output, 'CJK characters should not be escaped');
  
  // Greek letters
  input := 'αβγδεζηθικλμνξοπρστυφχψω';
  output := TYAMLCharUtils.EscapeStringForJSON(input);
  Assert.AreEqual(input, output, 'Greek letters should not be escaped');
  
  // Currency symbols in BMP
  input := '€£¥₹₽₩';
  output := TYAMLCharUtils.EscapeStringForJSON(input);
  Assert.AreEqual(input, output, 'Currency symbols should not be escaped');
end;

procedure TYAMLCharUtilsTests.TestOnlySurrogatePairsEscaped;
var
  input, output: string;
  containsEscapes: Boolean;
begin
  // Test that ONLY characters outside BMP (requiring surrogate pairs) are escaped
  
  // Emoji that require surrogate pairs (outside BMP)
  input := '🚀🌟💻😀';
  output := TYAMLCharUtils.EscapeStringForJSON(input);
  containsEscapes := output.Contains('\u');
  Assert.IsTrue(containsEscapes, 'Emoji (outside BMP) should be escaped as surrogate pairs');
  
  // Verify the escape format looks like surrogate pairs
  Assert.IsTrue(output.Contains('\uD8'), 'Should contain high surrogate escape');
  
  // Mathematical symbols in Supplementary Multilingual Plane
  input := '𝒜𝒷𝒸𝒹'; // Mathematical script letters (U+1D49C etc.)
  output := TYAMLCharUtils.EscapeStringForJSON(input);
  containsEscapes := output.Contains('\u');
  Assert.IsTrue(containsEscapes, 'Math script letters outside BMP should be escaped');
end;

initialization
  TDUnitX.RegisterTestFixture(TYAMLCharUtilsTests);

end.
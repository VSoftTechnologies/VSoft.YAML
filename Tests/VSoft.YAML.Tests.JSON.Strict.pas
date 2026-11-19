unit VSoft.YAML.Tests.JSON.Strict;

interface

uses
  DUnitX.TestFramework,
  VSoft.YAML;

type
  /// <summary> RFC 8259 cases for the JSON parser's strict mode (JSONMode). </summary>
  [TestFixture]
  TStrictJSONParserTests = class
  private
    function Parse(const json : string) : IYAMLDocument;
    procedure CheckRejects(const json : string);
    procedure CheckSameAsYAMLParser(const fileName : string);
  public
    [Test]
    [TestCase('object', '{"a":1}', '|')]
    [TestCase('array', '[1,2,3]', '|')]
    [TestCase('string', '"s"', '|')]
    [TestCase('integer', '1', '|')]
    [TestCase('negativeZero', '-0', '|')]
    [TestCase('fraction', '0.5', '|')]
    [TestCase('exponent', '1e5', '|')]
    [TestCase('exponentSigned', '1E-5', '|')]
    [TestCase('true', 'true', '|')]
    [TestCase('false', 'false', '|')]
    [TestCase('null', 'null', '|')]
    [TestCase('whitespace', ' [ ] ', '|')]
    [TestCase('nested', '{"a":[{"b":null},[]],"c":{}}', '|')]
    [TestCase('escapes', '"\u00e9\n\t\"\\\/\b\f\r"', '|')]
    procedure Accepts(const json : string);

    [Test]
    [TestCase('unquotedKey', '{a:1}', '|')]
    [TestCase('singleQuotedKey', '{''a'':1}', '|')]
    [TestCase('singleQuotedString', '''s''', '|')]
    [TestCase('trailingCommaArray', '[1,]', '|')]
    [TestCase('trailingCommaObject', '{"a":1,}', '|')]
    [TestCase('leadingComma', '[,1]', '|')]
    [TestCase('doubleComma', '[1,,2]', '|')]
    [TestCase('leadingZero', '01', '|')]
    [TestCase('plusSign', '+1', '|')]
    [TestCase('leadingPoint', '.5', '|')]
    [TestCase('trailingPoint', '1.', '|')]
    [TestCase('emptyExponent', '1e', '|')]
    [TestCase('hex', '0x1F', '|')]
    [TestCase('nan', 'NaN', '|')]
    [TestCase('infinity', 'Infinity', '|')]
    [TestCase('negativeInfinity', '-Infinity', '|')]
    [TestCase('loneMinus', '-', '|')]
    [TestCase('hexEscape', '"\x41"', '|')]
    [TestCase('identityEscape', '"\a"', '|')]
    [TestCase('shortUnicodeEscape', '"\u12"', '|')]
    [TestCase('badUnicodeEscape', '"\u12G4"', '|')]
    [TestCase('blockComment', '/* c */1', '|')]
    [TestCase('hashComment', '# c', '|')]
    [TestCase('capitalTrue', 'True', '|')]
    [TestCase('shortNull', 'nul', '|')]
    [TestCase('literalRunOn', 'truex', '|')]
    [TestCase('missingComma', '[1 2]', '|')]
    [TestCase('missingColon', '{"a" 1}', '|')]
    [TestCase('missingMemberComma', '{"a":1 "b":2}', '|')]
    [TestCase('twoValues', '1 2', '|')]
    [TestCase('unterminatedString', '"abc', '|')]
    [TestCase('unterminatedArray', '[', '|')]
    [TestCase('unterminatedObject', '{', '|')]
    [TestCase('missingValue', '{"a":}', '|')]
    [TestCase('missingKey', '{:1}', '|')]
    procedure Rejects(const json : string);

    [Test]
    procedure Rejects_EmptyInput;

    [Test]
    procedure Rejects_LineComment;

    [Test]
    procedure Rejects_ControlCharInString;

    [Test]
    procedure Rejects_RawTabInString;

    [Test]
    procedure Rejects_BOMAfterStart;

    [Test]
    procedure Accepts_DELInString;

    [Test]
    procedure Accepts_LeadingBOM;

    [Test]
    procedure Number_TextIsKept;

    [Test]
    procedure Escapes_AreDecoded;

    [Test]
    procedure DuplicateKey_Error;

    [Test]
    procedure DuplicateKey_LastWins;

    [Test]
    procedure Error_LineAndColumn;

    [Test]
    procedure Stream_SmallBlocks_SameAsString;

    [Test]
    procedure NestingLimit;

    [Test]
    procedure SameAsYAMLParser_TestJSON;

    [Test]
    procedure SameAsYAMLParser_SmallTestJSON;
  end;

implementation

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  VSoft.YAML.IO;

{ TStrictJSONParserTests }

function TStrictJSONParserTests.Parse(const json : string) : IYAMLDocument;
var
  options : IYAMLParserOptions;
begin
  options := TYAML.CreateParserOptions;
  options.JSONMode := true;
  result := TYAML.LoadFromString(json, options);
end;

procedure TStrictJSONParserTests.CheckRejects(const json : string);
begin
  Assert.WillRaise(
    procedure
    begin
      Parse(json);
    end,
    EYAMLParseException);
end;

procedure TStrictJSONParserTests.Accepts(const json : string);
var
  doc : IYAMLDocument;
begin
  doc := Parse(json);
  Assert.IsNotNull(doc);
  Assert.IsNotNull(doc.Root);
end;

procedure TStrictJSONParserTests.Rejects(const json : string);
begin
  CheckRejects(json);
end;

procedure TStrictJSONParserTests.Rejects_EmptyInput;
begin
  CheckRejects('');
  CheckRejects('   ' + sLineBreak);
end;

procedure TStrictJSONParserTests.Rejects_LineComment;
begin
  CheckRejects('// c' + sLineBreak + '1');
  CheckRejects('[1 // c' + sLineBreak + ']');
end;

procedure TStrictJSONParserTests.Rejects_ControlCharInString;
begin
  CheckRejects('"a' + #1 + 'b"');
  CheckRejects('"a' + #10 + 'b"');
end;

procedure TStrictJSONParserTests.Rejects_RawTabInString;
begin
  CheckRejects('"a' + #9 + 'b"');
end;

procedure TStrictJSONParserTests.Rejects_BOMAfterStart;
begin
  CheckRejects('[' + #$FEFF + '1]');
end;

procedure TStrictJSONParserTests.Accepts_DELInString;
begin
  Assert.AreEqual('a' + #127 + 'b', Parse('"a' + #127 + 'b"').Root.AsString);
end;

procedure TStrictJSONParserTests.Accepts_LeadingBOM;
begin
  Assert.AreEqual<Int64>(1, Parse(#$FEFF + '{"a":1}').AsMapping.Items['a'].AsInteger);
end;

procedure TStrictJSONParserTests.Number_TextIsKept;
var
  doc : IYAMLDocument;
begin
  doc := Parse('[1.50, 1e5, -0, 123456789012345678901234567890, 0]');
  Assert.AreEqual('1.50', doc.AsSequence[0].RawValue);
  Assert.IsTrue(doc.AsSequence[0].IsFloat);
  Assert.AreEqual('1e5', doc.AsSequence[1].RawValue);
  Assert.IsTrue(doc.AsSequence[1].IsFloat);
  Assert.AreEqual('-0', doc.AsSequence[2].RawValue);
  Assert.IsTrue(doc.AsSequence[2].IsInteger);
  Assert.AreEqual('123456789012345678901234567890', doc.AsSequence[3].RawValue);
  Assert.IsTrue(doc.AsSequence[3].IsInteger);
  Assert.AreEqual<Int64>(0, doc.AsSequence[4].AsInteger);
end;

procedure TStrictJSONParserTests.Escapes_AreDecoded;
begin
  Assert.AreEqual('"/' + #8#12#10#13#9 + 'A' + #$00E9 + '\',
    Parse('"\"\/\b\f\n\r\tA\u00e9\\"').Root.AsString);
  // a surrogate pair is kept as its two code units
  Assert.AreEqual(#$D83D#$DE00, Parse('"\uD83D\uDE00"').Root.AsString);
end;

procedure TStrictJSONParserTests.DuplicateKey_Error;
var
  options : IYAMLParserOptions;
begin
  options := TYAML.CreateParserOptions;
  options.JSONMode := true;
  options.DuplicateKeyBehavior := TYAMLDuplicateKeyBehavior.dkError;
  Assert.WillRaise(
    procedure
    begin
      TYAML.LoadFromString('{"a":1,"a":2}', options);
    end,
    EYAMLParseException);
end;

procedure TStrictJSONParserTests.DuplicateKey_LastWins;
var
  doc : IYAMLDocument;
begin
  doc := Parse('{"a":1,"a":2}');
  Assert.AreEqual(1, doc.AsMapping.Count);
  Assert.AreEqual<Int64>(2, doc.AsMapping.Items['a'].AsInteger);
end;

procedure TStrictJSONParserTests.Error_LineAndColumn;
var
  raised : boolean;
begin
  raised := false;
  try
    Parse('{"a":' + sLineBreak + '  @}');
  except
    on E : EYAMLParseException do
    begin
      raised := true;
      Assert.AreEqual(2, E.Line, 'line');
      Assert.AreEqual(3, E.Column, 'column');
    end;
  end;
  Assert.IsTrue(raised, 'no error raised');
end;

// The window refill paths: strings, escapes, numbers and literals cut by tiny stream blocks
// must read as from a string.
procedure TStrictJSONParserTests.Stream_SmallBlocks_SameAsString;
var
  sb : TStringBuilder;
  i : integer;
  json : string;
  expected, actual : string;
  stream : TStringStream;
  options : IYAMLParserOptions;
  oldBlockSize : integer;
  writeOptions : IYAMLEmitOptions;
begin
  sb := TStringBuilder.Create;
  try
    sb.Append('{"items":[');
    for i := 1 to 300 do
    begin
      if i > 1 then
        sb.Append(',');
      sb.Append('{"id":').Append(i * 1234567).Append(',"name":"item number ').Append(i)
        .Append(' with a long-ish name \"quoted\" \u00e9\\ end","ok":true,"none":null,"f":-12.5e-3,"list":[1,2.25,"x"]}');
    end;
    sb.Append(']}');
    json := sb.ToString;
  finally
    sb.Free;
  end;

  writeOptions := TYAML.CreateWriterOptions;
  writeOptions.PrettyPrint := false;
  expected := TYAML.WriteToJSONString(Parse(json).Root, writeOptions);

  options := TYAML.CreateParserOptions;
  options.JSONMode := true;
  oldBlockSize := TStreamTextSource.BlockSize;
  try
    TStreamTextSource.BlockSize := 8;
    stream := TStringStream.Create(json, TEncoding.UTF8);
    try
      actual := TYAML.WriteToJSONString(TYAML.LoadFromStream(stream, options).Root, writeOptions);
    finally
      stream.Free;
    end;
  finally
    TStreamTextSource.BlockSize := oldBlockSize;
  end;
  Assert.AreEqual(expected, actual);
end;

procedure TStrictJSONParserTests.NestingLimit;
begin
  Assert.IsNotNull(Parse(StringOfChar('[', 1000) + StringOfChar(']', 1000)));
  CheckRejects(StringOfChar('[', 1001) + StringOfChar(']', 1001));
end;

// JSON is YAML, so reading a JSON file as YAML must give the same document as reading it
// as JSON - the two parsers check each other. (load_test.json is not used: it is indented
// with tabs inside a flow mapping, which YAML allows but the YAML parser rejects - one of
// the yaml-test-suite known failures.)
procedure TStrictJSONParserTests.CheckSameAsYAMLParser(const fileName : string);
var
  text : string;
  options : IYAMLParserOptions;
  jsonDoc, yamlDoc : IYAMLDocument;
  writeOptions : IYAMLEmitOptions;
begin
  text := TFile.ReadAllText(TPath.Combine(ExtractFilePath(ParamStr(0)), '..\..\TestFiles\' + fileName), TEncoding.UTF8);
  options := TYAML.CreateParserOptions;
  options.JSONMode := true;
  jsonDoc := TYAML.LoadFromString(text, options);
  yamlDoc := TYAML.LoadFromString(text);
  writeOptions := TYAML.CreateWriterOptions;
  writeOptions.PrettyPrint := false;
  Assert.AreEqual(TYAML.WriteToJSONString(yamlDoc.Root, writeOptions), TYAML.WriteToJSONString(jsonDoc.Root, writeOptions), 'JSON output');
  Assert.AreEqual(TYAML.WriteToString(yamlDoc), TYAML.WriteToString(jsonDoc), 'YAML output');
end;

procedure TStrictJSONParserTests.SameAsYAMLParser_SmallTestJSON;
begin
  CheckSameAsYAMLParser('small_test.json');
end;

procedure TStrictJSONParserTests.SameAsYAMLParser_TestJSON;
begin
  CheckSameAsYAMLParser('test.json');
end;

initialization
  TDUnitX.RegisterTestFixture(TStrictJSONParserTests);

end.

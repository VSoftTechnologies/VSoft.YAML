unit VSoft.YAML.Tests.PlainScalars;

interface

uses
  DUnitX.TestFramework,
  VSoft.YAML;

type
  // A plain (unquoted) scalar's type follows the YAML 1.2 core schema - each word in
  // exactly three spellings, e.g. null, Null and NULL - plus the YAML 1.1 forms VSoft.YAML
  // also reads. A string the writer emits must read back as the same string.
  [TestFixture]
  TPlainScalarTests = class
  private
    function TypeName(const valueType : TYAMLValueType) : string;
  public
    [Test]
    // YAML 1.2 core schema null: null, Null, NULL or ~
    [TestCase('nullLower', 'null,vtNull')]
    [TestCase('nullCapitalised', 'Null,vtNull')]
    [TestCase('nullUpper', 'NULL,vtNull')]
    [TestCase('tilde', '~,vtNull')]
    [TestCase('nullMixed', 'nULL,vtString')]
    // YAML 1.2 core schema bool: true, True, TRUE, false, False, FALSE
    [TestCase('trueLower', 'true,vtBoolean')]
    [TestCase('trueCapitalised', 'True,vtBoolean')]
    [TestCase('trueUpper', 'TRUE,vtBoolean')]
    [TestCase('falseCapitalised', 'False,vtBoolean')]
    [TestCase('falseUpper', 'FALSE,vtBoolean')]
    [TestCase('trueMixed', 'tRUE,vtString')]
    [TestCase('falseMixed', 'FaLSE,vtString')]
    // YAML 1.1 yes/no/on/off, in the same three spellings
    [TestCase('yesLower', 'yes,vtBoolean')]
    [TestCase('yesCapitalised', 'Yes,vtBoolean')]
    [TestCase('yesUpper', 'YES,vtBoolean')]
    [TestCase('noCapitalised', 'No,vtBoolean')]
    [TestCase('noUpper', 'NO,vtBoolean')]
    [TestCase('onCapitalised', 'On,vtBoolean')]
    [TestCase('onUpper', 'ON,vtBoolean')]
    [TestCase('offCapitalised', 'Off,vtBoolean')]
    [TestCase('offUpper', 'OFF,vtBoolean')]
    [TestCase('noMixed', 'nO,vtString')]
    [TestCase('yesMixed', 'YeS,vtString')]
    [TestCase('onMixed', 'oN,vtString')]
    [TestCase('offMixed', 'OfF,vtString')]
    [TestCase('singleY', 'y,vtString')]
    [TestCase('singleN', 'N,vtString')]
    // YAML 1.2 core schema floats: .nan .NaN .NAN, [-+]? .inf .Inf .INF, and decimals
    // with the point at either end
    [TestCase('nanLower', '.nan,vtFloat')]
    [TestCase('nanCamel', '.NaN,vtFloat')]
    [TestCase('nanUpper', '.NAN,vtFloat')]
    [TestCase('infLower', '.inf,vtFloat')]
    [TestCase('infCapitalised', '.Inf,vtFloat')]
    [TestCase('infUpper', '.INF,vtFloat')]
    [TestCase('infPlus', '+.inf,vtFloat')]
    [TestCase('infMinusUpper', '-.INF,vtFloat')]
    [TestCase('nanMixed', '.nAn,vtString')]
    [TestCase('nanCapitalised', '.Nan,vtString')]
    [TestCase('infMixed', '.iNF,vtString')]
    [TestCase('nanSigned', '-.nan,vtString')]
    [TestCase('leadingPoint', '.5,vtFloat')]
    [TestCase('signedLeadingPoint', '+.5,vtFloat')]
    [TestCase('trailingPoint', '1.,vtFloat')]
    [TestCase('trailingPointExponent', '1.e5,vtFloat')]
    [TestCase('exponentNoPoint', '1e5,vtFloat')]
    [TestCase('pointOnly', '.,vtString')]
    // integers: decimal, 0o octal, 0x hex, and YAML 1.1 0b binary - prefixes in lower case
    [TestCase('signedInteger', '+7,vtInteger')]
    [TestCase('leadingZeros', '007,vtInteger')]
    [TestCase('octal', '0o17,vtInteger')]
    [TestCase('hex', '0x1F,vtInteger')]
    [TestCase('binary', '0b101,vtInteger')]
    [TestCase('hexUpperPrefix', '0X1F,vtString')]
    [TestCase('octalUpperPrefix', '0O17,vtString')]
    // YAML 1.1 timestamps
    [TestCase('date', '2026-10-22,vtTimestamp')]
    procedure Parse_ResolvesPlainScalar(const text : string; const expectedType : string);

    [Test]
    [TestCase('leadingPoint', '.5,0.5')]
    [TestCase('signedLeadingPoint', '+.5,0.5')]
    [TestCase('negativeLeadingPoint', '-.5,-0.5')]
    [TestCase('trailingPoint', '1.,1')]
    [TestCase('trailingPointExponent', '1.e5,100000')]
    procedure Parse_PointAtEitherEnd_AsFloat(const text : string; const expected : string);

    [Test]
    // every spelling the parser reads as something other than a string
    [TestCase('nullCapitalised', 'Null')]
    [TestCase('nullUpper', 'NULL')]
    [TestCase('trueCapitalised', 'True')]
    [TestCase('trueUpper', 'TRUE')]
    [TestCase('falseCapitalised', 'False')]
    [TestCase('falseUpper', 'FALSE')]
    [TestCase('yesCapitalised', 'Yes')]
    [TestCase('yesUpper', 'YES')]
    [TestCase('noCapitalised', 'No')]
    [TestCase('noUpper', 'NO')]
    [TestCase('onCapitalised', 'On')]
    [TestCase('onUpper', 'ON')]
    [TestCase('offCapitalised', 'Off')]
    [TestCase('offUpper', 'OFF')]
    [TestCase('nanLower', '.nan')]
    [TestCase('nanCamel', '.NaN')]
    [TestCase('nanUpper', '.NAN')]
    [TestCase('infLower', '.inf')]
    [TestCase('infCapitalised', '.Inf')]
    [TestCase('infUpper', '.INF')]
    [TestCase('infPlus', '+.inf')]
    [TestCase('infMinus', '-.inf')]
    [TestCase('infMinusUpper', '-.INF')]
    [TestCase('leadingPoint', '.5')]
    [TestCase('trailingPoint', '1.')]
    [TestCase('trailingPointExponent', '1.e5')]
    [TestCase('octal', '0o17')]
    [TestCase('binary', '0b101')]
    // the lexer drops '_' separators from a number, so these read as 1000 and 1000.5
    [TestCase('separatedInteger', '1_000')]
    [TestCase('separatedFloat', '1_000.5')]
    [TestCase('separatedNegative', '-1_0')]
    [TestCase('date', '2026-10-22')]
    [TestCase('dateTime', '2026-10-22T10:20:30Z')]
    [TestCase('dateSpaceTime', '2026-10-22 10:20:30')]
    // strings that are not special must still round trip
    [TestCase('nullMixed', 'nULL')]
    [TestCase('noMixed', 'nO')]
    [TestCase('nanMixed', '.nAn')]
    procedure Write_StringRoundTrips(const text : string);

    // a date and time separated by a space ends at the end of its line
    [Test]
    [TestCase('lf', '#10')]
    [TestCase('crlf', '#13#10')]
    [TestCase('cr', '#13')]
    procedure Parse_SpaceSeparatedTimestamp_EndsAtLineEnd(const lineBreak : string);

    [Test]
    procedure Parse_SpaceSeparatedTimestamp_Nested;

    [Test]
    procedure WriteToJSON_BenchmarkFile_IsValidJSON;
  end;

implementation

uses
  System.SysUtils,
  System.TypInfo,
  System.IOUtils,
  VSoft.YAML.Classes;

function TPlainScalarTests.TypeName(const valueType : TYAMLValueType) : string;
begin
  result := GetEnumName(TypeInfo(TYAMLValueType), Ord(valueType));
end;

procedure TPlainScalarTests.Parse_ResolvesPlainScalar(const text : string; const expectedType : string);
var
  doc : IYAMLDocument;
begin
  doc := TYAML.LoadFromString('v: ' + text);
  Assert.AreEqual(expectedType, TypeName(doc.AsMapping.Items['v'].ValueType), 'block mapping value');

  doc := TYAML.LoadFromString('[' + text + ']');
  Assert.AreEqual(expectedType, TypeName(doc.AsSequence[0].ValueType), 'flow sequence item');
end;

procedure TPlainScalarTests.Parse_PointAtEitherEnd_AsFloat(const text : string; const expected : string);
var
  doc : IYAMLDocument;
begin
  doc := TYAML.LoadFromString('v: ' + text);
  Assert.AreEqual(expected, FloatToStr(doc.AsMapping.Items['v'].AsFloat, YAMLFormatSettings));
end;

procedure TPlainScalarTests.Write_StringRoundTrips(const text : string);
var
  doc : IYAMLDocument;
  reloaded : IYAMLDocument;
begin
  // as a mapping value
  doc := TYAML.CreateMapping;
  doc.AsMapping.AddOrSetValue('v', text);
  reloaded := TYAML.LoadFromString(TYAML.WriteToString(doc));
  Assert.AreEqual('vtString', TypeName(reloaded.AsMapping.Items['v'].ValueType), 'value type');
  Assert.AreEqual(text, reloaded.AsMapping.Items['v'].AsString, 'value');

  // as a key
  doc := TYAML.CreateMapping;
  doc.AsMapping.AddOrSetValue(text, 1);
  reloaded := TYAML.LoadFromString(TYAML.WriteToString(doc));
  Assert.AreEqual(text, reloaded.AsMapping.Keys[0], 'key');

  // in a flow sequence
  doc := TYAML.CreateSequence;
  doc.Options.Format := TYAMLOutputFormat.yofFlow;
  doc.AsSequence.AddValue(text);
  reloaded := TYAML.LoadFromString(TYAML.WriteToString(doc));
  Assert.AreEqual('vtString', TypeName(reloaded.AsSequence[0].ValueType), 'flow item type');
  Assert.AreEqual(text, reloaded.AsSequence[0].AsString, 'flow item');
end;

procedure TPlainScalarTests.Parse_SpaceSeparatedTimestamp_EndsAtLineEnd(const lineBreak : string);
var
  lb : string;
  doc : IYAMLDocument;
begin
  // the test case passes the line break as Delphi char codes
  if lineBreak = '#10' then
    lb := #10
  else if lineBreak = '#13' then
    lb := #13
  else
    lb := #13#10;

  // the next key straight after: it used to be read into the timestamp
  doc := TYAML.LoadFromString('a: 2024-01-15 10:30:00' + lb + 'b: 1' + lb);
  Assert.AreEqual(2, doc.AsMapping.Count, 'keys');
  Assert.AreEqual('vtTimestamp', TypeName(doc.AsMapping.Items['a'].ValueType), 'type');
  Assert.AreEqual('2024-01-15 10:30:00', doc.AsMapping.Items['a'].RawValue, 'text');
  Assert.AreEqual<Int64>(1, doc.AsMapping.Items['b'].AsInteger, 'next key');

  // a blank line after: it used to end up in the value
  doc := TYAML.LoadFromString('a: 2024-01-15 10:30:00' + lb + lb + 'b: 1' + lb);
  Assert.AreEqual('2024-01-15 10:30:00', doc.AsMapping.Items['a'].RawValue, 'text before a blank line');
  Assert.AreEqual(2, doc.AsMapping.Count, 'keys after a blank line');

  // last in the input
  doc := TYAML.LoadFromString('a: 2024-01-15 10:30:00' + lb);
  Assert.AreEqual('2024-01-15 10:30:00', doc.AsMapping.Items['a'].RawValue, 'text at the end');
end;

procedure TPlainScalarTests.Parse_SpaceSeparatedTimestamp_Nested;
var
  doc : IYAMLDocument;
  inner : IYAMLMapping;
begin
  doc := TYAML.LoadFromString(
    'outer:' + sLineBreak +
    '  when: 2024-01-15 10:30:00' + sLineBreak +
    sLineBreak +
    '  next: x' + sLineBreak +
    'after: y' + sLineBreak);
  inner := doc.AsMapping.Items['outer'].AsMapping;
  Assert.AreEqual('2024-01-15 10:30:00', inner.Items['when'].RawValue);
  Assert.AreEqual('x', inner.Items['next'].AsString);
  Assert.AreEqual('y', doc.AsMapping.Items['after'].AsString);
end;

// benchmark_large.yaml holds such a timestamp; its JSON must read back as JSON
procedure TPlainScalarTests.WriteToJSON_BenchmarkFile_IsValidJSON;
var
  doc, reloaded : IYAMLDocument;
  options : IYAMLParserOptions;
  json : string;
begin
  doc := TYAML.LoadFromFile(TPath.Combine(ExtractFilePath(ParamStr(0)), '..\..\TestFiles\benchmark_large.yaml'));
  json := TYAML.WriteToJSONString(doc);
  options := TYAML.CreateParserOptions;
  options.JSONMode := true;
  reloaded := TYAML.LoadFromString(json, options);
  Assert.AreEqual('2024-01-15 10:30:00',
    reloaded.AsMapping.Items['special_values'].AsMapping.Items['timestamp_space'].AsString);
end;

initialization
  TDUnitX.RegisterTestFixture(TPlainScalarTests);

end.

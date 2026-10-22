unit VSoft.YAML.Tests.Numbers;

interface

uses
  DUnitX.TestFramework,
  VSoft.YAML;

type
  // Numbers must be written exactly - every digit of the value that was added or parsed -
  // in both JSON and YAML, not whatever survives a trip through Int64 or Double.
  [TestFixture]
  TNumberOutputTests = class
  private
    function WriteJSON(const doc : IYAMLDocument) : string;
    function WriteYAML(const doc : IYAMLDocument) : string;
    procedure CheckAddOrSetNumberRaises(const text : string);
  public
    // UInt64 values past High(Int64)
    [Test]
    procedure JSON_UInt64Max_WrittenAsIs;
    [Test]
    procedure YAML_UInt64Max_WrittenAsIs;

    // Currency keeps its four exact decimals
    [Test]
    procedure JSON_Currency_KeepsFourDecimals;
    [Test]
    procedure YAML_Currency_KeepsFourDecimals;

    // Numbers added from their text
    [Test]
    procedure JSON_AddOrSetNumber_WritesTextVerbatim;
    [Test]
    procedure YAML_AddOrSetNumber_WritesTextVerbatim;
    [Test]
    procedure JSON_AddNumber_WritesTextVerbatim;
    [Test]
    procedure AddOrSetNumber_TypeMatchesParser;
    [Test]
    procedure AddOrSetNumber_InvalidText_Raises;
    [Test]
    procedure AddNumber_InvalidText_Raises;

    // !!int is arbitrary size in YAML 1.2
    [Test]
    procedure IntTag_BeyondInt64_Accepted;

    // The repro from the FinalBuilder ADO Query report
    [Test]
    procedure JSON_RecordsetRow_AllValuesExact;

    // Parse then write keeps every digit
    [Test]
    procedure RoundTrip_JSON_KeepsEveryDigit;
    [Test]
    procedure RoundTrip_YAML_KeepsEveryDigit;
    [Test]
    procedure RoundTrip_YAMLToJSON_KeepsEveryDigit;

    // YAML hex, octal and binary integers
    [Test]
    procedure AsInteger_RadixPast32Bits;
    [Test]
    procedure AsInteger_RadixPastInt64_Raises;
    [Test]
    procedure RadixIntegerPastInt64_WrittenAsDecimal;
    [Test]
    procedure IntTag_YAMLRadixForms_Accepted;

    // A float is still a float when the YAML is read back
    [Test]
    procedure YAML_WholeNumberFloat_StaysFloat;
  end;

implementation

uses
  System.SysUtils;

const
  cDecimal38 = '1234567890123456789012345678.9012345678'; // a SQL DECIMAL(38,10)
  cUInt64Max = '18446744073709551615';
  cCurrencyMax = '922337203685477.5807';
  cNegativeExponent = '2.5e-8';
  cNegativeZero = '-0.0';

// Currency literals go through Extended (a Double on Win64), which cannot hold every
// digit of the extremes, so build them from the underlying scaled Int64.
function CurrencyFromScaled(const scaled : Int64) : Currency;
begin
  PInt64(@result)^ := scaled;
end;

{ TNumberOutputTests }

function TNumberOutputTests.WriteJSON(const doc : IYAMLDocument) : string;
begin
  doc.Options.PrettyPrint := false;
  result := TYAML.WriteToJSONString(doc);
end;

function TNumberOutputTests.WriteYAML(const doc : IYAMLDocument) : string;
begin
  result := Trim(TYAML.WriteToString(doc));
end;

procedure TNumberOutputTests.CheckAddOrSetNumberRaises(const text : string);
var
  doc : IYAMLDocument;
  numberText : string;
begin
  doc := TYAML.CreateMapping;
  numberText := text;
  Assert.WillRaise(
    procedure
    begin
      doc.AsMapping.AddOrSetNumber('k', numberText);
    end, EConvertError, 'AddOrSetNumber should reject "' + text + '"');
end;

procedure TNumberOutputTests.JSON_UInt64Max_WrittenAsIs;
var
  doc : IYAMLDocument;
begin
  doc := TYAML.CreateMapping;
  doc.AsMapping.AddOrSetValue('uint64Max', UInt64(High(UInt64)));
  Assert.AreEqual('{"uint64Max":' + cUInt64Max + '}', WriteJSON(doc));
end;

procedure TNumberOutputTests.YAML_UInt64Max_WrittenAsIs;
var
  doc : IYAMLDocument;
begin
  doc := TYAML.CreateMapping;
  doc.AsMapping.AddOrSetValue('uint64Max', UInt64(High(UInt64)));
  Assert.AreEqual('uint64Max: ' + cUInt64Max, WriteYAML(doc));
end;

procedure TNumberOutputTests.JSON_Currency_KeepsFourDecimals;
var
  doc : IYAMLDocument;
begin
  doc := TYAML.CreateMapping;
  doc.AsMapping.AddOrSetCurrencyValue('currencyMax', CurrencyFromScaled(High(Int64)));
  doc.AsMapping.AddOrSetCurrencyValue('currencyMin', CurrencyFromScaled(Low(Int64)));
  doc.AsMapping.AddOrSetCurrencyValue('currency', 19.99);
  Assert.AreEqual('{"currencyMax":' + cCurrencyMax + ',"currencyMin":-922337203685477.5808,"currency":19.99}', WriteJSON(doc));
end;

procedure TNumberOutputTests.YAML_Currency_KeepsFourDecimals;
var
  doc : IYAMLDocument;
begin
  doc := TYAML.CreateMapping;
  doc.AsMapping.AddOrSetCurrencyValue('currencyMax', CurrencyFromScaled(High(Int64)));
  doc.AsMapping.AddOrSetCurrencyValue('currencyMin', CurrencyFromScaled(Low(Int64)));
  doc.AsMapping.AddOrSetCurrencyValue('currency', 19.99);
  Assert.AreEqual('currencyMax: ' + cCurrencyMax + sLineBreak +
                  'currencyMin: -922337203685477.5808' + sLineBreak +
                  'currency: 19.99', WriteYAML(doc));
end;

procedure TNumberOutputTests.JSON_AddOrSetNumber_WritesTextVerbatim;
var
  doc : IYAMLDocument;
begin
  doc := TYAML.CreateMapping;
  doc.AsMapping.AddOrSetNumber('decimal', cDecimal38);
  doc.AsMapping.AddOrSetNumber('beyondUInt64', '18446744073709551616');
  doc.AsMapping.AddOrSetNumber('negativeExponent', cNegativeExponent);
  doc.AsMapping.AddOrSetNumber('negativeZero', cNegativeZero);
  doc.AsMapping.AddOrSetNumber('trailingZero', '1.50');
  Assert.AreEqual('{"decimal":' + cDecimal38 + ',"beyondUInt64":18446744073709551616,"negativeExponent":' + cNegativeExponent +
                  ',"negativeZero":' + cNegativeZero + ',"trailingZero":1.50}', WriteJSON(doc));
end;

procedure TNumberOutputTests.YAML_AddOrSetNumber_WritesTextVerbatim;
var
  doc : IYAMLDocument;
begin
  doc := TYAML.CreateMapping;
  doc.AsMapping.AddOrSetNumber('decimal', cDecimal38);
  doc.AsMapping.AddOrSetNumber('beyondUInt64', '18446744073709551616');
  doc.AsMapping.AddOrSetNumber('negativeExponent', cNegativeExponent);
  doc.AsMapping.AddOrSetNumber('negativeZero', cNegativeZero);
  doc.AsMapping.AddOrSetNumber('trailingZero', '1.50');
  Assert.AreEqual('decimal: ' + cDecimal38 + sLineBreak +
                  'beyondUInt64: 18446744073709551616' + sLineBreak +
                  'negativeExponent: ' + cNegativeExponent + sLineBreak +
                  'negativeZero: ' + cNegativeZero + sLineBreak +
                  'trailingZero: 1.50', WriteYAML(doc));
end;

procedure TNumberOutputTests.JSON_AddNumber_WritesTextVerbatim;
var
  doc : IYAMLDocument;
begin
  doc := TYAML.CreateSequence;
  doc.AsSequence.AddNumber(cDecimal38);
  doc.AsSequence.AddNumber(cUInt64Max);
  doc.AsSequence.AddNumber('-1E+400'); // beyond Double
  Assert.AreEqual('[' + cDecimal38 + ',' + cUInt64Max + ',-1E+400]', WriteJSON(doc));
end;

procedure TNumberOutputTests.AddOrSetNumber_TypeMatchesParser;
var
  doc : IYAMLDocument;
begin
  // the same split the parser makes: an integer unless there is a fraction or an exponent
  doc := TYAML.CreateMapping;
  Assert.IsTrue(doc.AsMapping.AddOrSetNumber('a', cUInt64Max).IsInteger, cUInt64Max);
  Assert.IsTrue(doc.AsMapping.AddOrSetNumber('b', '-42').IsInteger, '-42');
  Assert.IsTrue(doc.AsMapping.AddOrSetNumber('c', cDecimal38).IsFloat, cDecimal38);
  Assert.IsTrue(doc.AsMapping.AddOrSetNumber('d', '1e5').IsFloat, '1e5');
  Assert.IsTrue(doc.AsMapping.Items['b'].AsInteger = -42, 'AsInteger of -42');
end;

procedure TNumberOutputTests.AddOrSetNumber_InvalidText_Raises;
begin
  // anything outside the RFC 8259 number grammar
  CheckAddOrSetNumberRaises('');
  CheckAddOrSetNumberRaises(' 1');
  CheckAddOrSetNumberRaises('1 ');
  CheckAddOrSetNumberRaises('+1');
  CheckAddOrSetNumberRaises('01');
  CheckAddOrSetNumberRaises('-');
  CheckAddOrSetNumberRaises('1.');
  CheckAddOrSetNumberRaises('.5');
  CheckAddOrSetNumberRaises('1e');
  CheckAddOrSetNumberRaises('1e+');
  CheckAddOrSetNumberRaises('0x1F');
  CheckAddOrSetNumberRaises('1_000');
  CheckAddOrSetNumberRaises('1,5');
  CheckAddOrSetNumberRaises('NaN');
  CheckAddOrSetNumberRaises('.inf');
  CheckAddOrSetNumberRaises('abc');
end;

procedure TNumberOutputTests.AddNumber_InvalidText_Raises;
var
  doc : IYAMLDocument;
begin
  doc := TYAML.CreateSequence;
  Assert.WillRaise(
    procedure
    begin
      doc.AsSequence.AddNumber('1,5');
    end, EConvertError);
  Assert.AreEqual(0, doc.AsSequence.Count, 'nothing should be added when the text is rejected');
end;

procedure TNumberOutputTests.IntTag_BeyondInt64_Accepted;
var
  doc : IYAMLDocument;
begin
  doc := TYAML.CreateMapping;
  Assert.IsTrue(doc.AsMapping.AddOrSetValue('big', cUInt64Max, '!!int').IsInteger);
  Assert.AreEqual('{"big":' + cUInt64Max + '}', WriteJSON(doc));

  doc := TYAML.LoadFromString('pastInt32: !!int 3000000000' + sLineBreak +
                              'pastInt64: !!int ' + cUInt64Max);
  Assert.IsTrue(doc.AsMapping.Items['pastInt32'].IsInteger, 'pastInt32');
  Assert.IsTrue(doc.AsMapping.Items['pastInt64'].IsInteger, 'pastInt64');
  Assert.AreEqual('{"pastInt32":3000000000,"pastInt64":' + cUInt64Max + '}', WriteJSON(doc));
end;

procedure TNumberOutputTests.JSON_RecordsetRow_AllValuesExact;
var
  doc : IYAMLDocument;
  row : IYAMLMapping;
  double15 : Double;
  price : Currency;
begin
  // typed variables rather than Double(...) / Currency(...) casts, which XE2 rejects
  double15 := 1234567890.12345;
  price := 19.99;
  doc := TYAML.CreateMapping;
  row := doc.AsMapping;
  row.AddOrSetValue('int64Max', Int64(High(Int64)));
  row.AddOrSetValue('uint64Max', UInt64(High(UInt64)));
  row.AddOrSetValue('double15', double15);
  row.AddOrSetCurrencyValue('currencyMax', CurrencyFromScaled(High(Int64)));
  row.AddOrSetCurrencyValue('currency', price);
  row.AddOrSetValue('decimal', '12345678901234567890.1234567890', '!!float');
  Assert.AreEqual('{"int64Max":9223372036854775807,"uint64Max":' + cUInt64Max + ',"double15":1234567890.12345,' +
                  '"currencyMax":' + cCurrencyMax + ',"currency":19.99,"decimal":12345678901234567890.1234567890}', WriteJSON(doc));
end;

procedure TNumberOutputTests.RoundTrip_JSON_KeepsEveryDigit;
var
  options : IYAMLParserOptions;
  json : string;
  doc : IYAMLDocument;
begin
  json := '{"decimal":' + cDecimal38 + ',"uint64Max":' + cUInt64Max + ',"currencyMax":' + cCurrencyMax +
          ',"negativeExponent":' + cNegativeExponent + ',"negativeZero":' + cNegativeZero + '}';
  options := TYAML.CreateParserOptions;
  options.JSONMode := true;
  doc := TYAML.LoadFromString(json, options);
  Assert.AreEqual(json, WriteJSON(doc));
end;

procedure TNumberOutputTests.RoundTrip_YAML_KeepsEveryDigit;
var
  yaml : string;
  doc : IYAMLDocument;
begin
  yaml := 'decimal: ' + cDecimal38 + sLineBreak +
          'uint64Max: ' + cUInt64Max + sLineBreak +
          'currencyMax: ' + cCurrencyMax + sLineBreak +
          'negativeExponent: ' + cNegativeExponent + sLineBreak +
          'negativeZero: ' + cNegativeZero;
  doc := TYAML.LoadFromString(yaml);
  Assert.AreEqual(yaml, WriteYAML(doc));
end;

procedure TNumberOutputTests.RoundTrip_YAMLToJSON_KeepsEveryDigit;
var
  doc : IYAMLDocument;
begin
  doc := TYAML.LoadFromString('decimal: ' + cDecimal38 + sLineBreak +
                              'uint64Max: ' + cUInt64Max + sLineBreak +
                              'currencyMax: ' + cCurrencyMax + sLineBreak +
                              'negativeExponent: ' + cNegativeExponent + sLineBreak +
                              'negativeZero: ' + cNegativeZero);
  Assert.AreEqual('{"decimal":' + cDecimal38 + ',"uint64Max":' + cUInt64Max + ',"currencyMax":' + cCurrencyMax +
                  ',"negativeExponent":' + cNegativeExponent + ',"negativeZero":' + cNegativeZero + '}', WriteJSON(doc));
end;

procedure TNumberOutputTests.AsInteger_RadixPast32Bits;
var
  doc : IYAMLDocument;
begin
  doc := TYAML.LoadFromString('hex32: 0xFFFFFFFF' + sLineBreak +
                              'hex64: 0x7FFFFFFFFFFFFFFF' + sLineBreak +
                              'octal64: 0o' + StringOfChar('7', 21) + sLineBreak +
                              'binary64: 0b' + StringOfChar('1', 63));
  Assert.AreEqual('4294967295', IntToStr(doc.AsMapping.Items['hex32'].AsInteger), 'hex32');
  Assert.AreEqual('9223372036854775807', IntToStr(doc.AsMapping.Items['hex64'].AsInteger), 'hex64');
  Assert.AreEqual('9223372036854775807', IntToStr(doc.AsMapping.Items['octal64'].AsInteger), 'octal64');
  Assert.AreEqual('9223372036854775807', IntToStr(doc.AsMapping.Items['binary64'].AsInteger), 'binary64');
end;

procedure TNumberOutputTests.AsInteger_RadixPastInt64_Raises;
var
  doc : IYAMLDocument;
begin
  // each is 2^63 - as for a decimal past High(Int64), an error rather than a wrapped value
  doc := TYAML.LoadFromString('hex: 0x8000000000000000' + sLineBreak +
                              'octal: 0o1' + StringOfChar('0', 21) + sLineBreak +
                              'binary: 0b1' + StringOfChar('0', 63));
  Assert.WillRaise(
    procedure
    begin
      doc.AsMapping.Items['hex'].AsInteger;
    end, EConvertError, 'hex');
  Assert.WillRaise(
    procedure
    begin
      doc.AsMapping.Items['octal'].AsInteger;
    end, EConvertError, 'octal');
  Assert.WillRaise(
    procedure
    begin
      doc.AsMapping.Items['binary'].AsInteger;
    end, EConvertError, 'binary');
end;

procedure TNumberOutputTests.RadixIntegerPastInt64_WrittenAsDecimal;
var
  doc : IYAMLDocument;
begin
  // forms JSON does not have are written as decimal - exactly, whatever their size
  doc := TYAML.LoadFromString('hexMax: 0xFFFFFFFFFFFFFFFF' + sLineBreak +
                              'hexHuge: 0x10000000000000000' + sLineBreak +
                              'octal: 0o17' + sLineBreak +
                              'binary: 0b1010');
  Assert.AreEqual('{"hexMax":' + cUInt64Max + ',"hexHuge":18446744073709551616,"octal":15,"binary":10}', WriteJSON(doc));
  Assert.AreEqual('hexMax: ' + cUInt64Max + sLineBreak +
                  'hexHuge: 18446744073709551616' + sLineBreak +
                  'octal: 15' + sLineBreak +
                  'binary: 10', WriteYAML(doc));
end;

procedure TNumberOutputTests.IntTag_YAMLRadixForms_Accepted;
var
  doc : IYAMLDocument;
begin
  // 0o and 0x are YAML 1.2 core schema integers, so !!int takes them, at any size
  doc := TYAML.LoadFromString('octal: !!int 0o17' + sLineBreak +
                              'hex: !!int 0x1F' + sLineBreak +
                              'hexHuge: !!int 0x10000000000000000');
  Assert.AreEqual('15', IntToStr(doc.AsMapping.Items['octal'].AsInteger), 'octal');
  Assert.AreEqual('31', IntToStr(doc.AsMapping.Items['hex'].AsInteger), 'hex');
  Assert.IsTrue(doc.AsMapping.Items['hexHuge'].IsInteger, 'hexHuge');
  Assert.AreEqual('{"octal":15,"hex":31,"hexHuge":18446744073709551616}', WriteJSON(doc));
end;

procedure TNumberOutputTests.YAML_WholeNumberFloat_StaysFloat;
var
  doc : IYAMLDocument;
  reloaded : IYAMLDocument;
  two : Double;
  nineteen : Currency;
  yaml : string;
begin
  // YAML reads "2" back as an !!int, so a float is written "2.0". JSON has one number type
  // and keeps "2", as System.JSON writes it.
  two := 2;
  nineteen := 19;
  doc := TYAML.CreateMapping;
  doc.AsMapping.AddOrSetValue('double', two);
  doc.AsMapping.AddOrSetCurrencyValue('currency', nineteen);
  doc.AsMapping.AddOrSetValue('tagged', '1', '!!float');
  doc.AsMapping.AddOrSetSequence('list').AddValue(two);

  yaml := TYAML.WriteToString(doc);
  Assert.Contains(yaml, 'double: 2.0');
  Assert.Contains(yaml, 'currency: 19.0');
  Assert.Contains(yaml, 'tagged: !!float 1.0');

  reloaded := TYAML.LoadFromString(yaml);
  Assert.IsTrue(reloaded.AsMapping.Items['double'].IsFloat, 'double');
  Assert.IsTrue(reloaded.AsMapping.Items['currency'].IsFloat, 'currency');
  Assert.IsTrue(reloaded.AsMapping.Items['tagged'].IsFloat, 'tagged');
  Assert.IsTrue(reloaded.AsMapping.Items['list'].AsSequence[0].IsFloat, 'list item');

  Assert.AreEqual('{"double":2,"currency":19,"tagged":1,"list":[2]}', WriteJSON(doc));
end;

initialization
  TDUnitX.RegisterTestFixture(TNumberOutputTests);

end.

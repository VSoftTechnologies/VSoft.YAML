unit VSoft.YAML.Tests.MappingProperties;

interface

uses
  DUnitX.TestFramework,
  VSoft.YAML;

type
  // The JsonDataObjects-style getters - S[], I[], L[], U[], F[], C[], D[], DUtc[] and B[] -
  // read a missing key as the default without adding it, convert between scalar types as
  // JsonDataObjects does, and read a null as the default. A[] and O[] still create a
  // missing key, as documented.
  [TestFixture]
  TMappingPropertyTests = class
  private
    // the getter's result as text, or the class of the exception it raised
    function GetterText(const mapping : IYAMLMapping; const getter : string; const key : string) : string;
  public
    [Test]
    [TestCase('S', 'S,""')]
    [TestCase('I', 'I,0')]
    [TestCase('L', 'L,0')]
    [TestCase('U', 'U,0')]
    [TestCase('F', 'F,0')]
    [TestCase('C', 'C,0')]
    [TestCase('D', 'D,0')]
    [TestCase('DUtc', 'DUtc,0')]
    [TestCase('B', 'B,False')]
    procedure MissingKey_ReadsDefault_AddsNothing(const getter : string; const expected : string);

    [Test]
    procedure MissingKey_AAndO_StillCreate;

    [Test]
    [TestCase('intFromString', '"42",I,42')]
    [TestCase('intFromFloatString', '"3.9",I,3')]
    [TestCase('intFromFloatTruncates', '3.9,I,3')]
    [TestCase('intFromNegativeFloat', '-3.9,I,-3')]
    [TestCase('intFromBoolean', 'true,I,1')]
    [TestCase('longFromString', '"9876543210",L,9876543210')]
    [TestCase('ulongFromInteger', '18446744073709551615,U,18446744073709551615')]
    [TestCase('ulongFromString', '"18446744073709551615",U,18446744073709551615')]
    [TestCase('ulongFromHex', '0xFFFFFFFFFFFFFFFF,U,18446744073709551615')]
    [TestCase('ulongFromFloat', '3.9,U,3')]
    [TestCase('floatFromInteger', '42,F,42')]
    [TestCase('floatFromString', '"3.5",F,3.5')]
    [TestCase('floatFromBoolean', 'true,F,1')]
    [TestCase('currencyFromInteger', '42,C,42')]
    [TestCase('currencyFromString', '"19.99",C,19.99')]
    [TestCase('currencyExact', '922337203685477.5807,C,922337203685477.5807')]
    [TestCase('boolFromTrueString', '"true",B,True')]
    [TestCase('boolFromCapitalisedString', '"True",B,True')]
    [TestCase('boolFromYesString', '"yes",B,True')]
    [TestCase('boolFromFalseString', '"false",B,False')]
    [TestCase('boolFromOtherString', '"abc",B,False')]
    [TestCase('boolFromMixedCaseString', '"tRUE",B,False')]
    [TestCase('boolFromNonZero', '42,B,True')]
    [TestCase('boolFromZero', '0,B,False')]
    [TestCase('boolFromFloat', '0.5,B,True')]
    [TestCase('boolFromZeroFloat', '0.0,B,False')]
    // a null reads as the default
    [TestCase('nullString', '~,S,""')]
    [TestCase('nullInt', '~,I,0')]
    [TestCase('nullULong', '~,U,0')]
    [TestCase('nullFloat', '~,F,0')]
    [TestCase('nullCurrency', '~,C,0')]
    [TestCase('nullDate', '~,DUtc,0')]
    [TestCase('nullBool', '~,B,False')]
    // what cannot convert still raises
    [TestCase('intFromText', '"abc",I,EConvertError')]
    [TestCase('floatFromText', '"abc",F,EConvertError')]
    [TestCase('ulongFromNegative', '-1,U,EConvertError')]
    procedure Getter_ConvertsScalar(const yamlValue : string; const getter : string; const expected : string);

    [Test]
    [TestCase('timestamp', '2026-10-22T10:20:30Z,2026-10-22 10:20:30')]
    [TestCase('string', '"2026-10-22T10:20:30Z",2026-10-22 10:20:30')]
    procedure DUtc_ReadsTimestampOrISO8601String(const yamlValue : string; const expected : string);

    [Test]
    procedure SequenceGetters_ConvertTheSameWay;
  end;

implementation

uses
  System.SysUtils,
  VSoft.YAML.Classes;

function TMappingPropertyTests.GetterText(const mapping : IYAMLMapping; const getter : string; const key : string) : string;
begin
  try
    if getter = 'S' then
      result := '"' + mapping.S[key] + '"'
    else if getter = 'I' then
      result := IntToStr(mapping.I[key])
    else if getter = 'L' then
      result := IntToStr(mapping.L[key])
    else if getter = 'U' then
      result := UIntToStr(mapping.U[key])
    else if getter = 'F' then
      result := FloatToStr(mapping.F[key], YAMLFormatSettings)
    else if getter = 'C' then
      result := CurrToStr(mapping.C[key], YAMLFormatSettings)
    else if getter = 'D' then
      result := FloatToStr(mapping.D[key], YAMLFormatSettings)
    else if getter = 'DUtc' then
      result := FloatToStr(mapping.DUtc[key], YAMLFormatSettings)
    else if getter = 'B' then
      result := BoolToStr(mapping.B[key], true)
    else
      result := 'unknown getter ' + getter;
  except
    on e : Exception do
      result := e.ClassName;
  end;
end;

procedure TMappingPropertyTests.MissingKey_ReadsDefault_AddsNothing(const getter : string; const expected : string);
var
  doc : IYAMLDocument;
begin
  doc := TYAML.CreateMapping;
  Assert.AreEqual(expected, GetterText(doc.AsMapping, getter, 'missing'));
  Assert.AreEqual(0, doc.AsMapping.Count, 'reading a missing key must not add it');
end;

procedure TMappingPropertyTests.MissingKey_AAndO_StillCreate;
var
  doc : IYAMLDocument;
begin
  // builder code relies on A[] and O[] creating what they are asked for
  doc := TYAML.CreateMapping;
  doc.AsMapping.O['parent'].S['child'] := 'x';
  doc.AsMapping.A['list'].AddValue(1);
  Assert.AreEqual(2, doc.AsMapping.Count);
  Assert.AreEqual('x', doc.AsMapping.O['parent'].S['child']);
  Assert.AreEqual(1, doc.AsMapping.A['list'].Count);
end;

procedure TMappingPropertyTests.Getter_ConvertsScalar(const yamlValue : string; const getter : string; const expected : string);
var
  doc : IYAMLDocument;
begin
  doc := TYAML.LoadFromString('v: ' + yamlValue);
  Assert.AreEqual(expected, GetterText(doc.AsMapping, getter, 'v'));
end;

procedure TMappingPropertyTests.DUtc_ReadsTimestampOrISO8601String(const yamlValue : string; const expected : string);
var
  doc : IYAMLDocument;
begin
  doc := TYAML.LoadFromString('v: ' + yamlValue);
  Assert.AreEqual(expected, FormatDateTime('yyyy-mm-dd hh:nn:ss', doc.AsMapping.DUtc['v'], YAMLFormatSettings));
end;

procedure TMappingPropertyTests.SequenceGetters_ConvertTheSameWay;
var
  doc : IYAMLDocument;
  sequence : IYAMLSequence;
begin
  doc := TYAML.LoadFromString('["42", true, ~, 3.9, "yes"]');
  sequence := doc.AsSequence;
  Assert.AreEqual(42, sequence.I[0], 'I from a string');
  Assert.AreEqual('42', CurrToStr(sequence.C[0], YAMLFormatSettings), 'C from a string');
  Assert.AreEqual('1', FloatToStr(sequence.F[1], YAMLFormatSettings), 'F from a boolean');
  Assert.AreEqual(0, sequence.I[2], 'I from a null');
  Assert.IsFalse(sequence.B[2], 'B from a null');
  Assert.AreEqual('', sequence.S[2], 'S from a null');
  Assert.AreEqual(3, sequence.I[3], 'I from a float');
  Assert.AreEqual('3', UIntToStr(sequence.U[3]), 'U from a float');
  Assert.IsTrue(sequence.B[4], 'B from "yes"');
end;

initialization
  TDUnitX.RegisterTestFixture(TMappingPropertyTests);

end.

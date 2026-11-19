unit VSoft.YAML.Tests.JSON5;

interface

uses
  DUnitX.TestFramework,
  VSoft.YAML;

type
  [TestFixture]
  TJSON5ParserTests = class
  private
    function Parse(const text : string) : IYAMLDocument;
    procedure CheckRejects(const text : string);
  public
    [Test]
    [TestCase('unquotedKey', '{a:1}', '|')]
    [TestCase('identifierKeys', '{$a:1,_b:2,c3:3,$:4,_:5}', '|')]
    [TestCase('reservedWordKeys', '{null:1,true:2,false:3,Infinity:4,NaN:5,if:6}', '|')]
    [TestCase('singleQuotedKey', '{''a b'':1}', '|')]
    [TestCase('trailingCommaObject', '{"a":1,}', '|')]
    [TestCase('trailingCommaArray', '[1,2,]', '|')]
    [TestCase('trailingCommaNested', '{a:[1,],b:{c:2,},}', '|')]
    [TestCase('emptyArray', '[]', '|')]
    [TestCase('emptyObject', '{}', '|')]
    [TestCase('singleQuoted', '''single''', '|')]
    [TestCase('hex', '0x1F', '|')]
    [TestCase('hexUpper', '0XAbC', '|')]
    [TestCase('negativeHex', '-0x1F', '|')]
    [TestCase('plus', '+1', '|')]
    [TestCase('leadingPoint', '.5', '|')]
    [TestCase('trailingPoint', '5.', '|')]
    [TestCase('signedPointExponent', '+.5e3', '|')]
    [TestCase('trailingPointExponent', '0.e1', '|')]
    [TestCase('infinity', 'Infinity', '|')]
    [TestCase('negativeInfinity', '-Infinity', '|')]
    [TestCase('positiveInfinity', '+Infinity', '|')]
    [TestCase('nan', 'NaN', '|')]
    [TestCase('negativeNaN', '-NaN', '|')]
    [TestCase('blockComment', '/* c */ 1', '|')]
    [TestCase('commentInObject', '{a:/*x*/1/*y*/,/*z*/}', '|')]
    [TestCase('jsonStillValid', '{"a":[1,2.5,-3e2,true,false,null,"s"]}', '|')]
    procedure Accepts(const text : string);

    [Test]
    [TestCase('emptyArrayComma', '[,]', '|')]
    [TestCase('emptyObjectComma', '{,}', '|')]
    [TestCase('doubleComma', '[1,,2]', '|')]
    [TestCase('twoTrailingCommas', '[1,,]', '|')]
    [TestCase('twoTrailingCommasObject', '{a:1,,}', '|')]
    [TestCase('leadingZero', '01', '|')]
    [TestCase('doubleZero', '00', '|')]
    [TestCase('hexNoDigits', '0x', '|')]
    [TestCase('hexBadDigit', '0x1G', '|')]
    [TestCase('octalPrefix', '0o17', '|')]
    [TestCase('binaryPrefix', '0b101', '|')]
    [TestCase('underscore', '1_000', '|')]
    [TestCase('emptyExponent', '1e', '|')]
    [TestCase('signedEmptyExponent', '1e+', '|')]
    [TestCase('lonePoint', '.', '|')]
    [TestCase('pointExponent', '.e1', '|')]
    [TestCase('lonePlus', '+', '|')]
    [TestCase('loneMinus', '-', '|')]
    [TestCase('doubleSign', '+-1', '|')]
    [TestCase('spaceAfterSign', '- 1', '|')]
    [TestCase('lowerInfinity', 'infinity', '|')]
    [TestCase('lowerNaN', 'nan', '|')]
    [TestCase('infinityRunOn', 'Infinityx', '|')]
    [TestCase('numberRunOn', '1x', '|')]
    [TestCase('zeroDigitEscape', '"\01"', '|')]
    [TestCase('octalEscape', '"\1"', '|')]
    [TestCase('digitEscape', '"\8"', '|')]
    [TestCase('shortHexEscape', '"\x4"', '|')]
    [TestCase('shortUnicodeEscape', '"\u12"', '|')]
    [TestCase('mismatchedQuotes', '"abc''', '|')]
    [TestCase('numericKey', '{1:2}', '|')]
    [TestCase('signKey', '{-a:1}', '|')]
    [TestCase('spaceInKey', '{a b:1}', '|')]
    [TestCase('escapedDigitKey', '{\u0031a:1}', '|')]
    [TestCase('nonUnicodeKeyEscape', '{\x61:1}', '|')]
    [TestCase('literalRunOn', 'nullx', '|')]
    [TestCase('capitalTrue', 'True', '|')]
    [TestCase('undefined', 'undefined', '|')]
    [TestCase('unquotedValue', '{a:b}', '|')]
    [TestCase('unterminatedComment', '/* c', '|')]
    [TestCase('hashComment', '# c', '|')]
    [TestCase('loneSlash', '/ 1', '|')]
    [TestCase('unterminatedString', '"abc', '|')]
    [TestCase('twoValues', '1 2', '|')]
    [TestCase('missingBrace', '{a:1', '|')]
    [TestCase('missingBracket', '[1', '|')]
    [TestCase('missingValue', '{a:}', '|')]
    [TestCase('missingKey', '{:1}', '|')]
    procedure Rejects(const text : string);

    [Test]
    procedure Rejects_EmptyInput;

    [Test]
    procedure Rejects_RawLineBreakInString;

    [Test]
    [TestCase('hex', '0x1F|31', '|')]
    [TestCase('hexMixedCase', '0X1f|31', '|')]
    [TestCase('negativeHex', '-0x1F|-31', '|')]
    [TestCase('positiveHex', '+0x10|16', '|')]
    [TestCase('plus', '+1|1', '|')]
    [TestCase('negativeZero', '-0|0', '|')]
    [TestCase('decimal', '123|123', '|')]
    procedure Number_Integer(const text : string; const expected : string);

    [Test]
    [TestCase('leadingPoint', '.5|0.5', '|')]
    [TestCase('trailingPoint', '5.|5', '|')]
    [TestCase('signedPointExponent', '+.5e1|5', '|')]
    [TestCase('exponent', '1e3|1000', '|')]
    [TestCase('negative', '-1.5|-1.5', '|')]
    procedure Number_Float(const text : string; const expected : string);

    [Test]
    procedure Number_NonFinite;

    [Test]
    procedure Number_TextIsKept;

    [Test]
    procedure Strings_Escapes;

    [Test]
    procedure Strings_SingleQuoted;

    [Test]
    procedure Strings_LineContinuation;

    [Test]
    procedure Strings_RawCharacters;

    [Test]
    procedure Keys_Identifiers;

    [Test]
    procedure Whitespace_JSON5;

    [Test]
    procedure DuplicateKey;

    [Test]
    procedure Comments_LeadingOnMember;

    [Test]
    procedure Comments_SameLineAfterComma;

    [Test]
    procedure Comments_SameLineBeforeComma;

    [Test]
    procedure Comments_SameLineOnCollection;

    [Test]
    procedure Comments_EndOfCollection;

    [Test]
    procedure Comments_EmptyCollection;

    [Test]
    procedure Comments_RootAndDocument;

    [Test]
    procedure Comments_RootSameLine;

    [Test]
    procedure Comments_BlockCommentLines;

    [Test]
    procedure Comments_BetweenKeyAndValue;

    [Test]
    procedure Error_LineAndColumn;

    [Test]
    procedure NestingLimit;

    [Test]
    procedure Options_InputFormat;

    [Test]
    procedure LoadAll_OneDocument;

    [Test]
    procedure LoadFromFile_JSON5Extension;

    [Test]
    procedure LoadFromFile_JSONFileWithJSON5Options;

    [Test]
    procedure Stream_SmallBlocks_SameAsString;
  end;

implementation

uses
  System.SysUtils,
  System.Classes,
  System.Math,
  System.IOUtils,
  VSoft.YAML.Classes,
  VSoft.YAML.IO;

function JSON5Options : IYAMLParserOptions;
begin
  result := TYAML.CreateParserOptions;
  result.InputFormat := TYAMLInputFormat.yifJSON5;
end;

{ TJSON5ParserTests }

function TJSON5ParserTests.Parse(const text : string) : IYAMLDocument;
begin
  result := TYAML.LoadFromString(text, JSON5Options);
end;

procedure TJSON5ParserTests.CheckRejects(const text : string);
begin
  Assert.WillRaise(
    procedure
    begin
      Parse(text);
    end,
    EYAMLParseException);
end;

procedure TJSON5ParserTests.Accepts(const text : string);
var
  doc : IYAMLDocument;
begin
  doc := Parse(text);
  Assert.IsNotNull(doc);
  Assert.IsNotNull(doc.Root);
end;

procedure TJSON5ParserTests.Rejects(const text : string);
begin
  CheckRejects(text);
end;

procedure TJSON5ParserTests.Rejects_EmptyInput;
begin
  CheckRejects('');
  CheckRejects('  // only a comment' + sLineBreak);
end;

procedure TJSON5ParserTests.Rejects_RawLineBreakInString;
begin
  CheckRejects('"a' + #10 + 'b"');
  CheckRejects('''a' + #13 + 'b''');
end;

procedure TJSON5ParserTests.Number_Integer(const text : string; const expected : string);
var
  value : IYAMLValue;
begin
  value := Parse(text).Root;
  Assert.IsTrue(value.IsInteger, 'type');
  Assert.AreEqual(text, value.RawValue, 'text');
  Assert.AreEqual(expected, IntToStr(value.AsInteger));
end;

procedure TJSON5ParserTests.Number_Float(const text : string; const expected : string);
var
  value : IYAMLValue;
begin
  value := Parse(text).Root;
  Assert.IsTrue(value.IsFloat, 'type');
  Assert.AreEqual(text, value.RawValue, 'text');
  Assert.AreEqual(expected, FloatToStr(value.AsFloat, YAMLFormatSettings));
end;

procedure TJSON5ParserTests.Number_NonFinite;
var
  seq : IYAMLSequence;
begin
  seq := Parse('[Infinity, +Infinity, -Infinity, NaN, -NaN, +NaN]').AsSequence;
  Assert.IsTrue(IsInfinite(seq[0].AsFloat) and (seq[0].AsFloat > 0), 'Infinity');
  Assert.IsTrue(IsInfinite(seq[1].AsFloat) and (seq[1].AsFloat > 0), '+Infinity');
  Assert.IsTrue(IsInfinite(seq[2].AsFloat) and (seq[2].AsFloat < 0), '-Infinity');
  Assert.IsTrue(IsNan(seq[3].AsFloat), 'NaN');
  Assert.IsTrue(IsNan(seq[4].AsFloat), '-NaN');
  Assert.IsTrue(IsNan(seq[5].AsFloat), '+NaN');
  Assert.IsTrue(seq[0].IsFloat);
end;

procedure TJSON5ParserTests.Number_TextIsKept;
var
  seq : IYAMLSequence;
begin
  seq := Parse('[0XaB, +.5e-3, 5., -0x0]').AsSequence;
  Assert.AreEqual('0XaB', seq[0].RawValue);
  Assert.AreEqual<Int64>(171, seq[0].AsInteger);
  Assert.AreEqual('+.5e-3', seq[1].RawValue);
  Assert.AreEqual('5.', seq[2].RawValue);
  Assert.AreEqual('-0x0', seq[3].RawValue);
  Assert.AreEqual<Int64>(0, seq[3].AsInteger);
end;

procedure TJSON5ParserTests.Strings_Escapes;
begin
  // \x \u \v \0 \' \" \\ \/ and identity escapes (\a is a, \q is q)
  Assert.AreEqual('aAB' + #11 + #0 + '''"\/aq', Parse('"a\x41\u0042\v\0\''\"\\\/\a\q"').Root.AsString);
  Assert.AreEqual(#8#12#10#13#9, Parse('"\b\f\n\r\t"').Root.AsString);
end;

procedure TJSON5ParserTests.Strings_SingleQuoted;
begin
  Assert.AreEqual('say "hi"', Parse('''say "hi"''').Root.AsString);
  Assert.AreEqual('it''s', Parse('''it\''s''').Root.AsString);
  Assert.AreEqual('', Parse('''''').Root.AsString);
end;

procedure TJSON5ParserTests.Strings_LineContinuation;
begin
  // the backslash and line break go; the next line's leading whitespace stays
  Assert.AreEqual('ab   cd', Parse('"ab\' + #10 + '   cd"').Root.AsString);
  Assert.AreEqual('abcd', Parse('"ab\' + #13#10 + 'cd"').Root.AsString);
  Assert.AreEqual('abcd', Parse('"ab\' + #13 + 'cd"').Root.AsString);
  Assert.AreEqual('abcd', Parse('''ab\' + #$2028 + 'cd''').Root.AsString);
  Assert.AreEqual('abcd', Parse('"ab\' + #$2029 + 'cd"').Root.AsString);
end;

procedure TJSON5ParserTests.Strings_RawCharacters;
begin
  // only CR and LF must be escaped
  Assert.AreEqual('a' + #9 + 'b', Parse('"a' + #9 + 'b"').Root.AsString);
  Assert.AreEqual('a' + #1 + 'b', Parse('"a' + #1 + 'b"').Root.AsString);
  Assert.AreEqual('a' + #$2028 + 'b' + #$2029, Parse('"a' + #$2028 + 'b' + #$2029 + '"').Root.AsString);
end;

procedure TJSON5ParserTests.Keys_Identifiers;
var
  mapping : IYAMLMapping;
begin
  // U+00FC is a lowercase letter, U+1D49C (as a surrogate pair) an uppercase one, U+0301 a
  // combining mark (allowed after the first character) and \u0061 is a
  mapping := Parse('{$id:1, _x:2, ' + #$00FC + 'ber:3, \u0061b:4, ' + #$D835#$DC9C + 'x:5, e' + #$0301 + ':6, a\u0063:7}').AsMapping;
  Assert.AreEqual(7, mapping.Count);
  Assert.AreEqual('$id', mapping.Keys[0]);
  Assert.AreEqual('_x', mapping.Keys[1]);
  Assert.AreEqual(#$00FC + 'ber', mapping.Keys[2]);
  Assert.AreEqual('ab', mapping.Keys[3]);
  Assert.AreEqual(#$D835#$DC9C + 'x', mapping.Keys[4]);
  Assert.AreEqual('e' + #$0301, mapping.Keys[5]);
  Assert.AreEqual('ac', mapping.Keys[6]);
  // a combining mark cannot start a name
  CheckRejects('{' + #$0301 + 'a:1}');
end;

procedure TJSON5ParserTests.Whitespace_JSON5;
var
  seq : IYAMLSequence;
begin
  seq := Parse(#$FEFF + '[' + #11 + '1,' + #12 + '2,' + #$00A0 + '3' + #$2028 + ',' + #$3000 + '4' + #$FEFF + ',' + #$2029 + '5' + #$1680 + ']').AsSequence;
  Assert.AreEqual(5, seq.Count);
  Assert.AreEqual<Int64>(5, seq[4].AsInteger);
end;

procedure TJSON5ParserTests.DuplicateKey;
var
  options : IYAMLParserOptions;
begin
  Assert.AreEqual<Int64>(2, Parse('{a:1, a:2}').AsMapping.Items['a'].AsInteger);
  options := JSON5Options;
  options.DuplicateKeyBehavior := TYAMLDuplicateKeyBehavior.dkError;
  Assert.WillRaise(
    procedure
    begin
      TYAML.LoadFromString('{a:1, ''a'':2}', options);
    end,
    EYAMLParseException);
end;

procedure TJSON5ParserTests.Comments_LeadingOnMember;
var
  mapping : IYAMLMapping;
begin
  mapping := Parse('{' + sLineBreak +
                   '  // first' + sLineBreak +
                   '  /* second */' + sLineBreak +
                   '  a: 1,' + sLineBreak +
                   '  b: 2' + sLineBreak +
                   '}').AsMapping;
  Assert.IsTrue(mapping.Items['a'].HasComments);
  Assert.AreEqual(2, Integer(Length(mapping.Items['a'].Comments)));
  Assert.AreEqual('first', mapping.Items['a'].Comments[0]);
  Assert.AreEqual('second', mapping.Items['a'].Comments[1]);
  Assert.IsFalse(mapping.Items['b'].HasComments);
  Assert.IsFalse(mapping.HasComments);
  Assert.IsFalse(mapping.HasEndComments);
end;

procedure TJSON5ParserTests.Comments_SameLineAfterComma;
var
  mapping : IYAMLMapping;
begin
  mapping := Parse('{a: 1, // about a' + sLineBreak +
                   ' b: 2 // about b' + sLineBreak +
                   '}').AsMapping;
  Assert.AreEqual('about a', mapping.Items['a'].Comment);
  Assert.AreEqual('about b', mapping.Items['b'].Comment);
  Assert.IsFalse(mapping.Items['b'].HasComments);
  Assert.IsFalse(mapping.HasEndComments);
end;

procedure TJSON5ParserTests.Comments_SameLineBeforeComma;
var
  seq : IYAMLSequence;
begin
  seq := Parse('[1 /* one */, 2 /* two */ /* more */]').AsSequence;
  Assert.AreEqual('one', seq[0].Comment);
  Assert.AreEqual('two more', seq[1].Comment);
end;

procedure TJSON5ParserTests.Comments_SameLineOnCollection;
var
  mapping : IYAMLMapping;
begin
  mapping := Parse('{a: [1, 2], // the list' + sLineBreak +
                   'b: {' + sLineBreak +
                   '  c: 3' + sLineBreak +
                   '} // the map' + sLineBreak +
                   '}').AsMapping;
  Assert.AreEqual('the list', mapping.Items['a'].Comment);
  Assert.AreEqual('the map', mapping.Items['b'].Comment);
  Assert.AreEqual('', mapping.Items['b'].AsMapping.Items['c'].Comment);
end;

procedure TJSON5ParserTests.Comments_EndOfCollection;
var
  seq : IYAMLSequence;
begin
  seq := Parse('[' + sLineBreak +
               '  1,' + sLineBreak +
               '  // end one' + sLineBreak +
               '  // end two' + sLineBreak +
               ']').AsSequence;
  Assert.AreEqual(1, seq.Count);
  Assert.IsTrue(seq.HasEndComments);
  Assert.AreEqual(2, Integer(Length(seq.EndComments)));
  Assert.AreEqual('end one', seq.EndComments[0]);
  Assert.AreEqual('end two', seq.EndComments[1]);
end;

procedure TJSON5ParserTests.Comments_EmptyCollection;
var
  mapping : IYAMLMapping;
begin
  mapping := Parse('{ /* nothing */ }').AsMapping;
  Assert.AreEqual(0, mapping.Count);
  Assert.AreEqual(1, Integer(Length(mapping.EndComments)));
  Assert.AreEqual('nothing', mapping.EndComments[0]);
end;

procedure TJSON5ParserTests.Comments_RootAndDocument;
var
  doc : IYAMLDocument;
begin
  doc := Parse('// head' + sLineBreak +
               '{}' + sLineBreak +
               '// tail one' + sLineBreak +
               '/* tail two */');
  Assert.AreEqual(1, Integer(Length(doc.Root.Comments)));
  Assert.AreEqual('head', doc.Root.Comments[0]);
  Assert.IsTrue(doc.HasEndComments);
  Assert.AreEqual(2, Integer(Length(doc.EndComments)));
  Assert.AreEqual('tail one', doc.EndComments[0]);
  Assert.AreEqual('tail two', doc.EndComments[1]);
end;

procedure TJSON5ParserTests.Comments_RootSameLine;
var
  doc : IYAMLDocument;
begin
  doc := Parse('42 // the answer');
  Assert.AreEqual('the answer', doc.Root.Comment);
  Assert.IsFalse(doc.HasEndComments);
end;

procedure TJSON5ParserTests.Comments_BlockCommentLines;
var
  value : IYAMLValue;
begin
  value := Parse('/*' + sLineBreak +
                 ' * one' + sLineBreak +
                 sLineBreak +
                 ' * two' + sLineBreak +
                 ' */' + sLineBreak +
                 '1').Root;
  Assert.AreEqual(3, Integer(Length(value.Comments)));
  Assert.AreEqual('* one', value.Comments[0]);
  Assert.AreEqual('', value.Comments[1]);
  Assert.AreEqual('* two', value.Comments[2]);
end;

procedure TJSON5ParserTests.Comments_BetweenKeyAndValue;
var
  value : IYAMLValue;
begin
  value := Parse('{a /* k */ : /* v */ 1}').AsMapping.Items['a'];
  Assert.AreEqual(2, Integer(Length(value.Comments)));
  Assert.AreEqual('k', value.Comments[0]);
  Assert.AreEqual('v', value.Comments[1]);
end;

procedure TJSON5ParserTests.Error_LineAndColumn;
var
  raised : boolean;
begin
  raised := false;
  try
    Parse('{' + sLineBreak + '  a: 1, // c' + sLineBreak + '  b: @' + sLineBreak + '}');
  except
    on E : EYAMLParseException do
    begin
      raised := true;
      Assert.AreEqual(3, E.Line, 'line');
      Assert.AreEqual(6, E.Column, 'column');
    end;
  end;
  Assert.IsTrue(raised, 'no error raised');
end;

procedure TJSON5ParserTests.NestingLimit;
begin
  Assert.IsNotNull(Parse(StringOfChar('[', 1000) + StringOfChar(']', 1000)));
  CheckRejects(StringOfChar('[', 1001) + StringOfChar(']', 1001));
end;

procedure TJSON5ParserTests.Options_InputFormat;
var
  options : IYAMLParserOptions;
begin
  options := TYAML.CreateParserOptions;
  Assert.IsTrue(options.InputFormat = TYAMLInputFormat.yifYAML, 'default');
  options.InputFormat := TYAMLInputFormat.yifJSON5;
  Assert.IsFalse(options.JSONMode, 'JSON5 is not JSONMode');
  Assert.IsTrue(options.Clone.InputFormat = TYAMLInputFormat.yifJSON5, 'clone');
  options.JSONMode := true;
  Assert.IsTrue(options.InputFormat = TYAMLInputFormat.yifJSON, 'JSONMode true');
  options.JSONMode := false;
  Assert.IsTrue(options.InputFormat = TYAMLInputFormat.yifYAML, 'JSONMode false');
end;

procedure TJSON5ParserTests.LoadAll_OneDocument;
var
  docs : TArray<IYAMLDocument>;
begin
  docs := TYAML.LoadAllFromString('{a:1} // c', JSON5Options);
  Assert.AreEqual(1, integer(Length(docs)));
  Assert.AreEqual<Int64>(1, docs[0].AsMapping.Items['a'].AsInteger);
end;

procedure TJSON5ParserTests.LoadFromFile_JSON5Extension;
var
  fileName : string;
  doc : IYAMLDocument;
begin
  fileName := TPath.Combine(TPath.GetTempPath, 'vsoft_yaml_test_' + IntToStr(Random(MaxInt)) + '.json5');
  TFile.WriteAllText(fileName, '// settings' + sLineBreak + '{name: ''x'', list: [1, 2,],}', TEncoding.UTF8);
  try
    doc := TYAML.LoadFromFile(fileName);
    Assert.AreEqual('x', doc.AsMapping.Items['name'].AsString);
    Assert.AreEqual('settings', doc.Root.Comments[0]);
    // the shared defaults were not changed
    Assert.IsTrue(TYAML.DefaultParserOptions.InputFormat = TYAMLInputFormat.yifYAML);
  finally
    TFile.Delete(fileName);
  end;
end;

procedure TJSON5ParserTests.LoadFromFile_JSONFileWithJSON5Options;
var
  fileName : string;
  doc : IYAMLDocument;
begin
  // e.g. a settings.json with comments: JSON5 options are kept for a .json file
  fileName := TPath.Combine(TPath.GetTempPath, 'vsoft_yaml_test_' + IntToStr(Random(MaxInt)) + '.json');
  TFile.WriteAllText(fileName, '{' + sLineBreak + '  // comment' + sLineBreak + '  "a": 1,' + sLineBreak + '}', TEncoding.UTF8);
  try
    doc := TYAML.LoadFromFile(fileName, JSON5Options);
    Assert.AreEqual<Int64>(1, doc.AsMapping.Items['a'].AsInteger);
    // without them it is read as strict JSON, which has no comments or trailing commas
    Assert.WillRaise(
      procedure
      begin
        doc := TYAML.LoadFromFile(fileName, nil);
      end,
      EYAMLParseException);
  finally
    TFile.Delete(fileName);
  end;
end;

procedure TJSON5ParserTests.Stream_SmallBlocks_SameAsString;
var
  sb : TStringBuilder;
  i : integer;
  text : string;
  expected, actual : string;
  stream : TStringStream;
  oldBlockSize : integer;
begin
  sb := TStringBuilder.Create;
  try
    sb.Append('// a list' + sLineBreak + '{items: [' + sLineBreak);
    for i := 1 to 200 do
    begin
      sb.Append('  // item ').Append(i).Append(sLineBreak);
      sb.Append('  {id: 0x').Append(IntToHex(i * 4099, 6)).Append(', name: ''item number ').Append(i)
        .Append(' \''quoted\'' \x41\u00e9 \' + sLineBreak + '   continued'', ok: true, none: null, f: -.5e-3, inf: -Infinity,')
        .Append(' $key_').Append(i).Append(': [1, 2.25, "x",], /* block */ \u0061bc: +7}, /* same line */').Append(sLineBreak);
    end;
    sb.Append('  // end of items' + sLineBreak + ']}' + sLineBreak + '// tail');
    text := sb.ToString;
  finally
    sb.Free;
  end;

  expected := TYAML.WriteToJSON5String(Parse(text));

  oldBlockSize := TStreamTextSource.BlockSize;
  try
    TStreamTextSource.BlockSize := 8;
    stream := TStringStream.Create(text, TEncoding.UTF8);
    try
      actual := TYAML.WriteToJSON5String(TYAML.LoadFromStream(stream, JSON5Options));
    finally
      stream.Free;
    end;
  finally
    TStreamTextSource.BlockSize := oldBlockSize;
  end;
  Assert.AreEqual(expected, actual);
end;

initialization
  TDUnitX.RegisterTestFixture(TJSON5ParserTests);

end.

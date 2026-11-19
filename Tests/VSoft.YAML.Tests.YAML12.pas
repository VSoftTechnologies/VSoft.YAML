unit VSoft.YAML.Tests.YAML12;

// The YAML 1.2 parser (VSoft.YAML.Scanner and VSoft.YAML.Composer): the YAML11Compatibility
// option, which keeps the YAML 1.1 forms VSoft.YAML has always read, and YAML 1.2 behaviour
// the other fixtures do not cover. The yaml-test-suite fixture covers the grammar itself.

interface

uses
  DUnitX.TestFramework,
  VSoft.YAML;

type
  [TestFixture]
  TYAML12ParserTests = class
  private
    function StrictOptions : IYAMLParserOptions;
  public
    // the option
    [Test]
    procedure Option_DefaultsToCompatible;
    [Test]
    procedure Option_IsCloned;

    // plain scalars
    [Test]
    [TestCase('yes', 'yes')]
    [TestCase('No', 'No')]
    [TestCase('ON', 'ON')]
    [TestCase('off', 'off')]
    procedure YesNoOnOff_AreBooleansOnlyWhenCompatible(const text : string);
    [Test]
    procedure Binary_IsIntegerOnlyWhenCompatible;
    [Test]
    procedure Timestamp_IsTimestampOnlyWhenCompatible;
    [Test]
    procedure DigitSeparators_AreDroppedOnlyWhenCompatible;
    [Test]
    procedure CoreSchema_IsTheSameInBothModes;

    // merge keys and sets
    [Test]
    procedure MergeKey_MergesOnlyWhenCompatible;
    [Test]
    procedure MergeKey_SequenceOfMappings;
    [Test]
    procedure ExplicitKeysWithoutValues_AreASetOnlyWhenCompatible;
    [Test]
    procedure SetTag_MakesASetInBothModes;

    // directives and tags
    [Test]
    procedure DirectiveAfterOpenDocument_NeedsDocumentEnd;
    [Test]
    procedure UndeclaredTagHandle_Raises;
    [Test]
    procedure TagDirective_HandleAndPrefix;
    [Test]
    procedure TagDirective_SecondaryHandleRedefined;

    // documents
    [Test]
    procedure LoadAll_EmptyStream_HasNoDocuments;
    [Test]
    procedure LoadFromString_EmptyStream_IsNull;

    // syntax
    [Test]
    procedure ComplexKey_IsItsFlowText;
    [Test]
    procedure FlowMapping_KeySpanningLines;
    [Test]
    procedure BlockScalar_EndOfInputEndsTheLastLine;
    [Test]
    procedure PlainScalar_ContinuationLines;
    [Test]
    procedure QuotedScalar_UnderIndentedLine_Raises;
    [Test]
    procedure ImplicitKeyAfterValue_Raises;
    [Test]
    procedure Anchors_OnKeysAndValues;

    // comments
    [Test]
    procedure Comments_AfterTheRoot_AreDocumentEndComments;
    [Test]
    procedure Comments_OnTheirOwnLine_AreNotSameLineComments;
  end;

implementation

uses
  System.SysUtils;

function TYAML12ParserTests.StrictOptions : IYAMLParserOptions;
begin
  result := TYAML.CreateParserOptions;
  result.YAML11Compatibility := false;
end;

procedure TYAML12ParserTests.Option_DefaultsToCompatible;
begin
  Assert.IsTrue(TYAML.CreateParserOptions.YAML11Compatibility);
  Assert.IsTrue(TYAML.DefaultParserOptions.YAML11Compatibility);
end;

procedure TYAML12ParserTests.Option_IsCloned;
var
  options : IYAMLParserOptions;
begin
  options := StrictOptions;
  Assert.IsFalse(options.Clone.YAML11Compatibility);
end;

procedure TYAML12ParserTests.YesNoOnOff_AreBooleansOnlyWhenCompatible(const text : string);
var
  doc : IYAMLDocument;
begin
  doc := TYAML.LoadFromString('a: ' + text);
  Assert.IsTrue(doc.AsMapping.Items['a'].IsBoolean, 'compatible');
  doc := TYAML.LoadFromString('a: ' + text, StrictOptions);
  Assert.IsTrue(doc.AsMapping.Items['a'].IsString, 'strict');
  Assert.AreEqual(text, doc.AsMapping.Items['a'].AsString);
end;

procedure TYAML12ParserTests.Binary_IsIntegerOnlyWhenCompatible;
var
  doc : IYAMLDocument;
begin
  doc := TYAML.LoadFromString('a: 0b1010');
  Assert.AreEqual<Int64>(10, doc.AsMapping.Items['a'].AsInteger);
  doc := TYAML.LoadFromString('a: 0b1010', StrictOptions);
  Assert.IsTrue(doc.AsMapping.Items['a'].IsString);
end;

procedure TYAML12ParserTests.Timestamp_IsTimestampOnlyWhenCompatible;
var
  doc : IYAMLDocument;
begin
  doc := TYAML.LoadFromString('a: 2001-12-14T21:59:43.10-05:00');
  Assert.IsTrue(doc.AsMapping.Items['a'].IsTimeStamp);
  doc := TYAML.LoadFromString('a: 2001-12-14T21:59:43.10-05:00', StrictOptions);
  Assert.IsTrue(doc.AsMapping.Items['a'].IsString);
  Assert.AreEqual('2001-12-14T21:59:43.10-05:00', doc.AsMapping.Items['a'].AsString);
end;

procedure TYAML12ParserTests.DigitSeparators_AreDroppedOnlyWhenCompatible;
var
  doc : IYAMLDocument;
begin
  doc := TYAML.LoadFromString('a: 1_000' + sLineBreak + 'b: -2_500.5' + sLineBreak + 'c: 001_0466.JPG');
  Assert.AreEqual<Int64>(1000, doc.AsMapping.Items['a'].AsInteger);
  Assert.IsTrue(doc.AsMapping.Items['b'].IsFloat);
  Assert.AreEqual('001_0466.JPG', doc.AsMapping.Items['c'].AsString);
  doc := TYAML.LoadFromString('a: 1_000', StrictOptions);
  Assert.IsTrue(doc.AsMapping.Items['a'].IsString);
  Assert.AreEqual('1_000', doc.AsMapping.Items['a'].AsString);
end;

procedure TYAML12ParserTests.CoreSchema_IsTheSameInBothModes;
var
  yamlText : string;
  i : integer;
  doc : IYAMLDocument;
  map : IYAMLMapping;
begin
  yamlText := 'n: ~' + sLineBreak + 'n2: Null' + sLineBreak + 'b: TRUE' + sLineBreak + 'i: -42' + sLineBreak +
              'o: 0o17' + sLineBreak + 'h: 0x1F' + sLineBreak + 'f: 1.5e3' + sLineBreak + 'inf: -.inf' + sLineBreak +
              'nan: .NaN' + sLineBreak + 's: nULL';
  for i := 0 to 1 do
  begin
    if i = 0 then
      doc := TYAML.LoadFromString(yamlText)
    else
      doc := TYAML.LoadFromString(yamlText, StrictOptions);
    map := doc.AsMapping;
    Assert.IsTrue(map.Items['n'].IsNull);
    Assert.IsTrue(map.Items['n2'].IsNull);
    Assert.IsTrue(map.Items['b'].AsBoolean);
    Assert.AreEqual<Int64>(-42, map.Items['i'].AsInteger);
    Assert.AreEqual<Int64>(15, map.Items['o'].AsInteger);
    Assert.AreEqual<Int64>(31, map.Items['h'].AsInteger);
    Assert.IsTrue(map.Items['f'].IsFloat);
    Assert.IsTrue(map.Items['inf'].IsFloat);
    Assert.IsTrue(map.Items['nan'].IsFloat);
    Assert.IsTrue(map.Items['s'].IsString);
  end;
end;

procedure TYAML12ParserTests.MergeKey_MergesOnlyWhenCompatible;
const
  cText = 'base: &b' + #10 + '  x: 1' + #10 + '  y: 2' + #10 +
          'item:' + #10 + '  <<: *b' + #10 + '  y: 3';
var
  doc : IYAMLDocument;
  item : IYAMLMapping;
begin
  doc := TYAML.LoadFromString(cText);
  item := doc.AsMapping.Items['item'].AsMapping;
  Assert.AreEqual(2, item.Count);
  Assert.AreEqual<Int64>(1, item.Items['x'].AsInteger);
  Assert.AreEqual<Int64>(3, item.Items['y'].AsInteger);
  Assert.IsFalse(item.ContainsKey('<<'));

  doc := TYAML.LoadFromString(cText, StrictOptions);
  item := doc.AsMapping.Items['item'].AsMapping;
  Assert.AreEqual(2, item.Count);
  Assert.IsTrue(item.Items['<<'].IsMapping);
end;

procedure TYAML12ParserTests.MergeKey_SequenceOfMappings;
var
  doc : IYAMLDocument;
  item : IYAMLMapping;
begin
  // the earlier mapping in the sequence wins, and the mapping's own keys win over both
  doc := TYAML.LoadFromString('a: &a {x: 1, y: 1}' + #10 + 'b: &b {y: 2, z: 2}' + #10 +
                              'item: {<<: [*a, *b], z: 3}');
  item := doc.AsMapping.Items['item'].AsMapping;
  Assert.AreEqual(3, item.Count);
  Assert.AreEqual<Int64>(1, item.Items['x'].AsInteger);
  Assert.AreEqual<Int64>(1, item.Items['y'].AsInteger);
  Assert.AreEqual<Int64>(3, item.Items['z'].AsInteger);
end;

procedure TYAML12ParserTests.ExplicitKeysWithoutValues_AreASetOnlyWhenCompatible;
const
  cText = '? apple' + #10 + '? banana' + #10 + '? apple';
var
  doc : IYAMLDocument;
begin
  doc := TYAML.LoadFromString(cText);
  Assert.IsTrue(doc.Root.IsSet);
  Assert.AreEqual(2, doc.AsSet.Count);
  Assert.AreEqual('banana', doc.AsSet[1].AsString);

  doc := TYAML.LoadFromString(cText, StrictOptions);
  Assert.IsTrue(doc.Root.IsMapping);
  Assert.AreEqual(2, doc.AsMapping.Count);
  Assert.IsTrue(doc.AsMapping.Items['apple'].IsNull);

  // a value makes it a mapping in either mode
  doc := TYAML.LoadFromString('? a' + #10 + ': 1' + #10 + '? b');
  Assert.IsTrue(doc.Root.IsMapping);
  Assert.AreEqual<Int64>(1, doc.AsMapping.Items['a'].AsInteger);
end;

procedure TYAML12ParserTests.SetTag_MakesASetInBothModes;
var
  doc : IYAMLDocument;
begin
  doc := TYAML.LoadFromString('--- !!set' + #10 + '? a' + #10 + '? b', StrictOptions);
  Assert.IsTrue(doc.Root.IsSet);
  Assert.AreEqual(2, doc.AsSet.Count);
  doc := TYAML.LoadFromString('s: !!set {a, b}');
  Assert.IsTrue(doc.AsMapping.Items['s'].IsSet);
end;

procedure TYAML12ParserTests.DirectiveAfterOpenDocument_NeedsDocumentEnd;
const
  // (after a top-level plain scalar, the '%' line would go on with the scalar instead)
  cText = 'a: 1' + #10 + '%YAML 1.2' + #10 + '--- b';
var
  docs : TArray<IYAMLDocument>;
begin
  // an error in either mode
  Assert.WillRaise(
    procedure
    begin
      TYAML.LoadAllFromString(cText);
    end, EYAMLParseException);
  Assert.WillRaise(
    procedure
    begin
      TYAML.LoadAllFromString(cText, StrictOptions);
    end, EYAMLParseException);
  // with '...' it is fine
  docs := TYAML.LoadAllFromString('a: 1' + #10 + '...' + #10 + '%YAML 1.2' + #10 + '--- b');
  Assert.AreEqual(2, Integer(Length(docs)));
end;

procedure TYAML12ParserTests.UndeclaredTagHandle_Raises;
begin
  // an error in either mode
  Assert.WillRaise(
    procedure
    begin
      TYAML.LoadFromString('a: !e!thing value');
    end, EYAMLParseException);
  Assert.WillRaise(
    procedure
    begin
      TYAML.LoadFromString('a: !e!thing value', StrictOptions);
    end, EYAMLParseException);
end;

procedure TYAML12ParserTests.TagDirective_HandleAndPrefix;
var
  doc : IYAMLDocument;
  value : IYAMLValue;
begin
  doc := TYAML.LoadFromString('%TAG !e! tag:example.com,2000:app/' + #10 + '---' + #10 + 'a: !e!foo bar', StrictOptions);
  Assert.AreEqual(3, Integer(doc.TagDirectives.Count));
  Assert.AreEqual('!e!', doc.TagDirectives[2].Handle);
  Assert.AreEqual('tag:example.com,2000:app/', doc.TagDirectives[2].Prefix);
  value := doc.AsMapping.Items['a'];
  Assert.AreEqual('!e!foo', value.Tag);
  Assert.AreEqual('tag:example.com,2000:app/foo', value.TagInfo.ResolvedTag);
end;

procedure TYAML12ParserTests.TagDirective_SecondaryHandleRedefined;
var
  doc : IYAMLDocument;
begin
  // !!int no longer means the core schema's int, so the text is not checked as one
  doc := TYAML.LoadFromString('%TAG !! tag:example.com,2000:app/' + #10 + '---' + #10 + '!!int 1 - 3', StrictOptions);
  Assert.AreEqual('1 - 3', doc.Root.AsString);
  Assert.AreEqual('tag:example.com,2000:app/int', doc.Root.TagInfo.ResolvedTag);
end;

procedure TYAML12ParserTests.LoadAll_EmptyStream_HasNoDocuments;
begin
  Assert.AreEqual(0, Integer(Length(TYAML.LoadAllFromString(''))));
  Assert.AreEqual(0, Integer(Length(TYAML.LoadAllFromString('# just a comment' + #10))));
  Assert.AreEqual(1, Integer(Length(TYAML.LoadAllFromString('---'))));
end;

procedure TYAML12ParserTests.LoadFromString_EmptyStream_IsNull;
begin
  Assert.IsTrue(TYAML.LoadFromString('').Root.IsNull);
  Assert.IsTrue(TYAML.LoadFromString('# just a comment').Root.IsNull);
end;

procedure TYAML12ParserTests.ComplexKey_IsItsFlowText;
var
  doc : IYAMLDocument;
begin
  doc := TYAML.LoadFromString('? [a, b]' + #10 + ': 1' + #10 + '? {c: d}' + #10 + ': 2');
  Assert.AreEqual<Int64>(1, doc.AsMapping.Items['[a, b]'].AsInteger);
  Assert.AreEqual<Int64>(2, doc.AsMapping.Items['{c: d}'].AsInteger);
end;

procedure TYAML12ParserTests.FlowMapping_KeySpanningLines;
var
  doc : IYAMLDocument;
begin
  doc := TYAML.LoadFromString('{ multi' + #10 + '  line: value,' + #10 + '"quoted"' + #10 + ': 2 }');
  Assert.AreEqual('value', doc.AsMapping.Items['multi line'].AsString);
  Assert.AreEqual<Int64>(2, doc.AsMapping.Items['quoted'].AsInteger);
  // but not in a flow sequence, where a key: value pair must be on one line
  Assert.WillRaise(
    procedure
    begin
      TYAML.LoadFromString('[ key' + #10 + '  : value ]');
    end, EYAMLParseException);
end;

procedure TYAML12ParserTests.BlockScalar_EndOfInputEndsTheLastLine;
begin
  Assert.AreEqual('a' + #10, TYAML.LoadFromString('k: |' + #10 + '  a').AsMapping.Items['k'].AsString);
  Assert.AreEqual('a', TYAML.LoadFromString('k: |-' + #10 + '  a').AsMapping.Items['k'].AsString);
  Assert.AreEqual('a' + #10 + #10, TYAML.LoadFromString('k: |+' + #10 + '  a' + #10 + '  ').AsMapping.Items['k'].AsString);
end;

procedure TYAML12ParserTests.PlainScalar_ContinuationLines;
var
  doc : IYAMLDocument;
begin
  doc := TYAML.LoadFromString('a: one' + #10 + '  two' + #10 + #10 + '  three' + #10 + 'b: 2');
  Assert.AreEqual('one two' + #10 + 'three', doc.AsMapping.Items['a'].AsString);
  Assert.AreEqual<Int64>(2, doc.AsMapping.Items['b'].AsInteger);
end;

procedure TYAML12ParserTests.QuotedScalar_UnderIndentedLine_Raises;
begin
  // each line of a quoted scalar in a mapping must be indented more than the mapping
  Assert.WillRaise(
    procedure
    begin
      TYAML.LoadFromString('a: "one' + #10 + 'two"');
    end, EYAMLParseException);
  Assert.AreEqual('one two', TYAML.LoadFromString('a: "one' + #10 + ' two"').AsMapping.Items['a'].AsString);
end;

procedure TYAML12ParserTests.ImplicitKeyAfterValue_Raises;
begin
  Assert.WillRaise(
    procedure
    begin
      TYAML.LoadFromString('a: b: c');
    end, EYAMLParseException);
  // after '- ' a compact mapping is fine
  Assert.AreEqual('c', TYAML.LoadFromString('- b: c').AsSequence[0].AsMapping.Items['b'].AsString);
end;

procedure TYAML12ParserTests.Anchors_OnKeysAndValues;
var
  doc : IYAMLDocument;
begin
  doc := TYAML.LoadFromString('&k key: &v value' + #10 + 'copy: *v' + #10 + '*k : aliased');
  Assert.AreEqual('value', doc.AsMapping.Items['copy'].AsString);
  // the alias of the key 'key' is a key too - the later value replaces the first
  Assert.AreEqual('aliased', doc.AsMapping.Items['key'].AsString);
end;

procedure TYAML12ParserTests.Comments_AfterTheRoot_AreDocumentEndComments;
var
  doc : IYAMLDocument;
begin
  doc := TYAML.LoadFromString('a: 1 # one' + #10 + 'b: 2' + #10 + '# the end');
  Assert.AreEqual('one', doc.AsMapping.Items['a'].Comment);
  Assert.IsTrue(doc.HasEndComments);
  Assert.AreEqual('the end', doc.EndComments[0]);
end;

procedure TYAML12ParserTests.Comments_OnTheirOwnLine_AreNotSameLineComments;
var
  doc : IYAMLDocument;
begin
  doc := TYAML.LoadFromString('a: 1' + #10 + #10 + '# about b' + #10 + 'b:' + #10 + '  c: 2');
  Assert.AreEqual('', doc.AsMapping.Items['a'].Comment);
  Assert.AreEqual('about b', doc.AsMapping.Items['b'].AsMapping.Comments[0]);
end;

initialization
  TDUnitX.RegisterTestFixture(TYAML12ParserTests);

end.

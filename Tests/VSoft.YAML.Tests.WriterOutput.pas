unit VSoft.YAML.Tests.WriterOutput;

// YAML writer output that must read back as the same tree: tags in every place a node can be
// (sequence items, the root, flow collections, sets), the indentation of what a key holds in
// a mapping that is a sequence item, sets and nulls in flow output, and MaxLineLength
// folding.

interface

uses
  DUnitX.TestFramework,
  VSoft.YAML;

type
  [TestFixture]
  TYAMLWriterOutputTests = class
  public
    // tags
    [Test]
    procedure Tags_SequenceItems;
    [Test]
    procedure Tags_RootCollection;
    [Test]
    procedure Tags_RootSequenceAndScalar;
    [Test]
    procedure Tags_RootFlowAndEmpty;
    [Test]
    procedure Tags_BlockMappingCollections;
    [Test]
    procedure Tags_FlowOutput;
    [Test]
    procedure Tags_MappingInSequence;
    [Test]
    procedure Tags_SetItems;
    [Test]
    procedure Tags_NullWithTag;
    [Test]
    procedure Tags_EmitTagsOff;
    [Test]
    procedure Tags_BlockScalars;

    // a mapping that is a sequence item
    [Test]
    [TestCase('indent1', '1')]
    [TestCase('indent2', '2')]
    [TestCase('indent3', '3')]
    [TestCase('indent4', '4')]
    procedure MappingInSequence_NestedCollectionsReadBack(indentSize : integer);
    [Test]
    procedure MappingInSequence_NestedMappingUnderFirstKey;
    [Test]
    [TestCase('indent1', '1')]
    [TestCase('indent2', '2')]
    [TestCase('indent4', '4')]
    procedure MappingInSequence_BlockScalarsReadBack(indentSize : integer);
    [Test]
    procedure MappingInSequence_SetValue;

    // sets and nulls
    [Test]
    procedure Flow_SetsAreWritten;
    [Test]
    procedure Flow_NullItemInSequence;
    [Test]
    procedure Set_MappingItem;

    // MaxLineLength
    [Test]
    procedure MaxLineLength_DefaultDoesNotFold;
    [Test]
    [TestCase('plain', '0')]
    [TestCase('singleQuoted', '1')]
    [TestCase('doubleQuoted', '2')]
    procedure MaxLineLength_FoldsAndReadsBack(style : integer);
    [Test]
    [TestCase('indent1', '1')]
    [TestCase('indent2', '2')]
    [TestCase('indent4', '4')]
    procedure MaxLineLength_FoldsEveryPlace(indentSize : integer);
    [Test]
    procedure MaxLineLength_KeepsDoubleSpaces;
    [Test]
    procedure MaxLineLength_PlainDoesNotBreakBeforeIndicators;
    [Test]
    procedure MaxLineLength_LongWordStaysWhole;
    [Test]
    procedure MaxLineLength_KeysAndFlowAreNotFolded;

    // block scalars
    [Test]
    [TestCase('literal', '1')]
    [TestCase('folded', '2')]
    procedure BlockScalar_ReadsBackTheSameText(style : integer);
    [Test]
    procedure BlockScalar_ChompingFromTheText;
    [Test]
    procedure BlockScalar_CRLFReadsBackAsLF;
    [Test]
    procedure BlockScalar_FallsBackToQuotes;
    [Test]
    procedure BlockScalar_IndentationIndicator;
    [Test]
    procedure BlockScalar_IndentationIndicatorTooLarge;
    [Test]
    procedure BlockScalar_FoldedLineBreaks;
    [Test]
    procedure BlockScalar_FoldedLongLines;
    [Test]
    procedure BlockScalar_SameLineComment;
    [Test]
    procedure Quoted_ControlCharactersAreEscaped;
  end;

implementation

// #$80..#$FF in the character literals below are Unicode code points, not ANSI characters
{$HIGHCHARUNICODE ON}

uses
  System.SysUtils,
  System.Classes;

function Lines(const values : array of string) : string;
var
  i : integer;
begin
  result := '';
  for i := 0 to Length(values) - 1 do
    result := result + values[i] + sLineBreak;
end;

function CompactJSON(const value : IYAMLValue) : string;
var
  options : IYAMLEmitOptions;
begin
  options := TYAML.CreateWriterOptions;
  options.PrettyPrint := false;
  result := TYAML.WriteToJSONString(value, options);
end;

// writes doc as YAML and reads it back
function ReadBack(const doc : IYAMLDocument) : IYAMLDocument;
begin
  result := TYAML.LoadFromString(TYAML.WriteToString(doc));
end;

function LongWords(count : integer; const prefix : string) : string;
var
  i : integer;
begin
  result := '';
  for i := 1 to count do
  begin
    if i > 1 then
      result := result + ' ';
    result := result + prefix + IntToStr(i);
  end;
end;

// the length of the longest line of text
function LongestLine(const text : string) : integer;
var
  list : TStringList;
  i : integer;
begin
  result := 0;
  list := TStringList.Create;
  try
    list.Text := text;
    for i := 0 to list.Count - 1 do
      if Length(list[i]) > result then
        result := Length(list[i]);
  finally
    list.Free;
  end;
end;

function LineCount(const text : string) : integer;
var
  list : TStringList;
begin
  list := TStringList.Create;
  try
    list.Text := text;
    result := list.Count;
  finally
    list.Free;
  end;
end;

{ tags }

procedure TYAMLWriterOutputTests.Tags_SequenceItems;
var
  doc, back : IYAMLDocument;
begin
  doc := TYAML.LoadFromString(Lines([
    '- !a x',
    '- !!str 42',
    '- !point',
    '  k: v',
    '- !list',
    '  - 1']));
  Assert.AreEqual(Lines([
    '- !a x',
    '- !!str ''42''',
    '- !point',
    '  k: v',
    '- !list',
    '  - 1']), TYAML.WriteToString(doc));

  back := ReadBack(doc);
  Assert.AreEqual('!a', back.AsSequence[0].Tag);
  Assert.IsTrue(back.AsSequence[1].IsString);
  Assert.AreEqual('!point', back.AsSequence[2].Tag);
  Assert.AreEqual('v', back.AsSequence[2].AsMapping.S['k']);
  Assert.AreEqual('!list', back.AsSequence[3].Tag);
  Assert.AreEqual(CompactJSON(doc.Root), CompactJSON(back.Root));
end;

procedure TYAMLWriterOutputTests.Tags_RootCollection;
var
  doc, back : IYAMLDocument;
begin
  doc := TYAML.LoadFromString('--- !point' + sLineBreak + 'a: 1' + sLineBreak + 'b: 2');
  Assert.AreEqual('!point', doc.Root.Tag);
  Assert.AreEqual(Lines(['!point', 'a: 1', 'b: 2']), TYAML.WriteToString(doc));
  back := ReadBack(doc);
  Assert.AreEqual('!point', back.Root.Tag);
  Assert.AreEqual(2, back.AsMapping.Count);

  doc.Options.EmitDocumentMarkers := true;
  back := ReadBack(doc);
  Assert.AreEqual('!point', back.Root.Tag);
end;

procedure TYAMLWriterOutputTests.Tags_RootSequenceAndScalar;
var
  doc, back : IYAMLDocument;
begin
  doc := TYAML.LoadFromString('--- !list' + sLineBreak + '- 1' + sLineBreak + '- 2');
  Assert.AreEqual(Lines(['!list', '- 1', '- 2']), TYAML.WriteToString(doc));
  back := ReadBack(doc);
  Assert.AreEqual('!list', back.Root.Tag);
  Assert.AreEqual(2, back.AsSequence.Count);

  doc := TYAML.LoadFromString('!custom scalar');
  Assert.AreEqual(Lines(['!custom scalar']), TYAML.WriteToString(doc));
  Assert.AreEqual('!custom', ReadBack(doc).Root.Tag);
end;

procedure TYAMLWriterOutputTests.Tags_RootFlowAndEmpty;
var
  doc, back : IYAMLDocument;
begin
  doc := TYAML.LoadFromString('--- !point' + sLineBreak + 'a: 1');
  doc.Options.Format := TYAMLOutputFormat.yofFlow;
  Assert.AreEqual(Lines(['!point {a: 1}']), TYAML.WriteToString(doc));
  Assert.AreEqual('!point', ReadBack(doc).Root.Tag);

  doc := TYAML.LoadFromString('--- !point {}');
  Assert.AreEqual(Lines(['!point', '{}']), TYAML.WriteToString(doc));
  back := ReadBack(doc);
  Assert.AreEqual('!point', back.Root.Tag);
  Assert.AreEqual(0, back.AsMapping.Count);

  doc.Options.Format := TYAMLOutputFormat.yofFlow;
  Assert.AreEqual(Lines(['!point {}']), TYAML.WriteToString(doc));
  Assert.AreEqual('!point', ReadBack(doc).Root.Tag);
end;

procedure TYAMLWriterOutputTests.Tags_BlockMappingCollections;
var
  doc, back : IYAMLDocument;
begin
  doc := TYAML.LoadFromString(Lines([
    'a: !local v',
    'b: !thing',
    '  c: 1',
    'd: !list',
    '  - 1',
    'e: !empty {}']));
  Assert.AreEqual(Lines([
    'a: !local v',
    'b: !thing',
    '  c: 1',
    'd: !list',
    '  - 1',
    'e: !empty',
    '  {}']), TYAML.WriteToString(doc));
  back := ReadBack(doc);
  Assert.AreEqual('!local', back.AsMapping['a'].Tag);
  Assert.AreEqual('!thing', back.AsMapping['b'].Tag);
  Assert.AreEqual(1, back.AsMapping['b'].AsMapping.I['c']);
  Assert.AreEqual('!list', back.AsMapping['d'].Tag);
  Assert.AreEqual('!empty', back.AsMapping['e'].Tag);
end;

procedure TYAMLWriterOutputTests.Tags_FlowOutput;
var
  doc, back : IYAMLDocument;
begin
  doc := TYAML.LoadFromString(Lines([
    'a: !local v',
    'b: !x [!y 1, 2]',
    'c: !m {k: !n v}',
    's: !!set {p, q}']));
  doc.Options.Format := TYAMLOutputFormat.yofFlow;
  Assert.AreEqual(Lines(['{a: !local v, b: !x [!y 1, 2], c: !m {k: !n v}, s: !!set [p, q]}']), TYAML.WriteToString(doc));
  back := ReadBack(doc);
  Assert.AreEqual('!x', back.AsMapping['b'].Tag);
  Assert.AreEqual('!y', back.AsMapping['b'].AsSequence[0].Tag);
  Assert.AreEqual('!n', back.AsMapping['c'].AsMapping['k'].Tag);
  Assert.IsTrue(back.AsMapping['s'].IsSet);
  Assert.AreEqual(2, back.AsMapping['s'].AsSet.Count);
end;

procedure TYAMLWriterOutputTests.Tags_MappingInSequence;
var
  doc, back : IYAMLDocument;
  item : IYAMLMapping;
begin
  doc := TYAML.LoadFromString(Lines([
    '- a: !local v',
    '  b: !list',
    '    - 1',
    '  c: !m',
    '    k: v',
    '  d: !f [1, 2]']));
  Assert.AreEqual(Lines([
    '- a: !local v',
    '  b: !list',
    '    - 1',
    '  c: !m',
    '    k: v',
    '  d: !f',
    '    - 1',
    '    - 2']), TYAML.WriteToString(doc));
  back := ReadBack(doc);
  item := back.AsSequence[0].AsMapping;
  Assert.AreEqual('!local', item['a'].Tag);
  Assert.AreEqual('!list', item['b'].Tag);
  Assert.AreEqual('!m', item['c'].Tag);
  Assert.AreEqual('!f', item['d'].Tag);
  Assert.AreEqual(CompactJSON(doc.Root), CompactJSON(back.Root));

  // mixed: the small collections go in flow style, with their tags once
  doc.Options.Format := TYAMLOutputFormat.yofMixed;
  back := ReadBack(doc);
  item := back.AsSequence[0].AsMapping;
  Assert.AreEqual('!list', item['b'].Tag, TYAML.WriteToString(doc));
  Assert.AreEqual('!m', item['c'].Tag);
  Assert.AreEqual('!f', item['d'].Tag);
  Assert.AreEqual(CompactJSON(doc.Root), CompactJSON(back.Root));
end;

procedure TYAMLWriterOutputTests.Tags_SetItems;
var
  doc, back : IYAMLDocument;
begin
  // a block mapping of '? ' keys with no values reads as a set
  doc := TYAML.LoadFromString(Lines(['? !a x', '? !b y']));
  Assert.IsTrue(doc.Root.IsSet);
  Assert.AreEqual(Lines(['? !a x', '? !b y']), TYAML.WriteToString(doc));
  back := ReadBack(doc);
  Assert.IsTrue(back.Root.IsSet);
  Assert.AreEqual('!a', back.AsSet[0].Tag);
  Assert.AreEqual('!b', back.AsSet[1].Tag);
end;

procedure TYAMLWriterOutputTests.Tags_NullWithTag;
var
  doc, back : IYAMLDocument;
begin
  doc := TYAML.LoadFromString(Lines(['a: !t', 'b:', '  - !u', '  - x']));
  Assert.AreEqual(Lines(['a: !t', 'b:', '  - !u', '  - x']), TYAML.WriteToString(doc), 'no space after a tag with nothing after it');
  back := ReadBack(doc);
  Assert.IsTrue(back.AsMapping['a'].IsNull);
  Assert.AreEqual('!t', back.AsMapping['a'].Tag);
  Assert.AreEqual('!u', back.AsMapping['b'].AsSequence[0].Tag);

  doc.Options.Format := TYAMLOutputFormat.yofFlow;
  Assert.AreEqual(Lines(['{a: !t, b: [!u null, x]}']), TYAML.WriteToString(doc));
  back := ReadBack(doc);
  Assert.IsTrue(back.AsMapping['b'].AsSequence[0].IsNull);
  Assert.AreEqual('!u', back.AsMapping['b'].AsSequence[0].Tag);
end;

procedure TYAMLWriterOutputTests.Tags_EmitTagsOff;
var
  doc : IYAMLDocument;
begin
  doc := TYAML.LoadFromString(Lines([
    '--- !root',
    '- !a x',
    '- !point',
    '  k: !v v',
    '- !list [1]']));
  doc.Options.EmitTags := false;
  Assert.AreEqual(Lines(['- x', '- k: v', '-', '  - 1']), TYAML.WriteToString(doc));
  doc.Options.Format := TYAMLOutputFormat.yofFlow;
  Assert.AreEqual(Lines(['[x, {k: v}, [1]]']), TYAML.WriteToString(doc));
end;

procedure TYAMLWriterOutputTests.Tags_BlockScalars;
var
  doc, back : IYAMLDocument;
  sequence : IYAMLSequence;
begin
  doc := TYAML.CreateSequence;
  sequence := doc.AsSequence;
  sequence.AddValue('l1' + #10 + 'l2' + #10, '!text');
  sequence.AddMapping.AddOrSetValue('k', 'm1' + #10 + 'm2' + #10, '!text');
  doc.Options.BlockScalarStyle := TYAMLBlockScalarStyle.bssLiteral;
  Assert.AreEqual(Lines(['- !text |', '  l1', '  l2', '- k: !text |', '    m1', '    m2']), TYAML.WriteToString(doc));
  back := ReadBack(doc);
  Assert.AreEqual('!text', back.AsSequence[0].Tag);
  Assert.AreEqual('l1' + #10 + 'l2' + #10, back.AsSequence[0].AsString);
  Assert.AreEqual('!text', back.AsSequence[1].AsMapping['k'].Tag);
  Assert.AreEqual('m1' + #10 + 'm2' + #10, back.AsSequence[1].AsMapping['k'].AsString);
end;

{ a mapping that is a sequence item }

procedure TYAMLWriterOutputTests.MappingInSequence_NestedCollectionsReadBack(indentSize : integer);
var
  doc, back : IYAMLDocument;
begin
  doc := TYAML.LoadFromString(
    '[{a: {b: 1, c: {d: 2}}, e: [1, [2, 3]], f: {g: [4]}, h: [{i: 5}], j: x}, {k: [l], m: {n: o}}]');
  doc.Options.IndentSize := indentSize;
  back := ReadBack(doc);
  Assert.AreEqual(CompactJSON(doc.Root), CompactJSON(back.Root), TYAML.WriteToString(doc));
end;

procedure TYAMLWriterOutputTests.MappingInSequence_NestedMappingUnderFirstKey;
var
  doc : IYAMLDocument;
begin
  // the keys of the mapping under a were at the indent of a, so they read back as keys of
  // the mapping a is in
  doc := TYAML.LoadFromString('[{a: {b: 1}, c: 2}]');
  Assert.AreEqual(Lines(['- a:', '    b: 1', '  c: 2']), TYAML.WriteToString(doc));
  Assert.AreEqual('[{"a":{"b":1},"c":2}]', CompactJSON(ReadBack(doc).Root));
  // what was right before is unchanged: a sequence may line up with its key
  doc := TYAML.LoadFromString('[{a: [x], c: 2}]');
  Assert.AreEqual(Lines(['- a:', '  - x', '  c: 2']), TYAML.WriteToString(doc));
end;

procedure TYAMLWriterOutputTests.MappingInSequence_BlockScalarsReadBack(indentSize : integer);
var
  doc, back : IYAMLDocument;
  item : IYAMLMapping;
begin
  doc := TYAML.CreateSequence;
  item := doc.AsSequence.AddMapping;
  item.AddOrSetValue('a', 'l1' + #10 + 'l2' + #10);
  item.AddOrSetValue('b', 'm1' + #10 + 'm2' + #10);
  doc.Options.IndentSize := indentSize;
  doc.Options.BlockScalarStyle := TYAMLBlockScalarStyle.bssLiteral;
  back := ReadBack(doc);
  Assert.AreEqual(CompactJSON(doc.Root), CompactJSON(back.Root), TYAML.WriteToString(doc));
end;

procedure TYAMLWriterOutputTests.MappingInSequence_SetValue;
var
  doc, back : IYAMLDocument;
begin
  // a set under a key of a mapping that is a sequence item was written as nothing
  doc := TYAML.LoadFromString(Lines(['- a: 1', '  s: !!set {p, q}']));
  back := ReadBack(doc);
  Assert.IsTrue(back.AsSequence[0].AsMapping['s'].IsSet, TYAML.WriteToString(doc));
  Assert.AreEqual(2, back.AsSequence[0].AsMapping['s'].AsSet.Count);
end;

{ sets and nulls }

procedure TYAMLWriterOutputTests.Flow_SetsAreWritten;
var
  doc, back : IYAMLDocument;
begin
  // a set in a flow mapping or flow sequence was written as nothing
  doc := TYAML.LoadFromString(Lines(['s: !!set {p, q}', 'l:', '  - !!set {x}']));
  doc.Options.Format := TYAMLOutputFormat.yofFlow;
  Assert.AreEqual(Lines(['{s: !!set [p, q], l: [!!set [x]]}']), TYAML.WriteToString(doc));
  back := ReadBack(doc);
  Assert.IsTrue(back.AsMapping['s'].IsSet);
  Assert.AreEqual(2, back.AsMapping['s'].AsSet.Count);
  Assert.IsTrue(back.AsMapping['l'].AsSequence[0].IsSet);
end;

procedure TYAMLWriterOutputTests.Flow_NullItemInSequence;
var
  doc, back : IYAMLDocument;
begin
  // [a, , b] is not YAML: an empty entry needs null
  doc := TYAML.LoadFromString(Lines(['l: [a, ~, b]', 'm: {k: ~}']));
  doc.Options.Format := TYAMLOutputFormat.yofFlow;
  Assert.AreEqual(Lines(['{l: [a, null, b], m: {k: }}']), TYAML.WriteToString(doc));
  back := ReadBack(doc);
  Assert.AreEqual(3, back.AsMapping['l'].AsSequence.Count);
  Assert.IsTrue(back.AsMapping['l'].AsSequence[1].IsNull);
  Assert.IsTrue(back.AsMapping['m'].AsMapping['k'].IsNull);
end;

procedure TYAMLWriterOutputTests.Set_MappingItem;
var
  doc, back : IYAMLDocument;
  aSet : IYAMLSet;
begin
  // a mapping in a set was written as a '- ' item among the '? ' ones
  doc := TYAML.CreateSet;
  aSet := doc.AsSet;
  aSet.AddMapping.AddOrSetValue('k', 'v');
  aSet.AddValue('x');
  Assert.AreEqual(Lines(['?', '  k: v', '? x']), TYAML.WriteToString(doc));
  back := ReadBack(doc);
  Assert.IsTrue(back.Root.IsSet);
  Assert.AreEqual(2, back.AsSet.Count);
  Assert.AreEqual('v', back.AsSet[0].AsMapping.S['k']);
end;

{ MaxLineLength }

procedure TYAMLWriterOutputTests.MaxLineLength_DefaultDoesNotFold;
var
  doc : IYAMLDocument;
begin
  doc := TYAML.CreateMapping;
  doc.AsMapping.AddOrSetValue('text', LongWords(60, 'word'));
  Assert.AreEqual(0, Integer(doc.Options.MaxLineLength));
  Assert.AreEqual(1, LineCount(TYAML.WriteToString(doc)));
end;

procedure TYAMLWriterOutputTests.MaxLineLength_FoldsAndReadsBack(style : integer);
var
  doc, back : IYAMLDocument;
  text, yaml : string;
begin
  case style of
    0 : text := LongWords(40, 'word');                    // plain
    1 : text := 'key: ' + LongWords(40, 'word');          // single quoted (': ')
  else
    text := LongWords(20, 'tab' + #9) + ' ' + LongWords(20, 'w'); // double quoted (a tab)
  end;
  doc := TYAML.CreateMapping;
  doc.AsMapping.AddOrSetValue('text', text);
  doc.Options.MaxLineLength := 40;
  yaml := TYAML.WriteToString(doc);
  Assert.IsTrue(LineCount(yaml) > 5, yaml);
  Assert.IsTrue(LongestLine(yaml) <= 40, yaml);
  back := TYAML.LoadFromString(yaml);
  Assert.AreEqual(text, back.AsMapping.S['text']);
end;

procedure TYAMLWriterOutputTests.MaxLineLength_FoldsEveryPlace(indentSize : integer);
var
  doc, back : IYAMLDocument;
  item : IYAMLMapping;
  text, yaml : string;
begin
  text := LongWords(30, 'word');
  doc := TYAML.CreateSequence;
  doc.AsSequence.AddValue(text);
  item := doc.AsSequence.AddMapping;
  item.AddOrSetValue('first', text);
  item.AddOrSetValue('second', text, '!tagged');
  item.AddOrSetMapping('nested').AddOrSetValue('deep', text);
  doc.AsSequence.AddSequence.AddValue(text);
  doc.Options.IndentSize := indentSize;
  doc.Options.MaxLineLength := 50;
  yaml := TYAML.WriteToString(doc);
  Assert.IsTrue(LongestLine(yaml) <= 50, yaml);
  back := TYAML.LoadFromString(yaml);
  Assert.AreEqual(CompactJSON(doc.Root), CompactJSON(back.Root), yaml);
  Assert.AreEqual('!tagged', back.AsSequence[1].AsMapping['second'].Tag);

  // a root scalar
  doc := TYAML.LoadFromString('"' + text + '"');
  doc.Options.IndentSize := indentSize;
  doc.Options.MaxLineLength := 50;
  yaml := TYAML.WriteToString(doc);
  Assert.IsTrue(LineCount(yaml) > 1, yaml);
  Assert.AreEqual(text, TYAML.LoadFromString(yaml).Root.AsString);
end;

procedure TYAMLWriterOutputTests.MaxLineLength_KeepsDoubleSpaces;
var
  doc : IYAMLDocument;
  text, yaml : string;
begin
  // only a single space can become a line break
  text := StringReplace(LongWords(30, 'word'), ' ', '  ', [rfReplaceAll]);
  doc := TYAML.CreateMapping;
  doc.AsMapping.AddOrSetValue('text', text);
  doc.Options.MaxLineLength := 30;
  yaml := TYAML.WriteToString(doc);
  Assert.AreEqual(text, TYAML.LoadFromString(yaml).AsMapping.S['text'], yaml);
end;

procedure TYAMLWriterOutputTests.MaxLineLength_PlainDoesNotBreakBeforeIndicators;
var
  doc : IYAMLDocument;
  text, yaml : string;
begin
  // a plain scalar does not break before a word that starts with '-' (or '#', '?', ':' ...)
  text := 'start ' + LongWords(30, '-w');
  doc := TYAML.CreateMapping;
  doc.AsMapping.AddOrSetValue('text', text);
  doc.Options.MaxLineLength := 30;
  yaml := TYAML.WriteToString(doc);
  Assert.AreEqual(1, LineCount(yaml), yaml);
  Assert.AreEqual(text, TYAML.LoadFromString(yaml).AsMapping.S['text']);
end;

procedure TYAMLWriterOutputTests.MaxLineLength_LongWordStaysWhole;
var
  doc : IYAMLDocument;
  text, yaml : string;
begin
  text := StringOfChar('x', 100) + ' y';
  doc := TYAML.CreateMapping;
  doc.AsMapping.AddOrSetValue('text', text);
  doc.Options.MaxLineLength := 40;
  yaml := TYAML.WriteToString(doc);
  Assert.AreEqual(Lines(['text: ' + StringOfChar('x', 100), '  y']), yaml);
  Assert.AreEqual(text, TYAML.LoadFromString(yaml).AsMapping.S['text']);
end;

procedure TYAMLWriterOutputTests.MaxLineLength_KeysAndFlowAreNotFolded;
var
  doc : IYAMLDocument;
  key : string;
begin
  key := LongWords(20, 'key');
  doc := TYAML.CreateMapping;
  doc.AsMapping.AddOrSetValue(key, 'v');
  doc.Options.MaxLineLength := 30;
  Assert.AreEqual(Lines([key + ': v']), TYAML.WriteToString(doc));

  doc := TYAML.CreateMapping;
  doc.AsMapping.AddOrSetValue('text', LongWords(20, 'word'));
  doc.Options.MaxLineLength := 30;
  doc.Options.Format := TYAMLOutputFormat.yofFlow;
  Assert.AreEqual(1, LineCount(TYAML.WriteToString(doc)));
end;

{ block scalars }

const
  BS = '\';
  // texts with line breaks that a block scalar can hold
  cBlockTexts : array[0..18] of string = (
    'l1'#10'l2',                                       // no final line break: -
    'l1'#10'l2'#10,                                    // one: no indicator
    'l1'#10'l2'#10#10,                                 // more: +
    'l1'#10#10'l2'#10,                                 // an empty line
    '  indented'#10'l2'#10,                            // needs an indentation indicator
    #10'l1'#10,                                        // starts with a line break
    'l1  '#10'l2'#10,                                  // spaces at the end of a line
    'a'#10'  b'#10'c'#10,                              // a more indented line
    'l1'#10#9'tab'#10,                                 // a line that starts with a tab
    #10#10,                                            // only line breaks
    #10,
    'a'#10'  ',                                        // a last line of spaces
    '   '#10'b',                                       // a first line of spaces
    'a'#10'b'#10'c',                                   // lines a folded scalar would join
    'x'#10#10#10'y',
    'para one'#10'para two'#10#10'  code'#10'more'#10,
    #9'tab first'#10'b',
    '# not a comment'#10'- not an item'#10'key: not a key'#10'---'#10,
    'next line '#$85' and '#$2028' separators'#10'b');

function BlockStyleName(style : TYAMLBlockScalarStyle) : string;
begin
  if style = TYAMLBlockScalarStyle.bssFolded then
    result := 'folded'
  else
    result := 'literal';
end;

procedure TYAMLWriterOutputTests.BlockScalar_ReadsBackTheSameText(style : integer);
var
  doc, back : IYAMLDocument;
  item : IYAMLMapping;
  i, indentSize : integer;
  yaml, name : string;
begin
  for indentSize := 1 to 4 do
    for i := Low(cBlockTexts) to High(cBlockTexts) do
    begin
      // as a mapping value, a sequence item, and the first and second values of a mapping
      // in a sequence
      doc := TYAML.CreateMapping;
      doc.AsMapping.AddOrSetValue('k', cBlockTexts[i]);
      doc.AsMapping.AddOrSetSequence('s').AddValue(cBlockTexts[i]);
      item := doc.AsMapping.AddOrSetSequence('m').AddMapping;
      item.AddOrSetValue('first', cBlockTexts[i]);
      item.AddOrSetValue('second', cBlockTexts[i]);
      doc.Options.BlockScalarStyle := TYAMLBlockScalarStyle(style);
      doc.Options.IndentSize := indentSize;
      yaml := TYAML.WriteToString(doc);
      name := BlockStyleName(TYAMLBlockScalarStyle(style)) + ', indent ' + IntToStr(indentSize) + ', text ' + IntToStr(i) + ':' + sLineBreak + yaml;
      Assert.IsTrue((Pos('k: |', yaml) = 1) or (Pos('k: >', yaml) = 1), 'a block scalar - ' + name);
      back := TYAML.LoadFromString(yaml);
      Assert.AreEqual(cBlockTexts[i], back.AsMapping.S['k'], name);
      Assert.AreEqual(cBlockTexts[i], back.AsMapping['s'].AsSequence.S[0], name);
      Assert.AreEqual(cBlockTexts[i], back.AsMapping['m'].AsSequence[0].AsMapping.S['first'], name);
      Assert.AreEqual(cBlockTexts[i], back.AsMapping['m'].AsSequence[0].AsMapping.S['second'], name);
    end;
end;

procedure TYAMLWriterOutputTests.BlockScalar_ChompingFromTheText;
var
  doc : IYAMLDocument;
begin
  doc := TYAML.CreateMapping;
  doc.AsMapping.AddOrSetValue('none', 'a'#10'b');
  doc.AsMapping.AddOrSetValue('one', 'a'#10'b'#10);
  doc.AsMapping.AddOrSetValue('two', 'a'#10'b'#10#10);
  doc.AsMapping.AddOrSetValue('only', #10);
  doc.Options.BlockScalarStyle := TYAMLBlockScalarStyle.bssLiteral;
  Assert.AreEqual(Lines([
    'none: |-', '  a', '  b',
    'one: |', '  a', '  b',
    'two: |+', '  a', '  b', '',
    'only: |+', '']), TYAML.WriteToString(doc));
end;

procedure TYAMLWriterOutputTests.BlockScalar_CRLFReadsBackAsLF;
var
  doc : IYAMLDocument;
  yaml : string;
begin
  // a block scalar holds no carriage return: a CR LF line break reads back as LF
  doc := TYAML.CreateMapping;
  doc.AsMapping.AddOrSetValue('k', 'l1'#13#10'l2'#13#10);
  doc.Options.BlockScalarStyle := TYAMLBlockScalarStyle.bssLiteral;
  yaml := TYAML.WriteToString(doc);
  Assert.AreEqual(Lines(['k: |', '  l1', '  l2']), yaml);
  Assert.AreEqual('l1'#10'l2'#10, TYAML.LoadFromString(yaml).AsMapping.S['k']);
end;

procedure TYAMLWriterOutputTests.BlockScalar_FallsBackToQuotes;
const
  cTexts : array[0..4] of string = (
    'a'#13'b'#10'c',     // a CR on its own
    'l1'#13#10'l2'#13,   // a CR at the end
    'a'#10#1'b',         // a control character
    'a'#10#127,          // DEL
    'a'#10#$FEFF'b');    // a byte order mark
var
  doc : IYAMLDocument;
  i : integer;
  yaml : string;
begin
  for i := Low(cTexts) to High(cTexts) do
  begin
    doc := TYAML.CreateMapping;
    doc.AsMapping.AddOrSetValue('k', cTexts[i]);
    doc.Options.BlockScalarStyle := TYAMLBlockScalarStyle.bssLiteral;
    yaml := TYAML.WriteToString(doc);
    Assert.IsTrue(Pos('k: "', yaml) = 1, 'double quoted: ' + yaml);
    Assert.AreEqual(cTexts[i], TYAML.LoadFromString(yaml).AsMapping.S['k'], yaml);
  end;
end;

procedure TYAMLWriterOutputTests.BlockScalar_IndentationIndicator;
var
  doc : IYAMLDocument;
  text : string;
begin
  // the indent of the lines is otherwise taken from the first one, which starts with spaces
  text := '  indented'#10'l2'#10;
  doc := TYAML.CreateMapping;
  doc.AsMapping.AddOrSetValue('k', text);
  doc.AsMapping.AddOrSetSequence('s').AddValue(text);
  doc.Options.BlockScalarStyle := TYAMLBlockScalarStyle.bssLiteral;
  Assert.AreEqual(Lines(['k: |2', '    indented', '  l2', 's:', '  - |2', '      indented', '    l2']), TYAML.WriteToString(doc));

  doc.Options.IndentSize := 4;
  Assert.AreEqual(Lines(['k: |4', '      indented', '    l2', 's:', '    - |4', '          indented', '        l2']), TYAML.WriteToString(doc));
  Assert.AreEqual(text, TYAML.LoadFromString(TYAML.WriteToString(doc)).AsMapping.S['k']);
end;

procedure TYAMLWriterOutputTests.BlockScalar_IndentationIndicatorTooLarge;
var
  doc : IYAMLDocument;
  yaml : string;
begin
  // an indentation indicator is one digit, so past 9 the text is double quoted
  doc := TYAML.CreateMapping;
  doc.AsMapping.AddOrSetValue('k', '  indented'#10'l2'#10);
  doc.AsMapping.AddOrSetValue('other', 'a'#10'b'#10);
  doc.Options.BlockScalarStyle := TYAMLBlockScalarStyle.bssLiteral;
  doc.Options.IndentSize := 10;
  yaml := TYAML.WriteToString(doc);
  Assert.Contains(yaml, 'k: "  indented' + BS + 'nl2' + BS + 'n"');
  Assert.Contains(yaml, 'other: |');
  Assert.AreEqual('  indented'#10'l2'#10, TYAML.LoadFromString(yaml).AsMapping.S['k']);
  Assert.AreEqual('a'#10'b'#10, TYAML.LoadFromString(yaml).AsMapping.S['other']);
end;

procedure TYAMLWriterOutputTests.BlockScalar_FoldedLineBreaks;
var
  doc : IYAMLDocument;
begin
  // a single line break between two lines would read as a space, so it is an empty line; one
  // next to a line that starts with white space is not
  doc := TYAML.CreateMapping;
  doc.AsMapping.AddOrSetValue('k', 'a'#10'b'#10#10'  code'#10'c'#10);
  doc.Options.BlockScalarStyle := TYAMLBlockScalarStyle.bssFolded;
  Assert.AreEqual(Lines(['k: >', '  a', '', '  b', '', '    code', '  c']), TYAML.WriteToString(doc));
end;

procedure TYAMLWriterOutputTests.BlockScalar_FoldedLongLines;
var
  doc : IYAMLDocument;
  text, yaml : string;
begin
  text := LongWords(20, 'word') + #10 + 'next' + #10 + '  ' + LongWords(10, 'kept') + #10;
  doc := TYAML.CreateMapping;
  doc.AsMapping.AddOrSetValue('k', text);
  doc.Options.BlockScalarStyle := TYAMLBlockScalarStyle.bssFolded;
  doc.Options.MaxLineLength := 30;
  yaml := TYAML.WriteToString(doc);
  Assert.IsTrue(LineCount(yaml) > 6, yaml);
  Assert.Contains(yaml, '    ' + LongWords(10, 'kept'), 'a line that starts with a space is not folded');
  Assert.AreEqual(text, TYAML.LoadFromString(yaml).AsMapping.S['k'], yaml);

  // a literal block scalar cannot be folded
  doc.Options.BlockScalarStyle := TYAMLBlockScalarStyle.bssLiteral;
  yaml := TYAML.WriteToString(doc);
  Assert.AreEqual(4, LineCount(yaml), yaml);
  Assert.AreEqual(text, TYAML.LoadFromString(yaml).AsMapping.S['k']);
end;

procedure TYAMLWriterOutputTests.BlockScalar_SameLineComment;
var
  doc : IYAMLDocument;
  yaml : string;
begin
  doc := TYAML.CreateMapping;
  doc.AsMapping.AddOrSetValue('k', 'a'#10'b'#10).Comment := 'note';
  doc.AsMapping.AddOrSetSequence('s').AddValue('c'#10'd').Comment := 'item';
  doc.Options.BlockScalarStyle := TYAMLBlockScalarStyle.bssLiteral;
  yaml := TYAML.WriteToString(doc);
  Assert.AreEqual(Lines(['k: | # note', '  a', '  b', 's:', '  - |- # item', '    c', '    d']), yaml);
  Assert.AreEqual('a'#10'b'#10, TYAML.LoadFromString(yaml).AsMapping.S['k']);
  Assert.AreEqual('c'#10'd', TYAML.LoadFromString(yaml).AsMapping['s'].AsSequence.S[0]);
end;

procedure TYAMLWriterOutputTests.Quoted_ControlCharactersAreEscaped;
var
  doc, back : IYAMLDocument;
begin
  // YAML allows none of these in a stream as they are
  doc := TYAML.CreateMapping;
  doc.AsMapping.AddOrSetValue('c0', 'a'#1'b'#31);
  doc.AsMapping.AddOrSetValue('del', 'a'#127);
  doc.AsMapping.AddOrSetValue('c1', 'a'#$9F'b'#$80);
  doc.AsMapping.AddOrSetValue('bom', 'a'#$FEFF);
  doc.AsMapping.AddOrSetValue('nel', 'a'#$85);
  doc.AsMapping.AddOrSetValue('key'#2, 'x');
  Assert.AreEqual(Lines([
    'c0: "a' + BS + 'x01b' + BS + 'x1F"',
    'del: "a' + BS + 'x7F"',
    'c1: "a' + BS + 'x9Fb' + BS + 'x80"',
    'bom: "a' + BS + 'uFEFF"',
    'nel: "a' + BS + 'N"',
    '"key' + BS + 'x02": x']), TYAML.WriteToString(doc));
  back := TYAML.LoadFromString(TYAML.WriteToString(doc));
  Assert.AreEqual('a'#1'b'#31, back.AsMapping.S['c0']);
  Assert.AreEqual('a'#127, back.AsMapping.S['del']);
  Assert.AreEqual('a'#$9F'b'#$80, back.AsMapping.S['c1']);
  Assert.AreEqual('a'#$FEFF, back.AsMapping.S['bom']);
  Assert.AreEqual('a'#$85, back.AsMapping.S['nel']);
  Assert.IsTrue(back.AsMapping.ContainsKey('key'#2));
end;

initialization
  TDUnitX.RegisterTestFixture(TYAMLWriterOutputTests);

end.

unit VSoft.YAML.Tests.TagInfo;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  VSoft.YAML,
  VSoft.YAML.TagInfo;

type
  [TestFixture]
  TYAMLTagInfoTests = class
  public
    [Test]
    procedure TestStandardTagCreation;

    [Test]
    procedure TestLocalTagCreation;

    [Test]
    procedure TestCustomTagCreation;

    [Test]
    procedure TestVerbatimTagCreation;

    [Test]
    procedure TestUnresolvedTagCreation;

    [Test]
    procedure TestTagParsing;

    [Test]
    procedure TestTagValidation;

    [Test]
    procedure TestTagUtilities;

    [Test]
    procedure TestTagInfoWithValue;

    [Test]
    procedure TestTagEquality;

    [Test]
    procedure TestTagTypeChecks;

    [Test]
    procedure TestBackwardCompatibility;

    [Test]
    procedure TestTagAwareSequenceAddValue;

    [Test]
    procedure TestTagAwareMappingAddOrSetValue;

    [Test]
    procedure TestTagModificationMethods;

    [Test]
    procedure TestTagAwareValueWithStrings;

    [Test]
    procedure TestTagAwareValueWithTagInfo;

    [Test]
    procedure TestTagPersistenceAfterModification;
  end;

implementation

uses
  VSoft.YAML.Classes;

{ TYAMLTagInfoTests }

procedure TYAMLTagInfoTests.TestStandardTagCreation;
var
  tagInfo: IYAMLTagInfo;
begin
  tagInfo := TYAMLTagInfoFactory.CreateStandardTag('str');
  
  Assert.IsNotNull(tagInfo);
  Assert.IsTrue(tagInfo.IsStandardTag);
  Assert.IsFalse(tagInfo.IsLocalTag);
  Assert.IsFalse(tagInfo.IsCustomTag);
  Assert.IsFalse(tagInfo.IsVerbatimTag);
  Assert.IsFalse(tagInfo.IsUnresolved);
  
  Assert.AreEqual('!!str', tagInfo.OriginalText);
  Assert.AreEqual('tag:yaml.org,2002:str', tagInfo.ResolvedTag);
  Assert.AreEqual('!!', tagInfo.Handle);
  Assert.AreEqual('str', tagInfo.Suffix);
  Assert.AreEqual('tag:yaml.org,2002:', tagInfo.Prefix);
end;

procedure TYAMLTagInfoTests.TestLocalTagCreation;
var
  tagInfo: IYAMLTagInfo;
begin
  tagInfo := TYAMLTagInfoFactory.CreateLocalTag('mytype');
  
  Assert.IsNotNull(tagInfo);
  Assert.IsFalse(tagInfo.IsStandardTag);
  Assert.IsTrue(tagInfo.IsLocalTag);
  Assert.IsFalse(tagInfo.IsCustomTag);
  Assert.IsFalse(tagInfo.IsVerbatimTag);
  Assert.IsFalse(tagInfo.IsUnresolved);
  
  Assert.AreEqual('!mytype', tagInfo.OriginalText);
  Assert.AreEqual('!mytype', tagInfo.ResolvedTag);
  Assert.AreEqual('!', tagInfo.Handle);
  Assert.AreEqual('mytype', tagInfo.Suffix);
  Assert.AreEqual('!', tagInfo.Prefix);
end;

procedure TYAMLTagInfoTests.TestCustomTagCreation;
var
  tagInfo: IYAMLTagInfo;
begin
  tagInfo := TYAMLTagInfoFactory.CreateCustomTag('!company!', 'product', 'http://company.com/');
  
  Assert.IsNotNull(tagInfo);
  Assert.IsFalse(tagInfo.IsStandardTag);
  Assert.IsFalse(tagInfo.IsLocalTag);
  Assert.IsTrue(tagInfo.IsCustomTag);
  Assert.IsFalse(tagInfo.IsVerbatimTag);
  Assert.IsFalse(tagInfo.IsUnresolved);
  
  Assert.AreEqual('!company!product', tagInfo.OriginalText);
  Assert.AreEqual('http://company.com/product', tagInfo.ResolvedTag);
  Assert.AreEqual('!company!', tagInfo.Handle);
  Assert.AreEqual('product', tagInfo.Suffix);
  Assert.AreEqual('http://company.com/', tagInfo.Prefix);
end;

procedure TYAMLTagInfoTests.TestVerbatimTagCreation;
var
  tagInfo: IYAMLTagInfo;
begin
  tagInfo := TYAMLTagInfoFactory.CreateVerbatimTag('http://example.com/schema#item');
  
  Assert.IsNotNull(tagInfo);
  Assert.IsFalse(tagInfo.IsStandardTag);
  Assert.IsFalse(tagInfo.IsLocalTag);
  Assert.IsFalse(tagInfo.IsCustomTag);
  Assert.IsTrue(tagInfo.IsVerbatimTag);
  Assert.IsFalse(tagInfo.IsUnresolved);
  
  Assert.AreEqual('!<http://example.com/schema#item>', tagInfo.OriginalText);
  Assert.AreEqual('http://example.com/schema#item', tagInfo.ResolvedTag);
end;

procedure TYAMLTagInfoTests.TestUnresolvedTagCreation;
var
  tagInfo: IYAMLTagInfo;
begin
  tagInfo := TYAMLTagInfoFactory.CreateUnresolvedTag('!unknown');
  
  Assert.IsNotNull(tagInfo);
  Assert.IsFalse(tagInfo.IsStandardTag);
  Assert.IsFalse(tagInfo.IsLocalTag);
  Assert.IsFalse(tagInfo.IsCustomTag);
  Assert.IsFalse(tagInfo.IsVerbatimTag);
  Assert.IsTrue(tagInfo.IsUnresolved);
  
  Assert.AreEqual('!unknown', tagInfo.OriginalText);
  Assert.AreEqual('', tagInfo.ResolvedTag);
end;

procedure TYAMLTagInfoTests.TestTagParsing;
var
  tagInfo: IYAMLTagInfo;
begin
  // Test standard tag parsing
  tagInfo := TYAMLTagInfoFactory.ParseTag('!!str');
  Assert.IsTrue(tagInfo.IsStandardTag);
  Assert.AreEqual('str', tagInfo.Suffix);
  
  // Test local tag parsing
  tagInfo := TYAMLTagInfoFactory.ParseTag('!local');
  Assert.IsTrue(tagInfo.IsLocalTag);
  Assert.AreEqual('local', tagInfo.Suffix);
  
  // Test verbatim tag parsing
  tagInfo := TYAMLTagInfoFactory.ParseTag('!<http://example.com>');
  Assert.IsTrue(tagInfo.IsVerbatimTag);
  Assert.AreEqual('http://example.com', tagInfo.ResolvedTag);
  
  // Test custom tag parsing
  tagInfo := TYAMLTagInfoFactory.ParseTag('!handle!suffix');
  Assert.IsTrue(tagInfo.IsCustomTag);
  Assert.AreEqual('!handle!', tagInfo.Handle);
  Assert.AreEqual('suffix', tagInfo.Suffix);
  
  // Test global URI tag parsing
  tagInfo := TYAMLTagInfoFactory.ParseTag('http://example.com/type');
  Assert.IsTrue(tagInfo.IsGlobalTag);
  Assert.AreEqual('http://example.com/type', tagInfo.ResolvedTag);
  
  // Test unresolved tag parsing
  tagInfo := TYAMLTagInfoFactory.ParseTag('?');
  Assert.IsTrue(tagInfo.IsUnresolved);
end;

procedure TYAMLTagInfoTests.TestTagValidation;
begin
  // Test valid handles
  Assert.IsTrue(TYAMLTagInfoFactory.IsValidTagHandle('!!'));
  Assert.IsTrue(TYAMLTagInfoFactory.IsValidTagHandle('!handle!'));
  Assert.IsTrue(TYAMLTagInfoFactory.IsValidTagHandle('!company-tag!'));
  
  // Test invalid handles
  Assert.IsFalse(TYAMLTagInfoFactory.IsValidTagHandle('!'));
  Assert.IsFalse(TYAMLTagInfoFactory.IsValidTagHandle('handle!'));
  Assert.IsFalse(TYAMLTagInfoFactory.IsValidTagHandle('!invalid@!'));
  
  // Test valid suffixes
  Assert.IsTrue(TYAMLTagInfoFactory.IsValidTagSuffix('str'));
  Assert.IsTrue(TYAMLTagInfoFactory.IsValidTagSuffix('my-type'));
  Assert.IsTrue(TYAMLTagInfoFactory.IsValidTagSuffix('namespace/type'));
  
  // Test invalid suffixes
  Assert.IsFalse(TYAMLTagInfoFactory.IsValidTagSuffix(''));
  
  // Test valid URIs
  Assert.IsTrue(TYAMLTagInfoFactory.IsValidTagURI('http://example.com'));
  Assert.IsTrue(TYAMLTagInfoFactory.IsValidTagURI('tag:yaml.org,2002:str'));
  
  // Test invalid URIs
  Assert.IsFalse(TYAMLTagInfoFactory.IsValidTagURI(''));
  Assert.IsFalse(TYAMLTagInfoFactory.IsValidTagURI('noscheme'));
end;

procedure TYAMLTagInfoTests.TestTagUtilities;
var
  tag1, tag2: IYAMLTagInfo;
  comparison: Integer;
begin
  // Test priority comparison
  tag1 := TYAMLTagInfoFactory.CreateStandardTag('str');
  tag2 := TYAMLTagInfoFactory.CreateLocalTag('custom');
  comparison := TYAMLTagInfoFactory.CompareTagsByPriority(tag1, tag2);
  Assert.IsTrue(comparison < 0); // Standard tag has higher priority
  
  // Test standard tag type lookup
  Assert.AreEqual('string', TYAMLTagInfoFactory.GetStandardTagType('str'));
  Assert.AreEqual('integer', TYAMLTagInfoFactory.GetStandardTagType('int'));
  Assert.AreEqual('boolean', TYAMLTagInfoFactory.GetStandardTagType('bool'));
  Assert.AreEqual('unknown', TYAMLTagInfoFactory.GetStandardTagType('unknown'));
end;

procedure TYAMLTagInfoTests.TestTagInfoWithValue;
var
  doc: IYAMLDocument;
  value: IYAMLValue;
  tagInfo: IYAMLTagInfo;
begin
  // Create a value with tag info
  tagInfo := TYAMLTagInfoFactory.CreateStandardTag('str');
  doc := TYAML.CreateMapping;
  
  // Test that value can store and retrieve tag info
  value := TYAMLValue.Create(doc.Root, TYAMLValueType.vtString, 'test', tagInfo);
  
  Assert.IsNotNull(value.TagInfo);
  Assert.IsTrue(value.TagInfo.IsStandardTag);
  Assert.AreEqual('!!str', value.Tag);
end;

procedure TYAMLTagInfoTests.TestTagEquality;
var
  tag1, tag2, tag3: IYAMLTagInfo;
begin
  tag1 := TYAMLTagInfoFactory.CreateStandardTag('str');
  tag2 := TYAMLTagInfoFactory.CreateStandardTag('str');
  tag3 := TYAMLTagInfoFactory.CreateStandardTag('int');
  
  Assert.IsTrue(tag1.AreEqual(tag2));
  Assert.IsFalse(tag1.AreEqual(tag3));
  Assert.IsFalse(tag1.AreEqual(nil));
end;

procedure TYAMLTagInfoTests.TestTagTypeChecks;
var
  tagInfo: IYAMLTagInfo;
begin
  // Test each tag type
  tagInfo := TYAMLTagInfoFactory.CreateStandardTag('str');
  Assert.AreEqual(TYAMLTagType.ytStandard, tagInfo.TagType);
  
  tagInfo := TYAMLTagInfoFactory.CreateLocalTag('local');
  Assert.AreEqual(TYAMLTagType.ytLocal, tagInfo.TagType);
  
  tagInfo := TYAMLTagInfoFactory.CreateCustomTag('!h!', 'suffix', 'prefix');
  Assert.AreEqual(TYAMLTagType.ytCustom, tagInfo.TagType);
  
  tagInfo := TYAMLTagInfoFactory.CreateVerbatimTag('http://example.com');
  Assert.AreEqual(TYAMLTagType.ytVerbatim, tagInfo.TagType);
  
  tagInfo := TYAMLTagInfoFactory.CreateUnresolvedTag('?');
  Assert.AreEqual(TYAMLTagType.ytUnresolved, tagInfo.TagType);
end;

procedure TYAMLTagInfoTests.TestBackwardCompatibility;
var
  doc: IYAMLDocument;
  value: IYAMLValue;
begin
  // Test that old string-based tag creation still works
  doc := TYAML.CreateMapping;
  value := TYAMLValue.Create(doc.Root, TYAMLValueType.vtString, 'test', '!!str');
  
  Assert.AreEqual('!!str', value.Tag);
  Assert.IsNotNull(value.TagInfo);
  Assert.IsTrue(value.TagInfo.IsStandardTag);
end;

procedure TYAMLTagInfoTests.TestTagAwareSequenceAddValue;
var
  doc: IYAMLDocument;
  sequence: IYAMLSequence;
  value: IYAMLValue;
  tagInfo: IYAMLTagInfo;
begin
  doc := TYAML.CreateSequence;
  sequence := doc.AsSequence;
  
  // Test tag-aware AddValue with string tag
  value := sequence.AddValue(42, '!!int');
  Assert.AreEqual('!!int', value.Tag);
  Assert.IsNotNull(value.TagInfo);
  Assert.IsTrue(value.TagInfo.IsStandardTag);
  Assert.AreEqual<Int64>(42, value.AsInteger);
  
  // Test tag-aware AddValue with IYAMLTagInfo
  tagInfo := TYAMLTagInfoFactory.CreateStandardTag('str');
  value := sequence.AddValue('hello', tagInfo);
  Assert.AreEqual('!!str', value.Tag);
  Assert.IsNotNull(value.TagInfo);
  Assert.IsTrue(value.TagInfo.IsStandardTag);
  Assert.AreEqual('hello', value.AsString);
  
  // Test with boolean
  value := sequence.AddValue(true, '!!bool');
  Assert.AreEqual('!!bool', value.Tag);
  Assert.IsTrue(value.AsBoolean);
  
  // Test with float
  value := sequence.AddValue(3.14, '!!float');
  Assert.AreEqual('!!float', value.Tag);
  Assert.AreEqual(3.14, value.AsFloat, 0.01);
end;

procedure TYAMLTagInfoTests.TestTagAwareMappingAddOrSetValue;
var
  doc: IYAMLDocument;
  mapping: IYAMLMapping;
  value: IYAMLValue;
  tagInfo: IYAMLTagInfo;
begin
  doc := TYAML.CreateMapping;
  mapping := doc.AsMapping;
  
  // Test tag-aware AddOrSetValue with string tag
  value := mapping.AddOrSetValue('number', 42, '!!int');
  Assert.AreEqual('!!int', value.Tag);
  Assert.IsNotNull(value.TagInfo);
  Assert.IsTrue(value.TagInfo.IsStandardTag);
  Assert.AreEqual<Int64>(42, value.AsInteger);
  
  // Test tag-aware AddOrSetValue with IYAMLTagInfo
  tagInfo := TYAMLTagInfoFactory.CreateStandardTag('str');
  value := mapping.AddOrSetValue('text', 'hello', tagInfo);
  Assert.AreEqual('!!str', value.Tag);
  Assert.IsNotNull(value.TagInfo);
  Assert.IsTrue(value.TagInfo.IsStandardTag);
  Assert.AreEqual('hello', value.AsString);
  
  // Test with boolean
  value := mapping.AddOrSetValue('flag', true, '!!bool');
  Assert.AreEqual('!!bool', value.Tag);
  Assert.IsTrue(value.AsBoolean);
  
  // Test with float
  value := mapping.AddOrSetValue('pi', 3.14159, '!!float');
  Assert.AreEqual('!!float', value.Tag);
  Assert.AreEqual(3.14159, value.AsFloat, 0.00001);
  
  // Test overwriting existing value with new tag
  value := mapping.AddOrSetValue('number', 99, '!!str');
  Assert.AreEqual('!!str', value.Tag);
  Assert.AreEqual('99', value.AsString);
end;

procedure TYAMLTagInfoTests.TestTagModificationMethods;
var
  doc: IYAMLDocument;
  value: IYAMLValue;
  tagInfo: IYAMLTagInfo;
begin
  doc := TYAML.CreateMapping;
  
  // Create value without tag
  value := TYAMLValue.Create(doc.Root, TYAMLValueType.vtString, 'test');
  Assert.AreEqual('', value.Tag);
  
  // Test SetTag method
  value.SetTag('!!str');
  Assert.AreEqual('!!str', value.Tag);
  Assert.IsNotNull(value.TagInfo);
  Assert.IsTrue(value.TagInfo.IsStandardTag);
  
  // Test SetTagInfo method
  tagInfo := TYAMLTagInfoFactory.CreateLocalTag('custom');
  value.SetTagInfo(tagInfo);
  Assert.AreEqual('!custom', value.Tag);
  Assert.IsNotNull(value.TagInfo);
  Assert.IsTrue(value.TagInfo.IsLocalTag);
  
  // Test ClearTag method
  value.ClearTag;
  Assert.AreEqual('', value.Tag);
  Assert.IsNull(value.TagInfo);
end;

procedure TYAMLTagInfoTests.TestTagAwareValueWithStrings;
var
  doc: IYAMLDocument;
  sequence: IYAMLSequence;
  mapping: IYAMLMapping;
begin
  // Test sequence with various string tags
  doc := TYAML.CreateSequence;
  sequence := doc.AsSequence;
  
  sequence.AddValue('hello', '!local');
  sequence.AddValue('world', '!!str');
  sequence.AddValue('uri', '!<http://example.com/schema#item>');
  
  Assert.AreEqual('!local', sequence.Items[0].Tag);
  Assert.AreEqual('!!str', sequence.Items[1].Tag);
  Assert.AreEqual('!<http://example.com/schema#item>', sequence.Items[2].Tag);
  
  // Test mapping with various string tags
  doc := TYAML.CreateMapping;
  mapping := doc.AsMapping;
  
  mapping.AddOrSetValue('local', 'value1', '!local');
  mapping.AddOrSetValue('standard', 'value2', '!!str');
  mapping.AddOrSetValue('verbatim', 'value3', '!<http://example.com/type>');
  
  Assert.AreEqual('!local', mapping.Values['local'].Tag);
  Assert.AreEqual('!!str', mapping.Values['standard'].Tag);
  Assert.AreEqual('!<http://example.com/type>', mapping.Values['verbatim'].Tag);
end;

procedure TYAMLTagInfoTests.TestTagAwareValueWithTagInfo;
var
  doc: IYAMLDocument;
  sequence: IYAMLSequence;
  mapping: IYAMLMapping;
  standardTag, localTag, customTag: IYAMLTagInfo;
begin
  standardTag := TYAMLTagInfoFactory.CreateStandardTag('int');
  localTag := TYAMLTagInfoFactory.CreateLocalTag('mytype');
  customTag := TYAMLTagInfoFactory.CreateCustomTag('!ns!', 'item', 'http://example.com/ns/');
  
  // Test sequence with IYAMLTagInfo objects
  doc := TYAML.CreateSequence;
  sequence := doc.AsSequence;
  
  sequence.AddValue(42, standardTag);
  sequence.AddValue('custom', localTag);
  sequence.AddValue('item', customTag);
  
  Assert.IsTrue(sequence.Items[0].TagInfo.IsStandardTag);
  Assert.IsTrue(sequence.Items[1].TagInfo.IsLocalTag);
  Assert.IsTrue(sequence.Items[2].TagInfo.IsCustomTag);
  
  Assert.AreEqual('!!int', sequence.Items[0].Tag);
  Assert.AreEqual('!mytype', sequence.Items[1].Tag);
  Assert.AreEqual('!ns!item', sequence.Items[2].Tag);
  
  // Test mapping with IYAMLTagInfo objects
  doc := TYAML.CreateMapping;
  mapping := doc.AsMapping;
  
  mapping.AddOrSetValue('number', 123, standardTag);
  mapping.AddOrSetValue('custom', 'value', localTag);
  mapping.AddOrSetValue('typed', 'data', customTag);
  
  Assert.IsTrue(mapping.Values['number'].TagInfo.IsStandardTag);
  Assert.IsTrue(mapping.Values['custom'].TagInfo.IsLocalTag);
  Assert.IsTrue(mapping.Values['typed'].TagInfo.IsCustomTag);
end;

procedure TYAMLTagInfoTests.TestTagPersistenceAfterModification;
var
  doc: IYAMLDocument;
  mapping: IYAMLMapping;
  value: IYAMLValue;
  originalTag, modifiedTag: IYAMLTagInfo;
begin
  doc := TYAML.CreateMapping;
  mapping := doc.AsMapping;
  
  // Create value with initial tag
  originalTag := TYAMLTagInfoFactory.CreateStandardTag('str');
  value := mapping.AddOrSetValue('test', 'initial', originalTag);
  
  Assert.AreEqual('!!str', value.Tag);
  Assert.IsTrue(value.TagInfo.IsStandardTag);
  
  // Modify the tag using SetTag
  value.SetTag('!local');
  Assert.AreEqual('!local', value.Tag);
  Assert.IsTrue(value.TagInfo.IsLocalTag);
  
  // Modify the tag using SetTagInfo
  modifiedTag := TYAMLTagInfoFactory.CreateCustomTag('!ns!', 'type', 'http://example.com/');
  value.SetTagInfo(modifiedTag);
  Assert.AreEqual('!ns!type', value.Tag);
  Assert.IsTrue(value.TagInfo.IsCustomTag);
  
  // Verify tag is persisted when value is accessed from mapping
  Assert.AreEqual('!ns!type', mapping.Values['test'].Tag);
  Assert.IsTrue(mapping.Values['test'].TagInfo.IsCustomTag);
  
  // Clear tag and verify
  value.ClearTag;
  Assert.AreEqual('', value.Tag);
  Assert.IsTrue(value.TagInfo = nil);
  Assert.AreEqual('', mapping.Values['test'].Tag);
end;

initialization
  TDUnitX.RegisterTestFixture(TYAMLTagInfoTests);


end.
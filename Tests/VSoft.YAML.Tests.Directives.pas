unit VSoft.YAML.Tests.Directives;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TYAMLDirectiveTests = class

  public

    [Test]
    procedure TestYAMLDirectiveParsing;

    [Test]
    procedure TestTAGDirectiveParsing;

    [Test]
    procedure TestMultipleYAMLDirectivesError;

    [Test]
    procedure TestUnsupportedYAMLVersionError;

    [Test]
    procedure TestInvalidYAMLDirectiveFormat;

    [Test]
    procedure TestTagResolution;

    [Test]
    procedure TestDefaultTagHandles;

    [Test]
    procedure TestCustomTagHandle;

    [Test]
    procedure TestEmitTagDirectives;

  end;

implementation

uses 
  VSoft.YAML,
  System.SysUtils;

{ TYAMLDirectiveTests }

procedure TYAMLDirectiveTests.TestYAMLDirectiveParsing;
var
  yamlText: string;
  doc: IYAMLDocument;
begin
  yamlText := 
    '%YAML 1.2' + sLineBreak +
    '---' + sLineBreak +
    'test: value';

  doc := TYAML.LoadFromString(yamlText);
  Assert.IsNotNull(doc.Root, 'Document should be parsed successfully');
  Assert.AreEqual('value', doc.Root.Values['test'].AsString, 'Value should be parsed correctly');
  Assert.AreEqual<Int64>(1, doc.Version.Major, 'Major version');
  Assert.AreEqual<Int64>(2, doc.Version.Minor, 'Minor version');
end;

procedure TYAMLDirectiveTests.TestTAGDirectiveParsing;
var
  yamlText: string;
  doc: IYAMLDocument;
begin
  yamlText := 
    '%TAG !local! tag:example.com,2000:app/' + sLineBreak +
    '---' + sLineBreak +
    'test: value';

  doc := TYAML.LoadFromString(yamlText);
  Assert.IsNotNull(doc.Root, 'Document should be parsed successfully');
  Assert.AreEqual('value', doc.Root.Values['test'].AsString, 'Value should be parsed correctly');
  //two standard ones are added
  Assert.AreEqual<NativeInt>(3, doc.TagDirectives.Count, 'Should be 3 tags directive');


end;

procedure TYAMLDirectiveTests.TestMultipleYAMLDirectivesError;
var
  yamlText: string;
  doc: IYAMLDocument;
begin
  yamlText := 
    '%YAML 1.2' + sLineBreak +
    '%YAML 1.1' + sLineBreak +
    '---' + sLineBreak +
    'test: value';

  Assert.WillRaise(
    procedure
    begin
      doc := TYAML.LoadFromString(yamlText);
    end,
    EYAMLParseException,
    'Multiple YAML directives should raise an exception'
  );
end;

procedure TYAMLDirectiveTests.TestUnsupportedYAMLVersionError;
var
  yamlText: string;
  doc: IYAMLDocument;
begin
  yamlText := 
    '%YAML 2.0' + sLineBreak +
    '---' + sLineBreak +
    'test: value';

  Assert.WillRaise(
    procedure
    begin
      doc := TYAML.LoadFromString(yamlText);
    end,
    EYAMLParseException,
    'Unsupported YAML version should raise an exception'
  );
end;

procedure TYAMLDirectiveTests.TestInvalidYAMLDirectiveFormat;
var
  yamlText: string;
  doc: IYAMLDocument;
begin
  yamlText := 
    '%YAML invalid' + sLineBreak +
    '---' + sLineBreak +
    'test: value';

  Assert.WillRaise(
    procedure
    begin
      doc := TYAML.LoadFromString(yamlText);
    end,
    EYAMLParseException,
    'Invalid YAML directive format should raise an exception'
  );
end;

procedure TYAMLDirectiveTests.TestTagResolution;
var
  yamlText: string;
  doc: IYAMLDocument;
begin
  // Test that default !! tags work without explicit directives.
  // (Two items in a sequence: two bare root scalars is not a valid document, and used to
  // parse only because the parser silently dropped the second line.)
  yamlText :=
    '---' + sLineBreak +
    '- !!str test' + sLineBreak +
    '- !!int 42';

  doc := TYAML.LoadFromString(yamlText);
  Assert.IsNotNull(doc.Root, 'Document should be parsed successfully');
  Assert.AreEqual(2, doc.Root.AsSequence.Count);
  Assert.AreEqual('test', doc.Root.AsSequence[0].AsString);
  Assert.AreEqual<Int64>(42, doc.Root.AsSequence[1].AsInteger);
end;

procedure TYAMLDirectiveTests.TestDefaultTagHandles;
var
  yamlText: string;
  doc: IYAMLDocument;
begin
  // Test that default tag handles are available (sequence items - see TestTagResolution)
  yamlText :=
    '---' + sLineBreak +
    '- !local test' + sLineBreak +
    '- !!str value';

  doc := TYAML.LoadFromString(yamlText);
  Assert.IsNotNull(doc.Root, 'Document should be parsed successfully');
  Assert.AreEqual(2, doc.Root.AsSequence.Count);
  Assert.AreEqual('value', doc.Root.AsSequence[1].AsString);
end;

procedure TYAMLDirectiveTests.TestEmitTagDirectives;
var
  yamlText: string;
  doc: IYAMLDocument;
  written : string;
begin
  yamlText :=
    '%TAG !custom! tag:example.com,2000:app/' + sLineBreak +
    '---' + sLineBreak +
    'foo: !custom!type value';

  doc := TYAML.LoadFromString(yamlText);
  Assert.IsNotNull(doc.Root, 'Document should be parsed successfully');

  doc.Options.EmitYAMLDirective := true;
  doc.Options.EmitDocumentMarkers := true;
  doc.Options.EmitTagDirectives := true;

  written := TYAML.WriteToString(doc);

  Assert.Contains(written, '%TAG !custom! tag:example.com,2000:app/');
  Assert.Contains(written, '%YAML 1.2');


end;

procedure TYAMLDirectiveTests.TestCustomTagHandle;
var
  yamlText: string;
  doc: IYAMLDocument;
begin
  yamlText :=
    '%TAG !custom! tag:example.com,2000:app/' + sLineBreak +
    '---' + sLineBreak +
    'foo: !custom!type value';

  doc := TYAML.LoadFromString(yamlText);
  Assert.IsNotNull(doc.Root, 'Document should be parsed successfully');
end;

initialization
  TDUnitX.RegisterTestFixture(TYAMLDirectiveTests);

end.
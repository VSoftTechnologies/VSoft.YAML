unit VSoft.YAML.Tests.MergeKeys;

interface

uses
  DUnitX.TestFramework,
  VSoft.YAML,
  System.SysUtils,
  System.Classes;

type
  [TestFixture]
  TYAMLMergeKeyTests = class
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    // Basic merge key tests
    [Test]
    procedure Test_MergeKey_SimpleAlias;
    [Test]
    procedure Test_MergeKey_MultipleAliases;
    [Test]
    procedure Test_MergeKey_NestedMappings;
    [Test]
    procedure Test_MergeKey_OverrideValues;
    [Test]
    procedure Test_MergeKey_EmptyMapping;
    [Test]
    procedure Test_MergeKey_WithSequence;
    [Test]
    procedure Test_MergeKey_MultipleReferences;
    [Test]
    procedure Test_MergeKey_DeepNesting;
    [Test]
    procedure Test_MergeKey_CircularReference;
    [Test]
    procedure Test_MergeKey_InvalidReference;
    [Test]
    procedure Test_MergeKey_CopiesScalarsExactly;
  end;

implementation

procedure TYAMLMergeKeyTests.Setup;
begin
  // Setup code if needed
end;

procedure TYAMLMergeKeyTests.TearDown;
begin
  // Teardown code if needed
end;

procedure TYAMLMergeKeyTests.Test_MergeKey_SimpleAlias;
var
  yamlContent: string;
  document: IYAMLDocument;
  root: IYAMLMapping;
  person: IYAMLMapping;
begin
  yamlContent := 
    'defaults: &defaults' + sLineBreak +
    '  name: John' + sLineBreak +
    '  age: 30' + sLineBreak +
    'person:' + sLineBreak +
    '  <<: *defaults' + sLineBreak +
    '  city: New York';

  document := TYAML.LoadFromString(yamlContent);
  Assert.IsNotNull(document, 'Document should not be null');
  Assert.IsTrue(document.Root.IsMapping, 'Root should be a mapping');
  
  root := document.Root.AsMapping;
  Assert.IsTrue(root.ContainsKey('person'), 'Should have person key');
  
  person := root.Values['person'].AsMapping;
  Assert.AreEqual('John', person.Values['name'].AsString, 'Name should be merged from defaults');
  Assert.AreEqual<Int64>(30, person.Values['age'].AsInteger, 'Age should be merged from defaults');
  Assert.AreEqual('New York', person.Values['city'].AsString, 'City should be from person');
  Assert.AreEqual<Int64>(3, person.Count, 'Person should have 3 properties');
end;

procedure TYAMLMergeKeyTests.Test_MergeKey_MultipleAliases;
var
  yamlContent: string;
  document: IYAMLDocument;
  root: IYAMLMapping;
  result: IYAMLMapping;
begin
  yamlContent := 
    'base: &base' + sLineBreak +
    '  name: Base' + sLineBreak +
    '  type: foundation' + sLineBreak +
    'extra: &extra' + sLineBreak +
    '  color: blue' + sLineBreak +
    '  size: large' + sLineBreak +
    'combined:' + sLineBreak +
    '  <<: *base' + sLineBreak +
    '  <<: *extra' + sLineBreak +
    '  priority: high';

  document := TYAML.LoadFromString(yamlContent);
  Assert.IsNotNull(document, 'Document should not be null');
  
  root := document.Root.AsMapping;
  result := root.Values['combined'].AsMapping;
  
  Assert.AreEqual('Base', result.Values['name'].AsString, 'Should have name from base');
  Assert.AreEqual('foundation', result.Values['type'].AsString, 'Should have type from base');
  Assert.AreEqual('blue', result.Values['color'].AsString, 'Should have color from extra');
  Assert.AreEqual('large', result.Values['size'].AsString, 'Should have size from extra');
  Assert.AreEqual('high', result.Values['priority'].AsString, 'Should have priority from combined');
  Assert.AreEqual(5, result.Count, 'Combined should have 5 properties');
end;

procedure TYAMLMergeKeyTests.Test_MergeKey_NestedMappings;
var
  yamlContent: string;
  document: IYAMLDocument;
  root: IYAMLMapping;
  child: IYAMLMapping;
  address: IYAMLMapping;
begin
  yamlContent := 
    'address_defaults: &address' + sLineBreak +
    '  country: USA' + sLineBreak +
    '  postal_code: "00000"' + sLineBreak +
    'person:' + sLineBreak +
    '  name: Alice' + sLineBreak +
    '  address:' + sLineBreak +
    '    <<: *address' + sLineBreak +
    '    city: Boston' + sLineBreak +
    '    state: MA';

  document := TYAML.LoadFromString(yamlContent);
  Assert.IsNotNull(document, 'Document should not be null');
  
  root := document.Root.AsMapping;
  child := root.Values['person'].AsMapping;
  address := child.Values['address'].AsMapping;
  
  Assert.AreEqual('USA', address.Values['country'].AsString, 'Should have country from defaults');
  Assert.AreEqual('00000', address.Values['postal_code'].AsString, 'Should have postal_code from defaults');
  Assert.AreEqual('Boston', address.Values['city'].AsString, 'Should have city from address');
  Assert.AreEqual('MA', address.Values['state'].AsString, 'Should have state from address');
  Assert.AreEqual(4, address.Count, 'Address should have 4 properties');
end;

procedure TYAMLMergeKeyTests.Test_MergeKey_OverrideValues;
var
  yamlContent: string;
  document: IYAMLDocument;
  root: IYAMLMapping;
  config: IYAMLMapping;
begin
  yamlContent := 
    'defaults: &defaults' + sLineBreak +
    '  debug: true' + sLineBreak +
    '  timeout: 30' + sLineBreak +
    '  retries: 3' + sLineBreak +
    'production_config:' + sLineBreak +
    '  <<: *defaults' + sLineBreak +
    '  debug: false' + sLineBreak +
    '  timeout: 60';

  document := TYAML.LoadFromString(yamlContent);
  Assert.IsNotNull(document, 'Document should not be null');
  
  root := document.Root.AsMapping;
  config := root.Values['production_config'].AsMapping;
  
  Assert.AreEqual(False, config.Values['debug'].AsBoolean, 'Debug should be overridden to false');
  Assert.AreEqual<Int64>(60, config.Values['timeout'].AsInteger, 'Timeout should be overridden to 60');
  Assert.AreEqual<Int64>(3, config.Values['retries'].AsInteger, 'Retries should be from defaults');
  Assert.AreEqual<Int64>(3, config.Count, 'Config should have 3 properties');
end;

procedure TYAMLMergeKeyTests.Test_MergeKey_EmptyMapping;
var
  yamlContent: string;
  document: IYAMLDocument;
  root: IYAMLMapping;
  result: IYAMLMapping;
begin
  yamlContent := 
    'empty: &empty {}' + sLineBreak +
    'test:' + sLineBreak +
    '  <<: *empty' + sLineBreak +
    '  value: 42';

  document := TYAML.LoadFromString(yamlContent);
  Assert.IsNotNull(document, 'Document should not be null');
  
  root := document.Root.AsMapping;
  result := root.Values['test'].AsMapping;
  
  Assert.AreEqual<Int64>(42, result.Values['value'].AsInteger, 'Should have value property');
  Assert.AreEqual<Int64>(1, result.Count, 'Test should have only 1 property');
end;

procedure TYAMLMergeKeyTests.Test_MergeKey_WithSequence;
var
  yamlContent: string;
  document: IYAMLDocument;
  root: IYAMLMapping;
  config: IYAMLMapping;
  servers: IYAMLSequence;
begin
  yamlContent := 
    'base_config: &base' + sLineBreak +
    '  enabled: true' + sLineBreak +
    '  servers:' + sLineBreak +
    '    - server1' + sLineBreak +
    '    - server2' + sLineBreak +
    'extended_config:' + sLineBreak +
    '  <<: *base' + sLineBreak +
    '  max_connections: 100';

  document := TYAML.LoadFromString(yamlContent);
  Assert.IsNotNull(document, 'Document should not be null');
  
  root := document.Root.AsMapping;
  config := root.Values['extended_config'].AsMapping;
  
  Assert.AreEqual(True, config.Values['enabled'].AsBoolean, 'Should have enabled from base');
  Assert.AreEqual<Int64>(100, config.Values['max_connections'].AsInteger, 'Should have max_connections');
  Assert.IsTrue(config.Values['servers'].IsSequence, 'Servers should be a sequence');
  
  servers := config.Values['servers'].AsSequence;
  Assert.AreEqual<Int64>(2, servers.Count, 'Servers should have 2 items');
  Assert.AreEqual('server1', servers.Items[0].AsString, 'First server should be server1');
  Assert.AreEqual('server2', servers.Items[1].AsString, 'Second server should be server2');
end;

procedure TYAMLMergeKeyTests.Test_MergeKey_MultipleReferences;
var
  yamlContent: string;
  document: IYAMLDocument;
  root: IYAMLMapping;
  result: IYAMLMapping;
begin
  yamlContent := 
    'ref1: &ref1' + sLineBreak +
    '  a: 1' + sLineBreak +
    '  b: 2' + sLineBreak +
    'ref2: &ref2' + sLineBreak +
    '  c: 3' + sLineBreak +
    '  d: 4' + sLineBreak +
    'ref3: &ref3' + sLineBreak +
    '  e: 5' + sLineBreak +
    'merged:' + sLineBreak +
    '  <<: *ref1' + sLineBreak +
    '  <<: *ref2' + sLineBreak +
    '  <<: *ref3' + sLineBreak +
    '  f: 6';

  document := TYAML.LoadFromString(yamlContent);
  Assert.IsNotNull(document, 'Document should not be null');
  
  root := document.Root.AsMapping;
  result := root.Values['merged'].AsMapping;
  
  Assert.AreEqual<Int64>(1, result.Values['a'].AsInteger, 'Should have a from ref1');
  Assert.AreEqual<Int64>(2, result.Values['b'].AsInteger, 'Should have b from ref1');
  Assert.AreEqual<Int64>(3, result.Values['c'].AsInteger, 'Should have c from ref2');
  Assert.AreEqual<Int64>(4, result.Values['d'].AsInteger, 'Should have d from ref2');
  Assert.AreEqual<Int64>(5, result.Values['e'].AsInteger, 'Should have e from ref3');
  Assert.AreEqual<Int64>(6, result.Values['f'].AsInteger, 'Should have f from merged');
  Assert.AreEqual<Int64>(6, result.Count, 'Merged should have 6 properties');
end;

procedure TYAMLMergeKeyTests.Test_MergeKey_DeepNesting;
var
  yamlContent: string;
  document: IYAMLDocument;
  root: IYAMLMapping;
  app: IYAMLMapping;
  database: IYAMLMapping;
  connection: IYAMLMapping;
begin
  yamlContent := 
    'db_defaults: &db_defaults' + sLineBreak +
    '  host: localhost' + sLineBreak +
    '  port: 5432' + sLineBreak +
    '  ssl: true' + sLineBreak +
    'application:' + sLineBreak +
    '  name: MyApp' + sLineBreak +
    '  database:' + sLineBreak +
    '    connection:' + sLineBreak +
    '      <<: *db_defaults' + sLineBreak +
    '      database: production' + sLineBreak +
    '      username: admin';

  document := TYAML.LoadFromString(yamlContent);
  Assert.IsNotNull(document, 'Document should not be null');
  
  root := document.Root.AsMapping;
  app := root.Values['application'].AsMapping;
  database := app.Values['database'].AsMapping;
  connection := database.Values['connection'].AsMapping;
  
  Assert.AreEqual('localhost', connection.Values['host'].AsString, 'Should have host from defaults');
  Assert.AreEqual<Int64>(5432, connection.Values['port'].AsInteger, 'Should have port from defaults');
  Assert.AreEqual(True, connection.Values['ssl'].AsBoolean, 'Should have ssl from defaults');
  Assert.AreEqual('production', connection.Values['database'].AsString, 'Should have database name');
  Assert.AreEqual('admin', connection.Values['username'].AsString, 'Should have username');
  Assert.AreEqual<Int64>(5, connection.Count, 'Connection should have 5 properties');
end;

procedure TYAMLMergeKeyTests.Test_MergeKey_CircularReference;
var
  yamlContent: string;
  document: IYAMLDocument;
  root: IYAMLMapping;
  first: IYAMLMapping;
begin
  yamlContent := 
    'first: &first' + sLineBreak +
    '  name: first' + sLineBreak +
    '  <<: *second' + sLineBreak +
    'second: &second' + sLineBreak +
    '  name: second' + sLineBreak +
    '  <<: *first';

  try
    document := TYAML.LoadFromString(yamlContent);
    // If we get here, the parser handled circular references gracefully
    // Let's verify the structure makes sense
    Assert.IsNotNull(document, 'Document should not be null');
    root := document.Root.AsMapping;
    first := root.Values['first'].AsMapping;
    Assert.IsTrue(first.ContainsKey('name'), 'First should have name property');
  except
    on E: Exception do
    begin
      // It's acceptable for the parser to throw an exception on circular references
      Assert.IsTrue(True, 'Parser correctly detected circular reference: ' + E.Message);
    end;
  end;
end;

procedure TYAMLMergeKeyTests.Test_MergeKey_InvalidReference;
var
  yamlContent: string;
begin
  yamlContent := 
    'test:' + sLineBreak +
    '  <<: *nonexistent' + sLineBreak +
    '  value: 42';

  try
    TYAML.LoadFromString(yamlContent);
    Assert.Fail('Should have thrown exception for invalid reference');
  except
    on E: Exception do
    begin
      // Expected behavior - should throw exception for nonexistent reference
      Assert.IsTrue(True, 'Parser correctly threw exception for invalid reference: ' + E.Message);
    end;
  end;
end;

procedure TYAMLMergeKeyTests.Test_MergeKey_CopiesScalarsExactly;
var
  yamlContent: string;
  document: IYAMLDocument;
  child: IYAMLMapping;
begin
  // Merged scalars are copies with the original text, type and tag - not values re-made
  // through Int64 / Double, which raised on the integer and dropped digits of the decimal.
  yamlContent :=
    'base: &base' + sLineBreak +
    '  big: 18446744073709551615' + sLineBreak +
    '  decimal: 1234567890123456789012345678.9012345678' + sLineBreak +
    '  flag: yes' + sLineBreak +
    '  tagged: !!str 42' + sLineBreak +
    'child:' + sLineBreak +
    '  <<: *base' + sLineBreak +
    '  own: 1';

  document := TYAML.LoadFromString(yamlContent);
  child := document.AsMapping.Items['child'].AsMapping;

  Assert.IsTrue(child.Items['big'].IsInteger, 'big');
  Assert.AreEqual('18446744073709551615', child.Items['big'].RawValue);
  Assert.IsTrue(child.Items['decimal'].IsFloat, 'decimal');
  Assert.AreEqual('1234567890123456789012345678.9012345678', child.Items['decimal'].RawValue);
  Assert.IsTrue(child.Items['flag'].IsBoolean, 'flag');
  Assert.AreEqual('yes', child.Items['flag'].RawValue);
  Assert.IsTrue(child.Items['tagged'].IsString, 'tagged');
  Assert.AreEqual('!!str', child.Items['tagged'].Tag);
  Assert.AreEqual(1, Integer(child.Items['own'].AsInteger));
end;

initialization
  TDUnitX.RegisterTestFixture(TYAMLMergeKeyTests);

end.
unit VSoft.YAML.Tests.Comments;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TYAMLCommentTests = class

  public

    [Test]
    procedure TestSameLineCommentOnScalar;

    [Test]
    procedure TestSameLineCommentOnMapping;

    [Test]
    procedure TestPreCollectionCommentsOnMapping;

    [Test]
    procedure TestPreCollectionCommentsOnSequence;

    [Test]
    procedure TestMultiplePreCollectionComments;

    [Test]
    procedure TestMixedCommentScenarios;

    [Test]
    procedure TestCommentRoundTrip;

    [Test]
    procedure TestCommentInFlowStyle;

    [Test]
    procedure TestCommentWhitespaceHandling;

    [Test]
    procedure TestEmptyComments;

    [Test]
    procedure TestCommentPreservationInNestedStructures;

    [Test]
    procedure TestCompleteCommentRoundTripIntegration;

    [Test]
    procedure TestDocumentLevelCommentOnFlatMapping;

  end;

implementation

uses 
  VSoft.YAML,
  System.SysUtils;

{ TYAMLCommentTests }

procedure TYAMLCommentTests.TestSameLineCommentOnScalar;
var
  yamlText: string;
  doc: IYAMLDocument;
  root: IYAMLMapping;
begin
  yamlText := 
    'name: John Doe  # Person''s full name' + sLineBreak +
    'age: 30        # Age in years' + sLineBreak +
    'active: true   # Is currently active';

  doc := TYAML.LoadFromString(yamlText);
  root := doc.Root.AsMapping;

  // Test that same-line comments are preserved
  Assert.AreEqual('Person''s full name', root.Items['name'].Comment, 'Name comment not preserved');
  Assert.AreEqual('Age in years', root.Items['age'].Comment, 'Age comment not preserved');
  Assert.AreEqual('Is currently active', root.Items['active'].Comment, 'Active comment not preserved');
end;

procedure TYAMLCommentTests.TestSameLineCommentOnMapping;
var
  yamlText: string;
  doc: IYAMLDocument;
  root: IYAMLMapping;
  address: IYAMLMapping;
begin
  yamlText := 
    'address:' + sLineBreak +
    '  street: 123 Main St    # Street address' + sLineBreak +
    '  city: Springfield      # City name' + sLineBreak +
    '  zip: 62701            # Postal code';

  doc := TYAML.LoadFromString(yamlText);
  root := doc.Root.AsMapping;
  address := root.Items['address'].AsMapping;

  // Test that same-line comments on nested mapping values are preserved
  Assert.AreEqual('Street address', address.Items['street'].Comment, 'Street comment not preserved');
  Assert.AreEqual('City name', address.Items['city'].Comment, 'City comment not preserved');
  Assert.AreEqual('Postal code', address.Items['zip'].Comment, 'Zip comment not preserved');
end;

procedure TYAMLCommentTests.TestPreCollectionCommentsOnMapping;
var
  yamlText: string;
  doc: IYAMLDocument;
  root: IYAMLMapping;
  address: IYAMLMapping;
begin
  yamlText := 
    '# Personal information' + sLineBreak +
    '# Contact details follow' + sLineBreak +
    'address:' + sLineBreak +
    '  street: 123 Main St' + sLineBreak +
    '  city: Springfield';

  doc := TYAML.LoadFromString(yamlText);
  root := doc.Root.AsMapping;
  address := root.Items['address'].AsMapping;

  // Test that pre-collection comments are preserved
  Assert.IsTrue(address.HasComments, 'Address mapping should have comments');
  Assert.AreEqual(2, address.Comments.Count, 'Should have 2 pre-collection comments');
  Assert.AreEqual('Personal information', address.Comments[0], 'First comment not preserved');
  Assert.AreEqual('Contact details follow', address.Comments[1], 'Second comment not preserved');
end;

procedure TYAMLCommentTests.TestPreCollectionCommentsOnSequence;
var
  yamlText: string;
  doc: IYAMLDocument;
  root: IYAMLMapping;
  hobbies: IYAMLSequence;
begin
  yamlText := 
    '# List of favorite hobbies' + sLineBreak +
    '# In order of preference' + sLineBreak +
    'hobbies:' + sLineBreak +
    '  - reading' + sLineBreak +
    '  - swimming' + sLineBreak +
    '  - cooking';

  doc := TYAML.LoadFromString(yamlText);
  root := doc.Root.AsMapping;
  hobbies := root.Items['hobbies'].AsSequence;

  // Test that pre-collection comments are preserved on sequences
  Assert.IsTrue(hobbies.HasComments, 'Hobbies sequence should have comments');
  Assert.AreEqual(2, hobbies.Comments.Count, 'Should have 2 pre-collection comments');
  Assert.AreEqual('List of favorite hobbies', hobbies.Comments[0], 'First comment not preserved');
  Assert.AreEqual('In order of preference', hobbies.Comments[1], 'Second comment not preserved');
end;

procedure TYAMLCommentTests.TestMultiplePreCollectionComments;
var
  yamlText: string;
  doc: IYAMLDocument;
  root: IYAMLMapping;
  config: IYAMLMapping;
begin
  yamlText := 
    '# Application configuration' + sLineBreak +
    '# These settings control behavior' + sLineBreak +
    '# Modify with care' + sLineBreak +
    '# Version: 1.0' + sLineBreak +
    'config:' + sLineBreak +
    '  debug: true' + sLineBreak +
    '  timeout: 30';

  doc := TYAML.LoadFromString(yamlText);
  root := doc.Root.AsMapping;
  config := root.Items['config'].AsMapping;

  // Test multiple pre-collection comments
  Assert.IsTrue(config.HasComments, 'Config mapping should have comments');
  Assert.AreEqual(4, config.Comments.Count, 'Should have 4 pre-collection comments');
  Assert.AreEqual('Application configuration', config.Comments[0], 'First comment not preserved');
  Assert.AreEqual('These settings control behavior', config.Comments[1], 'Second comment not preserved');
  Assert.AreEqual('Modify with care', config.Comments[2], 'Third comment not preserved');
  Assert.AreEqual('Version: 1.0', config.Comments[3], 'Fourth comment not preserved');
end;

procedure TYAMLCommentTests.TestMixedCommentScenarios;
var
  yamlText: string;
  doc: IYAMLDocument;
  root: IYAMLMapping;
  person: IYAMLMapping;
  hobbies: IYAMLSequence;
begin
  yamlText := 
    '# Document header comment' + sLineBreak +
    'person:' + sLineBreak +
    '  name: John Doe      # Full name' + sLineBreak +
    '  age: 30            # Current age' + sLineBreak +
    '  # Person''s hobbies below' + sLineBreak +
    '  hobbies:' + sLineBreak +
    '    - reading         # Loves books' + sLineBreak +
    '    - swimming        # Good exercise';

  doc := TYAML.LoadFromString(yamlText);
  root := doc.Root.AsMapping;
  person := root.Items['person'].AsMapping;
  hobbies := person.Items['hobbies'].AsSequence;

  // Test mixed scenarios: same-line + pre-collection
  Assert.AreEqual('Full name', person.Items['name'].Comment, 'Name same-line comment not preserved');
  Assert.AreEqual('Current age', person.Items['age'].Comment, 'Age same-line comment not preserved');
  
  Assert.IsTrue(hobbies.HasComments, 'Hobbies sequence should have pre-collection comments');
  Assert.AreEqual(1, hobbies.Comments.Count, 'Should have 1 pre-collection comment');
  Assert.AreEqual('Person''s hobbies below', hobbies.Comments[0], 'Pre-collection comment not preserved');
  
  Assert.AreEqual('Loves books', hobbies.Items[0].Comment, 'First hobby comment not preserved');
  Assert.AreEqual('Good exercise', hobbies.Items[1].Comment, 'Second hobby comment not preserved');
end;

procedure TYAMLCommentTests.TestCommentRoundTrip;
var
  yamlText: string;
  doc: IYAMLDocument;
  outputText: string;
begin
  yamlText := 
    '# Configuration file' + sLineBreak +
    'name: Test App      # Application name' + sLineBreak +
    'version: 1.0        # Version number' + sLineBreak +
    '# Database settings' + sLineBreak +
    'database:' + sLineBreak +
    '  host: localhost   # Database host' + sLineBreak +
    '  port: 5432        # Database port';

  doc := TYAML.LoadFromString(yamlText);
  outputText := TYAML.WriteToString(doc);

  // Test that comments are preserved in output
  Assert.IsTrue(outputText.Contains('# Application name'), 'Same-line comment missing from output');
  Assert.IsTrue(outputText.Contains('# Version number'), 'Version comment missing from output');
  Assert.IsTrue(outputText.Contains('# Database settings'), 'Pre-collection comment missing from output');
  Assert.IsTrue(outputText.Contains('# Database host'), 'Database host comment missing from output');
  Assert.IsTrue(outputText.Contains('# Database port'), 'Database port comment missing from output');
end;

procedure TYAMLCommentTests.TestCommentInFlowStyle;
var
  yamlText: string;
  doc: IYAMLDocument;
  root: IYAMLMapping;
begin
  yamlText := 
    'point: [1, 2, 3]     # 3D coordinates' + sLineBreak +
    'config: {debug: true, timeout: 30}  # App settings';

  doc := TYAML.LoadFromString(yamlText);
  root := doc.Root.AsMapping;

  // Test same-line comments on flow style collections
  Assert.AreEqual('3D coordinates', root.Items['point'].Comment, 'Flow sequence comment not preserved');
  Assert.AreEqual('App settings', root.Items['config'].Comment, 'Flow mapping comment not preserved');
end;

procedure TYAMLCommentTests.TestCommentWhitespaceHandling;
var
  yamlText: string;
  doc: IYAMLDocument;
  root: IYAMLMapping;
begin
  yamlText := 
    'test1: value1    #    Comment with extra spaces   ' + sLineBreak +
    'test2: value2#No space before hash' + sLineBreak +
    'test3: value3 #Normal comment';

  doc := TYAML.LoadFromString(yamlText);
  root := doc.Root.AsMapping;

  // Test that comment whitespace is handled correctly
  Assert.AreEqual('Comment with extra spaces', root.Items['test1'].Comment.Trim, 'Extra spaces not trimmed from comment');
  Assert.AreEqual('No space before hash', root.Items['test2'].Comment, 'Comment without space not handled');
  Assert.AreEqual('Normal comment', root.Items['test3'].Comment, 'Normal comment not preserved');
end;

procedure TYAMLCommentTests.TestEmptyComments;
var
  yamlText: string;
  doc: IYAMLDocument;
  root: IYAMLMapping;
begin
  yamlText := 
    'test1: value1    #' + sLineBreak +
    'test2: value2    #   ' + sLineBreak +
    'test3: value3    # ';

  doc := TYAML.LoadFromString(yamlText);
  root := doc.Root.AsMapping;

  // Test that empty or whitespace-only comments are handled
  Assert.AreEqual('', root.Items['test1'].Comment, 'Empty comment should be empty string');
  Assert.AreEqual('', root.Items['test2'].Comment.Trim, 'Whitespace-only comment should trim to empty');
  Assert.AreEqual('', root.Items['test3'].Comment.Trim, 'Single space comment should trim to empty');
end;

procedure TYAMLCommentTests.TestCommentPreservationInNestedStructures;
var
  yamlText: string;
  doc: IYAMLDocument;
  root: IYAMLMapping;
  app: IYAMLMapping;
  db: IYAMLMapping;
  servers: IYAMLSequence;
begin
  yamlText := 
    '# Application configuration' + sLineBreak +
    'app:' + sLineBreak +
    '  name: MyApp          # Application name' + sLineBreak +
    '  # Database configuration' + sLineBreak +
    '  database:' + sLineBreak +
    '    host: localhost    # DB host' + sLineBreak +
    '    port: 5432         # DB port' + sLineBreak +
    '  # List of backup servers' + sLineBreak +
    '  servers:' + sLineBreak +
    '    - server1          # Primary' + sLineBreak +
    '    - server2          # Secondary';

  doc := TYAML.LoadFromString(yamlText);
  root := doc.Root.AsMapping;
  app := root.Items['app'].AsMapping;
  db := app.Items['database'].AsMapping;
  servers := app.Items['servers'].AsSequence;

  // Test deeply nested comment preservation
  Assert.IsTrue(app.HasComments, 'App should have pre-collection comments');
  Assert.AreEqual('Application configuration', app.Comments[0], 'App comment not preserved');
  
  Assert.AreEqual('Application name', app.Items['name'].Comment, 'App name comment not preserved');
  
  Assert.IsTrue(db.HasComments, 'Database should have pre-collection comments');
  Assert.AreEqual('Database configuration', db.Comments[0], 'Database comment not preserved');
  
  Assert.AreEqual('DB host', db.Items['host'].Comment, 'Database host comment not preserved');
  Assert.AreEqual('DB port', db.Items['port'].Comment, 'Database port comment not preserved');
  
  Assert.IsTrue(servers.HasComments, 'Servers should have pre-collection comments');
  Assert.AreEqual('List of backup servers', servers.Comments[0], 'Servers comment not preserved');
  
  Assert.AreEqual('Primary', servers.Items[0].Comment, 'First server comment not preserved');
  Assert.AreEqual('Secondary', servers.Items[1].Comment, 'Second server comment not preserved');
end;

procedure TYAMLCommentTests.TestCompleteCommentRoundTripIntegration;
var
  doc: IYAMLDocument;
  outputText: string;
  roundTripDoc: IYAMLDocument;
  app: IYAMLMapping;
  db: IYAMLMapping;
  features: IYAMLSequence;
begin
  // Load the comprehensive test file
  {$IFDEF POSIX}
  doc := TYAML.LoadFromFile('./test_comment_sample.yaml');
  {$ELSE}
  doc := TYAML.LoadFromFile('..\..\testfiles\test_comment_sample.yaml');
  {$ENDIF}

  // Write it back to string
  outputText := TYAML.WriteToString(doc);
  
  // Parse the output again to ensure round-trip compatibility
  roundTripDoc := TYAML.LoadFromString(outputText);
  app := roundTripDoc.Root.AsMapping.Items['application'].AsMapping;
  db := roundTripDoc.Root.AsMapping.Items['database'].AsMapping;
  features := roundTripDoc.Root.AsMapping.Items['features'].AsSequence;
  
  // Verify that comments survived the round trip
  Assert.AreEqual('Application name', app.Items['name'].Comment, 'App name comment lost in round trip');
  Assert.AreEqual('Semantic version', app.Items['version'].Comment, 'Version comment lost in round trip');
  Assert.AreEqual('Enable debug mode', app.Items['debug'].Comment, 'Debug comment lost in round trip');
  
  // Check pre-collection comments
  Assert.IsTrue(db.HasComments, 'Database pre-collection comments lost in round trip');
  Assert.AreEqual('Database configuration section', db.Comments[0], 'Database pre-collection comment lost');
  
  Assert.IsTrue(features.HasComments, 'Features pre-collection comments lost in round trip');
  Assert.AreEqual('List of enabled features', features.Comments[0], 'Features pre-collection comment lost');
  
  // Check that the output contains the expected comment markers
  Assert.IsTrue(outputText.Contains('# Application name'), 'Output missing same-line comment marker');
  Assert.IsTrue(outputText.Contains('# Database configuration section'), 'Output missing pre-collection comment');
  Assert.IsTrue(outputText.Contains('# List of enabled features'), 'Output missing sequence pre-collection comment');
  
  // Verify the structure is preserved
  Assert.AreEqual('Test App', app.Items['name'].AsString, 'App name value changed in round trip');
  Assert.AreEqual('1.2.3', app.Items['version'].AsString, 'Version value changed in round trip');
  Assert.AreEqual(3, features.Count, 'Features count changed in round trip');
end;

procedure TYAMLCommentTests.TestDocumentLevelCommentOnFlatMapping;
var
  yamlText : string;
  doc : IYAMLDocument;
  root : IYAMLMapping;
  outputText : string;
begin
  // A comment at the top of a document that contains only scalar values
  // (no nested collections) must be preserved on the root mapping.
  yamlText :=
    '# comment' + sLineBreak +
    'name: John Doe' + sLineBreak +
    'age: 30';

  doc := TYAML.LoadFromString(yamlText);
  root := doc.Root.AsMapping;

  Assert.IsTrue(root.HasComments,
    'Root mapping should have the document-level comment');
  Assert.AreEqual(1, root.Comments.Count,
    'Root mapping should have exactly 1 comment');
  Assert.AreEqual('comment', root.Comments[0],
    'Comment text should be preserved');

  // Also verify the comment survives a write/read round-trip
  outputText := TYAML.WriteToString(doc);
  Assert.IsTrue(outputText.Contains('# comment'),
    'Comment must appear in written output');
end;

initialization
  TDUnitX.RegisterTestFixture(TYAMLCommentTests);
end.
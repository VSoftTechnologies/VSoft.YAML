unit VSoft.YAML.Tests.Performance;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Diagnostics,
  VSoft.YAML;

type
  [TestFixture]
  TPerformanceTests = class
  private
    FTestFilesPath: string;
  public
    [Setup]
    procedure Setup;

    [Test]
    procedure TestLargeYAMLFileParsing;

    [Test]
    procedure TestLargeJSONFileParsing;

    [Test]
    procedure TestScalarValuePerformance;

    [Test]
    procedure TestTimestampPerformance;

    [Test]
    procedure TestNestedStructurePerformance;

    [Test]
    procedure TestJSONTestFile;

    [Test]
    procedure TestBlockScalarsParsing;

    [Test]
    procedure TestQuotedStringsParsing;

    [Test]
    procedure TestYAMLWriterPerformance;

    [Test]
    procedure TestJSONWriterPerformance;

    [Test]
    procedure TestYAMLWriterWithCommentsPerformance;

    [Test]
    procedure TestLoadTestJSONFile;
  end;

implementation

uses
  System.IOUtils,
  System.Classes;

{ TPerformanceTests }

procedure TPerformanceTests.Setup;
begin
  FTestFilesPath := TPath.Combine(ExtractFilePath(ParamStr(0)), '..\..\TestFiles');
end;

procedure TPerformanceTests.TestLargeYAMLFileParsing;
var
  yamlFile: string;
  doc: IYAMLDocument;
  stopwatch: TStopwatch;
  elapsedTicks: Int64;
  elapsedMs: Double;
  fileSize: Int64;
  users: IYAMLSequence;
  userCount: Integer;
begin
  yamlFile := TPath.Combine(FTestFilesPath, 'benchmark_large.yaml');

  if not FileExists(yamlFile) then
  begin
    Assert.Fail('Benchmark file not found: ' + yamlFile);
    Exit;
  end;

  fileSize := TFile.GetSize(yamlFile);

  // Parse the YAML file
  stopwatch := TStopwatch.StartNew;
  doc := TYAML.LoadFromFile(yamlFile);
  stopwatch.Stop;
  elapsedTicks := stopwatch.ElapsedTicks;
  elapsedMs := (elapsedTicks * 1000.0) / TStopwatch.Frequency;

  // Verify we parsed something
  Assert.IsNotNull(doc, 'Document should not be null');
  Assert.IsNotNull(doc.Root, 'Document root should not be null');

  // Try to access some data to ensure it's valid
  if doc.Root.IsMapping then
  begin
    if doc.Root.AsMapping.ContainsKey('users') then
    begin
      users := doc.Root.AsMapping.Values['users'].AsSequence;
      userCount := users.Count;
      Assert.IsTrue(userCount > 0, 'Should have parsed users');

      // Access some nested data
      if userCount > 0 then
      begin
        Assert.IsTrue(users[0].IsMapping, 'First user should be a mapping');
      end;
    end;
  end;

  // Output performance metrics
  WriteLn('');
  WriteLn('=== YAML Parsing Performance ===');
  WriteLn('File size: ' + IntToStr(fileSize div 1024) + ' KB');
  WriteLn('Parse time: ' + FormatFloat('0.00', elapsedMs) + ' ms');
  if elapsedMs > 0 then
    WriteLn('Throughput: ' + FormatFloat('0.00', (fileSize / 1024.0) / (elapsedMs / 1000.0)) + ' KB/s')
  else
    WriteLn('Throughput: Very fast (< 0.01 ms)');
  WriteLn('');

  // Assert reasonable performance
  Assert.IsTrue(elapsedMs < 10000, 'Parse should complete in less than 10 seconds');
end;

procedure TPerformanceTests.TestLargeJSONFileParsing;
var
  jsonFile: string;
  doc: IYAMLDocument;
  options: IYAMLParserOptions;
  stopwatch: TStopwatch;
  elapsedTicks: Int64;
  elapsedMs: Double;
  fileSize: Int64;
  users: IYAMLSequence;
  userCount: Integer;
begin
  jsonFile := TPath.Combine(FTestFilesPath, 'benchmark_large.json');

  if not FileExists(jsonFile) then
  begin
    Assert.Fail('Benchmark file not found: ' + jsonFile);
    Exit;
  end;

  fileSize := TFile.GetSize(jsonFile);

  // Create options for JSON mode
  options := TYAML.CreateParserOptions;
  options.JSONMode := true;

  // Parse the JSON file
  stopwatch := TStopwatch.StartNew;
  doc := TYAML.LoadFromFile(jsonFile, options);
  stopwatch.Stop;
  elapsedTicks := stopwatch.ElapsedTicks;
  elapsedMs := (elapsedTicks * 1000.0) / TStopwatch.Frequency;

  // Verify we parsed something
  Assert.IsNotNull(doc, 'Document should not be null');
  Assert.IsNotNull(doc.Root, 'Document root should not be null');

  // Try to access some data
  if doc.Root.IsMapping then
  begin
    if doc.Root.AsMapping.ContainsKey('users') then
    begin
      users := doc.Root.AsMapping.Values['users'].AsSequence;
      userCount := users.Count;
      Assert.IsTrue(userCount > 0, 'Should have parsed users');

      // Access some nested data
      if userCount > 0 then
      begin
        Assert.IsTrue(users[0].IsMapping, 'First user should be a mapping');
      end;
    end;
  end;

  // Output performance metrics
  WriteLn('');
  WriteLn('=== JSON Parsing Performance ===');
  WriteLn('File size: ' + IntToStr(fileSize div 1024) + ' KB');
  WriteLn('Parse time: ' + FormatFloat('0.00', elapsedMs) + ' ms');
  if elapsedMs > 0 then
    WriteLn('Throughput: ' + FormatFloat('0.00', (fileSize / 1024.0) / (elapsedMs / 1000.0)) + ' KB/s')
  else
    WriteLn('Throughput: Very fast (< 0.01 ms)');
  WriteLn('');

  // Assert reasonable performance
  Assert.IsTrue(elapsedMs < 15000, 'Parse should complete in less than 15 seconds');
end;

procedure TPerformanceTests.TestScalarValuePerformance;
var
  yamlText: string;
  doc: IYAMLDocument;
  stopwatch: TStopwatch;
  elapsed: Int64;
  i: Integer;
  iterations: Integer;
begin
  // Test with various scalar types to exercise IsScalarValue
  yamlText :=
    'booleans:' + sLineBreak +
    '  - true' + sLineBreak +
    '  - false' + sLineBreak +
    '  - yes' + sLineBreak +
    '  - no' + sLineBreak +
    '  - on' + sLineBreak +
    '  - off' + sLineBreak +
    'numbers:' + sLineBreak +
    '  - 42' + sLineBreak +
    '  - -123' + sLineBreak +
    '  - 3.14159' + sLineBreak +
    '  - 1.23e-4' + sLineBreak +
    '  - 0xFF' + sLineBreak +
    '  - 0o77' + sLineBreak +
    '  - 0b1010' + sLineBreak +
    'special:' + sLineBreak +
    '  - .inf' + sLineBreak +
    '  - -.inf' + sLineBreak +
    '  - .nan' + sLineBreak +
    '  - null' + sLineBreak +
    '  - ~' + sLineBreak +
    'strings:' + sLineBreak +
    '  - hello world' + sLineBreak +
    '  - "quoted string"' + sLineBreak;

  iterations := 1000;

  stopwatch := TStopwatch.StartNew;
  for i := 1 to iterations do
  begin
    doc := TYAML.LoadFromString(yamlText);
    Assert.IsNotNull(doc);
  end;
  stopwatch.Stop;
  elapsed := stopwatch.ElapsedMilliseconds;

  WriteLn('');
  WriteLn('=== Scalar Value Parsing Performance ===');
  WriteLn('Iterations: ' + IntToStr(iterations));
  WriteLn('Total time: ' + IntToStr(elapsed) + ' ms');
  WriteLn('Average per iteration: ' + FormatFloat('0.00', elapsed / iterations) + ' ms');
  WriteLn('');

  Assert.IsTrue(elapsed < 5000, 'Should complete ' + IntToStr(iterations) + ' iterations in less than 5 seconds');
end;

procedure TPerformanceTests.TestTimestampPerformance;
var
  yamlText: string;
  doc: IYAMLDocument;
  stopwatch: TStopwatch;
  elapsed: Int64;
  i: Integer;
  iterations: Integer;
begin
  // Test with various timestamp formats
  yamlText :=
    'timestamps:' + sLineBreak +
    '  - 2024-01-15' + sLineBreak +
    '  - 2024-01-15T10:30:00Z' + sLineBreak +
    '  - 2024-01-15 10:30:00' + sLineBreak +
    '  - 2023-12-25T15:45:30Z' + sLineBreak +
    '  - 2023-06-01T08:00:00+05:00' + sLineBreak +
    '  - 2023-03-15T12:00:00-08:00' + sLineBreak;

  iterations := 1000;

  stopwatch := TStopwatch.StartNew;
  for i := 1 to iterations do
  begin
    doc := TYAML.LoadFromString(yamlText);
    Assert.IsNotNull(doc);
  end;
  stopwatch.Stop;
  elapsed := stopwatch.ElapsedMilliseconds;

  WriteLn('');
  WriteLn('=== Timestamp Parsing Performance ===');
  WriteLn('Iterations: ' + IntToStr(iterations));
  WriteLn('Total time: ' + IntToStr(elapsed) + ' ms');
  WriteLn('Average per iteration: ' + FormatFloat('0.00', elapsed / iterations) + ' ms');
  WriteLn('');

  Assert.IsTrue(elapsed < 5000, 'Should complete ' + IntToStr(iterations) + ' iterations in less than 5 seconds');
end;

procedure TPerformanceTests.TestNestedStructurePerformance;
var
  yamlText: string;
  doc: IYAMLDocument;
  stopwatch: TStopwatch;
  elapsed: Int64;
  i: Integer;
  iterations: Integer;
begin
  // Test with deeply nested structures
  yamlText :=
    'level1:' + sLineBreak +
    '  level2:' + sLineBreak +
    '    level3:' + sLineBreak +
    '      level4:' + sLineBreak +
    '        data: value' + sLineBreak +
    '        number: 42' + sLineBreak +
    '        flag: true' + sLineBreak +
    'list:' + sLineBreak +
    '  - item1: value1' + sLineBreak +
    '    nested:' + sLineBreak +
    '      key: val' + sLineBreak +
    '  - item2: value2' + sLineBreak +
    '    nested:' + sLineBreak +
    '      key: val' + sLineBreak;

  iterations := 1000;

  stopwatch := TStopwatch.StartNew;
  for i := 1 to iterations do
  begin
    doc := TYAML.LoadFromString(yamlText);
    Assert.IsNotNull(doc);
  end;
  stopwatch.Stop;
  elapsed := stopwatch.ElapsedMilliseconds;

  WriteLn('');
  WriteLn('=== Nested Structure Parsing Performance ===');
  WriteLn('Iterations: ' + IntToStr(iterations));
  WriteLn('Total time: ' + IntToStr(elapsed) + ' ms');
  WriteLn('Average per iteration: ' + FormatFloat('0.00', elapsed / iterations) + ' ms');
  WriteLn('');

  Assert.IsTrue(elapsed < 5000, 'Should complete ' + IntToStr(iterations) + ' iterations in less than 5 seconds');
end;

procedure TPerformanceTests.TestJSONTestFile;
var
  jsonFile: string;
  doc: IYAMLDocument;
  options: IYAMLParserOptions;
  stopwatch: TStopwatch;
  elapsedTicks: Int64;
  elapsedMs: Double;
  fileSize: Int64;
begin
  jsonFile := TPath.Combine(FTestFilesPath, 'test.json');

  if not FileExists(jsonFile) then
  begin
    Assert.Fail('Test file not found: ' + jsonFile);
    Exit;
  end;

  fileSize := TFile.GetSize(jsonFile);

  // Create options for JSON mode
  options := TYAML.CreateParserOptions;
  options.JSONMode := true;

  // Parse the JSON file
  stopwatch := TStopwatch.StartNew;
  doc := TYAML.LoadFromFile(jsonFile, options);
  stopwatch.Stop;
  elapsedTicks := stopwatch.ElapsedTicks;
  elapsedMs := (elapsedTicks * 1000.0) / TStopwatch.Frequency;

  // Verify we parsed something
  Assert.IsNotNull(doc, 'Document should not be null');
  Assert.IsNotNull(doc.Root, 'Document root should not be null');
  Assert.AreEqual(TYAMLValueType.vtMapping, doc.Root.ValueType, 'Root should be a mapping');

  // Verify it's actually a large mapping with many keys
  Assert.IsTrue(doc.Root.AsMapping.Count > 1000, 'Should have more than 1000 keys');

  // Output performance metrics
  WriteLn('');
  WriteLn('=== JSON Test File Parsing Performance ===');
  WriteLn('File size: ' + IntToStr(fileSize div 1024) + ' KB');
  WriteLn('Parse time: ' + FormatFloat('0.00', elapsedMs) + ' ms');
  if elapsedMs > 0 then
    WriteLn('Throughput: ' + FormatFloat('0.00', (fileSize / 1024.0) / (elapsedMs / 1000.0)) + ' KB/s')
  else
    WriteLn('Throughput: Very fast (< 0.01 ms)');
  WriteLn('');

  // Assert reasonable performance
  Assert.IsTrue(elapsedMs < 10000, 'Parse should complete in less than 10 seconds');
end;

procedure TPerformanceTests.TestBlockScalarsParsing;
var
  yamlFile: string;
  doc: IYAMLDocument;
  stopwatch: TStopwatch;
  elapsedTicks: Int64;
  elapsedMs: Double;
  fileSize: Int64;
  documents: IYAMLSequence;
  docCount: Integer;
begin
  yamlFile := TPath.Combine(FTestFilesPath, 'benchmark_block_scalars.yaml');

  if not FileExists(yamlFile) then
  begin
    Assert.Fail('Benchmark file not found: ' + yamlFile);
    Exit;
  end;

  fileSize := TFile.GetSize(yamlFile);

  // Parse the YAML file with block scalars
  stopwatch := TStopwatch.StartNew;
  try
    doc := TYAML.LoadFromFile(yamlFile);
  except
    on E: Exception do
    begin
      Assert.Fail('Parse failed with: ' + E.ClassName + ': ' + E.Message);
      Exit;
    end;
  end;
  stopwatch.Stop;
  elapsedTicks := stopwatch.ElapsedTicks;
  elapsedMs := (elapsedTicks * 1000.0) / TStopwatch.Frequency;

  // Verify we parsed something
  Assert.IsNotNull(doc, 'Document should not be null');
  Assert.IsNotNull(doc.Root, 'Document root should not be null');

  // Verify the structure
  if doc.Root.IsMapping then
  begin
    if doc.Root.AsMapping.ContainsKey('documents') then
    begin
      documents := doc.Root.AsMapping.Values['documents'].AsSequence;
      docCount := documents.Count;
      Assert.IsTrue(docCount > 0, 'Should have parsed documents');

      // Verify first document has block scalar content
      if docCount > 0 then
      begin
        Assert.IsTrue(documents[0].IsMapping, 'First document should be a mapping');
        Assert.IsTrue(documents[0].AsMapping.ContainsKey('content'), 'Should have content field');
      end;
    end;
  end;

  // Output performance metrics
  WriteLn('');
  WriteLn('=== Block Scalars Parsing Performance ===');
  WriteLn('File size: ' + IntToStr(fileSize div 1024) + ' KB');
  WriteLn('Parse time: ' + FormatFloat('0.00', elapsedMs) + ' ms');
  if elapsedMs > 0 then
    WriteLn('Throughput: ' + FormatFloat('0.00', (fileSize / 1024.0) / (elapsedMs / 1000.0)) + ' KB/s')
  else
    WriteLn('Throughput: Very fast (< 0.01 ms)');
  WriteLn('');

  // Assert reasonable performance
  Assert.IsTrue(elapsedMs < 10000, 'Parse should complete in less than 10 seconds');
end;

procedure TPerformanceTests.TestQuotedStringsParsing;
var
  yamlFile: string;
  doc: IYAMLDocument;
  stopwatch: TStopwatch;
  elapsedTicks: Int64;
  elapsedMs: Double;
  fileSize: Int64;
  strings: IYAMLSequence;
  stringCount: Integer;
begin
  yamlFile := TPath.Combine(FTestFilesPath, 'benchmark_quoted_strings.yaml');

  if not FileExists(yamlFile) then
  begin
    Assert.Fail('Benchmark file not found: ' + yamlFile);
    Exit;
  end;

  fileSize := TFile.GetSize(yamlFile);

  // Parse the YAML file with quoted strings
  stopwatch := TStopwatch.StartNew;
  doc := TYAML.LoadFromFile(yamlFile);
  stopwatch.Stop;
  elapsedTicks := stopwatch.ElapsedTicks;
  elapsedMs := (elapsedTicks * 1000.0) / TStopwatch.Frequency;

  // Verify we parsed something
  Assert.IsNotNull(doc, 'Document should not be null');
  Assert.IsNotNull(doc.Root, 'Document root should not be null');

  // Verify the structure
  if doc.Root.IsMapping then
  begin
    if doc.Root.AsMapping.ContainsKey('strings') then
    begin
      strings := doc.Root.AsMapping.Values['strings'].AsSequence;
      stringCount := strings.Count;
      Assert.IsTrue(stringCount > 0, 'Should have parsed strings');

      // Verify first string entry
      if stringCount > 0 then
      begin
        Assert.IsTrue(strings[0].IsMapping, 'First string entry should be a mapping');
      end;
    end;
  end;

  // Output performance metrics
  WriteLn('');
  WriteLn('=== Quoted Strings Parsing Performance ===');
  WriteLn('File size: ' + IntToStr(fileSize div 1024) + ' KB');
  WriteLn('Parse time: ' + FormatFloat('0.00', elapsedMs) + ' ms');
  if elapsedMs > 0 then
    WriteLn('Throughput: ' + FormatFloat('0.00', (fileSize / 1024.0) / (elapsedMs / 1000.0)) + ' KB/s')
  else
    WriteLn('Throughput: Very fast (< 0.01 ms)');
  WriteLn('');

  // Assert reasonable performance
  Assert.IsTrue(elapsedMs < 10000, 'Parse should complete in less than 10 seconds');
end;

procedure TPerformanceTests.TestYAMLWriterPerformance;
var
  doc: IYAMLDocument;
  root: IYAMLMapping;
  sequence: IYAMLSequence;
  item: IYAMLMapping;
  i: Integer;
  outputYaml: string;
  stopwatch: TStopwatch;
  elapsedTicks: Int64;
  elapsedMs: Double;
  outputSize: Integer;
begin
  // Create a large YAML document with nested structures
  doc := TYAML.CreateMapping;
  root := doc.AsMapping;
  root.AddOrSetValue('title', 'Writer Performance Test');
  root.AddOrSetValue('version', '1.0.0');
  root.AddOrSetValue('timestamp', '2024-01-15T10:30:00Z');

  // Add a large sequence with many items
  sequence := root.AddOrSetSequence('items');
  for i := 0 to 999 do
  begin
    item := sequence.AddMapping;
    item.AddOrSetValue('id', i);
    item.AddOrSetValue('name', 'Item ' + IntToStr(i));
    item.AddOrSetValue('description', 'This is a description for item number ' + IntToStr(i) + ' with some additional text');
    item.AddOrSetValue('active', i mod 2 = 0);
    item.AddOrSetValue('priority', i mod 10);
    item.AddOrSetValue('tags', 'tag1,tag2,tag3');
  end;

  // Measure write performance
  stopwatch := TStopwatch.StartNew;
  outputYaml := TYAML.WriteToString(doc);
  stopwatch.Stop;
  elapsedTicks := stopwatch.ElapsedTicks;
  elapsedMs := (elapsedTicks * 1000.0) / TStopwatch.Frequency;

  outputSize := Length(outputYaml);

  // Verify output
  Assert.IsTrue(outputSize > 0, 'Output should not be empty');
  Assert.IsTrue(Pos('title:', outputYaml) > 0, 'Output should contain title');
  Assert.IsTrue(Pos('items:', outputYaml) > 0, 'Output should contain items');

  // Output performance metrics
  WriteLn('');
  WriteLn('=== YAML Writer Performance ===');
  WriteLn('Items written: 1000');
  WriteLn('Output size: ' + IntToStr(outputSize div 1024) + ' KB');
  WriteLn('Write time: ' + FormatFloat('0.00', elapsedMs) + ' ms');
  if elapsedMs > 0 then
    WriteLn('Throughput: ' + FormatFloat('0.00', (outputSize / 1024.0) / (elapsedMs / 1000.0)) + ' KB/s')
  else
    WriteLn('Throughput: Very fast (< 0.01 ms)');
  WriteLn('');

  // Assert reasonable performance
  Assert.IsTrue(elapsedMs < 5000, 'Write should complete in less than 5 seconds');
end;

procedure TPerformanceTests.TestJSONWriterPerformance;
var
  doc: IYAMLDocument;
  root: IYAMLMapping;
  sequence: IYAMLSequence;
  item: IYAMLMapping;
  i: Integer;
  outputJson: string;
  stopwatch: TStopwatch;
  elapsedTicks: Int64;
  elapsedMs: Double;
  outputSize: Integer;
begin
  // Create a large document similar to YAML test
  doc := TYAML.CreateMapping;
  root := doc.AsMapping;
  root.AddOrSetValue('title', 'JSON Writer Performance Test');
  root.AddOrSetValue('version', '1.0.0');
  root.AddOrSetValue('timestamp', '2024-01-15T10:30:00Z');

  // Add a large sequence with many items
  sequence := root.AddOrSetSequence('items');
  for i := 0 to 999 do
  begin
    item := sequence.AddMapping;
    item.AddOrSetValue('id', i);
    item.AddOrSetValue('name', 'Item ' + IntToStr(i));
    item.AddOrSetValue('description', 'This is a description for item number ' + IntToStr(i) + ' with some additional text');
    item.AddOrSetValue('active', i mod 2 = 0);
    item.AddOrSetValue('priority', i mod 10);
    item.AddOrSetValue('tags', 'tag1,tag2,tag3');
  end;

  // Enable pretty print
  doc.Options.PrettyPrint := True;
  doc.Options.IndentSize := 2;

  // Measure write performance
  stopwatch := TStopwatch.StartNew;
  outputJson := TYAML.WriteToJSONString(doc);
  stopwatch.Stop;
  elapsedTicks := stopwatch.ElapsedTicks;
  elapsedMs := (elapsedTicks * 1000.0) / TStopwatch.Frequency;

  outputSize := Length(outputJson);

  // Verify output
  Assert.IsTrue(outputSize > 0, 'Output should not be empty');
  Assert.IsTrue(Pos('"title":', outputJson) > 0, 'Output should contain title');
  Assert.IsTrue(Pos('"items":', outputJson) > 0, 'Output should contain items');

  // Output performance metrics
  WriteLn('');
  WriteLn('=== JSON Writer Performance ===');
  WriteLn('Items written: 1000');
  WriteLn('Output size: ' + IntToStr(outputSize div 1024) + ' KB');
  WriteLn('Write time: ' + FormatFloat('0.00', elapsedMs) + ' ms');
  if elapsedMs > 0 then
    WriteLn('Throughput: ' + FormatFloat('0.00', (outputSize / 1024.0) / (elapsedMs / 1000.0)) + ' KB/s')
  else
    WriteLn('Throughput: Very fast (< 0.01 ms)');
  WriteLn('');

  // Assert reasonable performance
  Assert.IsTrue(elapsedMs < 5000, 'Write should complete in less than 5 seconds');
end;

procedure TPerformanceTests.TestYAMLWriterWithCommentsPerformance;
var
  doc: IYAMLDocument;
  root: IYAMLMapping;
  sequence: IYAMLSequence;
  item: IYAMLMapping;
  i: Integer;
  outputYaml: string;
  stopwatch: TStopwatch;
  elapsedTicks: Int64;
  elapsedMs: Double;
  outputSize: Integer;
begin
  // Create a large YAML document with comments on every value
  doc := TYAML.CreateMapping;
  root := doc.AsMapping;
  root.AddOrSetValue('title', 'Writer Performance Test With Comments').Comment := 'Document title';
  root.AddOrSetValue('version', '1.0.0').Comment := 'Version number';
  root.AddOrSetValue('timestamp', '2024-01-15T10:30:00Z').Comment := 'Creation timestamp';

  // Add a large sequence with many items, each with comments
  sequence := root.AddOrSetSequence('items');
  for i := 0 to 999 do
  begin
    item := sequence.AddMapping;
    item.AddOrSetValue('id', i).Comment := 'Unique identifier ' + IntToStr(i);
    item.AddOrSetValue('name', 'Item ' + IntToStr(i)).Comment := 'Item name';
    item.AddOrSetValue('description', 'This is a description for item number ' + IntToStr(i) + ' with some additional text').Comment := 'Detailed description';
    item.AddOrSetValue('active', i mod 2 = 0).Comment := 'Active status flag';
    item.AddOrSetValue('priority', i mod 10).Comment := 'Priority level 0-9';
    item.AddOrSetValue('tags', 'tag1,tag2,tag3').Comment := 'Comma-separated tags';
  end;

  // Measure write performance
  stopwatch := TStopwatch.StartNew;
  outputYaml := TYAML.WriteToString(doc);
  stopwatch.Stop;
  elapsedTicks := stopwatch.ElapsedTicks;
  elapsedMs := (elapsedTicks * 1000.0) / TStopwatch.Frequency;

  outputSize := Length(outputYaml);

  // Verify output
  Assert.IsTrue(outputSize > 0, 'Output should not be empty');
  Assert.IsTrue(Pos('title:', outputYaml) > 0, 'Output should contain title');
  Assert.IsTrue(Pos('items:', outputYaml) > 0, 'Output should contain items');
  Assert.IsTrue(Pos('# Document title', outputYaml) > 0, 'Output should contain comments');

  // Output performance metrics
  WriteLn('');
  WriteLn('=== YAML Writer With Comments Performance ===');
  WriteLn('Items written: 1000 (with 6 comments each = 6000 comments total)');
  WriteLn('Output size: ' + IntToStr(outputSize div 1024) + ' KB');
  WriteLn('Write time: ' + FormatFloat('0.00', elapsedMs) + ' ms');
  if elapsedMs > 0 then
    WriteLn('Throughput: ' + FormatFloat('0.00', (outputSize / 1024.0) / (elapsedMs / 1000.0)) + ' KB/s')
  else
    WriteLn('Throughput: Very fast (< 0.01 ms)');
  WriteLn('');

  // Assert reasonable performance
  Assert.IsTrue(elapsedMs < 10000, 'Write with comments should complete in less than 10 seconds');
end;

procedure TPerformanceTests.TestLoadTestJSONFile;
var
  jsonFile: string;
  doc: IYAMLDocument;
  options: IYAMLParserOptions;
  stopwatch: TStopwatch;
  elapsedTicks: Int64;
  elapsedMs: Double;
  elapsedMsString: Double;
  fileSize: Int64;
  jsonString: string;
  loadTime: Double;
  i: Integer;
  iterations: Integer;
  totalTime: Double;
  avgTime: Double;
begin
  jsonFile := TPath.Combine(FTestFilesPath, 'load_test.json');

  if not FileExists(jsonFile) then
  begin
    Assert.Fail('Test file not found: ' + jsonFile);
    Exit;
  end;

  fileSize := TFile.GetSize(jsonFile);

  // Create options for JSON mode
  options := TYAML.CreateParserOptions;
  options.JSONMode := true;

  // Test 1: Parse from file (streaming) - single run
  stopwatch := TStopwatch.StartNew;
  doc := TYAML.LoadFromFile(jsonFile, options);
  stopwatch.Stop;
  elapsedTicks := stopwatch.ElapsedTicks;
  elapsedMs := (elapsedTicks * 1000.0) / TStopwatch.Frequency;

  // Verify we parsed something
  Assert.IsNotNull(doc, 'Document should not be null');
  Assert.IsNotNull(doc.Root, 'Document root should not be null');
  Assert.AreEqual(TYAMLValueType.vtMapping, doc.Root.ValueType, 'Root should be a mapping');

  // Test 2: Load into string first, then parse - single run
  stopwatch := TStopwatch.StartNew;
  jsonString := TFile.ReadAllText(jsonFile);
  loadTime := (stopwatch.ElapsedTicks * 1000.0) / TStopwatch.Frequency;

  doc := TYAML.LoadFromString(jsonString, options);
  stopwatch.Stop;
  elapsedTicks := stopwatch.ElapsedTicks;
  elapsedMsString := (elapsedTicks * 1000.0) / TStopwatch.Frequency;

  // Test 3: Multiple iterations from string to get average
  iterations := 10;
  stopwatch := TStopwatch.StartNew;
  for i := 1 to iterations do
  begin
    doc := TYAML.LoadFromString(jsonString, options);
  end;
  stopwatch.Stop;
  totalTime := (stopwatch.ElapsedTicks * 1000.0) / TStopwatch.Frequency;
  avgTime := totalTime / iterations;

  // Output performance metrics
  WriteLn('');
  WriteLn('=== Load Test JSON File Parsing Performance ===');
  WriteLn('File size: ' + IntToStr(fileSize div 1024) + ' KB');
  WriteLn('');
  WriteLn('Streaming (LoadFromFile):');
  WriteLn('  Parse time: ' + FormatFloat('0.00', elapsedMs) + ' ms');
  if elapsedMs > 0 then
    WriteLn('  Throughput: ' + FormatFloat('0.00', (fileSize / 1024.0) / (elapsedMs / 1000.0)) + ' KB/s');
  WriteLn('');
  WriteLn('String-based (LoadFromString):');
  WriteLn('  File load time: ' + FormatFloat('0.00', loadTime) + ' ms');
  WriteLn('  Parse time: ' + FormatFloat('0.00', elapsedMsString - loadTime) + ' ms');
  WriteLn('  Total time: ' + FormatFloat('0.00', elapsedMsString) + ' ms');
  if elapsedMsString > 0 then
    WriteLn('  Throughput: ' + FormatFloat('0.00', (fileSize / 1024.0) / (elapsedMsString / 1000.0)) + ' KB/s');
  WriteLn('');
  WriteLn('Average over ' + IntToStr(iterations) + ' iterations:');
  WriteLn('  Average parse time: ' + FormatFloat('0.00', avgTime) + ' ms');
  WriteLn('  Average throughput: ' + FormatFloat('0.00', (fileSize / 1024.0) / (avgTime / 1000.0)) + ' KB/s');
  WriteLn('');
  WriteLn('Summary:');
  WriteLn('  Original performance: ~110ms');
  WriteLn('  Current performance: ' + FormatFloat('0.00', avgTime) + ' ms');
  WriteLn('  Improvement: ' + FormatFloat('0.0', ((110.0 - avgTime) / 110.0) * 100) + '%');
  WriteLn('  To match 15-30ms parsers: need ' + FormatFloat('0.1', avgTime / 22.5) + 'x faster');
  WriteLn('');

  // Assert reasonable performance
  Assert.IsTrue(elapsedMs < 15000, 'Parse should complete in less than 15 seconds');
end;

initialization
  TDUnitX.RegisterTestFixture(TPerformanceTests);

end.
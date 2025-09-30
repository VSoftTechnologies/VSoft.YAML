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
  elapsed: Int64;
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
  elapsed := stopwatch.ElapsedMilliseconds;

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
  WriteLn('Parse time: ' + IntToStr(elapsed) + ' ms');
  WriteLn('Throughput: ' + FormatFloat('0.00', (fileSize / 1024.0) / (elapsed / 1000.0)) + ' KB/s');
  WriteLn('');

  // Assert reasonable performance (should parse at least 500 KB/s)
  Assert.IsTrue(elapsed < 10000, 'Parse should complete in less than 10 seconds');
end;

procedure TPerformanceTests.TestLargeJSONFileParsing;
var
  jsonFile: string;
  doc: IYAMLDocument;
  options: IYAMLParserOptions;
  stopwatch: TStopwatch;
  elapsed: Int64;
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
  elapsed := stopwatch.ElapsedMilliseconds;

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
  WriteLn('Parse time: ' + IntToStr(elapsed) + ' ms');
  WriteLn('Throughput: ' + FormatFloat('0.00', (fileSize / 1024.0) / (elapsed / 1000.0)) + ' KB/s');
  WriteLn('');

  // Assert reasonable performance
  Assert.IsTrue(elapsed < 15000, 'Parse should complete in less than 15 seconds');
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

initialization
  TDUnitX.RegisterTestFixture(TPerformanceTests);

end.
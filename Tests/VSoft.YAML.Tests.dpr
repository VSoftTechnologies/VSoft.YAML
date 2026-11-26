program VSoft.YAML.Tests;

{$IFNDEF TESTINSIGHT}
{$APPTYPE CONSOLE}
{$ENDIF}
{$STRONGLINKTYPES ON}
uses
  System.SysUtils,
  System.Diagnostics,
  {$IFDEF TESTINSIGHT}
  TestInsight.DUnitX,
  {$ELSE}
  DUnitX.Loggers.Console,
  DUnitX.Loggers.Xml.NUnit,
  {$ENDIF }
  DUnitX.TestFramework,
  VSoft.YAML.Tests.DateTimeToISO8601 in 'VSoft.YAML.Tests.DateTimeToISO8601.pas',
  VSoft.YAML.Tests.ISO8601 in 'VSoft.YAML.Tests.ISO8601.pas',
  VSoft.YAML.Utils in '..\Source\VSoft.YAML.Utils.pas',
  VSoft.YAML in '..\Source\VSoft.YAML.pas',
  VSoft.YAML.Scanner in '..\Source\VSoft.YAML.Scanner.pas',
  VSoft.YAML.Composer in '..\Source\VSoft.YAML.Composer.pas',
  VSoft.YAML.Classes in '..\Source\VSoft.YAML.Classes.pas',
  VSoft.YAML.Tests.Basics in 'VSoft.YAML.Tests.Basics.pas',
  VSoft.YAML.Writer in '..\Source\VSoft.YAML.Writer.pas',
  VSoft.YAML.Tests.Comprehensive in 'VSoft.YAML.Tests.Comprehensive.pas',
  VSoft.YAML.Tests.Writer in 'VSoft.YAML.Tests.Writer.pas',
  VSoft.YAML.Tests.EdgeCases in 'VSoft.YAML.Tests.EdgeCases.pas',
  VSoft.YAML.Path in '..\Source\VSoft.YAML.Path.pas',
  VSoft.YAML.Tests.Path in 'VSoft.YAML.Tests.Path.pas',
  VSoft.YAML.Tests.Comments in 'VSoft.YAML.Tests.Comments.pas',
  VSoft.YAML.Tests.MergeKeys in 'VSoft.YAML.Tests.MergeKeys.pas',
  VSoft.YAML.Tests.Directives in 'VSoft.YAML.Tests.Directives.pas',
  VSoft.YAML.Tests.TagInfo in 'VSoft.YAML.Tests.TagInfo.pas',
  VSoft.YAML.IO in '..\Source\VSoft.YAML.IO.pas',
  VSoft.YAML.TagInfo in '..\Source\VSoft.YAML.TagInfo.pas',
  VSoft.YAML.StreamWriter in '..\Source\VSoft.YAML.StreamWriter.pas',
  VSoft.YAML.Tests.JSON in 'VSoft.YAML.Tests.JSON.pas',
  VSoft.YAML.Writer.JSON in '..\Source\VSoft.YAML.Writer.JSON.pas',
  VSoft.YAML.Tests.JSON.Writer in 'VSoft.YAML.Tests.JSON.Writer.pas',
  VSoft.YAML.Tests.CharUtils in 'VSoft.YAML.Tests.CharUtils.pas',
  VSoft.YAML.Tests.SequenceProperties in 'VSoft.YAML.Tests.SequenceProperties.pas',
  VSoft.YAML.Tests.DateUtils in 'VSoft.YAML.Tests.DateUtils.pas',
  VSoft.YAML.Tests.Performance in 'VSoft.YAML.Tests.Performance.pas',
  VSoft.YAML.Tests.Numbers in 'VSoft.YAML.Tests.Numbers.pas',
  VSoft.YAML.Tests.PlainScalars in 'VSoft.YAML.Tests.PlainScalars.pas',
  VSoft.YAML.Tests.MappingProperties in 'VSoft.YAML.Tests.MappingProperties.pas',
  VSoft.YAML.Parser.JSON in '..\Source\VSoft.YAML.Parser.JSON.pas',
  VSoft.YAML.Tests.JSON.Strict in 'VSoft.YAML.Tests.JSON.Strict.pas',
  VSoft.YAML.Tests.JSON5 in 'VSoft.YAML.Tests.JSON5.pas',
  VSoft.YAML.Tests.JSON5.Writer in 'VSoft.YAML.Tests.JSON5.Writer.pas',
  VSoft.YAML.Tests.JSONSuites in 'VSoft.YAML.Tests.JSONSuites.pas',
  VSoft.YAML.Tests.YAMLSuite in 'VSoft.YAML.Tests.YAMLSuite.pas',
  VSoft.YAML.Tests.YAML12 in 'VSoft.YAML.Tests.YAML12.pas',
  VSoft.YAML.Tests.Nodes in 'VSoft.YAML.Tests.Nodes.pas',
  VSoft.YAML.Tests.Editing in 'VSoft.YAML.Tests.Editing.pas',
  VSoft.YAML.Tests.PathMatches in 'VSoft.YAML.Tests.PathMatches.pas';

{ keep comment here to protect the following conditional from being removed by the IDE when adding a unit }
{$IFNDEF TESTINSIGHT}
var
  runner: ITestRunner;
  results: IRunResults;
  logger: ITestLogger;
  nunitLogger : ITestLogger;
  stopwatch : TStopwatch;
{$ENDIF}
begin
{$IFDEF TESTINSIGHT}
  TestInsight.DUnitX.RunRegisteredTests;
{$ELSE}
  try
    //Check command line options, will exit if invalid
    TDUnitX.CheckCommandLine;
    //Create the test runner
    runner := TDUnitX.CreateRunner;
    //Tell the runner to use RTTI to find Fixtures
    runner.UseRTTI := false;
    //When true, Assertions must be made during tests;
    runner.FailsOnNoAsserts := False;

    TDUnitX.Options.ExitBehavior := TDUnitXExitBehavior.Pause;

    //tell the runner how we will log things
    //Log to the console window if desired
    TDUnitX.Options.ConsoleMode := TDunitXConsoleMode.Quiet;
    if TDUnitX.Options.ConsoleMode <> TDunitXConsoleMode.Off then
    begin
      ReportMemoryLeaksOnShutdown := True;
      logger := TDUnitXConsoleLogger.Create(TDUnitX.Options.ConsoleMode = TDunitXConsoleMode.Verbose);
      runner.AddLogger(logger);
    end;
    //Generate an NUnit compatible XML File
    if TDUnitX.Options.XMLOutputFile <> '' then
    begin
      nunitLogger := TDUnitXXMLNUnitFileLogger.Create(TDUnitX.Options.XMLOutputFile);
      runner.AddLogger(nunitLogger);
    end;

    //Run tests
    stopwatch := TStopwatch.StartNew;
    results := runner.Execute;
    stopwatch.Stop;
    if not results.AllPassed then
      System.ExitCode := EXIT_ERRORS;

    System.Writeln(Format('Tests completed in : %dms', [stopwatch.ElapsedMilliseconds]));

    {$IFNDEF CI}
    //We don't want this happening when running under CI.
    if TDUnitX.Options.ExitBehavior = TDUnitXExitBehavior.Pause then
    begin
      System.Write('Done.. press <Enter> key to quit.');
      System.Readln;
    end;
    {$ENDIF}
  except
    on E: Exception do
      System.Writeln(E.ClassName, ': ', E.Message);
  end;
{$ENDIF}
end.

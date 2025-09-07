program VSoft.YAML.Tests;

{$IFNDEF TESTINSIGHT}
{$APPTYPE CONSOLE}
{$ENDIF}
{$STRONGLINKTYPES ON}
uses
  System.SysUtils,
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
  VSoft.YAML.Lexer in '..\Source\VSoft.YAML.Lexer.pas',
  VSoft.YAML.Parser in '..\Source\VSoft.YAML.Parser.pas',
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
  VSoft.YAML.StreamReader in '..\Source\VSoft.YAML.StreamReader.pas',
  VSoft.YAML.TagInfo in '..\Source\VSoft.YAML.TagInfo.pas',
  VSoft.YAML.StreamWriter in '..\Source\VSoft.YAML.StreamWriter.pas',
  VSoft.YAML.Tests.JSON in 'VSoft.YAML.Tests.JSON.pas',
  VSoft.YAML.Writer.JSON in '..\Source\VSoft.YAML.Writer.JSON.pas',
  VSoft.YAML.Tests.JSON.Writer in 'VSoft.YAML.Tests.JSON.Writer.pas',
  VSoft.YAML.Tests.CharUtils in 'VSoft.YAML.Tests.CharUtils.pas';

{ keep comment here to protect the following conditional from being removed by the IDE when adding a unit }
{$IFNDEF TESTINSIGHT}
var
  runner: ITestRunner;
  results: IRunResults;
  logger: ITestLogger;
  nunitLogger : ITestLogger;
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

   // TDUnitX.Options.ExitBehavior := TDUnitXExitBehavior.Pause;

    //tell the runner how we will log things
    //Log to the console window if desired
    TDUnitX.Options.ConsoleMode := TDunitXConsoleMode.Quiet;
    if TDUnitX.Options.ConsoleMode <> TDunitXConsoleMode.Off then
    begin
      ReportMemoryLeaksOnShutdown := True;
      logger := TDUnitXConsoleLogger.Create(TDUnitX.Options.ConsoleMode = TDunitXConsoleMode.Quiet);
      runner.AddLogger(logger);
    end;
    //Generate an NUnit compatible XML File
    if TDUnitX.Options.XMLOutputFile <> '' then
    begin
      nunitLogger := TDUnitXXMLNUnitFileLogger.Create(TDUnitX.Options.XMLOutputFile);
      runner.AddLogger(nunitLogger);
    end;

    //Run tests
    results := runner.Execute;
    if not results.AllPassed then
      System.ExitCode := EXIT_ERRORS;

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

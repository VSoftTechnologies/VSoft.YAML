program SimpleDemo;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  System.Diagnostics,
  VSoft.YAML.Classes in '..\..\Source\VSoft.YAML.Classes.pas',
  VSoft.YAML.Lexer in '..\..\Source\VSoft.YAML.Lexer.pas',
  VSoft.YAML.Parser in '..\..\Source\VSoft.YAML.Parser.pas',
  VSoft.YAML in '..\..\Source\VSoft.YAML.pas',
  VSoft.YAML.Utils in '..\..\Source\VSoft.YAML.Utils.pas',
  VSoft.YAML.Writer in '..\..\Source\VSoft.YAML.Writer.pas',
  VSoft.YAML.Path in '..\..\Source\VSoft.YAML.Path.pas',
  VSoft.YAML.IO in '..\..\Source\VSoft.YAML.IO.pas',
  VSoft.YAML.StreamReader in '..\..\Source\VSoft.YAML.StreamReader.pas',
  VSoft.YAML.StreamWriter in '..\..\Source\VSoft.YAML.StreamWriter.pas',
  VSoft.YAML.TagInfo in '..\..\Source\VSoft.YAML.TagInfo.pas';

procedure YAMLPAthTest1;
var
  YAMLText : string;
  doc : IYAMLDocument;
  res : IYAMLSequence;
  i: Integer;
  sYAML : string;
begin
  YAMLText :=
    '# Mega YAML feature showcase for testing parsers and tools' + sLineBreak +
    '# Generated on: 2025-08-29 10:40:40 +1000'  + sLineBreak +
    '# This file attempts to exercise a broad set of YAML 1.2 features.'  + sLineBreak +
    '#%YAML 1.2'  + sLineBreak +
    '#%TAG !e! tag:example.com,2025:'  + sLineBreak +
    '#%TAG !yaml! tag:yaml.org,2002:'   + sLineBreak +
    '# comment'  + sLineBreak +
    '---  # Document 1: Core features'  + sLineBreak +
    '# comment'  + sLineBreak +
    'person:' + sLineBreak +
//    '  name: Jane Smith' + sLineBreak +
//    '  age: 25' + sLineBreak +
    '  hobbies:' + sLineBreak +
    '    - reading' + sLineBreak +
    '    - swimming' + sLineBreak +
    '    - coding' + sLineBreak +
    '  skills:' + sLineBreak +
    '    ? reading' + sLineBreak +
    '    ? swimming' + sLineBreak +
    '    ? coding' + sLineBreak +
    'company: ACME Corp' + sLineBreak +
    'employees:' + sLineBreak +
    '  - name: Alice' + sLineBreak +
    '    role: Developer' + sLineBreak +
    '  - name: Bob' + sLineBreak +
    '    role: Designer' + sLineBreak +
    '...';

//  '---' + sLineBreak +
//  'complex_keys:'  + sLineBreak +
//  '  ?'  + sLineBreak +
//  '    - list'  + sLineBreak +
//  '    - used'  + sLineBreak +
//  '    - as'  + sLineBreak +
//  '    - key'  + sLineBreak +
//  '  : value_for_complex_list_key'  + sLineBreak +
//  '  ? {x: 1, y: 2} : point'  + sLineBreak +
//  '  ? |'  + sLineBreak +
//  '    multi-line'  + sLineBreak +
//  '    key'  + sLineBreak +
//  '  : literal_key_value';

//  'complex_keys:' + sLineBreak +
//  '  "[ list, used, as, key ]": value_for_complex_list_key' + sLineBreak +
//  '  "{\n  ? { x: 1, y: 2 }\n  : point\n}": null' + sLineBreak +
//  '  "multi-line\nkey\n": literal_key_value';
//
  doc := TYAML.LoadFromString(YAMLText);
  doc.Options.Format := TYAMLOutputFormat.yofBlock;
  doc.Options.EmitDocumentMarkers := true;

//  res := TYAMLPath.Match(doc.Root, '$.person.hobbies');
//
//  if res[0].IsSequence then
//  for i := 0 to res[0].AsSequence.Count -1 do
//    WriteLn(res[0].AsSequence.Items[i].AsString);
  TYAML.DefaultWriterOptions.EmitDocumentMarkers := true;
  sYAML := doc.ToYAMLString();

  Write(sYAML);
  WriteLn;
end;

procedure LoadTest;
var
  fileName : string;
  doc : IYAMLDocument;
  sYAML : string;
  stopwatch : TStopwatch;
begin
  filename := 'I:\downloads\mega-yaml.yaml';
  stopwatch := TStopwatch.StartNew;
  doc := TYAML.LoadFromFile(fileName);
  WriteLn;
  WriteLn('ParseTime : ' + IntToStr(stopwatch.ElapsedTicks));

  doc.Options.Format := TYAMLOutputFormat.yofMixed;
  doc.Options.EmitDocumentMarkers := true;

  sYAML := doc.ToYAMLString();
  stopwatch.Stop;

  Write(sYAML);
  WriteLn;
end;


begin
  try
//    YAMLPAthTest1;
    LoadTest;
    readln;
  except
    on E: Exception do
    begin
      Writeln(E.ClassName, ': ', E.Message);
      readln;
    end;
  end;
end.

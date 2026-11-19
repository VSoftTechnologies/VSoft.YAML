program ProfBench;

// Profiling / A-B benchmark for VSoft.YAML.
//   ProfBench [rounds] [iters] [only-this-file|*] [test-files-dir]
// For each test file: parse (LoadFromString), free the document, and write (YAML + JSON),
// reporting the best of [rounds] rounds of [iters] iterations, plus an output hash so
// A/B runs can confirm identical results. test-files-dir defaults to ..\Tests\TestFiles
// (Bench\big holds ~100 MB versions made by GenBig).

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.Diagnostics,
  System.Generics.Collections,
  System.Hash,
  Winapi.Windows,
  VSoft.YAML in '..\Source\VSoft.YAML.pas';

// the run machine's clock and free memory, so results can be tied to a quiet-time lease
procedure Stamp(const what : string);
var
  ms : TMemoryStatusEx;
begin
  ms.dwLength := SizeOf(ms);
  GlobalMemoryStatusEx(ms);
  WriteLn(Format('[%s %s on %s, %.1f of %.1f GB free]', [what, FormatDateTime('yyyy-mm-dd hh:nn:ss', Now),
    GetEnvironmentVariable('COMPUTERNAME'), ms.ullAvailPhys / 1073741824, ms.ullTotalPhys / 1073741824]));
end;

function Best(var a : TArray<Double>) : Double;
begin
  TArray.Sort<Double>(a); // best-of: robust to background load
  Result := a[0];
end;

procedure BenchFile(const path : string; jsonMode : boolean; rounds, iters : integer);
var
  src, yamlOut, jsonOut : string;
  options : IYAMLParserOptions;
  doc, tmp : IYAMLDocument;
  sw : TStopwatch;
  r, i : integer;
  parseT, freeT, writeT, jsonT : TArray<Double>;
begin
  if (ParamStr(3) <> '') and (ParamStr(3) <> '*') and not SameText(ParamStr(3), ExtractFileName(path)) then
    Exit;
  if not FileExists(path) then
  begin
    WriteLn('SKIP (missing): ', path);
    Exit;
  end;
  src := TFile.ReadAllText(path);
  options := TYAML.CreateParserOptions;
  options.JSONMode := jsonMode;

  doc := TYAML.LoadFromString(src, options);
  yamlOut := TYAML.WriteToString(doc);
  jsonOut := TYAML.WriteToJSONString(doc);

  SetLength(parseT, rounds);
  SetLength(freeT, rounds);
  SetLength(writeT, rounds);
  SetLength(jsonT, rounds);
  for r := 0 to rounds - 1 do
  begin
    parseT[r] := 0;
    freeT[r] := 0;
    for i := 1 to iters do
    begin
      sw := TStopwatch.StartNew;
      tmp := TYAML.LoadFromString(src, options);
      parseT[r] := parseT[r] + sw.Elapsed.TotalMilliseconds;
      sw := TStopwatch.StartNew;
      tmp := nil;
      freeT[r] := freeT[r] + sw.Elapsed.TotalMilliseconds;
    end;
    parseT[r] := parseT[r] / iters;
    freeT[r] := freeT[r] / iters;

    sw := TStopwatch.StartNew;
    for i := 1 to iters do
      TYAML.WriteToString(doc);
    writeT[r] := sw.Elapsed.TotalMilliseconds / iters;

    sw := TStopwatch.StartNew;
    for i := 1 to iters do
      TYAML.WriteToJSONString(doc);
    jsonT[r] := sw.Elapsed.TotalMilliseconds / iters;
  end;

  WriteLn(Format('%-28s %7d KB  parse %8.1f ms (%6.1f MB/s)  free %7.1f ms  yaml-out %7.1f ms  json-out %7.1f ms  hash %s/%s',
    [ExtractFileName(path), Length(src) div 1024, Best(parseT), (Length(src) / 1048576) / (parseT[0] / 1000),
     Best(freeT), Best(writeT), Best(jsonT),
     Copy(THashMD5.GetHashString(yamlOut), 1, 8), Copy(THashMD5.GetHashString(jsonOut), 1, 8)]));
end;

// One parse of src with the given options, the document freed outside the timing.
function TimeParse(const src : string; const options : IYAMLParserOptions; iters : integer) : Double;
var
  sw : TStopwatch;
  i : integer;
  tmp : IYAMLDocument;
begin
  result := 0;
  for i := 1 to iters do
  begin
    sw := TStopwatch.StartNew;
    tmp := TYAML.LoadFromString(src, options);
    result := result + sw.Elapsed.TotalMilliseconds;
    tmp := nil;
  end;
  result := result / iters;
end;

// A JSON file read as JSON5 (json5) - the same parser as JSON (the parse column above) in its
// other mode - the JSON5 text the writer makes of it (json5-text), and that write
// (json5-out). The hashes are of the JSON written from the JSON and JSON5 documents, which
// must match.
procedure BenchJSON5(const path : string; rounds, iters : integer);
var
  src, json5Text, jsonOut, json5Out : string;
  jsonOptions, json5Options : IYAMLParserOptions;
  doc : IYAMLDocument;
  sw : TStopwatch;
  r, i : integer;
  json5T, json5TextT, json5OutT : TArray<Double>;
begin
  if (ParamStr(3) <> '') and (ParamStr(3) <> '*') and not SameText(ParamStr(3), ExtractFileName(path)) then
    Exit;
  if not FileExists(path) then
    Exit;
  src := TFile.ReadAllText(path);
  jsonOptions := TYAML.CreateParserOptions;
  jsonOptions.JSONMode := true;
  json5Options := TYAML.CreateParserOptions;
  json5Options.InputFormat := TYAMLInputFormat.yifJSON5;

  doc := TYAML.LoadFromString(src, jsonOptions);
  jsonOut := TYAML.WriteToJSONString(doc);
  json5Out := TYAML.WriteToJSONString(TYAML.LoadFromString(src, json5Options));
  json5Text := TYAML.WriteToJSON5String(doc);

  SetLength(json5T, rounds);
  SetLength(json5TextT, rounds);
  SetLength(json5OutT, rounds);
  for r := 0 to rounds - 1 do
  begin
    json5T[r] := TimeParse(src, json5Options, iters);
    json5TextT[r] := TimeParse(json5Text, json5Options, iters);
    sw := TStopwatch.StartNew;
    for i := 1 to iters do
      TYAML.WriteToJSON5String(doc);
    json5OutT[r] := sw.Elapsed.TotalMilliseconds / iters;
  end;

  WriteLn(Format('%-28s json5 %8.1f ms (%6.1f MB/s)  json5-text %8.1f ms  json5-out %7.1f ms  hash %s/%s',
    [ExtractFileName(path), Best(json5T), (Length(src) / 1048576) / (json5T[0] / 1000),
     Best(json5TextT), Best(json5OutT),
     Copy(THashMD5.GetHashString(jsonOut), 1, 8), Copy(THashMD5.GetHashString(json5Out), 1, 8)]));
end;

var
  base : string;
  rounds, iters : integer;
begin
  try
    rounds := StrToIntDef(ParamStr(1), 5);
    iters := StrToIntDef(ParamStr(2), 4);
    base := ParamStr(4);
    if base = '' then
      base := TPath.Combine(ExtractFilePath(ParamStr(0)), '..\Tests\TestFiles');
    Stamp('start');
    BenchFile(TPath.Combine(base, 'benchmark_large.yaml'), false, rounds, iters);
    BenchFile(TPath.Combine(base, 'benchmark_block_scalars.yaml'), false, rounds, iters);
    BenchFile(TPath.Combine(base, 'benchmark_quoted_strings.yaml'), false, rounds, iters);
    BenchFile(TPath.Combine(base, 'benchmark_large.json'), true, rounds, iters);
    BenchFile(TPath.Combine(base, 'load_test.json'), true, rounds, iters);
    BenchFile(TPath.Combine(base, 'test.json'), true, rounds, iters);
    BenchJSON5(TPath.Combine(base, 'benchmark_large.json'), rounds, iters);
    BenchJSON5(TPath.Combine(base, 'load_test.json'), rounds, iters);
    BenchJSON5(TPath.Combine(base, 'test.json'), rounds, iters);
    Stamp('end');
  except
    on E: Exception do
      WriteLn(E.ClassName, ': ', E.Message);
  end;
end.

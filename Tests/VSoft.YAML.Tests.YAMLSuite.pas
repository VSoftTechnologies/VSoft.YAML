unit VSoft.YAML.Tests.YAMLSuite;

// Runs the official YAML test suite (https://github.com/yaml/yaml-test-suite), copied to
// TestFiles\yaml-test-suite. Each case is an in.yaml, with an "error" file when it must be
// rejected, and an in.json holding its data when that can be shown as JSON. A case passes
// when invalid input raises a parse error, valid input parses, and the documents hold the
// data in in.json. The suite is YAML 1.2, so it is read with YAML11Compatibility off, and a
// !!set (2XXW) matches the JSON object of its items with null values.
//
// The cases that do not pass yet are listed in TestFiles\yaml-test-suite-known-failures.txt.
// The test fails when a case not on the list fails (a regression) or a case on the list
// passes (remove its line), so the list always matches the parser. To rewrite the list after
// changing the parser, set the environment variable VSOFT_YAML_SUITE_WRITE to a file name
// and run the tests: the current failures are written there in the list's format.

interface

uses
  DUnitX.TestFramework,
  VSoft.YAML;

type
  [TestFixture]
  TYAMLTestSuiteTests = class
  public
    [Test]
    procedure Cases_MatchKnownFailures;
  end;

implementation

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.Types,
  System.StrUtils,
  System.Math,
  System.Generics.Collections,
  System.Generics.Defaults,
  VSoft.YAML.Classes;

const
  cWriteVariable = 'VSOFT_YAML_SUITE_WRITE';

type
  TCaseResult = record
    Id : string;
    Name : string;
    Kind : string;   // '' when the case passes
    Detail : string;
  end;

function TestFilesDir : string;
begin
  result := TPath.GetFullPath(TPath.Combine(ExtractFilePath(ParamStr(0)), '..\..\TestFiles'));
end;

function SuiteDir : string;
begin
  result := TPath.Combine(TestFilesDir, 'yaml-test-suite');
end;

function KnownFailuresFile : string;
begin
  result := TPath.Combine(TestFilesDir, 'yaml-test-suite-known-failures.txt');
end;

// The text of a UTF-8 file, without its byte order mark if it has one. (XE2's
// TFile.ReadAllText(name, TEncoding.UTF8) drops the first three bytes whether or not they
// are a byte order mark.)
function ReadUTF8File(const fileName : string) : string;
var
  bytes, preamble : TBytes;
  start : integer;
begin
  bytes := TFile.ReadAllBytes(fileName);
  preamble := TEncoding.UTF8.GetPreamble;
  start := 0;
  if (Length(bytes) >= Length(preamble)) and CompareMem(@bytes[0], @preamble[0], Length(preamble)) then
    start := Length(preamble);
  if start >= Length(bytes) then
    result := ''
  else
    result := TEncoding.UTF8.GetString(bytes, start, Length(bytes) - start);
end;

// in.json holds one JSON value per document, one after the other
function SplitJSONTexts(const text : string) : TArray<string>;
var
  list : TList<string>;
  i, len, depth, start : integer;
  inString, escaped : boolean;
  ch : Char;
begin
  list := TList<string>.Create;
  try
    len := Length(text);
    i := 1;
    while i <= len do
    begin
      while (i <= len) and CharInSet(text[i], [' ', #9, #10, #13]) do
        Inc(i);
      if i > len then
        break;
      start := i;
      depth := 0;
      inString := false;
      escaped := false;
      while i <= len do
      begin
        ch := text[i];
        if inString then
        begin
          if escaped then
            escaped := false
          else if ch = '\' then
            escaped := true
          else if ch = '"' then
          begin
            inString := false;
            if depth = 0 then
            begin
              Inc(i);
              break;
            end;
          end;
        end
        else if ch = '"' then
          inString := true
        else if CharInSet(ch, ['[', '{']) then
          Inc(depth)
        else if CharInSet(ch, [']', '}']) then
        begin
          Dec(depth);
          if depth = 0 then
          begin
            Inc(i);
            break;
          end;
        end
        else if (depth = 0) and CharInSet(ch, [' ', #9, #10, #13]) then
          break;
        Inc(i);
      end;
      list.Add(Copy(text, start, i - start));
    end;
    result := list.ToArray;
  finally
    list.Free;
  end;
end;

function Shown(const value : string) : string;
begin
  result := StringReplace(StringReplace(StringReplace(value, #13, '\r', [rfReplaceAll]), #10, '\n', [rfReplaceAll]), #9, '\t', [rfReplaceAll]);
end;

// y (parsed from in.yaml) holds the data of j (parsed from in.json). A timestamp counts as
// its text, as JSON has no timestamps.
function NumberValue(const value : IYAMLValue) : Double;
begin
  if value.IsInteger then
    result := value.AsInteger
  else
    result := value.AsFloat;
end;

function SameData(const y, j : IYAMLValue; out why : string) : boolean;
var
  i : integer;
  ym, jm : IYAMLMapping;
  ys, js : IYAMLSequence;
  yText, jText : string;
  yv : IYAMLValue;
begin
  result := false;
  why := '';
  case j.ValueType of
    TYAMLValueType.vtNull :
      if not y.IsNull then
      begin
        why := 'expected null, got "' + Shown(y.RawValue) + '"';
        exit;
      end;
    TYAMLValueType.vtBoolean :
      if (not y.IsBoolean) or (y.AsBoolean <> j.AsBoolean) then
      begin
        why := 'expected ' + j.RawValue + ', got "' + Shown(y.RawValue) + '"';
        exit;
      end;
    TYAMLValueType.vtInteger, TYAMLValueType.vtFloat :
    begin
      if not (y.IsInteger or y.IsFloat) then
      begin
        why := 'expected the number ' + j.RawValue + ', got "' + Shown(y.RawValue) + '"';
        exit;
      end;
      if y.IsInteger and j.IsInteger and YAMLIntegerToDecimalText(y.RawValue, yText) and
         YAMLIntegerToDecimalText(j.RawValue, jText) then
      begin
        if yText <> jText then
        begin
          why := 'expected ' + jText + ', got ' + yText;
          exit;
        end;
      end
      else if not System.Math.SameValue(NumberValue(y), NumberValue(j)) then
      begin
        why := 'expected ' + j.RawValue + ', got ' + y.RawValue;
        exit;
      end;
    end;
    TYAMLValueType.vtString :
      if not (y.IsString or y.IsTimeStamp) or (y.AsString <> j.AsString) then
      begin
        why := 'expected the string "' + Shown(j.AsString) + '", got "' + Shown(y.RawValue) + '"';
        exit;
      end;
    TYAMLValueType.vtSequence :
    begin
      if y.IsSet then
        ys := y.AsSet
      else if y.IsSequence then
        ys := y.AsSequence
      else
      begin
        why := 'expected a sequence';
        exit;
      end;
      js := j.AsSequence;
      if ys.Count <> js.Count then
      begin
        why := Format('expected %d items, got %d', [js.Count, ys.Count]);
        exit;
      end;
      for i := 0 to js.Count - 1 do
      begin
        if not SameData(ys[i], js[i], why) then
        begin
          why := '[' + IntToStr(i) + '] ' + why;
          exit;
        end;
      end;
    end;
    TYAMLValueType.vtMapping :
    begin
      if y.IsSet then
      begin
        // a !!set is a mapping whose values are all null
        jm := j.AsMapping;
        ys := y.AsSet;
        if ys.Count <> jm.Count then
        begin
          why := Format('expected %d keys, got a set of %d items', [jm.Count, ys.Count]);
          exit;
        end;
        for i := 0 to jm.Count - 1 do
        begin
          if (ys[i].AsString <> jm.Keys[i]) or not jm.Values[jm.Keys[i]].IsNull then
          begin
            why := Format('set item %d is "%s", expected the key "%s" with a null value', [i, Shown(ys[i].AsString), Shown(jm.Keys[i])]);
            exit;
          end;
        end;
        result := true;
        exit;
      end;
      if not y.IsMapping then
      begin
        why := 'expected a mapping';
        exit;
      end;
      ym := y.AsMapping;
      jm := j.AsMapping;
      if ym.Count <> jm.Count then
      begin
        why := Format('expected %d keys, got %d', [jm.Count, ym.Count]);
        exit;
      end;
      for i := 0 to jm.Count - 1 do
      begin
        if not ym.TryGetValue(jm.Keys[i], yv) then
        begin
          why := 'missing the key "' + Shown(jm.Keys[i]) + '"';
          exit;
        end;
        if not SameData(yv, jm.Values[jm.Keys[i]], why) then
        begin
          why := '.' + jm.Keys[i] + ' ' + why;
          exit;
        end;
      end;
    end;
  end;
  result := true;
end;

function IsParseError(const error : string) : boolean;
begin
  result := StartsText('EYAMLParseException', error) or StartsText('EEncodingError', error);
end;

function RunCase(const dir : string) : TCaseResult;
var
  stream : TFileStream;
  docs : TArray<IYAMLDocument>;
  error, why : string;
  jsonTexts : TArray<string>;
  jsonOptions : IYAMLParserOptions;
  yamlOptions : IYAMLParserOptions;
  i : integer;
begin
  result.Id := StringReplace(Copy(dir, Length(SuiteDir) + 2, MaxInt), '\', '/', [rfReplaceAll]);
  result.Name := '';
  if FileExists(TPath.Combine(dir, '===')) then
    result.Name := Trim(ReadUTF8File(TPath.Combine(dir, '===')));
  result.Kind := '';
  result.Detail := '';

  error := '';
  // the suite is YAML 1.2, so read it without the YAML 1.1 extras
  yamlOptions := TYAML.CreateParserOptions;
  yamlOptions.YAML11Compatibility := false;
  try
    stream := TFileStream.Create(TPath.Combine(dir, 'in.yaml'), fmOpenRead or fmShareDenyWrite);
    try
      docs := TYAML.LoadAllFromStream(stream, yamlOptions);
    finally
      stream.Free;
    end;
  except
    on E : Exception do
      error := E.ClassName + ': ' + E.Message;
  end;

  if (error <> '') and not IsParseError(error) then
  begin
    result.Kind := 'crash';
    result.Detail := error;
  end
  else if FileExists(TPath.Combine(dir, 'error')) then
  begin
    if error = '' then
      result.Kind := 'accepted-invalid';
  end
  else if error <> '' then
  begin
    result.Kind := 'rejected-valid';
    result.Detail := error;
  end
  else if FileExists(TPath.Combine(dir, 'in.json')) then
  begin
    jsonTexts := SplitJSONTexts(ReadUTF8File(TPath.Combine(dir, 'in.json')));
    if Length(jsonTexts) <> Length(docs) then
    begin
      result.Kind := 'wrong-data';
      result.Detail := Format('expected %d documents, got %d', [Length(jsonTexts), Length(docs)]);
    end
    else
    begin
      jsonOptions := TYAML.CreateParserOptions;
      jsonOptions.JSONMode := true;
      for i := 0 to Length(docs) - 1 do
      begin
        if not SameData(docs[i].Root, TYAML.LoadFromString(jsonTexts[i], jsonOptions).Root, why) then
        begin
          result.Kind := 'wrong-data';
          result.Detail := Format('document %d: %s', [i + 1, why]);
          break;
        end;
      end;
    end;
  end;
end;

function RunAllCases : TArray<TCaseResult>;
var
  files : TStringDynArray;
  i : integer;
begin
  files := TDirectory.GetFiles(SuiteDir, 'in.yaml', TSearchOption.soAllDirectories);
  TArray.Sort<string>(files, TComparer<string>.Construct(
    function(const left, right : string) : integer
    begin
      result := CompareStr(left, right);
    end));
  SetLength(result, Length(files));
  for i := 0 to Length(files) - 1 do
    result[i] := RunCase(ExcludeTrailingPathDelimiter(ExtractFilePath(files[i])));
end;

function LoadKnownFailures : TDictionary<string, string>;
var
  lines : TStringList;
  i, p : integer;
  line : string;
begin
  result := TDictionary<string, string>.Create;
  lines := TStringList.Create;
  try
    lines.LoadFromFile(KnownFailuresFile, TEncoding.UTF8);
    for i := 0 to lines.Count - 1 do
    begin
      line := Trim(lines[i]);
      if (line = '') or (line[1] = '#') then
        continue;
      p := Pos(' ', line);
      if p = 0 then
        result.AddOrSetValue(line, line)
      else
        result.AddOrSetValue(Copy(line, 1, p - 1), line);
    end;
  finally
    lines.Free;
  end;
end;

procedure WriteKnownFailures(const fileName : string; const results : TArray<TCaseResult>; passed : integer);
var
  lines : TStringList;
  i : integer;
begin
  lines := TStringList.Create;
  try
    lines.Add('# yaml-test-suite cases VSoft.YAML does not pass yet - see VSoft.YAML.Tests.YAMLSuite.pas.');
    lines.Add('# A case listed here must keep failing (remove its line once it passes), and a case not');
    lines.Add('# listed must pass. One case a line: its id, how it fails, and its name.');
    lines.Add('#   rejected-valid    valid YAML raised a parse error');
    lines.Add('#   accepted-invalid  invalid YAML was accepted');
    lines.Add('#   wrong-data        parsed, but the documents do not hold the data in in.json');
    lines.Add(Format('# %d of %d cases pass.', [passed, Length(results)]));
    for i := 0 to Length(results) - 1 do
    begin
      if results[i].Kind <> '' then
        lines.Add(Format('%-10s %-17s %s', [results[i].Id, results[i].Kind, results[i].Name]));
    end;
    lines.WriteBOM := false;
    lines.SaveToFile(fileName, TEncoding.UTF8);
  finally
    lines.Free;
  end;
end;

{ TYAMLTestSuiteTests }

procedure TYAMLTestSuiteTests.Cases_MatchKnownFailures;
var
  results : TArray<TCaseResult>;
  known : TDictionary<string, string>;
  passing : TDictionary<string, boolean>;
  i, passed : integer;
  problems : TStringBuilder;
  id : string;
begin
  Assert.IsTrue(TDirectory.Exists(SuiteDir), 'missing ' + SuiteDir);
  results := RunAllCases;
  Assert.IsTrue(Length(results) > 0, 'no cases found in ' + SuiteDir);

  passed := 0;
  for i := 0 to Length(results) - 1 do
  begin
    if results[i].Kind = '' then
      Inc(passed);
  end;
  if GetEnvironmentVariable(cWriteVariable) <> '' then
    WriteKnownFailures(GetEnvironmentVariable(cWriteVariable), results, passed);

  known := LoadKnownFailures;
  passing := TDictionary<string, boolean>.Create;
  problems := TStringBuilder.Create;
  try
    for i := 0 to Length(results) - 1 do
    begin
      if results[i].Kind = '' then
        passing.Add(results[i].Id, true)
      else if (results[i].Kind = 'crash') or not known.ContainsKey(results[i].Id) then
        problems.AppendLine.Append('  ' + results[i].Id + ' ' + results[i].Kind + ' (' + results[i].Name + ')' +
          IfThen(results[i].Detail <> '', ': ' + Shown(results[i].Detail), ''));
    end;
    for id in known.Keys do
    begin
      if passing.ContainsKey(id) then
        problems.AppendLine.Append('  ' + id + ' now passes - remove it from yaml-test-suite-known-failures.txt');
    end;

    if problems.Length > 0 then
      Assert.Fail(Format('%d of %d cases pass. Not as listed in yaml-test-suite-known-failures.txt:', [passed, Length(results)]) +
        problems.ToString)
    else
      Assert.Pass(Format('%d of %d cases pass; %d known failures', [passed, Length(results), known.Count]));
  finally
    problems.Free;
    passing.Free;
    known.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TYAMLTestSuiteTests);

end.

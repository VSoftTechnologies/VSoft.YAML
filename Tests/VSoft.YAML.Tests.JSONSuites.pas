unit VSoft.YAML.Tests.JSONSuites;

// Runs the third-party conformance suites in TestFiles:
//   JSONTestSuite - https://github.com/nst/JSONTestSuite (y_ valid, n_ invalid, i_ either)
//   json5-tests   - https://github.com/json5/json5-tests (.json/.json5 valid, .js/.txt invalid)
// Each test goes through every file of one kind and lists all the files that went wrong.

interface

uses
  DUnitX.TestFramework,
  VSoft.YAML;

type
  [TestFixture]
  TJSONTestSuiteTests = class
  public
    // strict JSON (JSONMode)
    [Test]
    procedure JSON_AcceptsValid;
    [Test]
    procedure JSON_RejectsInvalid;
    [Test]
    procedure JSON_ImplementationDefined_NoCrash;

    // valid JSON is valid JSON5, and reads the same
    [Test]
    procedure JSON5_AcceptsValid;
  end;

  [TestFixture]
  TJSON5TestSuiteTests = class
  public
    [Test]
    procedure JSON5_AcceptsValid;
    [Test]
    procedure JSON5_RejectsInvalid;
    [Test]
    procedure JSON5_RoundTrip;

    [Test]
    procedure StrictJSON_AcceptsJSON;
    [Test]
    procedure StrictJSON_RejectsJSON5;
  end;

implementation

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.StrUtils,
  System.Types;

type
  TJSONParserKind = (jpJSON, jpJSON5);

const
  // Labelled JSON upstream, but it holds a /* */ comment - valid JSON5 only.
  cMislabelledJSON = 'irregular-block-comment.json';

function SuiteDir(const name : string) : string;
begin
  result := TPath.GetFullPath(TPath.Combine(ExtractFilePath(ParamStr(0)), '..\..\TestFiles\' + name));
end;

// The files of JSONTestSuite whose names start with prefix (y_, n_ or i_)
function JSONTestSuiteFiles(const prefix : string) : TArray<string>;
var
  all : TStringDynArray;
  i, count : integer;
begin
  all := TDirectory.GetFiles(TPath.Combine(SuiteDir('JSONTestSuite'), 'test_parsing'), '*.json');
  SetLength(result, Length(all));
  count := 0;
  for i := 0 to Length(all) - 1 do
  begin
    if StartsText(prefix, ExtractFileName(all[i])) then
    begin
      result[count] := all[i];
      Inc(count);
    end;
  end;
  SetLength(result, count);
  Assert.IsTrue(count > 0, 'no ' + prefix + ' files found in ' + SuiteDir('JSONTestSuite'));
end;

// The json5-tests files with any of the given extensions
function JSON5TestFiles(const extensions : array of string) : TArray<string>;
var
  all : TStringDynArray;
  i, j, count : integer;
begin
  all := TDirectory.GetFiles(SuiteDir('json5-tests'), '*.*', TSearchOption.soAllDirectories);
  SetLength(result, Length(all));
  count := 0;
  for i := 0 to Length(all) - 1 do
  begin
    for j := 0 to Length(extensions) - 1 do
    begin
      if SameText(ExtractFileExt(all[i]), extensions[j]) then
      begin
        result[count] := all[i];
        Inc(count);
        break;
      end;
    end;
  end;
  SetLength(result, count);
  Assert.IsTrue(count > 0, 'no test files found in ' + SuiteDir('json5-tests'));
end;

function ParserOptions(kind : TJSONParserKind) : IYAMLParserOptions;
begin
  result := TYAML.CreateParserOptions;
  if kind = jpJSON5 then
    result.InputFormat := TYAMLInputFormat.yifJSON5
  else
    result.InputFormat := TYAMLInputFormat.yifJSON;
end;

// Reads the file as LoadFromFile would (bytes decoded by the stream reader), with the
// format and parser given rather than chosen by the extension.
function TryLoad(const fileName : string; kind : TJSONParserKind; out doc : IYAMLDocument; out error : string) : boolean;
var
  stream : TFileStream;
begin
  doc := nil;
  error := '';
  try
    stream := TFileStream.Create(fileName, fmOpenRead or fmShareDenyWrite);
    try
      doc := TYAML.LoadFromStream(stream, ParserOptions(kind));
    finally
      stream.Free;
    end;
    result := true;
  except
    on E : Exception do
    begin
      error := E.ClassName + ': ' + E.Message;
      result := false;
    end;
  end;
end;

function CompactJSON(const doc : IYAMLDocument) : string;
var
  options : IYAMLEmitOptions;
begin
  options := TYAML.CreateWriterOptions;
  options.PrettyPrint := false;
  result := TYAML.WriteToJSONString(doc.Root, options);
end;

procedure AddFailure(var failures : string; const fileName, msg : string);
begin
  failures := failures + sLineBreak + '  ' + ExtractFileName(fileName) + ' - ' + msg;
end;

procedure CheckNoFailures(const failures : string; total : integer);
begin
  if failures <> '' then
    Assert.Fail('Failed files (of ' + IntToStr(total) + '):' + failures)
  else
    Assert.Pass(IntToStr(total) + ' files');
end;

procedure CheckAccepts(const files : TArray<string>; kind : TJSONParserKind);
var
  i : integer;
  doc : IYAMLDocument;
  error, failures : string;
begin
  failures := '';
  for i := 0 to Length(files) - 1 do
  begin
    if not TryLoad(files[i], kind, doc, error) then
      AddFailure(failures, files[i], 'rejected: ' + error);
  end;
  CheckNoFailures(failures, Length(files));
end;

// A rejection must be a parse error, or - for bytes that are not valid UTF-8 - the stream
// reader's EEncodingError, which comes before any parsing.
function IsRejection(const error : string) : boolean;
begin
  result := StartsText('EYAMLParseException', error) or StartsText('EEncodingError', error);
end;

procedure CheckRejects(const files : TArray<string>; kind : TJSONParserKind);
var
  i : integer;
  doc : IYAMLDocument;
  error, failures : string;
begin
  failures := '';
  for i := 0 to Length(files) - 1 do
  begin
    if TryLoad(files[i], kind, doc, error) then
      AddFailure(failures, files[i], 'accepted')
    else if not IsRejection(error) then
      AddFailure(failures, files[i], 'rejected with ' + error);
  end;
  CheckNoFailures(failures, Length(files));
end;

{ TJSONTestSuiteTests }

procedure TJSONTestSuiteTests.JSON_AcceptsValid;
begin
  CheckAccepts(JSONTestSuiteFiles('y_'), jpJSON);
end;

procedure TJSONTestSuiteTests.JSON_RejectsInvalid;
begin
  CheckRejects(JSONTestSuiteFiles('n_'), jpJSON);
end;

// Either result is allowed, but only as a document or a parse or encoding error - never
// an access violation, range error or the like.
procedure TJSONTestSuiteTests.JSON_ImplementationDefined_NoCrash;
var
  files : TArray<string>;
  i : integer;
  doc : IYAMLDocument;
  error, failures : string;
begin
  files := JSONTestSuiteFiles('i_');
  failures := '';
  for i := 0 to Length(files) - 1 do
  begin
    if not TryLoad(files[i], jpJSON, doc, error) then
    begin
      if not IsRejection(error) then
        AddFailure(failures, files[i], error);
    end;
  end;
  CheckNoFailures(failures, Length(files));
end;

procedure TJSONTestSuiteTests.JSON5_AcceptsValid;
var
  files : TArray<string>;
  i : integer;
  json5Doc, jsonDoc : IYAMLDocument;
  error, failures : string;
begin
  files := JSONTestSuiteFiles('y_');
  failures := '';
  for i := 0 to Length(files) - 1 do
  begin
    if not TryLoad(files[i], jpJSON5, json5Doc, error) then
      AddFailure(failures, files[i], 'rejected: ' + error)
    else if TryLoad(files[i], jpJSON, jsonDoc, error) and (CompactJSON(json5Doc) <> CompactJSON(jsonDoc)) then
      AddFailure(failures, files[i], 'reads differently: ' + CompactJSON(json5Doc) + ' vs ' + CompactJSON(jsonDoc));
  end;
  CheckNoFailures(failures, Length(files));
end;


{ TJSON5TestSuiteTests }

procedure TJSON5TestSuiteTests.JSON5_AcceptsValid;
begin
  CheckAccepts(JSON5TestFiles(['.json', '.json5']), jpJSON5);
end;

procedure TJSON5TestSuiteTests.JSON5_RejectsInvalid;
begin
  CheckRejects(JSON5TestFiles(['.js', '.txt']), jpJSON5);
end;

// Writing a file as JSON5, reading that back and writing it again gives the same text, and
// the same data.
procedure TJSON5TestSuiteTests.JSON5_RoundTrip;
var
  files : TArray<string>;
  i : integer;
  doc, readBack : IYAMLDocument;
  error, failures, written : string;
begin
  files := JSON5TestFiles(['.json', '.json5']);
  failures := '';
  for i := 0 to Length(files) - 1 do
  begin
    if not TryLoad(files[i], jpJSON5, doc, error) then
    begin
      AddFailure(failures, files[i], 'rejected: ' + error);
      continue;
    end;
    written := TYAML.WriteToJSON5String(doc);
    try
      readBack := TYAML.LoadFromString(written, ParserOptions(jpJSON5));
    except
      on E : Exception do
      begin
        AddFailure(failures, files[i], 'output did not read back: ' + E.Message + sLineBreak + written);
        continue;
      end;
    end;
    if TYAML.WriteToJSON5String(readBack) <> written then
      AddFailure(failures, files[i], 'output changed on a second round trip')
    else if CompactJSON(readBack) <> CompactJSON(doc) then
      AddFailure(failures, files[i], 'data changed: ' + CompactJSON(doc) + ' became ' + CompactJSON(readBack));
  end;
  CheckNoFailures(failures, Length(files));
end;

procedure TJSON5TestSuiteTests.StrictJSON_AcceptsJSON;
var
  files : TArray<string>;
  i, count : integer;
  doc : IYAMLDocument;
  error, failures : string;
begin
  files := JSON5TestFiles(['.json']);
  failures := '';
  count := 0;
  for i := 0 to Length(files) - 1 do
  begin
    if SameText(ExtractFileName(files[i]), cMislabelledJSON) then
      continue;
    Inc(count);
    if not TryLoad(files[i], jpJSON, doc, error) then
      AddFailure(failures, files[i], 'rejected: ' + error);
  end;
  CheckNoFailures(failures, count);
end;

procedure TJSON5TestSuiteTests.StrictJSON_RejectsJSON5;
var
  files : TArray<string>;
  mislabelled : string;
begin
  files := JSON5TestFiles(['.json5', '.js', '.txt']);
  mislabelled := TPath.Combine(TPath.Combine(SuiteDir('json5-tests'), 'comments'), cMislabelledJSON);
  Assert.IsTrue(FileExists(mislabelled), 'missing ' + mislabelled);
  SetLength(files, Length(files) + 1);
  files[Length(files) - 1] := mislabelled;
  CheckRejects(files, jpJSON);
end;

initialization
  TDUnitX.RegisterTestFixture(TJSONTestSuiteTests);
  TDUnitX.RegisterTestFixture(TJSON5TestSuiteTests);

end.

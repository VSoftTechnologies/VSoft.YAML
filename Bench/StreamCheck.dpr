program StreamCheck;

// Confirms LoadFromFile / LoadFromStream give the same result as LoadFromString for
// every test file: the same document, or the same error. Each file is also tried with
// CRLF line breaks and cut short at a few places (to compare errors), encoded as
// UTF-8 (with and without BOM) and UTF-16 LE and BE, and read from the stream in blocks
// of several sizes, small enough that block boundaries fall inside every kind of token.
//   StreamCheck [quick]     quick: only the default block size

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  VSoft.YAML in '..\Source\VSoft.YAML.pas',
  VSoft.YAML.IO in '..\Source\VSoft.YAML.IO.pas';

var
  failures, checks : integer;

function Outcome(const load : TFunc<IYAMLDocument>) : string;
begin
  try
    result := TYAML.WriteToJSONString(load());
  except
    on E : Exception do
      result := 'ERROR ' + E.ClassName + ': ' + E.Message;
  end;
end;

procedure CheckEncoded(const name, src, expected : string; jsonMode : boolean; encoding : TEncoding; withBOM : boolean);
var
  options : IYAMLParserOptions;
  stream : TMemoryStream;
  preamble, bytes : TBytes;
  actual : string;
begin
  options := TYAML.CreateParserOptions;
  options.JSONMode := jsonMode;
  stream := TMemoryStream.Create;
  try
    if withBOM then
    begin
      preamble := encoding.GetPreamble;
      if Length(preamble) > 0 then
        stream.WriteBuffer(preamble[0], Length(preamble));
    end;
    bytes := encoding.GetBytes(src);
    if Length(bytes) > 0 then
      stream.WriteBuffer(bytes[0], Length(bytes));
    stream.Position := 0;
    actual := Outcome(function : IYAMLDocument begin result := TYAML.LoadFromStream(stream, options); end);
  finally
    stream.Free;
  end;
  Inc(checks);
  if actual <> expected then
  begin
    Inc(failures);
    WriteLn('MISMATCH ', name, ' (', encoding.EncodingName, ' bom=', withBOM,
      ' block=', TStreamTextSource.BlockSize, ')');
    WriteLn('  string: ', Copy(expected, 1, 200));
    WriteLn('  stream: ', Copy(actual, 1, 200));
  end;
end;

procedure CheckText(const name, src : string; isJson : boolean);
var
  options : IYAMLParserOptions;
  expected : string;
begin
  options := TYAML.CreateParserOptions;
  options.JSONMode := isJson;
  expected := Outcome(function : IYAMLDocument begin result := TYAML.LoadFromString(src, options); end);
  CheckEncoded(name, src, expected, isJson, TEncoding.UTF8, false);
  CheckEncoded(name, src, expected, isJson, TEncoding.UTF8, true);
  CheckEncoded(name, src, expected, isJson, TEncoding.Unicode, true);
  CheckEncoded(name, src, expected, isJson, TEncoding.BigEndianUnicode, true);
end;

procedure CheckFile(const f : string);
var
  src, crlf, expected : string;
  isJson : boolean;
  opts : IYAMLParserOptions;
  cut : integer;
begin
  isJson := SameText(ExtractFileExt(f), '.json');
  src := TFile.ReadAllText(f, TEncoding.UTF8);
  CheckText(ExtractFileName(f), src, isJson);
  crlf := StringReplace(StringReplace(src, #13#10, #10, [rfReplaceAll]), #10, #13#10, [rfReplaceAll]);
  if crlf <> src then
    CheckText(ExtractFileName(f) + ' (CRLF)', crlf, isJson);
  for cut in [Length(src) div 3, Length(src) div 2 + 7, Length(src) - 5] do
    if (cut > 0) and (cut < Length(src)) then
      CheckText(ExtractFileName(f) + ' (cut at ' + IntToStr(cut) + ')', Copy(src, 1, cut), isJson);

  // and the real file path (explicit options: LoadFromFile with nil options on a
  // .json file flips the global default options to JSONMode - pre-existing behaviour)
  opts := TYAML.CreateParserOptions;
  opts.JSONMode := isJson;
  expected := Outcome(function : IYAMLDocument begin result := TYAML.LoadFromString(src, opts); end);
  Inc(checks);
  if Outcome(function : IYAMLDocument begin result := TYAML.LoadFromFile(f, opts); end) <> expected then
  begin
    Inc(failures);
    WriteLn('MISMATCH LoadFromFile ', ExtractFileName(f), ' block=', TStreamTextSource.BlockSize);
  end;
end;

var
  f : string;
  blockSize : integer;
  blockSizes : TArray<integer>;
begin
  failures := 0;
  checks := 0;
  if SameText(ParamStr(1), 'quick') then
    blockSizes := [TStreamTextSource.BlockSize]
  else
    blockSizes := [TStreamTextSource.BlockSize, 8, 9, 10, 11, 13, 64, 257, 4099];
  for blockSize in blockSizes do
  begin
    TStreamTextSource.BlockSize := blockSize;
    for f in TDirectory.GetFiles(TPath.Combine(ExtractFilePath(ParamStr(0)), '..\Tests\TestFiles')) do
      if SameText(ExtractFileExt(f), '.yaml') or SameText(ExtractFileExt(f), '.json') then
        CheckFile(f);
    WriteLn('block ', blockSize, ': ', checks, ' checks, ', failures, ' failures so far');
  end;
  WriteLn('failures=', failures);
  if failures > 0 then
    ExitCode := 1;
end.

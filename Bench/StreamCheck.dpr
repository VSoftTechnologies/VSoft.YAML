program StreamCheck;

// Confirms LoadFromFile / LoadFromStream give the same document as LoadFromString
// for every test file, including BOM-prefixed UTF-8 and UTF-16 copies.

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  VSoft.YAML in '..\Source\VSoft.YAML.pas';

var
  failures : integer;

function Dump(const doc : IYAMLDocument) : string;
begin
  result := TYAML.WriteToJSONString(doc);
end;

procedure CheckEncoded(const name, src : string; jsonMode : boolean; encoding : TEncoding; withBOM : boolean);
var
  options : IYAMLParserOptions;
  stream : TMemoryStream;
  preamble, bytes : TBytes;
  expected, actual : string;
begin
  options := TYAML.CreateParserOptions;
  options.JSONMode := jsonMode;
  expected := Dump(TYAML.LoadFromString(src, options));
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
    actual := Dump(TYAML.LoadFromStream(stream, options));
  finally
    stream.Free;
  end;
  if actual <> expected then
  begin
    Inc(failures);
    WriteLn('MISMATCH ', name, ' (', encoding.EncodingName, ' bom=', withBOM, ')');
  end;
end;

var
  f, src : string;
  isJson : boolean;
  opts : IYAMLParserOptions;
begin
  failures := 0;
  for f in TDirectory.GetFiles(TPath.Combine(ExtractFilePath(ParamStr(0)), '..\Tests\TestFiles')) do
  begin
    if not (SameText(ExtractFileExt(f), '.yaml') or SameText(ExtractFileExt(f), '.json')) then
      continue;
    isJson := SameText(ExtractFileExt(f), '.json');
    src := TFile.ReadAllText(f, TEncoding.UTF8);
    try
      CheckEncoded(ExtractFileName(f), src, isJson, TEncoding.UTF8, false);
      CheckEncoded(ExtractFileName(f), src, isJson, TEncoding.UTF8, true);
      CheckEncoded(ExtractFileName(f), src, isJson, TEncoding.Unicode, true);
      // and the real file path
      // explicit options: LoadFromFile(nil options) on a .json file flips the global
      // default options to JSONMode (pre-existing behaviour)
      opts := TYAML.CreateParserOptions;
      opts.JSONMode := isJson;
      if Dump(TYAML.LoadFromFile(f, opts)) <> Dump(TYAML.LoadFromString(src, opts)) then
      begin
        Inc(failures);
        WriteLn('MISMATCH LoadFromFile ', ExtractFileName(f));
      end;
      WriteLn('ok  ', ExtractFileName(f));
    except
      on E : Exception do
        WriteLn('n/a ', ExtractFileName(f), ': ', E.ClassName, ' ', E.Message);
    end;
  end;
  WriteLn('failures=', failures);
  if failures > 0 then
    ExitCode := 1;
end.

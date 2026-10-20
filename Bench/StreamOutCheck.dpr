program StreamOutCheck;
// Hashes stream output (YAML/JSON, UTF-8/UTF-16, BOM) of the given test files, for
//    comparing two builds.
{$APPTYPE CONSOLE}
uses
  System.SysUtils, System.Classes, System.IOUtils, System.Hash,
  VSoft.YAML in '..\Source\VSoft.YAML.pas';

function HashStream(ms : TMemoryStream) : string;
var b : TBytes;
begin
  SetLength(b, ms.Size);
  if ms.Size > 0 then Move(ms.Memory^, b[0], ms.Size);
  result := Copy(THashMD5.GetHashString(TEncoding.ANSI.GetString(b) + IntToStr(ms.Size)), 1, 12);
end;

procedure FileHashes(const dir : string);
var f : string; opts : IYAMLParserOptions; doc : IYAMLDocument; ms : TMemoryStream; e : integer;
begin
  for f in TDirectory.GetFiles(dir) do
  begin
    opts := TYAML.CreateParserOptions;
    opts.JSONMode := SameText(ExtractFileExt(f), '.json');
    doc := TYAML.LoadFromString(TFile.ReadAllText(f), opts);
    ms := TMemoryStream.Create;
    try
      for e := 0 to 1 do
      begin
        if e = 0 then doc.Options.Encoding := TEncoding.UTF8 else doc.Options.Encoding := TEncoding.Unicode;
        doc.Options.WriteByteOrderMark := e = 1;
        ms.Clear; TYAML.WriteToStream(doc, ms);
        Write(ExtractFileName(f), ' e', e, ' yaml ', HashStream(ms));
        ms.Clear; TYAML.WriteToJSONStream(doc, ms);
        WriteLn('  json ', HashStream(ms));
      end;
    finally
      ms.Free;
    end;
  end;
end;


begin
  if ParamStr(1) <> '' then FileHashes(ParamStr(1));
end.

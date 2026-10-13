program NumFuzz;
// Writes a deterministic dump (value type + raw value, or the error) for many random
// number-like scalars in YAML block, YAML flow and JSON contexts. Build against two
// source trees and diff the outputs.
{$APPTYPE CONSOLE}
uses System.SysUtils, System.Classes, VSoft.YAML in '..\Source\VSoft.YAML.pas';
const
  Pieces : array[0..21] of string = ('0', '1', '7', '9', '-', '+', '.', '_', 'e', 'E', 'x', 'b', 'o',
    ':', ' ', ',', 'a', '$', '00', '123', '.5', 'e-3');
var
  outLines : TStringList;
function RandToken : string;
var n, i : integer;
begin
  result := '';
  n := 1 + Random(6);
  for i := 1 to n do
    result := result + Pieces[Random(Length(Pieces))];
end;
function Describe(const v : IYAMLValue) : string;
var i : integer;
begin
  if v.IsMapping then
  begin
    result := '{';
    for i := 0 to v.AsMapping.Count - 1 do
      result := result + v.AsMapping.Keys[i] + '=' + Describe(v.AsMapping.Values[v.AsMapping.Keys[i]]) + ';';
    result := result + '}';
  end
  else if v.IsSequence then
  begin
    result := '[';
    for i := 0 to v.AsSequence.Count - 1 do
      result := result + Describe(v.AsSequence[i]) + ';';
    result := result + ']';
  end
  else
    result := IntToStr(Ord(v.ValueType)) + ':' + v.RawValue;
end;
procedure Run(const src : string; json : boolean);
var opts : IYAMLParserOptions; doc : IYAMLDocument;
begin
  opts := TYAML.CreateParserOptions;
  opts.JSONMode := json;
  try
    doc := TYAML.LoadFromString(src, opts);
    outLines.Add(src.Replace(#10, '\n') + ' => ' + Describe(doc.Root));
  except
    on E : Exception do
      outLines.Add(src.Replace(#10, '\n') + ' => ' + E.ClassName + ': ' + E.Message);
  end;
end;
var i : integer; t, t2 : string;
begin
  RandSeed := 12345;
  outLines := TStringList.Create;
  try
    for i := 1 to 20000 do
    begin
      t := RandToken;
      t2 := RandToken;
      Run('k: ' + t + #10 + 'j: ' + t2 + #10, false);
      Run('- ' + t + #10 + '- ' + t2 + #10, false);
      Run('k: [' + t + ', ' + t2 + ']' + #10, false);
      Run('{a: ' + t + ', ' + t2 + ': 1}' + #10, false);
      Run(t + #10, false);
      Run('{"a": ' + t + ', "b": [' + t2 + ', 1]}', true);
      Run('[' + t + ']', true);
    end;
    outLines.SaveToFile(ParamStr(1), TEncoding.UTF8);
    WriteLn(outLines.Count, ' cases');
  finally
    outLines.Free;
  end;
end.

program TruncCheck;
// Content after a mis-indented line must raise, not be silently dropped; valid
// documents (trailing comments, multi-doc, ...) must still load.
{$APPTYPE CONSOLE}
uses System.SysUtils, VSoft.YAML in '..\Source\VSoft.YAML.pas';
var failures : integer;
procedure Check(const title, src : string; expectError : boolean; all : boolean = false);
var doc : IYAMLDocument; docs : TArray<IYAMLDocument>; outText : string;
begin
  try
    if all then
    begin
      docs := TYAML.LoadAllFromString(src);
      outText := IntToStr(Length(docs)) + ' docs: ' + TYAML.WriteToJSONString(docs);
    end
    else
    begin
      doc := TYAML.LoadFromString(src);
      outText := TYAML.WriteToJSONString(doc);
    end;
    outText := outText.Replace(#13#10, ' ').Replace('  ', '');
    if expectError then begin Inc(failures); WriteLn('FAIL ', title, ' parsed: ', outText); end
    else WriteLn('ok   ', title, ' -> ', outText);
  except
    on E : Exception do
      if expectError then WriteLn('ok   ', title, ' -> ', E.ClassName, ': ', E.Message)
      else begin Inc(failures); WriteLn('FAIL ', title, ' raised ', E.ClassName, ': ', E.Message); end;
  end;
end;
begin
  failures := 0;
  // invalid: must raise
  Check('A', 'list:'#10'  - 1'#10'types:'#10'  a: 1'#10'  - id: 0'#10'more: 2'#10, true);
  Check('B', 'types:'#10'  a: 1'#10'  - id: 0'#10'more: 2'#10, true);
  Check('C', 'a: 1'#10'  - x'#10'b: 2'#10, true);
  Check('D', 'top:'#10'  a: 1'#10'    - x'#10'  b: 2'#10'c: 3'#10, true);
  Check('E all', 'a: 1'#10'  - x'#10'b: 2'#10, true, true);
  // valid: must load
  Check('V1 trailing comment', 'a: 1'#10'b: 2'#10'# end'#10#10, false);
  Check('V2 seq root', '- 1'#10'- 2'#10, false);
  Check('V3 multi-doc first', 'a: 1'#10'---'#10'b: 2'#10, false);
  Check('V4 multi-doc all', 'a: 1'#10'---'#10'b: 2'#10'...'#10, false, true);
  Check('V5 nested', 'a:'#10'  - x'#10'  - y'#10'b:'#10'  c: 1'#10, false);
  Check('V6 doc end', 'a: 1'#10'...'#10, false);
  Check('V7 seq of maps', '- a: 1'#10'  b: 2'#10'- a: 3'#10, false);
  Check('V8 scalar', 'hello'#10'# c'#10, false);
  WriteLn('failures=', failures);
  ExitCode := failures;
end.

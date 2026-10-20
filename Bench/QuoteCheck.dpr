program QuoteCheck;
// For every UTF-16 first char outside NeedsQuoting's number pre-check set, confirm
// TryStrToInt / TryStrToFloat reject the string for a spread of suffixes.
{$APPTYPE CONSOLE}
uses System.SysUtils, VSoft.YAML.Classes in '..\Source\VSoft.YAML.Classes.pas';
const
  Suffixes : array[0..11] of string = ('', '1', '0', '12.5', 'e5', 'E5', 'NF', 'nf', 'AN', 'an', 'x1', '.5');
var
  c : integer; s, suf : string; iv : integer; fv : Double; bad : integer;
begin
  bad := 0;
  for c := 1 to $FFFF do
  begin
    if CharInSet(Char(c), ['0'..'9', '+', '-', '.', '$', 'x', 'X', 'i', 'I', 'n', 'N']) then
      continue;
    // whitespace-led values are quoted before this check runs
    if (c = 32) or (c = 9) then
      continue;
    for suf in Suffixes do
    begin
      s := Char(c) + suf;
      if TryStrToInt(s, iv) or TryStrToFloat(s, fv, YAMLFormatSettings) then
      begin
        Inc(bad);
        if bad < 20 then WriteLn('accepted: U+', IntToHex(c, 4), ' "', s, '"');
      end;
    end;
  end;
  WriteLn('bad=', bad);
end.

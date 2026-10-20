program FloatCheck;

// Verifies YAMLCanonicalFloatText against FloatToStr(StrToFloat()) for edge cases and
// a few million random decimal strings. Any accepted input must match exactly.

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  VSoft.YAML.Classes in '..\Source\VSoft.YAML.Classes.pas';

var
  checked, accepted, failures : Int64;

procedure Check(const s : string);
var
  fast, slow : string;
begin
  Inc(checked);
  if not YAMLCanonicalFloatText(s, fast) then
    exit;
  Inc(accepted);
  slow := FloatToStr(StrToFloat(s, YAMLFormatSettings), YAMLFormatSettings);
  if fast <> slow then
  begin
    Inc(failures);
    if failures <= 30 then
      WriteLn('MISMATCH  raw=', s, '  fast=', fast, '  rtl=', slow);
  end;
end;

function RandDigits(n : integer; noLeadingZero : boolean) : string;
var
  i : integer;
begin
  SetLength(result, n);
  for i := 1 to n do
    result[i] := Char(Ord('0') + Random(10));
  if noLeadingZero and (n > 0) and (result[1] = '0') then
    result[1] := Char(Ord('1') + Random(9));
end;

const
  Edge : array[0..33] of string = (
    '0.0', '-0.0', '0.5', '-0.5', '0.05', '0.005', '0.0005', '0.00005', '0.000001',
    '1.0', '10.0', '100.0', '224.0', '100.85', '-86.8760416666719', '-86.87604166667190',
    '123456789012345.0', '1234567890123456.0', '12345678901234.5', '1234567890123.45',
    '0.123456789012345', '0.1234567890123456', '999999999999999.0', '99999999999999.9',
    '9.99999999999999', '0.999999999999999', '1e5', '1.5e3', '01.5', '.5', '5.', '+1.5',
    '1.5 ', '1_000.5');
var
  i, intLen, fracLen : integer;
  s : string;
begin
  Randomize;
  for s in Edge do
    Check(s);
  for i := 1 to 3000000 do
  begin
    intLen := 1 + Random(17);
    fracLen := 1 + Random(17);
    if Random(4) = 0 then
      s := '0.' + StringOfChar('0', Random(5)) + RandDigits(fracLen, false)
    else
      s := RandDigits(intLen, true) + '.' + RandDigits(fracLen, false);
    if Random(6) = 0 then
      s := s + StringOfChar('0', Random(4));
    if Random(2) = 0 then
      s := '-' + s;
    Check(s);
  end;
  WriteLn(Format('checked=%d accepted=%d failures=%d', [checked, accepted, failures]));
  if failures > 0 then
    ExitCode := 1;
end.

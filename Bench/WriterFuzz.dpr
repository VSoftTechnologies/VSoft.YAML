program WriterFuzz;

// Differential test for the YAML and JSON writers: builds many random documents
// (keys/strings needing quoting or escaping, comments, tags, sets, multi-line strings,
// empty and nested collections, non-BMP characters) and writes each one under a range
// of emit options through string and stream output. Everything is dumped to a file;
// build against two source trees and compare the files byte for byte.
//   WriterFuzz <outfile> [docs]

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Classes,
  VSoft.YAML in '..\Source\VSoft.YAML.pas';

const
  Atoms : array[0..35] of string = (
    'a', 'key', 'value', 'Hello World', '', ' ', 'x y', 'true', 'null', '~', 'yes', '123', '1.5',
    '-', '- a', ':', 'a: b', 'a:b', '#', 'a #b', '[x]', '{y}', ',', '"q"', '''s''', '\', 'tab'#9,
    'line1'#10'line2', 'cr'#13'lf'#10, #1'ctl', 'é', #$2028, 'smile '#$D83D#$DE00, 'x'#$85,
    'lone'#$D800, #$DC00'low');

var
  outStream : TFileStream;

procedure Emit(const s : string);
var
  b : TBytes;
begin
  b := TEncoding.UTF8.GetBytes(s + #10);
  if Length(b) > 0 then
    outStream.WriteBuffer(b[0], Length(b));
end;

procedure EmitBytes(const title : string; ms : TMemoryStream);
var
  hex : TStringBuilder;
  p : PByte;
  i : integer;
begin
  hex := TStringBuilder.Create;
  try
    p := ms.Memory;
    for i := 0 to ms.Size - 1 do
    begin
      hex.Append(IntToHex(p^, 2));
      Inc(p);
    end;
    Emit(title + ' ' + hex.ToString);
  finally
    hex.Free;
  end;
end;

function RandText : string;
var
  n, i : integer;
begin
  result := '';
  n := Random(3);
  for i := 0 to n do
    result := result + Atoms[Random(Length(Atoms))];
end;

function RandTag : string;
begin
  case Random(8) of
    0 : result := '!!str';
    1 : result := '!custom';
  else
    result := '';
  end;
end;

procedure FillSequence(const seq : IYAMLSequence; depth : integer); forward;

procedure FillMapping(const map : IYAMLMapping; depth : integer);
var
  i, n : integer;
  key : string;
  v : IYAMLValue;
begin
  n := Random(5);
  if Random(6) = 0 then
    map.AddComment(RandText);
  for i := 0 to n do
  begin
    key := RandText;
    if key = '' then
      key := 'k' + IntToStr(i);
    v := nil;
    case Random(10) of
      0 : if depth < 4 then FillMapping(map.AddOrSetMapping(key, RandTag), depth + 1);
      1 : if depth < 4 then FillSequence(map.AddOrSetSequence(key, RandTag), depth + 1);
      2 : if depth < 4 then FillSequence(map.AddOrSetSet(key), depth + 1);
      3 : v := map.AddOrSetValue(key, Int64(Random(100000) - 50000));
      4 : v := map.AddOrSetValue(key, Random(2) = 0);
      5 : v := map.AddOrSetNull(key);
      6 : v := map.AddOrSetValue(key, (Random(100000) - 50000) / 7.0);
    else
      v := map.AddOrSetValue(key, RandText, RandTag);
    end;
    if (v <> nil) and (Random(5) = 0) then
      v.Comment := RandText;
  end;
end;

procedure FillSequence(const seq : IYAMLSequence; depth : integer);
var
  i, n : integer;
  v : IYAMLValue;
begin
  n := Random(7);
  if Random(6) = 0 then
    seq.AddComment(RandText);
  for i := 0 to n - 1 do
  begin
    v := nil;
    case Random(10) of
      0 : if depth < 4 then FillMapping(seq.AddMapping(RandTag), depth + 1);
      1 : if depth < 4 then FillSequence(seq.AddSequence(RandTag), depth + 1);
      2 : v := seq.AddValue(Int64(Random(1000)));
      3 : v := seq.AddValue(Random(2) = 0);
      4 : v := seq.AddNull;
    else
      v := seq.AddValue(RandText, RandTag);
    end;
    if (v <> nil) and (Random(5) = 0) then
      v.Comment := RandText;
  end;
end;

procedure Guard(const title : string; const proc : TProc);
begin
  try
    proc;
  except
    on E : Exception do
      Emit(title + ' RAISED ' + E.ClassName + ': ' + E.Message);
  end;
end;

procedure WriteAll(const caseNo : integer; const doc : IYAMLDocument);
const
  Formats : array[0..2] of TYAMLOutputFormat = (TYAMLOutputFormat.yofBlock, TYAMLOutputFormat.yofFlow, TYAMLOutputFormat.yofMixed);
var
  f, variant : integer;
  ms : TMemoryStream;
  title : string;
begin
  for f := 0 to 2 do
    for variant := 0 to 3 do
    begin
      doc.Options.Format := Formats[f];
      doc.Options.PrettyPrint := (variant and 1) = 0;
      doc.Options.EmitExplicitNull := (variant and 2) <> 0;
      doc.Options.EmitDocumentMarkers := variant = 3;
      doc.Options.EmitTags := variant <> 1;
      doc.Options.QuoteStrings := (caseNo mod 11 = 0) and (variant = 2);
      if variant = 2 then
        doc.Options.BlockScalarStyle := TYAMLBlockScalarStyle.bssLiteral
      else if variant = 3 then
        doc.Options.BlockScalarStyle := TYAMLBlockScalarStyle.bssFolded
      else
        doc.Options.BlockScalarStyle := TYAMLBlockScalarStyle.bssNone;
      title := Format('#%d f%d v%d', [caseNo, f, variant]);
      Guard(title + ' yaml', procedure begin Emit(title + ' yaml'#10 + TYAML.WriteToString(doc)); end);
      Guard(title + ' json', procedure begin Emit(title + ' json'#10 + TYAML.WriteToJSONString(doc)); end);
      if variant < 2 then
      begin
        ms := TMemoryStream.Create;
        try
          if variant = 0 then
            doc.Options.Encoding := TEncoding.UTF8
          else
            doc.Options.Encoding := TEncoding.Unicode;
          doc.Options.WriteByteOrderMark := (caseNo mod 2) = 0;
          Guard(title + ' yaml-stream', procedure begin TYAML.WriteToStream(doc, ms); EmitBytes(title + ' yaml-stream', ms); end);
          ms.Clear;
          Guard(title + ' json-stream', procedure begin TYAML.WriteToJSONStream(doc, ms); EmitBytes(title + ' json-stream', ms); end);
          ms.Clear;
          Guard(title + ' yaml-stream-multi', procedure begin TYAML.WriteToStream(TArray<IYAMLDocument>.Create(doc, doc), ms); EmitBytes(title + ' yaml-stream-multi', ms); end);
        finally
          ms.Free;
          doc.Options.Encoding := TEncoding.UTF8;
          doc.Options.WriteByteOrderMark := false;
        end;
      end;
    end;
  Guard('multi', procedure begin Emit(Format('#%d multi'#10'%s', [caseNo, TYAML.WriteToString(TArray<IYAMLDocument>.Create(doc, doc))])); end);
  Guard('multi-json', procedure begin Emit(Format('#%d multi-json'#10'%s', [caseNo, TYAML.WriteToJSONString(TArray<IYAMLDocument>.Create(doc, doc))])); end);
end;

var
  i, count : integer;
  doc : IYAMLDocument;
begin
  RandSeed := 4242;
  count := StrToIntDef(ParamStr(2), 3000);
  outStream := TFileStream.Create(ParamStr(1), fmCreate);
  try
    for i := 1 to count do
    begin
      if Random(4) = 0 then
      begin
        doc := TYAML.CreateSequence;
        FillSequence(doc.AsSequence, 0);
      end
      else
      begin
        doc := TYAML.CreateMapping;
        FillMapping(doc.AsMapping, 0);
      end;
      try
        WriteAll(i, doc);
      except
        on E : Exception do
          Emit(Format('#%d %s: %s', [i, E.ClassName, E.Message]));
      end;
    end;
  finally
    outStream.Free;
  end;
  WriteLn(count, ' documents');
end.

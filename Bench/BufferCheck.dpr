program BufferCheck;
// Feeds TYAMLOutputBuffer random text (surrogate pairs, lone surrogates, writes bigger
// than a chunk) through 64-char chunks and checks the bytes equal encoding it in one go.
{$APPTYPE CONSOLE}
uses
  System.SysUtils, System.Classes,
  VSoft.YAML.StreamWriter in '..\Source\VSoft.YAML.StreamWriter.pas';

procedure ChunkCheck;
const Pool : array[0..5] of string = ('a', 'bc', #$D83D#$DE00, 'é', #$D800, #13#10);
var i, j, k, fails : integer; whole, piece : string; ms : TMemoryStream; buf : TYAMLOutputBuffer;
    expect : TBytes; enc : TEncoding; got : TBytes;
begin
  fails := 0;
  RandSeed := 99;
  for i := 1 to 2000 do
  begin
    for k := 0 to 1 do
    begin
      if k = 0 then enc := TEncoding.UTF8 else enc := TEncoding.Unicode;
      whole := '';
      ms := TMemoryStream.Create;
      try
        buf := TYAMLOutputBuffer.CreateForStream(ms, enc, false, 64);
        try
          for j := 1 to Random(80) do
          begin
            piece := Pool[Random(Length(Pool))];
            if Random(10) = 0 then piece := StringOfChar('x', Random(200)) + piece; // larger than a chunk
            whole := whole + piece;
            case Random(3) of
              0 : buf.Write(piece);
              1 : if Length(piece) = 1 then buf.WriteChar(piece[1]) else buf.Write(piece);
              2 : begin buf.Write(piece); buf.WriteSpaces(2); whole := whole + '  '; end;
            end;
          end;
        finally
          buf.Free; // flushes
        end;
        expect := enc.GetBytes(whole);
        SetLength(got, ms.Size);
        if ms.Size > 0 then Move(ms.Memory^, got[0], ms.Size);
        if (Length(got) <> Length(expect)) or ((Length(got) > 0) and not CompareMem(@got[0], @expect[0], Length(got))) then
          Inc(fails);
      finally
        ms.Free;
      end;
    end;
  end;
  WriteLn('chunk check failures=', fails);
end;

procedure StringModeCheck;
const Pool : array[0..4] of string = ('a', 'bc', #$D83D#$DE00, '', #13#10);
var i, j, fails : integer; whole, piece, got : string; buf : TYAMLOutputBuffer;
begin
  fails := 0;
  RandSeed := 7;
  for i := 1 to 3000 do
  begin
    whole := '';
    buf := TYAMLOutputBuffer.CreateForString(16);
    try
      for j := 1 to Random(300) do
      begin
        piece := Pool[Random(Length(Pool))];
        if Random(15) = 0 then piece := StringOfChar('y', Random(400)) + piece;
        whole := whole + piece;
        if (Length(piece) = 1) and (Random(2) = 0) then buf.WriteChar(piece[1]) else buf.Write(piece);
      end;
      got := buf.ExtractString;
      if got <> whole then Inc(fails);
      // the buffer must be reusable after ExtractString
      buf.Write('again');
      if buf.ExtractString <> 'again' then Inc(fails);
    finally
      buf.Free;
    end;
  end;
  WriteLn('string mode failures=', fails);
end;

begin
  ChunkCheck;
  StringModeCheck;
end.

program GenBig;

// Scales the benchmark test files up to ~[MB] megabytes each, keeping their style by
// repeating each file's repeating region.
//   GenBig [outDir] [MB]

{$APPTYPE CONSOLE}
{$R GenBigFiles.res}

uses
  Winapi.Windows,
  System.SysUtils,
  System.Classes,
  System.IOUtils;

var
  srcDir, outDir : string;
  target : Int64;

procedure Save(const name : string; sb : TStringBuilder);
begin
  TFile.WriteAllText(TPath.Combine(outDir, name), sb.ToString, TUTF8Encoding.Create(false)); // no BOM, like the originals
  WriteLn(Format('%-30s %8.1f MB', [name, TFile.GetSize(TPath.Combine(outDir, name)) / (1024 * 1024)]));
end;

// prefix + body repeated (joined by sep) + suffix. renamer may rewrite each copy.
procedure Repeated(const name, prefix, body, sep, suffix : string; renamer : TFunc<string, integer, string>);
var
  sb : TStringBuilder;
  copyNo : integer;
begin
  sb := TStringBuilder.Create(target + 1024 * 1024);
  try
    sb.Append(prefix);
    copyNo := 0;
    while sb.Length + Length(body) + Length(suffix) < target do
    begin
      if copyNo > 0 then
        sb.Append(sep);
      if Assigned(renamer) then
        sb.Append(renamer(body, copyNo))
      else
        sb.Append(body);
      Inc(copyNo);
    end;
    sb.Append(suffix);
    Save(name, sb);
  finally
    sb.Free;
  end;
end;

function ReadSrc(const name : string) : string;
var
  resName : string;
  rs : TResourceStream;
  bytes : TBytes;
begin
  if FileExists(TPath.Combine(srcDir, name)) then
    exit(TFile.ReadAllText(TPath.Combine(srcDir, name), TEncoding.UTF8));
  // not next to a repository checkout (e.g. on a benchmark machine): use the copy
  // embedded from GenBigFiles.rc
  resName := UpperCase(name).Replace('.', '_'); // benchmark_large.yaml -> BENCHMARK_LARGE_YAML
  rs := TResourceStream.Create(HInstance, resName, RT_RCDATA);
  try
    SetLength(bytes, rs.Size);
    if rs.Size > 0 then
      rs.ReadBuffer(bytes[0], rs.Size);
  finally
    rs.Free;
  end;
  result := TEncoding.UTF8.GetString(bytes);
end;

procedure SplitAt(const s, marker : string; out before, after : string; fromEnd : boolean = false);
var
  p : integer;
begin
  if fromEnd then
    p := s.LastIndexOf(marker) + 1
  else
    p := Pos(marker, s);
  if p = 0 then
    raise Exception.Create('marker not found: ' + marker);
  before := Copy(s, 1, p - 1);
  after := Copy(s, p, MaxInt);
end;

// data_batch_N: at the start of a line -> data_batch_<copy*100000+N>: so keys stay
// unique across copies (the original's own duplicate keys are kept as duplicates)
function RenameBatches(b : string; n : integer) : string; // TFunc signature: no const
const
  key = 'data_batch_';
var
  sb : TStringBuilder;
  i, j, len : integer;
begin
  sb := TStringBuilder.Create(Length(b) + 4096);
  try
    i := 1;
    len := Length(b);
    while i <= len do
    begin
      if ((i = 1) or (b[i - 1] = #10)) and (Copy(b, i, Length(key)) = key) then
      begin
        j := i + Length(key);
        while (j <= len) and CharInSet(b[j], ['0'..'9']) do
          Inc(j);
        sb.Append(key).Append(n * 100000 + StrToInt(Copy(b, i + Length(key), j - i - Length(key))));
        i := j;
      end
      else
      begin
        sb.Append(b[i]);
        Inc(i);
      end;
    end;
    result := sb.ToString;
  finally
    sb.Free;
  end;
end;

procedure GenLargeYaml;
var
  s, prefix, body : string;
begin
  // header sections + data_batch_1..3, then repeat data_batch_4.. with renamed keys
  s := ReadSrc('benchmark_large.yaml');
  SplitAt(s, #10'data_batch_4:', prefix, body);
  prefix := prefix + #10;
  body := Copy(body, 2, MaxInt);
  if not body.EndsWith(#10) then
    body := body + sLineBreak;
  Repeated('benchmark_large.yaml', prefix, body, '', '', RenameBatches);
end;

procedure GenListYaml(const name : string);
var
  s, prefix, body, suffix : string;
  p : integer;
begin
  // header + "key:" line, then repeat the whole list of "  - id:" items
  s := ReadSrc(name);
  SplitAt(s, #10'  - id:', prefix, body);
  prefix := prefix + #10;
  body := Copy(body, 2, MaxInt);
  // the list ends at the first non-indented line; what follows (other top-level
  // sections) is written once after the copies
  p := 1;
  while p < Length(body) do
  begin
    if (body[p] = #10) and not CharInSet(body[p + 1], [' ', #13, #10]) then
      break;
    Inc(p);
  end;
  suffix := Copy(body, p + 1, MaxInt);
  body := Copy(body, 1, p);
  Repeated(name, prefix, body, '', suffix, nil);
end;

procedure GenJsonArray(const name, openMarker, closeMarker : string);
var
  s, prefix, rest, body, suffix : string;
begin
  // repeat the elements of the one big array, comma-joined
  s := ReadSrc(name);
  SplitAt(s, openMarker, prefix, rest);
  prefix := prefix + openMarker;
  rest := Copy(rest, Length(openMarker) + 1, MaxInt);
  SplitAt(rest, closeMarker, body, suffix, true);
  body := body.TrimRight;
  Repeated(name, prefix, body, ',' + sLineBreak, sLineBreak + suffix.TrimLeft([#13, #10]), nil);
end;

procedure GenKeyValueJson;
var
  sb : TStringBuilder;
  i : integer;
begin
  // same pattern as test.json: one flat object {"keyN":"valueN",...}
  sb := TStringBuilder.Create(target + 1024);
  try
    sb.Append('{');
    i := 1;
    while sb.Length < target do
    begin
      if i > 1 then
        sb.Append(',');
      sb.Append('"key').Append(i).Append('":"value').Append(i).Append('"');
      Inc(i);
    end;
    sb.Append('}');
    Save('test.json', sb);
  finally
    sb.Free;
  end;
end;

begin
  try
    srcDir := TPath.GetFullPath(TPath.Combine(ExtractFilePath(ParamStr(0)), '..\Tests\TestFiles'));
    outDir := ParamStr(1);
    if outDir = '' then
      outDir := TPath.Combine(ExtractFilePath(ParamStr(0)), 'big');
    target := Int64(StrToIntDef(ParamStr(2), 100)) * 1024 * 1024;
    ForceDirectories(outDir);
    GenLargeYaml;
    GenListYaml('benchmark_block_scalars.yaml');
    GenListYaml('benchmark_quoted_strings.yaml');
    GenJsonArray('benchmark_large.json', '"users": [', '],');
    GenJsonArray('load_test.json', '"sample":[', ']');
    GenKeyValueJson;
  except
    on E : Exception do
    begin
      WriteLn(E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.

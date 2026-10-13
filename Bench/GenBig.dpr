program GenBig;

// Makes versions of the benchmark test files of about a given size, keeping their
// style: each file's repeating units (data_batch_N sections, "- id:" list items, the
// elements of a JSON array) are taken in order, cycling back to the first, until the
// target is reached. Works for sizes below the originals as well as above.
//   GenBig [outDir] [size]      size: MB, or with a K/KB suffix kilobytes (default 100)

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
var
  size : Int64;
begin
  TFile.WriteAllText(TPath.Combine(outDir, name), sb.ToString, TUTF8Encoding.Create(false)); // no BOM, like the originals
  size := TFile.GetSize(TPath.Combine(outDir, name));
  if size < 1024 * 1024 then
    WriteLn(Format('%-30s %8.1f KB', [name, size / 1024]))
  else
    WriteLn(Format('%-30s %8.1f MB', [name, size / (1024 * 1024)]));
end;

// prefix + units (joined by sep, cycling through them) + suffix, stopping before the
// target would be passed (at least one unit is always written). renamer may rewrite a
// unit for each pass through the list.
procedure Repeated(const name, prefix : string; const units : TArray<string>; const sep, suffix : string;
  renamer : TFunc<string, integer, string>);
var
  sb : TStringBuilder;
  count, pass, i : integer;
  u : string;
begin
  sb := TStringBuilder.Create(target + 1024 * 1024);
  try
    sb.Append(prefix);
    count := 0;
    pass := 0;
    i := 0;
    while True do
    begin
      u := units[i];
      if Assigned(renamer) then
        u := renamer(u, pass);
      if (count > 0) and (sb.Length + Length(sep) + Length(u) + Length(suffix) > target) then
        break;
      if count > 0 then
        sb.Append(sep);
      sb.Append(u);
      Inc(count);
      Inc(i);
      if i = Length(units) then
      begin
        i := 0;
        Inc(pass);
      end;
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

// Splits body (which starts with marker) into units that each start with marker at
// the beginning of a line; every unit keeps its own trailing line break.
function SplitLineUnits(const body, marker : string) : TArray<string>;
var
  starts : TArray<integer>;
  p, k : integer;
begin
  starts := TArray<integer>.Create(1);
  p := Pos(#10 + marker, body);
  while p > 0 do
  begin
    starts := starts + [p + 1];
    p := Pos(#10 + marker, body, p + 1);
  end;
  SetLength(result, Length(starts));
  for k := 0 to High(starts) do
    if k < High(starts) then
      result[k] := Copy(body, starts[k], starts[k + 1] - starts[k])
    else
      result[k] := Copy(body, starts[k], MaxInt);
  if not result[High(result)].EndsWith(#10) then
    result[High(result)] := result[High(result)] + sLineBreak;
end;

// Splits the inside of a JSON array at its top-level commas (outside strings and
// nested brackets). Each element keeps its leading white space.
function SplitJsonElements(const body : string) : TArray<string>;
var
  i, depth, start : integer;
  inString : boolean;
begin
  result := nil;
  depth := 0;
  inString := False;
  start := 1;
  i := 1;
  while i <= Length(body) do
  begin
    if inString then
    begin
      if body[i] = '\' then
        Inc(i)
      else if body[i] = '"' then
        inString := False;
    end
    else
      case body[i] of
        '"' : inString := True;
        '[', '{' : Inc(depth);
        ']', '}' : Dec(depth);
        ',' : if depth = 0 then
              begin
                result := result + [Copy(body, start, i - start)];
                start := i + 1;
              end;
      end;
    Inc(i);
  end;
  if Trim(Copy(body, start, MaxInt)) <> '' then
    result := result + [Copy(body, start, MaxInt)];
end;

// data_batch_N: at the start of a line -> data_batch_<pass*100000+N>: so keys stay
// unique across passes (the original's own duplicate keys are kept as duplicates)
function RenameBatches(b : string; n : integer) : string; // TFunc signature: no const
const
  key = 'data_batch_';
var
  sb : TStringBuilder;
  i, j, len : integer;
begin
  if n = 0 then
    exit(b);
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
  // header sections + data_batch_1..3, then data_batch_4.. sections (renamed per pass)
  s := ReadSrc('benchmark_large.yaml');
  SplitAt(s, #10'data_batch_4:', prefix, body);
  prefix := prefix + #10;
  body := Copy(body, 2, MaxInt);
  Repeated('benchmark_large.yaml', prefix, SplitLineUnits(body, 'data_batch_'), '', '', RenameBatches);
end;

procedure GenListYaml(const name : string);
var
  s, prefix, body, suffix : string;
  p : integer;
begin
  // header + "key:" line, then the "  - id:" items
  s := ReadSrc(name);
  SplitAt(s, #10'  - id:', prefix, body);
  prefix := prefix + #10;
  body := Copy(body, 2, MaxInt);
  // the list ends at the first non-indented line; what follows (other top-level
  // sections) is written once after the items
  p := 1;
  while p < Length(body) do
  begin
    if (body[p] = #10) and not CharInSet(body[p + 1], [' ', #13, #10]) then
      break;
    Inc(p);
  end;
  suffix := Copy(body, p + 1, MaxInt);
  body := Copy(body, 1, p);
  Repeated(name, prefix, SplitLineUnits(body, '  - id:'), '', suffix, nil);
end;

procedure GenJsonArray(const name, openMarker, closeMarker : string);
var
  s, prefix, rest, body, suffix : string;
begin
  // the elements of the one big array, comma-joined
  s := ReadSrc(name);
  SplitAt(s, openMarker, prefix, rest);
  prefix := prefix + openMarker;
  rest := Copy(rest, Length(openMarker) + 1, MaxInt);
  SplitAt(rest, closeMarker, body, suffix, true);
  body := body.TrimRight;
  Repeated(name, prefix, SplitJsonElements(body), ',', sLineBreak + suffix.TrimLeft([#13, #10]), nil);
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

function ParseSize(const s : string) : Int64;
var
  t : string;
begin
  t := UpperCase(Trim(s));
  if t = '' then
    exit(100 * 1024 * 1024);
  if t.EndsWith('KB') then
    result := Int64(StrToInt(Copy(t, 1, Length(t) - 2))) * 1024
  else if t.EndsWith('K') then
    result := Int64(StrToInt(Copy(t, 1, Length(t) - 1))) * 1024
  else if t.EndsWith('MB') then
    result := Int64(StrToInt(Copy(t, 1, Length(t) - 2))) * 1024 * 1024
  else
    result := Int64(StrToInt(t)) * 1024 * 1024;
end;

begin
  try
    srcDir := TPath.GetFullPath(TPath.Combine(ExtractFilePath(ParamStr(0)), '..\Tests\TestFiles'));
    outDir := ParamStr(1);
    if outDir = '' then
      outDir := TPath.Combine(ExtractFilePath(ParamStr(0)), 'big');
    target := ParseSize(ParamStr(2));
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

program MemBreak;

// Where a loaded document's memory goes: loads a file and reports the heap the tree
// holds (from the memory manager), node counts, object sizes, and an estimate of the
// bytes in key and value strings, with how many of those strings are duplicates.
//   MemBreak <file>

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.IOUtils,
  System.Generics.Collections,
  VSoft.YAML in '..\Source\VSoft.YAML.pas',
  VSoft.YAML.Classes in '..\Source\VSoft.YAML.Classes.pas';

function HeapBytes : UInt64;
var
  st : TMemoryManagerState;
  sb : TSmallBlockTypeState;
begin
  GetMemoryManagerState(st);
  result := st.TotalAllocatedMediumBlockSize + st.TotalAllocatedLargeBlockSize;
  for sb in st.SmallBlockTypeStates do
    Inc(result, UInt64(sb.UseableBlockSize) * sb.AllocatedBlockCount);
end;

// heap bytes for a string of len chars: StrRec header + chars + null, rounded to 16
function StrBytes(len : integer) : Int64;
begin
  if len = 0 then
    exit(0);
  result := ((SizeOf(Pointer) * 2 + (len + 1) * SizeOf(Char)) + 15) and not 15;
end;

var
  scalars, mappings, sequences, keys : Int64;
  keyBytes, valueBytes : Int64;
  uniqueKeys, uniqueValues : TDictionary<string, integer>;

procedure Walk(const v : IYAMLValue);
var
  i : integer;
  m : IYAMLMapping;
  s : IYAMLSequence;
  k : string;
begin
  if v.IsMapping then
  begin
    Inc(mappings);
    m := v.AsMapping;
    for i := 0 to m.Count - 1 do
    begin
      k := m.Keys[i];
      Inc(keys);
      Inc(keyBytes, StrBytes(Length(k)));
      uniqueKeys.AddOrSetValue(k, 0);
      Walk(m.Items[k]);
    end;
  end
  else if v.IsSequence or v.IsSet then
  begin
    Inc(sequences);
    s := v.AsSequence;
    for i := 0 to s.Count - 1 do
      Walk(s.Items[i]);
  end
  else
  begin
    Inc(scalars);
    Inc(valueBytes, StrBytes(Length(v.RawValue)));
    uniqueValues.AddOrSetValue(v.RawValue, 0);
  end;
end;

function MB(b : Int64) : string;
begin
  result := Format('%8.1f MB', [b / (1024 * 1024)]);
end;

var
  text : string;
  options : IYAMLParserOptions;
  doc : IYAMLDocument;
  before, after : UInt64;
  uk, uv : Int64;
begin
  text := TFile.ReadAllText(ParamStr(1), TEncoding.UTF8);
  options := TYAML.CreateParserOptions;
  options.JSONMode := SameText(ExtractFileExt(ParamStr(1)), '.json');
  before := HeapBytes;
  doc := TYAML.LoadFromString(text, options);
  after := HeapBytes;

  uniqueKeys := TDictionary<string, integer>.Create;
  uniqueValues := TDictionary<string, integer>.Create;
  Walk(doc.Root);
  uk := 0;
  for text in uniqueKeys.Keys do
    Inc(uk, StrBytes(Length(text)));
  uv := 0;
  for text in uniqueValues.Keys do
    Inc(uv, StrBytes(Length(text)));

  WriteLn(ExtractFileName(ParamStr(1)));
  WriteLn('  tree heap          ', MB(after - before), Format('  (%.1fx the file)', [(after - before) / TFile.GetSize(ParamStr(1))]));
  WriteLn(Format('  nodes              %d scalars, %d mappings, %d sequences, %d keys', [scalars, mappings, sequences, keys]));
  WriteLn(Format('  instance sizes     value %d, mapping %d, sequence %d bytes',
    [TYAMLValue.InstanceSize, TYAMLMapping.InstanceSize, TYAMLSequence.InstanceSize]));
  WriteLn('  scalar objects     ', MB(scalars * ((TYAMLValue.InstanceSize + 15) and not 15)));
  WriteLn('  key strings        ', MB(keyBytes), '   distinct only:', MB(uk), Format('  (%d distinct)', [uniqueKeys.Count]));
  WriteLn('  value strings      ', MB(valueBytes), '   distinct only:', MB(uv), Format('  (%d distinct)', [uniqueValues.Count]));
end.

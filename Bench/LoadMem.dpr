program LoadMem;

// Loads one file with TYAML.LoadFromFile and reports the process's peak memory
// (everything the load needed at its high point: input buffers, the tree, the
// allocator's slack) and the heap the loaded tree keeps afterwards. Run once per file
// so each peak is that file's alone.
//   LoadMem <file>

{$APPTYPE CONSOLE}

uses
  Winapi.Windows,
  Winapi.PsAPI,
  System.SysUtils,
  System.IOUtils,
  VSoft.YAML in '..\Source\VSoft.YAML.pas';

function PeakBytes : UInt64;
var
  counters : TProcessMemoryCounters;
begin
  counters.cb := SizeOf(counters);
  GetProcessMemoryInfo(GetCurrentProcess, @counters, SizeOf(counters));
  result := counters.PeakPagefileUsage;
end;

{$WARN SYMBOL_PLATFORM OFF}
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
{$WARN SYMBOL_PLATFORM ON}

const
  MB = 1024 * 1024;

var
  options : IYAMLParserOptions;
  doc : IYAMLDocument;
  heapBefore, heapAfter, peakBefore : UInt64;
begin
  try
    options := TYAML.CreateParserOptions;
    options.JSONMode := SameText(ExtractFileExt(ParamStr(1)), '.json');
    peakBefore := PeakBytes;
    heapBefore := HeapBytes;
    doc := TYAML.LoadFromFile(ParamStr(1), options);
    heapAfter := HeapBytes;
    WriteLn(Format('%-30s %7.1f MB file   peak %8.1f MB   tree %8.1f MB   (%.1f MB peak before loading)',
      [ExtractFileName(ParamStr(1)), TFile.GetSize(ParamStr(1)) / MB, PeakBytes / MB,
       (heapAfter - heapBefore) / MB, peakBefore / MB]));
  except
    on E : Exception do
    begin
      WriteLn('LoadMem ', ParamStr(1), ': ', E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.

# Bench

Benchmark, profiling and verification tools for VSoft.YAML. Build any of them with
`sh build.sh <Program.dpr>` (Delphi 12 Win64, optimised, TD32 symbols embedded).

## Benchmarking

- **ProfBench** `[rounds] [iters] [file|*] [dir]`: for each test file, times parse,
  free, YAML output and JSON output (best of `rounds`), and prints an MD5 of both
  outputs so A/B runs can confirm identical results. It also prints the machine's
  clock and free memory at the start and end. `dir` defaults to `..\Tests\TestFiles`.
- **GenBig** `[outDir] [MB]`: scales the benchmark test files up to about `MB`
  megabytes each, keeping their style. The source files are embedded
  (`GenBigFiles.rc`), so it also runs on a machine without the repository.

For an A/B comparison, build ProfBench a second time against an older `Source/`
(`git archive <commit> Source`), and compare timings and hashes.

## Verification

Each checker builds against the current `Source/`. The differential ones dump their
results to a file: build them a second time against another commit's `Source/` and
the two dumps must be byte-identical.

| Program | Checks |
|---|---|
| WriterFuzz `<out> [docs]` | differential: random documents x every emit option x string/stream output (UTF-8/UTF-16, BOM) |
| StreamOutCheck `<dir>` | differential: hashes stream output of the files in `dir` |
| NumFuzz `<out>` | differential: number-like scalars in YAML block/flow and JSON (types, values, errors) |
| BufferCheck | TYAMLOutputBuffer string and stream (64-char chunks, surrogate pairs) against whole-string encoding |
| FloatCheck | YAMLCanonicalFloatText against FloatToStr(StrToFloat()) on 3M inputs |
| QuoteCheck | NeedsQuoting's first-character pre-check never skips a string the RTL parses as a number |
| StreamCheck | LoadFromFile / LoadFromStream (UTF-8, BOM, UTF-16) match LoadFromString |
| TruncCheck | content after a mis-indented line raises instead of being dropped |

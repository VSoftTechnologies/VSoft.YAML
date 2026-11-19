# YAML parser baseline - 2026-11-19

Recorded before any rework of the YAML lexer/parser, to compare a rewrite against. It was
taken after these changes, so it reflects the code a rewrite would start from:
- JSON moved to its own parser, and the JSON branches were taken out of the YAML lexer and parser;
- the space-separated timestamp fix;
- block scalar line breaks became line feeds;
- tabs became accepted as separation.

## Setup

- **Machine:** TROJAN, Windows 11 Pro (10.0.26300), 64 GB RAM, about 23 GB free during the runs.
- **Compiler:** Delphi 13 (`E:\Emb\Studio\37.0`) `dcc64`, Win64, `-$O+`, no range or overflow checks.
- **Source:** the working tree on top of commit `a5dc66c`, with the JSON5 work and the changes above. **Replace this with the commit hash once that work is committed**, so the baseline can be rebuilt.
- **Test data:**
  - `Tests\TestFiles` (the small files).
  - 20 MB versions made by `Bench\GenBig.dpr` (`GenBig <dir> 20`). Generation is deterministic, so rerunning it gives the same files (the hashes below confirm it).

## How to reproduce

From `Bench\`, building into a scratch folder:

```
dcc64 -B -Q -$O+ -E<out> -NU<out>\dcu -U..\Source -NSSystem;Winapi;System.Win ProfBench.dpr
dcc64 -B -Q -$O+ -E<out> -NU<out>\dcu -U..\Source -NSSystem;Winapi;System.Win LoadMem.dpr
<out>\ProfBench.exe 15 4 * ..\Tests\TestFiles
<out>\ProfBench.exe 5 1 * <dir with the GenBig 20 MB files>
<out>\LoadMem.exe <file>
```

For an A/B comparison, build ProfBench a second time against this baseline's commit (`git archive <commit> Source`) and run both one after the other on the same machine (see `Bench\README.md`). This machine is noisy, so use many rounds, alternate old and new, and repeat any run that looks off. A rewrite should give the same output hashes. Where it doesn't, the difference should be a bug fix that can be accounted for.

## Conformance

The YAML test suite (`Tests\VSoft.YAML.Tests.YAMLSuite.pas`) passes 195 of its 402 cases. The other 207 are listed in `Tests\TestFiles\yaml-test-suite-known-failures.txt`:
- 102 reject valid YAML;
- 47 accept invalid YAML;
- 58 read the wrong data.

A rewrite must not fail a case that passes now. It should remove lines from that list.

## Small files - ProfBench 15 rounds x 4 iterations (best), two runs

| File | Size | Parse ms | MB/s | Free ms | YAML out ms | JSON out ms | Hashes (YAML/JSON out) |
|---|---|---|---|---|---|---|---|
| benchmark_large.yaml | 1398 KB | 36.1 / 36.1 | 37.8 / 37.8 | 4.8 / 4.7 | 6.0 / 6.5 | 4.1 / 4.3 | fc751b98 / 56468ae4 |
| benchmark_block_scalars.yaml | 244 KB | 3.2 / 3.1 | 74.0 / 76.8 | 0.4 / 0.4 | 1.1 / 1.1 | 0.7 / 0.7 | e48f9d99 / 57c839e9 |
| benchmark_quoted_strings.yaml | 341 KB | 4.4 / 4.5 | 76.1 / 74.1 | 0.6 / 0.6 | 1.7 / 1.8 | 1.2 / 1.3 | 816c02a1 / 671cfc64 |
| benchmark_large.json | 2291 KB | 17.7 / 18.2 | 126.3 / 123.3 | 7.7 / 7.9 | 13.3 / 13.6 | 9.2 / 9.6 | 8e7e585b / a416d2a3 |
| load_test.json | 1013 KB | 19.0 / 19.1 | 52.1 / 51.8 | 8.9 / 9.0 | 13.3 / 13.3 | 12.0 / 12.5 | c41e333a / 32e4ffcd |
| test.json | 1150 KB | 14.5 / 14.9 | 77.3 / 75.4 | 6.4 / 6.8 | 6.6 / 6.6 | 4.6 / 4.7 | b91baa73 / c5603629 |

The JSON files are read by the JSON parser. They were read by the YAML parser in JSON mode before, at about twice these parse times, and the output hashes are the same as then.

JSON5 on the same files (run 1):

| File | JSON5 parse | JSON5 text parse | JSON5 out |
|---|---|---|---|
| benchmark_large.json | 17.8 ms | 19.0 ms | 11.0 ms |
| load_test.json | 19.7 ms | 23.8 ms | 14.0 ms |
| test.json | 14.9 ms | 15.3 ms | 5.7 ms |

## 20 MB files (GenBig) - ProfBench 5 rounds x 1 iteration (best)

| File | Parse ms | MB/s | Free ms | YAML out ms | JSON out ms | Hashes |
|---|---|---|---|---|---|---|
| benchmark_large.yaml | 563.5 | 35.5 | 81.2 | 105.2 | 83.4 | 2739660a / 9cc9ee6d |
| benchmark_block_scalars.yaml | 302.7 | 66.1 | 45.4 | 103.5 | 73.3 | ecf85e2a / 800b6ab3 |
| benchmark_quoted_strings.yaml | 297.8 | 67.2 | 44.4 | 110.2 | 84.3 | cfed2b1c / 96d9e5b1 |
| benchmark_large.json | 161.7 | 123.7 | 72.0 | 121.0 | 86.4 | ac95756b / 6b028b50 |
| load_test.json | 391.4 | 51.1 | 182.9 | 269.4 | 245.6 | b3318f50 / 35e09df0 |
| test.json | 447.6 | 44.7 | 158.6 | 121.3 | 90.5 | 91bab6c4 / dd004477 |

## Memory - LoadMem (LoadFromFile, peak process memory and heap kept by the tree)

| File | File size | Peak | Tree |
|---|---|---|---|
| benchmark_large.yaml | 1.4 MB | 9.0 MB | 6.1 MB |
| benchmark_block_scalars.yaml | 0.2 MB | 4.0 MB | 0.8 MB |
| benchmark_quoted_strings.yaml | 0.3 MB | 4.0 MB | 1.0 MB |
| benchmark_large.yaml (20 MB) | 20.0 MB | 98.6 MB | 88.4 MB |
| benchmark_block_scalars.yaml (20 MB) | 20.0 MB | 73.5 MB | 65.6 MB |
| benchmark_quoted_strings.yaml (20 MB) | 20.0 MB | 66.0 MB | 57.5 MB |

The peak before loading was 2.8 MB in each run.

## Where the time goes (informational)

These figures are from earlier the same day, before the JSON branches were removed; the YAML parse times are the same within noise. They come from a scratch harness, not from a tool in the repository. It parsed the same text repeatedly in three ways, and every figure includes freeing the document. The best of 40 is shown.

| Data | YAML parse | Lexer alone | Same tree from JSON (JSON parser) |
|---|---|---|---|
| benchmark_large.yaml, duplicate keys made unique | 38-43 ms | 13.6 ms | 17.3 ms |
| benchmark_block_scalars.yaml | 3.7 ms | 1.95 ms | 1.2 ms |
| benchmark_quoted_strings.yaml | 5.4 ms | 2.8 ms | 2.0 ms |

The last column is the cost of scanning the JSON form and building and freeing the identical tree. It is a floor that no YAML parser using these document classes can go below.

**vsprof**, `--user-code`, benchmark_large.yaml (150 parses), share of CPU by routine self time:
- `ReadToken`: 12.9%. A copy of the peeked token record takes 3.7%.
- `ReadUnquotedString`: 8.0%. That is StringBuilder append and `ToString`.
- `TYAMLStringInterner.Intern`: 7.9%.
- Freeing the tree: about 24%, mostly `TYAMLMapping.Destroy`, `DetachFromParent`, `TYAMLValue.Destroy` and `TDictionary.Clear`.
- Node creation (`NewInstance`, `TYAMLValue.Create`): about 6%.
- `ParseScalar` and `ParseMapping` own code: about 7%.
- `SkipWhitespaceAndCalculateIndent`: 3.6%.
- `ScanPlainScalarRun`: 3.4%.
- `PeekTokenKind`: 4.6%.

The 20 MB quoted-strings file shows the same pattern, with `ReadDoubleQuotedString` (13.7%) and `ReadSingleQuotedString` (7.5%) on top.

## After: the YAML 1.2 parser (same day)

The rewrite (`VSoft.YAML.Scanner` and `VSoft.YAML.Composer`) against the old parser, in one
ProfBench build that switches between them with `YAMLUseNewParser` (a temporary switch,
removed along with the old parser), run alternately on the same machine. Best of 15 rounds x 4 iterations, and of 5 x 1 for the 20 MB files:

| File | Old parse | New parse | Change |
|---|---|---|---|
| benchmark_large.yaml | 35.4 ms | 33.3 ms | 6% faster |
| benchmark_block_scalars.yaml | 3.1 ms | 2.2 ms | 30% faster |
| benchmark_quoted_strings.yaml | 4.4 ms | 3.8 ms | 14% faster |
| benchmark_large.yaml (20 MB) | 562 ms | 500 ms | 11% faster |
| benchmark_block_scalars.yaml (20 MB) | 293 ms | 208 ms | 29% faster |
| benchmark_quoted_strings.yaml (20 MB) | 294 ms | 269 ms | 8% faster |

- **Same data:** the JSON output hashes are the same as the old parser's for every file.
- **Comment placement:** the YAML output hashes of benchmark_large.yaml and benchmark_block_scalars.yaml differ because of a comment on a line of its own after a blank line. The old parser attached it to the scalar before it as a same-line comment; the new one keeps it before what follows, as in the source.
- **Memory (LoadMem):** the same as the old parser for all three 20 MB files, at 98.6, 73.5 and 66.0 MB peak.
- **Conformance:** all 402 cases of the YAML test suite pass, read with `YAML11Compatibility` off, so `yaml-test-suite-known-failures.txt` is empty.

## After: lighter nodes (same day)

Three changes to the value classes, measured against builds of the code just before them,
run alternately (ProfBench, best of 15 x 4; LoadMem on the 20 MB files):
- **Mappings:** a mapping with more than 8 keys finds them through its own small hash table instead of a `TDictionary`.
- **Freeing collections:** freeing a collection no longer detaches each child; only a child that outlives its collection forgets it as its parent.
- **Comments:** they are string arrays rather than string lists.

The output hashes are unchanged. Parse times are the same within noise, except test.json (wide objects), which is 38% faster. Freeing is faster:

| File | Free before | Free after |
|---|---|---|
| benchmark_large.yaml | 5.0 ms | 3.0 ms |
| benchmark_quoted_strings.yaml | 0.6 ms | 0.4 ms |
| benchmark_large.json | 8.0 ms | 6.0 ms |
| load_test.json | 8.9 ms | 6.4 ms |
| test.json | 7.2 ms | 2.9 ms |

| File (20 MB) | Tree before | Tree after |
|---|---|---|
| benchmark_large.yaml | 88.4 MB | 63.6 MB |
| benchmark_block_scalars.yaml | 64.6 MB | 62.1 MB |
| benchmark_quoted_strings.yaml | 57.5 MB | 54.6 MB |
| test.json | 161.7 MB | 133.7 MB |
| benchmark_large.json | 92.3 MB | 90.7 MB |
| load_test.json | 237.9 MB | 236.4 MB |

**Two arrays per mapping were tried and dropped.** Keeping a mapping's keys and values in two arrays, rather than one array of records, made freeing a little faster, but the trees grew by 6-7 MB on the block-scalar and quoted-string files. FastMM rounds two blocks up where it rounded one, and when a small block grows it leaves room for it to grow again. The kept design still uses one array, and the first time a mapping grows (from 4 to 8 entries) its entries move to a new array of exactly that size.

## Caveats

- **Duplicate keys.** benchmark_large.yaml repeats its top-level `data_batch_N` keys three times, and GenBig keeps the repeats. A later copy replaces an earlier one, so its parse time includes building and freeing subtrees that are thrown away. The kept document is about half the size of the text.
- **Earlier hashes.** Two files' hashes differ from those in the first run of this baseline:
  - benchmark_large.yaml: the timestamp `special_values.timestamp_space` used to take in the line break and blank line after it; it is now just its own text.
  - benchmark_block_scalars.yaml: its block scalars hold `\n` line breaks, where they held CRLF.

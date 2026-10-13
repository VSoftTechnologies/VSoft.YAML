#!/bin/sh
# Build a Bench program (default ProfBench) with Delphi 12 Win64: optimised, TD32
# symbols embedded (for DelphiProfiler / MiniDelphiDebugger).   sh build.sh [Prog.dpr]
cd "$(dirname "$0")" || exit 1
BDS="/c/Program Files (x86)/Embarcadero/Studio/23.0/bin"
mkdir -p dcu
prog=${1:-ProfBench.dpr}
# GenBig embeds the original test files
if [ "$prog" = "GenBig.dpr" ]; then
  "$BDS/brcc32.exe" -foGenBigFiles.res GenBigFiles.rc >/dev/null || exit 1
fi
"$BDS/dcc64.exe" -B -Q -V -\$O+ -\$D+ -NUdcu -NSSystem -U../Source -I../Source "$prog" 2>&1 | grep -v "^Embarcadero\|^Copyright\|H2077"

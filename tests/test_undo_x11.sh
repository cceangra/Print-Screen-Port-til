#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
TEMP="$(mktemp -d)";PID=''
trap '[[ -z "$PID" ]] || kill "$PID" 2>/dev/null || true; rm -rf -- "$TEMP"' EXIT
mkdir -p "$TEMP/images"
printf 'save_dir=%s\ncopy_clipboard=0\n' "$TEMP/images" > "$TEMP/options"
export PRINT_RC_CONFIG="$TEMP/options"
g++ -std=c++17 -O2 "$ROOT/tests/performance/x11_driver.cpp" -o "$TEMP/driver" $(pkg-config --cflags --libs x11)
"$TEMP/driver" paint
"$ROOT/bin/print-rc" > "$TEMP/log" 2>&1 & PID=$!
"$TEMP/driver" wait >/dev/null
xdotool mousemove --sync 512 35 click 1
xdotool mousemove --sync 170 180 mousedown 1 mousemove --sync 230 210 mouseup 1
xdotool mousemove --sync 566 35 click 1
xdotool mousemove --sync 404 35 click 1
xdotool mousemove --sync 120 130 mousedown 1 mousemove --sync 370 320 mouseup 1
wait "$PID";PID=''
# libpng's decoded first pixel remains white and no blue pen pixel may survive undo.
python3 - "$TEMP/images" <<'PY'
from pathlib import Path
import struct,sys,zlib
p=list(Path(sys.argv[1]).glob('*.png'));assert len(p)==1
png=p[0].read_bytes();w,h=struct.unpack('>II',png[16:24]);assert (w,h)==(250,190)
pos=8;chunks=[]
while pos<len(png):
 n=int.from_bytes(png[pos:pos+4],'big')
 if png[pos+4:pos+8]==b'IDAT':chunks.append(png[pos+8:pos+8+n])
 pos+=n+12
raw=zlib.decompress(b''.join(chunks));stride=w*4
previous=bytearray(stride)
for y in range(h):
 offset=y*(stride+1);f=raw[offset];row=bytearray(raw[offset+1:offset+1+stride])
 for x in range(stride):
  a=row[x-4] if x>=4 else 0;b=previous[x];c=previous[x-4] if x>=4 else 0
  if f==1:row[x]=(row[x]+a)&255
  elif f==2:row[x]=(row[x]+b)&255
  elif f==3:row[x]=(row[x]+(a+b)//2)&255
  elif f==4:
   p=a+b-c;da,db,dc=abs(p-a),abs(p-b),abs(p-c)
   row[x]=(row[x]+(a if da<=db and da<=dc else b if db<=dc else c))&255
  else:assert f==0
 assert all(x==255 for x in row),'Undo left ink in the saved PNG'
 previous=row
print('PASS: pen stroke undone before area capture')
PY
for action in escape close right; do
    "$ROOT/bin/print-rc" > "$TEMP/log" 2>&1 & PID=$!
    "$TEMP/driver" wait >/dev/null
    case "$action" in escape) xdotool key Escape ;; close) xdotool mousemove --sync 620 35 click 1 ;; right) xdotool click 3 ;; esac
    wait "$PID";PID=''
done
test "$(find "$TEMP/images" -name '*.png' | wc -l)" -eq 1
echo 'PASS: Escape, close and right-click cancel without additional files'

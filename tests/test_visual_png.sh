#!/usr/bin/env bash
# Use an isolated Xvfb. Tests full PNG conversion at this server's actual visual/size.
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
TEMP="$(mktemp -d)"
PID=''
trap '[[ -z "$PID" ]] || kill "$PID" 2>/dev/null || true; rm -rf -- "$TEMP"' EXIT
mkdir -p "$TEMP/images"
printf 'save_dir=%s\ncopy_clipboard=0\n' "$TEMP/images" > "$TEMP/options"
export PRINT_RC_CONFIG="$TEMP/options"
g++ -std=c++17 -O2 "$ROOT/tests/performance/x11_driver.cpp" -o "$TEMP/driver" $(pkg-config --cflags --libs x11)
read -r width height < <("$TEMP/driver" dimensions)
"$TEMP/driver" paint
"$ROOT/bin/print-rc" > "$TEMP/log" 2>&1 & PID=$!
"$TEMP/driver" wait >/dev/null
"$TEMP/driver" full
wait "$PID";PID=''
python3 - "$TEMP/images" "$width" "$height" <<'PY'
from pathlib import Path
import struct,sys,zlib
files=list(Path(sys.argv[1]).glob('*.png'));assert len(files)==1
png=files[0].read_bytes();assert png[:8]==b'\x89PNG\r\n\x1a\n'
w,h=struct.unpack('>II',png[16:24]);assert (w,h)==tuple(map(int,sys.argv[2:]))
assert png[25]==6
pos=8;parts=[]
while pos<len(png):
 n=int.from_bytes(png[pos:pos+4],'big');tag=png[pos+4:pos+8]
 if tag==b'IDAT':parts.append(png[pos+8:pos+8+n])
 pos+=n+12
raw=zlib.decompress(b''.join(parts));stride=w*4
previous=bytearray(stride);offset=0
for y in range(h):
 f=raw[offset];offset+=1;row=bytearray(raw[offset:offset+stride]);offset+=stride
 for x in range(stride):
  a=row[x-4] if x>=4 else 0;b=previous[x];c=previous[x-4] if x>=4 else 0
  if f==1:row[x]=(row[x]+a)&255
  elif f==2:row[x]=(row[x]+b)&255
  elif f==3:row[x]=(row[x]+(a+b)//2)&255
  elif f==4:
   p=a+b-c;da,db,dc=abs(p-a),abs(p-b),abs(p-c)
   row[x]=(row[x]+(a if da<=db and da<=dc else b if db<=dc else c))&255
  else:assert f==0
 assert all(x==255 for x in row),'PNG differs from original white pixels'
 previous=row
print('PASS: valid RGBA PNG, exact original pixels, visual and odd geometry',w,h)
PY

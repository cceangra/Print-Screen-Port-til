#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
TEMP="$(mktemp -d)"
PID=''
cleanup() {
  if [[ -n "$PID" ]]; then kill "$PID" 2>/dev/null || true; fi
  rm -rf -- "$TEMP"
}
trap cleanup EXIT
mkdir -p "$TEMP/images"
printf 'save_dir=%s\ncopy_clipboard=0\n' "$TEMP/images" > "$TEMP/config"
export PRINT_RC_CONFIG="$TEMP/config"
finished() {
  for ((i=0;i<100;i++)); do
    if ! kill -0 "$PID" 2>/dev/null; then
      wait "$PID"
      PID=''
      return 0
    fi
    sleep 0.1
  done
  cat "$TEMP/log" || true
  echo 'ERRO: capturador nao encerrou em 10s'
  return 1
}
echo '[1] Captura de TELA inteira por um clique'
"$ROOT/bin/print-rc" > "$TEMP/log" 2>&1 &
PID=$!
sleep 0.8
echo '[0] Segunda captura simultanea nao deve roubar teclado/mouse'
if "$ROOT/bin/print-rc" > "$TEMP/segunda.log" 2>&1; then
  echo 'ERRO: segunda instancia aceitou captura simultanea.'
  exit 1
else
  status=$?
  test "$status" -eq 7 || { echo "Segundo print retornou codigo inesperado: $status"; exit 1; }
fi
grep -q 'ja existe uma captura em andamento' "$TEMP/segunda.log"
# Em 1024x768: barra 280px centrada em x=372, botao TELA em x=458.
xdotool mousemove --sync 458 35 click 1
finished
python3 - "$TEMP/images" <<'PY'
import glob,struct,sys
files=glob.glob(sys.argv[1]+'/*.png')
assert len(files)==1,files
data=open(files[0],'rb').read(24)
assert data[:8]==b'\x89PNG\r\n\x1a\n'
assert struct.unpack('>II',data[16:24])==(1024,768)
print('OK: PNG tela inteira 1024x768')
PY
echo '[2] LAPIS, mudar para AREA e salvar captura'
"$ROOT/bin/print-rc" > "$TEMP/log" 2>&1 &
PID=$!
sleep 0.8
xdotool mousemove --sync 512 35 click 1
xdotool mousemove --sync 170 180 mousedown 1
xdotool mousemove --sync 210 200
xdotool mousemove --sync 230 210 mouseup 1
xdotool mousemove --sync 404 35 click 1
xdotool mousemove --sync 120 130 mousedown 1
xdotool mousemove --sync 370 320 mouseup 1
finished
python3 - "$TEMP/images" <<'PY'
import glob,struct,sys,zlib
paths=glob.glob(sys.argv[1]+'/*.png')
assert len(paths)==2,paths
png=None
for path in paths:
    data=open(path,'rb').read()
    w,h=struct.unpack('>II',data[16:24])
    if (w,h)==(250,190):png=data
assert png is not None,'captura por area 250x190 ausente'
pos=8;idat=[];color=None
while pos<len(png):
    n=int.from_bytes(png[pos:pos+4],'big')
    tag=png[pos+4:pos+8]
    if tag==b'IHDR':color=png[pos+17]
    if tag==b'IDAT':idat.append(png[pos+8:pos+8+n])
    pos+=n+12
assert color==6,'Esperado PNG RGBA'
raw=zlib.decompress(b''.join(idat))
width=250;height=190;stride=width*4
last=bytearray(stride);offset=0;found=False
for y in range(height):
    filt=raw[offset];offset+=1
    row=bytearray(raw[offset:offset+stride]);offset+=stride
    for x in range(stride):
        a=row[x-4] if x>=4 else 0
        b=last[x];c=last[x-4] if x>=4 else 0
        if filt==1:row[x]=(row[x]+a)&255
        elif filt==2:row[x]=(row[x]+b)&255
        elif filt==3:row[x]=(row[x]+(a+b)//2)&255
        elif filt==4:
            p=a+b-c
            da,db,dc=abs(p-a),abs(p-b),abs(p-c)
            row[x]=(row[x]+(a if da<=db and da<=dc else b if db<=dc else c))&255
        else:assert filt==0, filt
    if 45<=y<=85:
        found=found or any(tuple(row[4*x:4*x+3])==(55,180,255) for x in range(45,115))
    last=row
assert found,'Lapis azul nao aparece no PNG final'
print('OK: area selecionada com desenho azul salvo no PNG')
PY
echo 'OK: interacao real do X11 validada.'

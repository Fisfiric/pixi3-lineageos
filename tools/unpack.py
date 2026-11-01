"""Split MediaTek Android boot images into kernel / ramdisk / cmdline, stripping the 512-byte MediaTek headers.

usage: unpack.py OUTDIR IMAGE [IMAGE ...]

For each IMAGE (boot.img, recovery.img, or the bootimg.bin / recovery.bin slices from backup-small.ps1) it writes
OUTDIR/<image name>/{kernel.bin,ramdisk.bin,cmdline.txt} and prints the header fields (page size, load addresses,
board name). kernel.bin is the plain ARM zImage; ramdisk.bin is a gzip-compressed newc cpio.
"""
import sys, struct, os, gzip, re
def unpack(path, out):
    d=open(path,'rb').read()
    os.makedirs(out,exist_ok=True)
    assert d[:8]==b'ANDROID!', d[:8]
    ks,ka,rs,ra,ss,sa,ta,ps=struct.unpack('<8I',d[8:40])
    name=d[48:64].rstrip(b'\0').decode(); cmd=d[64:576].rstrip(b'\0').decode()
    pg=ps; r=lambda n:(n+pg-1)//pg*pg
    ko=pg; ro=ko+r(ks); so=ro+r(rs)
    parts={'kernel':d[ko:ko+ks],'ramdisk':d[ro:ro+rs],'second':d[so:so+ss]}
    print(os.path.basename(path),f"page={pg} kernel={ks:#x}@{ka:#x} ramdisk={rs:#x}@{ra:#x} second={ss} tags={ta:#x} name={name!r}")
    print(" cmdline:",cmd)
    for k,v in parts.items():
        if not v: continue
        print(f" {k}: head={v[:8].hex()}", "MTK-hdr" if v[:4]==bytes.fromhex('88168858') else "")
        # strip MTK 512-byte header
        if v[:4]==bytes.fromhex('88168858'): print("   mtk name:",v[8:40].rstrip(b'\0')); v=v[512:]
        open(os.path.join(out,k+'.bin'),'wb').write(v)
    open(os.path.join(out,'cmdline.txt'),'w').write(cmd)
if len(sys.argv) < 3:
    sys.exit(__doc__)
for f in sys.argv[2:]: unpack(f, os.path.join(sys.argv[1],os.path.splitext(os.path.basename(f))[0]))

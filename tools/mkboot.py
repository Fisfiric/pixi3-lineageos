"""Replace the kernel inside an existing MediaTek boot image, keeping its ramdisk and header.

usage: mkboot.py SRC_BOOT.img NEW_ZIMAGE OUT.img

Re-wraps NEW_ZIMAGE with the 512-byte MediaTek "KERNEL" header, fixes the kernel size and the header's SHA-1 field,
and page-aligns the result. Use it to try a new kernel with the tablet's own ramdisk (e.g. SRC = backup/small/bootimg.bin).
The bootloader has no `fastboot boot`, so the result has to be flashed to the boot partition.
"""
import sys, struct, hashlib
if len(sys.argv) != 4:
    sys.exit(__doc__)
src, newk, out = sys.argv[1:4]
d = open(src,'rb').read()
ks,ka,rs,ra,ss,sa,ta,ps = struct.unpack('<8I', d[8:40])
r = lambda n: (n+ps-1)//ps*ps
ko = ps; ro = ko + r(ks)
ramdisk = d[ro:ro+rs]                      # stock ramdisk, MTK header included
kern = open(newk,'rb').read()
kern = b'\x88\x16\x88\x58' + struct.pack('<I', len(kern)) + b'KERNEL'.ljust(32,b'\0') + b'\xff'*472 + kern
hdr = bytearray(d[:ps])
hdr[8:12] = struct.pack('<I', len(kern))
sha = hashlib.sha1(kern + struct.pack('<I',len(kern)) + ramdisk + struct.pack('<I',len(ramdisk)) + b'' + struct.pack('<I',0)).digest()
hdr[576:608] = sha.ljust(32,b'\0')
pad = lambda b: b + b'\0'*(r(len(b))-len(b))
open(out,'wb').write(bytes(hdr) + pad(kern) + pad(ramdisk))
print('kernel',len(kern),'ramdisk',len(ramdisk),'total',len(bytes(hdr)+pad(kern)+pad(ramdisk)))

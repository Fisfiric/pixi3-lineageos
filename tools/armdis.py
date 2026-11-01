#!/usr/bin/env python3
"""Disassemble a range of a raw ARM Linux kernel image with symbol and string annotations.

Used to reverse-engineer the panel (LCM) driver from the stock kernel: it resolves
literal-pool loads to kernel symbols and C strings, which is enough to read out DSI
parameters, GPIO sequences and init tables.

usage: armdis.py IMAGE.raw SYMBOLS.nm START END [--base 0xc0008000]

  IMAGE.raw    decompressed kernel (see docs/PORTING-NOTES.md: strip the MTK header, unxz the zImage payload)
  SYMBOLS.nm   `nm` output for the same kernel ("<addr> <type> <name>"); vmlinux-to-elf can
               recover a symbol table from a stripped kernel, then run `arm-linux-gnueabi-nm` on its ELF
  START END    virtual addresses (hex) of the function to dump
  --base       virtual address of the first byte of IMAGE.raw (default: stock MT8127 kernel)

requires: pip install capstone
"""
import argparse
import bisect
import struct

import capstone

ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
ap.add_argument("image")
ap.add_argument("symbols")
ap.add_argument("start", type=lambda s: int(s, 16))
ap.add_argument("end", type=lambda s: int(s, 16))
ap.add_argument("--base", type=lambda s: int(s, 0), default=0xC0008000)
args = ap.parse_args()

base = args.base
img = open(args.image, "rb").read()

syms = []
for line in open(args.symbols):
    p = line.split()
    if len(p) == 3:
        syms.append((int(p[0], 16), p[2]))
syms.sort()
addrs = [a for a, _ in syms]


def sym(a):
    i = bisect.bisect_right(addrs, a) - 1
    if i < 0:
        return ""
    s, n = syms[i]
    return n if a == s else f"{n}+{a - s:#x}"


def word(a):
    return struct.unpack_from("<I", img, a - base)[0]


def cstr(a):
    o = a - base
    if not 0 <= o < len(img):
        return None
    e = img.find(b"\0", o, o + 120)
    s = img[o:e]
    return s.decode() if e > o and all(32 <= c < 127 or c in (9, 10) for c in s) else None


md = capstone.Cs(capstone.CS_ARCH_ARM, capstone.CS_MODE_ARM)
md.detail = True
code = img[args.start - base:args.end - base]
pool = set()
for ins in md.disasm(code, args.start):
    note = ""
    if ins.mnemonic.startswith("ldr") and "[pc" in ins.op_str:
        op = ins.operands[1]
        la = ins.address + 8 + op.mem.disp
        pool.add(la)
        v = word(la)
        s = cstr(v)
        note = f"; ={v:#x} {sym(v) if 0xC0000000 <= v < 0xC1000000 else ''} {repr(s) if s else ''}"
    if ins.mnemonic in ("bl", "b", "blx") or ins.mnemonic.startswith("b") and ins.op_str.startswith("#"):
        try:
            note = f"; {sym(int(ins.op_str.lstrip('#'), 16))}"
        except ValueError:
            pass
    if ins.address in pool:
        w = word(ins.address)
        print(f"{ins.address:08x}:  .word {w:#010x}  {sym(w) if 0xC0000000 <= w < 0xC1000000 else ''}")
        continue
    label = sym(ins.address)
    if "+" not in label:
        print(f"\n<{label}>:")
    print(f"{ins.address:08x}:  {ins.mnemonic:8} {ins.op_str:30} {note}")

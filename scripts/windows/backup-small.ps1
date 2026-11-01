# Phase 3.1: read-only dump of everything BEFORE custpack (first 0x4780000 bytes of the eMMC user area).
# Contains MBR/EBR, pro_info, nvram, protect_f/s, seccfg, lk, boot, recovery, sec_ro, misc, logo.
# ~71 MB, one BROM connection. Writes nothing to the tablet.
# Run:  powershell -ExecutionPolicy Bypass -File .\scripts\windows\backup-small.ps1
# Then: tablet fully OFF, plug in USB when it says "Waiting for device".
# Needs firmware_dl\extracted\preloader_ttab.bin (from the stock firmware zip, see docs/INSTALL.md).
$ErrorActionPreference = "Stop"
$root = (Resolve-Path "$PSScriptRoot\..\..").Path
Set-Location $root

$mtk = "$root\external\mtkclient\mtk.py"
$py  = "$root\.venv\Scripts\python"
$plf = "$root\firmware_dl\extracted\preloader_ttab.bin"
if (-not (Test-Path $plf)) { throw "Missing $plf - extract the stock firmware zip into firmware_dl\extracted\ first." }
$pl  = (Resolve-Path $plf).Path
$out = "backup\small"
New-Item -ItemType Directory -Force $out | Out-Null
$file = "$out\emmc_0x0_0x4780000.bin"

& $py $mtk ro 0x0 0x4780000 $file --preloader $pl --noreconnect

if ((Get-Item $file).Length -ne 0x4780000) { throw "Short read: $((Get-Item $file).Length) bytes" }
$hash = (Get-FileHash $file -Algorithm SHA256).Hash
"$hash  emmc_0x0_0x4780000.bin" | Set-Content "$out\SHA256.txt" -Encoding ascii

# Slice named partitions out of the dump (scatter offsets) for convenience
$parts = [ordered]@{
    pro_info  = @(0x100000, 0x300000)
    nvram     = @(0x400000, 0x500000)
    protect_f = @(0x900000, 0xA00000)
    protect_s = @(0x1300000, 0xA00000)
    seccfg    = @(0x1D00000, 0x20000)
    uboot     = @(0x1D20000, 0x60000)
    bootimg   = @(0x1D80000, 0x1000000)
    recovery  = @(0x2D80000, 0x1000000)
    sec_ro    = @(0x3D80000, 0x600000)
    misc      = @(0x4380000, 0x80000)
    logo      = @(0x4400000, 0x300000)
}
$all = [IO.File]::ReadAllBytes((Resolve-Path $file))
foreach ($k in $parts.Keys) {
    $o, $l = $parts[$k]
    $b = New-Object byte[] $l
    [Array]::Copy($all, $o, $b, 0, $l)
    [IO.File]::WriteAllBytes((Join-Path (Resolve-Path $out) "$k.bin"), $b)
}
Write-Host ""
Write-Host "Done. SHA256 $hash"
Write-Host "Copy the whole backup\small folder somewhere safe (it holds this tablet's nvram)."

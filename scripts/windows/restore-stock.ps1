# Restore stock partitions over BROM. DRY RUN by default: prints what would be written.
#   .\scripts\windows\restore-stock.ps1 -What boot,recovery            (dry run)
#   .\scripts\windows\restore-stock.ps1 -What boot,recovery -Go        (actually writes)
# -What: boot, recovery, uboot, logo, nvram, protect_f, protect_s, pro_info, sec_ro
# Every item is restored from backup\small\ (this tablet's own data, made by backup-small.ps1).
# Each item is one BROM session: the script pauses so you can power off and replug between items.
param(
    [Parameter(Mandatory = $true)][string[]]$What,
    [switch]$Go
)
$ErrorActionPreference = "Stop"
$root = (Resolve-Path "$PSScriptRoot\..\..").Path
Set-Location $root
$What = @($What | ForEach-Object { $_ -split ',' } | Where-Object { $_ })

$mtk = "$root\external\mtkclient\mtk.py"
$py  = "$root\.venv\Scripts\python"
$pl  = (Resolve-Path "$root\firmware_dl\extracted\preloader_ttab.bin").Path
$bk  = "$root\backup\small"

# name = offset, partition size, source file
$map = @{
    boot      = @(0x1D80000, 0x1000000, "$bk\bootimg.bin")
    recovery  = @(0x2D80000, 0x1000000, "$bk\recovery.bin")
    uboot     = @(0x1D20000, 0x60000,   "$bk\uboot.bin")
    logo      = @(0x4400000, 0x300000,  "$bk\logo.bin")
    nvram     = @(0x400000,  0x500000,  "$bk\nvram.bin")
    protect_f = @(0x900000,  0xA00000,  "$bk\protect_f.bin")
    protect_s = @(0x1300000, 0xA00000,  "$bk\protect_s.bin")
    pro_info  = @(0x100000,  0x300000,  "$bk\pro_info.bin")
    sec_ro    = @(0x3D80000, 0x600000,  "$bk\sec_ro.bin")
}

foreach ($w in $What) {
    if (-not $map.ContainsKey($w)) { throw "Unknown item '$w'. Valid: $($map.Keys -join ', ')" }
    $off, $max, $src = $map[$w]
    if (-not (Test-Path $src)) { throw "Missing source file $src" }
    $len = (Get-Item $src).Length
    if ($len -gt $max) { throw "$w source is $len bytes, partition holds only $max" }
    $hex = '0x{0:X}' -f $off
    Write-Host ("{0,-10} offset {1,-10} {2,9} bytes  <- {3}" -f $w, $hex, $len, $src)
}
if (-not $Go) { Write-Host "`nDry run only. Re-run with -Go to write."; return }

foreach ($w in $What) {
    $off, $max, $src = $map[$w]
    $len = (Get-Item $src).Length
    Read-Host "`nPower the tablet OFF, then press Enter and plug it into BROM for '$w'"
    & $py $mtk wo ('0x{0:X}' -f $off) ('0x{0:X}' -f $len) $src --preloader $pl --noreconnect
}
Write-Host "`nDone."

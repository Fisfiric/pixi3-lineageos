# Step 0: install mtkclient (pinned revision + UsbDk patch) into a local virtual environment.
# Run from anywhere:  powershell -ExecutionPolicy Bypass -File .\scripts\windows\setup.ps1
# Needs: git, Python 3.9+ on PATH. Creates .venv\ and external\mtkclient\ in the repo root (both git-ignored).
$ErrorActionPreference = "Stop"
$root = (Resolve-Path "$PSScriptRoot\..\..").Path
Set-Location $root

# The revision the port was developed and tested with.
$rev = "118a000a83ea31c4f427fe5225abfe964546e05e"

if (-not (Test-Path external\mtkclient)) {
    New-Item -ItemType Directory -Force external\mtkclient | Out-Null
    git -C external\mtkclient init
    git -C external\mtkclient remote add origin https://github.com/bkerler/mtkclient.git
    git -C external\mtkclient fetch --depth 1 origin $rev
    git -C external\mtkclient checkout FETCH_HEAD
    # Windows binds the BROM port to the usbser driver; libusb can only open it through UsbDk.
    git -C external\mtkclient apply "$PSScriptRoot\mtkclient-usbdk.patch"
}

if (-not (Test-Path .venv)) { python -m venv .venv }
.\.venv\Scripts\python -m pip install --upgrade pip
.\.venv\Scripts\python -m pip install -r external\mtkclient\requirements.txt

Write-Host ""
Write-Host "mtkclient installed. Next: install the UsbDk driver (see docs/INSTALL.md), then run backup-small.ps1"

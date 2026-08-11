# Thin forwarder to tools/godot.sh, for people whose terminal is PowerShell.
#
# All logic lives in tools/godot.sh (single source of truth). Godot's headless output
# cannot be captured by PowerShell directly - the GUI build writes to the attached
# console - so everything runs through Git Bash.
#
# NOTE: keep this file ASCII-only. Windows PowerShell 5.1 reads BOM-less UTF-8 scripts
# as ANSI, and non-ASCII characters (e.g. Japanese) break parsing.
# Japanese documentation lives in docs/. See docs/setup.md.
#
# Usage:  .\tools\godot.ps1 <path|version|import|check|verify|run|editor> [args...]

if (-not (Get-Command bash -ErrorAction SilentlyContinue)) {
	Write-Host "bash not found. Install Git for Windows (Git Bash). See docs/setup.md." -ForegroundColor Red
	exit 127
}

$root = Split-Path -Parent $PSScriptRoot
Push-Location $root
try {
	bash tools/godot.sh @args
} finally {
	Pop-Location
}
exit $LASTEXITCODE

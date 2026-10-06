param([string]$GameRoot = (Split-Path -Parent $PSScriptRoot), [switch]$BuildOnly)
$ErrorActionPreference = 'Stop'
$backup = $null
$committed = $false
try {
 $GameRoot = [IO.Path]::GetFullPath($GameRoot)
 if (!(Test-Path -LiteralPath (Join-Path $GameRoot 'bin\Divinity2.exe'))) { throw 'Oyun klasoru bulunamadi. Paketi divinity2_dev_cut klasorune cikarin.' }
 if (!$BuildOnly -and (Get-Process -Name Divinity2,Divinity2-debug -ErrorAction SilentlyContinue)) { throw 'Once oyunu kapatin.' }
 $groups = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
 Add-Type -Path (Join-Path $PSScriptRoot 'Archive.cs')
 foreach ($group in $groups) {
  $original = Join-Path $GameRoot $group.archive
  if (!(Test-Path -LiteralPath $original)) { throw "Eksik oyun arsivi: $original" }
  foreach ($entry in $group.entries) {
   $payload = Join-Path $PSScriptRoot $entry.file
   if ((Get-FileHash -LiteralPath $payload -Algorithm SHA256).Hash -ne $entry.sha256) { throw "Bozuk yama dosyasi: $($entry.file)" }
  }
 }
 $backup = Join-Path $GameRoot ('TurkceYama_Yedek_' + (Get-Date -Format 'yyyyMMdd_HHmmss_fff'))
 New-Item -ItemType Directory -Path $backup | Out-Null
 foreach ($group in $groups) {
  $original = Join-Path $GameRoot $group.archive
  $saved = Join-Path $backup $group.archive
  New-Item -ItemType Directory -Path (Split-Path -Parent $saved) -Force | Out-Null
  Copy-Item -LiteralPath $original -Destination $saved
  $built = $saved + '.turkce'
  Write-Host "Ceviri ekleniyor: $($group.archive)"
  [string[]]$names = @($group.entries | ForEach-Object { $_.name })
  [string[]]$files = @($group.entries | ForEach-Object { Join-Path $PSScriptRoot $_.file })
  [TranslationArchive]::Build($saved, $built, $names, $files)
 }
 if ($BuildOnly) { Write-Host "TEST_OUTPUT=$backup"; exit 0 }
 $committed = $true
 foreach ($group in $groups) {
  Copy-Item -LiteralPath ((Join-Path $backup $group.archive) + '.turkce') -Destination (Join-Path $GameRoot $group.archive)
 }
 $restore = @'
$ErrorActionPreference = 'Stop'
if (Get-Process -Name Divinity2,Divinity2-debug -ErrorAction SilentlyContinue) { throw 'Once oyunu kapatin.' }
$game = Split-Path -Parent $PSScriptRoot
$items = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'arsivler.json') -Raw | ConvertFrom-Json
foreach ($item in $items) { Copy-Item -LiteralPath (Join-Path $PSScriptRoot $item) -Destination (Join-Path $game $item) }
Write-Host 'Yama oncesindeki arsivler geri yuklendi.'
'@
 @($groups | ForEach-Object { $_.archive }) | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $backup 'arsivler.json') -Encoding UTF8
 $restore | Set-Content -LiteralPath (Join-Path $backup 'Geri_Yukle.ps1') -Encoding UTF8
 '@echo off', 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Geri_Yukle.ps1"', 'pause' | Set-Content -LiteralPath (Join-Path $backup 'GERI_YUKLE.cmd') -Encoding ASCII
 foreach ($group in $groups) { Remove-Item -LiteralPath ((Join-Path $backup $group.archive) + '.turkce') }
 Write-Host 'TURKCE YAMA KURULDU.' -ForegroundColor Green
 Write-Host 'Steam oyun dilini English secin. Oyunu normal Steam kisayolundan acin.'
 Write-Host "Yedek ve geri yukleme dosyasi: $backup"
 exit 0
} catch {
 if ($committed) {
  foreach ($group in $groups) { Copy-Item -LiteralPath (Join-Path $backup $group.archive) -Destination (Join-Path $GameRoot $group.archive) }
 }
 Write-Host "KURULAMADI: $($_.Exception.Message)" -ForegroundColor Red
 exit 1
}

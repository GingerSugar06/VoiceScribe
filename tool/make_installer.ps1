# VoiceScribe kurulum sihirbazını (Setup.exe) üretir.
#   powershell -ExecutionPolicy Bypass -File tool\make_installer.ps1
# Gerekenler: Flutter, Inno Setup 6 (winget install JRSoftware.InnoSetup)
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)

# 1) Uygulamayı derle
Write-Host '== 1/4 uygulama derleniyor ==' -ForegroundColor Cyan
flutter build windows --release

# 2) Visual C++ çalışma zamanı DLL'lerini topla (uygulama-yerel dağıtım)
Write-Host '== 2/4 çalışma zamanı DLL''leri ==' -ForegroundColor Cyan
$crt = Get-ChildItem 'C:\Program Files\Microsoft Visual Studio','C:\Program Files (x86)\Microsoft Visual Studio' -Recurse -Directory -Filter 'Microsoft.VC*.CRT' -ErrorAction SilentlyContinue |
  Where-Object { $_.FullName -match '\\x64\\' -and $_.FullName -notmatch 'onecore|debug' } | Sort-Object FullName -Descending | Select-Object -First 1
if (-not $crt) { throw 'Visual C++ CRT klasörü bulunamadı (Visual Studio C++ iş yükü kurulu mu?)' }
New-Item -ItemType Directory -Force installer\redist\crt | Out-Null
Copy-Item "$($crt.FullName)\*.dll" installer\redist\crt -Force
Write-Host "  kaynak: $($crt.FullName)"


# 3) Sihirbazı derle
Write-Host '== 4/4 sihirbaz derleniyor ==' -ForegroundColor Cyan
$iscc = @("$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe", 'C:\Program Files (x86)\Inno Setup 6\ISCC.exe', 'C:\Program Files\Inno Setup 6\ISCC.exe') | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $iscc) { throw 'Inno Setup 6 bulunamadı: winget install JRSoftware.InnoSetup' }
& $iscc installer\VoiceScribe.iss
if ($LASTEXITCODE -ne 0) { throw 'ISCC başarısız' }
Write-Host ''
Write-Host (Get-ChildItem installer\Output\*.exe | Select-Object -First 1).FullName -ForegroundColor Green

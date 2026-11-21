# ============================================================
#  WDS Deployment Kit - WinPE Deploy skripti (Deploy.ps1)
#  Yer: WDS serverde E:\Deploy\Scripts\Deploy.ps1
#  Ne vaxt isleyir: PXE ile WinPE acilanda, startnet.cmd onu AVTOMATIK isledir
#  Etdiyi: disk secimi + tesdiq -> diskpart -> dism /Apply -> unattend + FirstLogon kopyala -> bcdboot -> reboot
# ============================================================

$Company   = 'YOUR COMPANY'                 # ekranda gorunen ad
$Image     = 'Z:\Images\Win11-Base.wim'      # deploy olunan image
$Unattend  = 'Z:\Scripts\unattend.xml'
$FirstLogon= 'Z:\Scripts\FirstLogon.ps1'
$Log       = 'X:\deploy.log'

Start-Transcript -Path $Log | Out-Null

function Stop-Deploy([string]$msg) {
    Write-Host ''
    Write-Host "XETA: $msg" -ForegroundColor Red
    Write-Host 'Proses dayandirildi. Komanda pencereine qayitmaq ucun ENTER basin.' -ForegroundColor Red
    Stop-Transcript | Out-Null
    Read-Host | Out-Null
    exit 1
}

Clear-Host
Write-Host '=================================================' -ForegroundColor Cyan
Write-Host "     $Company - Windows 11 avtomatik qurulum" -ForegroundColor Cyan
Write-Host '=================================================' -ForegroundColor Cyan
Write-Host ''

# ---------- 0. Fayllar yerindedir? ----------
foreach ($f in @($Image, $Unattend, $FirstLogon)) {
    if (-not (Test-Path $f)) { Stop-Deploy "Fayl tapilmadi: $f" }
}

# ---------- 1. Komputer haqqinda ----------
$cs = Get-CimInstance Win32_ComputerSystem
Write-Host "Komputer: $($cs.Manufacturer) $($cs.Model)"
Write-Host ''

# ---------- 2. Daxili diski tap (USB/SD kartlari CIXARILIR) ----------
$disks = @(Get-Disk | Where-Object {
    $_.BusType -notin @('USB','SD','MMC','File Backed Virtual') -and $_.Size -ge 30GB
} | Sort-Object Number)

if ($disks.Count -eq 0) {
    Stop-Deploy 'Daxili disk tapilmadi. Noutbukda Intel VMD/RST aktivdirse, WinPE-ye VMD driver-i lazimdir (ve ya BIOS-da VMD-ni sondurun).'
}

function Show-Disk($d) {
    $gb = [math]::Round($d.Size / 1GB)
    Write-Host ("  Disk {0}: {1}  |  {2} GB  |  {3}" -f $d.Number, $d.FriendlyName, $gb, $d.BusType)
}

if ($disks.Count -eq 1) {
    $target = $disks[0]
} else {
    Write-Host 'Bir nece daxili disk tapildi:' -ForegroundColor Yellow
    $disks | ForEach-Object { Show-Disk $_ }
    $num = Read-Host 'Windows hansi diske yazilsin? (Disk nomresini yazin)'
    $target = $disks | Where-Object { "$($_.Number)" -eq $num.Trim() }
    if (-not $target) { Stop-Deploy 'Yanlis disk nomresi. Hec ne deyisdirilmedi.' }
}

Write-Host 'Secilen disk:' -ForegroundColor Yellow
Show-Disk $target

# ---------- 3. Diskde Windows / melumat var? ----------
$hasWindows = $false
$parts = @(Get-Partition -DiskNumber $target.Number -ErrorAction SilentlyContinue)
foreach ($p in $parts) {
    if ($p.DriveLetter -and (Test-Path "$($p.DriveLetter):\Windows\System32")) { $hasWindows = $true }
}
Write-Host ''
if ($hasWindows) {
    Write-Host '  !!! DIQQET: Bu diskde Windows VAR. Butun fayllar SILINECEK !!!' -ForegroundColor White -BackgroundColor Red
} elseif ($parts.Count -gt 0) {
    Write-Host '  DIQQET: Diskde bolmeler (melumat) var. Hamisi SILINECEK.' -ForegroundColor Red
} else {
    Write-Host '  Disk bosdur.' -ForegroundColor Green
}

# ---------- 4. Tesdiq: Y yox, "SIL" sozu ----------
Write-Host ''
$answer = Read-Host 'Davam etmek ucun boyuk herflerle SIL yazin (imtina ucun sadece ENTER)'
if ($answer -cne 'SIL') {
    Write-Host 'Imtina edildi. Diske TOXUNULMADI.' -ForegroundColor Green
    Stop-Transcript | Out-Null
    exit 0
}

# ---------- 5. Diskpart ----------
Write-Host ''
Write-Host '[1/4] Disk hazirlanir...' -ForegroundColor Yellow
$dp = @"
select disk $($target.Number)
clean
convert gpt
create partition efi size=260
format quick fs=fat32 label="System"
assign letter=S
create partition msr size=16
create partition primary
format quick fs=ntfs label="Windows"
assign letter=W
exit
"@
$dp | Out-File -FilePath 'X:\dp.txt' -Encoding ascii
diskpart /s X:\dp.txt
if ($LASTEXITCODE -ne 0 -or -not (Test-Path 'W:\') -or -not (Test-Path 'S:\')) { Stop-Deploy 'Diskpart ugursuz oldu.' }

# ---------- 6. Image-i yaz ----------
Write-Host ''
Write-Host '[2/4] Windows diske yazilir (10-15 deq)... PENCEREYE KLIK ETMEYIN' -ForegroundColor Yellow
dism /Apply-Image /ImageFile:$Image /Index:1 /ApplyDir:W:\
if ($LASTEXITCODE -ne 0) { Stop-Deploy "DISM ugursuz oldu (kod $LASTEXITCODE)." }

# ---------- 7. En son unattend.xml ve FirstLogon.ps1 ----------
# Serverdeki versiyalar her defe image-dekinin USTUNE yazilir.
# Yeni: unattend/skripti deyismek ucun image-e toxunmaq LAZIM DEYIL, sadece E:\Deploy\Scripts-deki fayli deyis.
Write-Host ''
Write-Host '[3/4] Ayarlar kopyalanir...' -ForegroundColor Yellow
New-Item -Path 'W:\Windows\Panther' -ItemType Directory -Force | Out-Null
Copy-Item $Unattend 'W:\Windows\Panther\unattend.xml' -Force
New-Item -Path 'W:\Deploy' -ItemType Directory -Force | Out-Null
Copy-Item $FirstLogon 'W:\Deploy\FirstLogon.ps1' -Force

# ---------- 8. Acilis fayllari ----------
Write-Host ''
Write-Host '[4/4] Acilis fayllari yazilir...' -ForegroundColor Yellow
bcdboot W:\Windows /s S: /f UEFI
if ($LASTEXITCODE -ne 0) { Stop-Deploy 'BCDBoot ugursuz oldu.' }

# ---------- Son ----------
Write-Host ''
Write-Host 'HAZIRDIR! 15 saniyeye restart. Restartda "network boot" cixsa ENTER BASMAYIN.' -ForegroundColor Green
Stop-Transcript | Out-Null
Copy-Item $Log 'W:\Deploy\deploy.log' -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 15
wpeutil reboot

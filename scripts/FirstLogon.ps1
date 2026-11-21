# ============================================================
#  WDS Deployment Kit - Post-deploy skripti (FirstLogon.ps1)  v2
#  Yer: WDS serverde E:\Deploy\Scripts\FirstLogon.ps1
#       (Deploy.ps1 onu her defe yeni PC-nin C:\Deploy\ qovluguna kopyalayir)
#  Ne vaxt isleyir: yeni PC-de admin hesabi ilk defe daxil olanda, AVTOMATIK
#  Ne edir: sifre qaliqlari -> System Restore -> dil siyahisi -> ikonlar -> PC adi -> istifadeci -> restart
# ============================================================

# ---------- AYARLAR (basqa sirkete kecende yalniz bunlari deyis) ----------
$Company        = 'YOUR COMPANY'
$Languages      = @('en-US', 'az-Latn-AZ', 'ru-RU')   # ilki = Windows interfeys dili
$Culture        = 'az-Latn-AZ'                         # tarix/saat/valyuta formati
$CreateLocalUser = $true                               # AD olan yerde $false et
# --------------------------------------------------------------------------

$ErrorActionPreference = 'Continue'
New-Item -Path 'C:\Deploy' -ItemType Directory -Force | Out-Null
Start-Transcript -Path 'C:\Deploy\FirstLogon.log' -Append | Out-Null

Write-Host ''
Write-Host '=============================================' -ForegroundColor Cyan
Write-Host "   $Company - Komputerin son hazirligi" -ForegroundColor Cyan
Write-Host '=============================================' -ForegroundColor Cyan
Write-Host ''

# ---------- 1. Tehlukesizlik: sifre qaliqlarini sil ----------
# AutoLogon admin sifresini registry-de aciq saxlayir, unattend.xml-de de sifre var.
Write-Host '[1/5] Sifre qaliqlari silinir...' -ForegroundColor Yellow
$wl = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
Set-ItemProperty -Path $wl -Name 'AutoAdminLogon' -Value '0'
Remove-ItemProperty -Path $wl -Name 'DefaultPassword' -ErrorAction SilentlyContinue
Remove-ItemProperty -Path $wl -Name 'AutoLogonCount' -ErrorAction SilentlyContinue
Remove-Item -Path 'C:\Windows\Panther\unattend.xml',
                  'C:\Windows\Panther\Unattend\unattend.xml',
                  'C:\Windows\System32\Sysprep\unattend.xml' -Force -ErrorAction SilentlyContinue

# ---------- 2. System Protection (Restore) ----------
Write-Host '[2/5] System Protection yandirilir...' -ForegroundColor Yellow
Enable-ComputerRestore -Drive 'C:\'
vssadmin resize shadowstorage /for=C: /on=C: /maxsize=5% | Out-Null
Checkpoint-Computer -Description 'Ilk qurulum' -RestorePointType 'MODIFY_SETTINGS' -ErrorAction SilentlyContinue

# ---------- 3. Dil siyahisi: YALNIZ $Languages ----------
# Windows ozu elave diller/klaviaturalar elave edir. Burada siyahini tam yeniden yaziriq
# ve onu Welcome ekranina + bundan sonra yaradilan HER yeni istifadeciye kopyalayiriq.
Write-Host '[3/5] Dil ve klaviaturalar ayarlanir...' -ForegroundColor Yellow
try {
    $list = New-WinUserLanguageList $Languages[0]
    foreach ($l in ($Languages | Select-Object -Skip 1)) { $list.Add($l) }
    Set-WinUserLanguageList -LanguageList $list -Force
    Set-Culture -CultureInfo $Culture
    Copy-UserInternationalSettingsToSystem -WelcomeScreen $true -NewUser $true
} catch {
    Write-Host "  Dil ayari xetasi: $($_.Exception.Message)" -ForegroundColor Red
}

# ---------- 4. Yeni istifadecilerin masaustunde "This PC" ve "Control Panel" ----------
# Default profil sablonuna yazilir: bundan sonra yaradilan HER istifadecide gorunur.
reg load 'HKU\DefUser' 'C:\Users\Default\NTUSER.DAT' | Out-Null
$k = 'HKU\DefUser\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel'
reg add $k /v '{20D04FE0-3AEA-1069-A2D8-08002B30309D}' /t REG_DWORD /d 0 /f | Out-Null  # This PC
reg add $k /v '{5399E694-6CE5-4D6C-8FCE-1D8870FDCBA0}' /t REG_DWORD /d 0 /f | Out-Null  # Control Panel
[gc]::Collect(); Start-Sleep -Seconds 1
reg unload 'HKU\DefUser' | Out-Null

# ---------- 5. PC adi ----------
Write-Host ''
Write-Host '[4/5] Komputerin adi' -ForegroundColor Yellow
do {
    $pc = (Read-Host 'Yeni PC adi (mes. MUH-AYTAN, max 15 simvol, bosluqsuz)').Trim()
    $ok = ($pc -match '^[A-Za-z0-9-]{1,15}$')
    if (-not $ok) { Write-Host '  Yanlis ad! Yalniz herf, reqem ve "-", max 15 simvol.' -ForegroundColor Red }
} until ($ok)

# ---------- 6. Istifadeci (STANDARD user, admin DEYIL) ----------
$user = '-'
if ($CreateLocalUser) {
    Write-Host ''
    Write-Host '[5/5] Istifadecinin hesabi (standard user)' -ForegroundColor Yellow
    do {
        $user = (Read-Host 'Istifadeci adi (mes. aytan.m)').Trim()
        $ok = ($user -match '^[A-Za-z0-9._-]{1,20}$') -and -not (Get-LocalUser -Name $user -ErrorAction SilentlyContinue)
        if (-not $ok) { Write-Host '  Yanlis ad ve ya bu adda istifadeci artiq var.' -ForegroundColor Red }
    } until ($ok)

    $pw = Read-Host "$user ucun muveqqeti sifre (sifresiz ucun sadece ENTER)" -AsSecureString
    if ($pw.Length -eq 0) {
        New-LocalUser -Name $user -FullName $user -NoPassword | Out-Null
        Write-Host '  Sifresiz hesab yaradildi.' -ForegroundColor DarkYellow
    } else {
        New-LocalUser -Name $user -FullName $user -Password $pw | Out-Null
        # Ilk girisde istifadeci oz sifresini deyissin
        net user $user /logonpasswordchg:yes | Out-Null
    }
    Add-LocalGroupMember -Group 'Users' -Member $user
} else {
    Write-Host '[5/5] Lokal istifadeci yaradilmir (AD rejimi).' -ForegroundColor DarkYellow
}

# ---------- Son ----------
Write-Host ''
Write-Host "Hazirdir: PC = $pc | Istifadeci = $user" -ForegroundColor Green
Stop-Transcript | Out-Null

Rename-Computer -NewName $pc -Force -ErrorAction SilentlyContinue
Write-Host '15 saniyeye restart olunur...' -ForegroundColor Green
Start-Sleep -Seconds 15
Restart-Computer -Force

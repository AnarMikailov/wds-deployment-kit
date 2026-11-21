# 04 — Troubleshooting və FAQ

Problemin harada olduğunu tapmaq üçün əvvəl **hansı mərhələdə dayandığına** bax:
PXE → TFTP → WinPE/startnet → Deploy.ps1 → ilk açılış (unattend) → FirstLogon.ps1.
Təxmin etmə — log-a bax.

## 1. Simptom → səbəb → həll

### Şəbəkə və PXE

| Simptom | Səbəb | Həll |
| --- | --- | --- |
| "Checking media presence" ilişir | Kabeldə fiziki link yoxdur | Portların işığı; hipervizorda DEPLOY NIC-inin link statusu; başqa kabel; işləyən laptopla eyni kabeli yoxla |
| PC əvvəl IPv6 PXE-ni 3 dəfə yoxlayır | IPv6 PXE yoxdur | Boot menyusunda birbaşa IPv4; BIOS-da IPv6 PXE → Disable |
| Boot menyusunda şəbəkə seçimi yoxdur | BIOS-da Network Stack / PXE off | BIOS → Onboard LAN, LAN Boot ROM / PXE OpROM, Network Stack → Enable |
| PC IP almır | Kabel DEPLOY-da deyil; DHCP dayanıb | Kabeli yoxla; firewall-da DHCP servisi və log |
| IP alır, WDS cavab vermir | WDS servisi dayanıb; DHCP-də option 66/67 yazılıb | WDS → All Tasks → Start; option 66/67-ni sil |
| "Loading files" çox uzun | TFTP yavaşdır (VMware EFI PXE xüsusilə) | WDS → TFTP: block 8192 + Variable Window; real PC-də vaxtı ölç |
| Gateway-ə ping və DNS işləmir, internet işləyir | Firewall alias-ında DEPLOY subnet-i istehsalat alias-ına düşüb | Live View → hansı qayda tutur; alias-ı düzəlt |

### WinPE və Deploy.ps1

| Simptom | Səbəb | Həll |
| --- | --- | --- |
| "Servere qosulmaq olmadi" | WDS sönülü, svc_imaging şifrəsi səhv, SMB bloklanıb | Ping WDS; startnet.cmd-dəki şifrə; WDS-də `Enable-NetFirewallRule -DisplayGroup "File and Printer Sharing"` |
| `System error 86` (net use) | Şifrə səhv yazılıb | Yenidən yaz |
| `System error 53` | Server tapılmır / SMB bloklanıb | IP; WDS firewall |
| "Daxili disk tapilmadi" | Intel VMD/RST: WinPE diski görmür | BIOS-da VMD → off (AHCI) və ya VMD driver-ini `Drivers\WinPE`-yə + boot.wim yenilə |
| WinPE-də şəbəkə yoxdur (VM) | VM-in NIC-i VMXNET3 | WinPE ilə açılan VM-lərdə E1000E |
| WinPE-də şəbəkə yoxdur (yeni noutbuk) | NIC driver-i WinPE-də yoxdur | NIC driver-ini `Drivers\WinPE`-yə + boot.wim yenilə |
| DISM faizi saatlarla dəyişmir, CPU 0 | CMD pəncərəsinə klik → "Select" (QuickEdit) prosesi dondurur | **Esc**. Həqiqi ilişmə yoxlaması: WIM faylının ölçüsü böyüyür? CPU? |
| `format ... The file system is incompatible` | `fs=nfts` hərf səhvi | `fs=ntfs` |
| Windows yazılır, amma açılmır | PC Legacy BIOS rejimində açılıb (skript UEFI/GPT yazır) | BIOS → UEFI şəbəkə açılışı (Boot Override → "UEFI: IP4 ...") |
| Secure Boot xətası (signature verification) | PC yalnız Windows UEFI CA 2023-ə etibar edir | Ən son ADK + 2023-imzalı boot faylları ilə WinPE-ni yenidən qur |

### Sysprep və capture

| Simptom | Səbəb | Həll |
| --- | --- | --- |
| "Sysprep was not able to validate your Windows installation" | Store tətbiqi və ya dil paketi yalnız bir istifadəçi üçün | `Select-String -Path C:\Windows\System32\Sysprep\Panther\setupact.log -Pattern "Error" \| Select -Last 10` → paket adı → `Get-AppxPackage *ad* \| Remove-AppxPackage`. Dil paketi: əvvəl Settings-də Windows dilini English et, Azərbaycan/rus dillərini **Remove** et, sonra paketi sil |
| Sysprep-dən sonra Windows səhvən açıldı | Boot Manager-də Virtual disk seçilib | VM-i söndür → "after sysprep" snapshot-una qayıt |
| Snapshot "Restore" düyməsi bozdur | Snapshot seçilməyib | Əvvəl snapshot sətrinə klik et |
| VM diskini böyütmək olmur (insufficient disk space / boz) | Datastore-da yer yoxdur və ya VM-in snapshot-u var | Datastore-u təmizlə; snapshot-ları sil, sonra böyüt |
| Windows-da C:-ni genişləndirmək olmur (Extend boz) | Recovery bölməsi C: ilə boş yerin arasındadır | Aşağıdakı prosedur |
| Capture `Access denied` | svc_imaging yalnız oxuya bilir | `net use` → `WDS\Administrator` |

**Recovery bölməsini çıxarıb C:-ni genişləndirmək** (CMD admin):
```cmd
reagentc /disable
diskpart
select disk 0
list partition
```
⚠️ **Yalnız** ölçüsü ~600–700 MB, tipi Recovery olan bölməni seç. Nömrədən əmin deyilsənsə — dayan.
```cmd
select partition <N>
delete partition override
exit
```
Disk Management → C: → Extend Volume → `reagentc /enable` → `reagentc /info` → "Enabled".

### İlk açılış və FirstLogon

| Simptom | Səbəb | Həll |
| --- | --- | --- |
| İlk girişdə "password incorrect" | unattend.xml-də `LocalAccount` və `AutoLogon`-da **ad və ya şifrə fərqlidir** (məs. `ladmin` vs `itadmin`, ya da `BURAYA_SIFRE` qalıb) | 2 yerdə eyni ad + eyni şifrə. LogonCount 3 yalnız update restart-ı üçün ehtiyatdır. Əl ilə admin kimi daxil olsan, skript yenə başlayır |
| Region / hesab ekranı çıxdı | unattend Panther-ə düşməyib və ya XML xətalıdır | `C:\Deploy\deploy.log`; unattend.xml-i Edge-də aç |
| Çox dil / artıq klaviaturalar | Windows özü dillər əlavə edir | FirstLogon.ps1 v2 (`$Languages`); InputLocale-da `042c:0000042c` |
| FirstLogon-da qırmızı "Dil ayari xetasi" | Cmdlet bu Windows versiyasında yoxdur | Skript davam edir; dili əl ilə düzəlt, versiyanı yoxla |
| Masaüstündə This PC / Control Panel yoxdur | Köhnə FirstLogon versiyası | FirstLogon.ps1 v2 |
| Windows aktiv deyil | Sysprep aktivasiyanı sıfırlayır; VM-də OEM açarı yoxdur | Fiziki PC-də OEM açarı BIOS-dan; edition uyğun olmalıdır (Home açarı ≠ Pro) |

### WDS server

| Simptom | Səbəb | Həll |
| --- | --- | --- |
| Capture/apply ilişir, server yavaşdır | C: doludur, RAM azdır | C:-də ≥ 10 GB boş yer, 8 GB RAM |
| Capture/apply yavaşdır | Defender WIM-i skan edir | `Add-MpPreference -ExclusionPath "E:\Deploy","E:\RemoteInstall"` |
| ADK quraşdırılmır | C:-də yer yoxdur | ADK-nı E:-yə quraşdır |

## 2. Log faylları

| Log | Harada |
| --- | --- |
| Deploy.ps1 | WinPE-də `X:\deploy.log` → yeni PC-də `C:\Deploy\deploy.log` |
| FirstLogon.ps1 | `C:\Deploy\FirstLogon.log` |
| Windows quraşdırılması | `C:\Windows\Panther\setupact.log`, `setuperr.log`, `C:\Windows\Panther\UnattendGC\setupact.log` |
| Sysprep | `C:\Windows\System32\Sysprep\Panther\setupact.log` |
| DHCP | Firewall → DHCP log (OPNsense: Services → Kea DHCP → Log File) |
| Firewall | Firewall → Log Files → Live View (source 172.16.50.x) |

## 3. FAQ

**Skriptdə nəyisə dəyişmək istəyirəm: klientdə, yoxsa WDS-də?**
Həmişə WDS-də, `E:\Deploy\Scripts`. Klientlər faylları oradan götürür. İstisna: `startnet.cmd` boot.wim-in içindədir.

**PC şəbəkəni görmürdü. SSD-ni başqa PC-yə taxıb Windows yazdım, sonra geri taxdım. Sysprep lazımdır?**
Xeyr. Image artıq Sysprep olunub; SSD unikal SID-ini ilk açılışda alır.
- **Ən düzgün:** "HAZIRDIR! 15 saniyeye restart" yazısı çıxanda power-i basıb saxla, SSD-ni hədəf PC-yə tax.
  İlk açılış hədəf PC-nin avadanlığında gedir.
- **15 saniyəni qaçırsan** və ilk açılış (avadanlığın tanınması, unattend, FirstLogon, PC adı, istifadəçi) donor PC-də
  bitərsə, SSD-ni hədəfə taxanda **adətən yenə işləyir**: Windows 10/11 yeni avadanlığı tanıyır, driver-ləri
  Windows Update tamamlayır, PC adı və istifadəçi SSD-də qalır. Mümkün problemlər:
  - **INACCESSIBLE_BOOT_DEVICE (mavi ekran):** donor və hədəf PC-nin disk kontroller rejimi fərqlidir
    (Intel VMD/RAID ↔ AHCI). Həll: hədəf PC-nin BIOS-unda rejimi donor ilə eyni et və ya SSD-ni yenidən deploy et.
  - **Aktivasiya:** donor PC-nin OEM açarı ilə aktivləşmiş ola bilər; hədəf PC-də öz BIOS açarı ilə yenidən
    aktivləşir. Edition fərqlidirsə (Home/Pro), aktivləşməyə bilər.
  - **Donor PC-nin artıq driver-ləri** sistemdə qalır — zərərsizdir.
  - Açılış adətən problemsizdir: bcdboot UEFI üçün ehtiyat açılış faylını da yazır.

**Köhnə PC-lər (Windows 7 dövrü)?**
Deploy.ps1 yalnız UEFI/GPT yazır. 2012+ anakartların çoxunda UEFI var (CSM ilə yanaşı): Boot Override → "UEFI: IP4 ...".
Windows 11 TPM 2.0 və Intel 8-ci nəsil / Ryzen 2000+ istəyir; köhnələrdə DISM ilə qurulur, amma **dəstəklənmir**
(update zəmanəti yoxdur). Ən köhnə prosessorlarda 24H2 ümumiyyətlə açılmır.

**Capture üçün PXE ilə açanda Deploy ekranı çıxır.**
Normaldır. SIL yazma, Enter bas, komanda pəncərəsində `net use`-u Administrator ilə et.

**Eyni anda neçə PC?**
Gigabit switch ilə 4–5 PC eyni vaxtda işləyir. Limit serverdən switch-ə gedən 1 Gbps kabeldir: image hər PC-yə
ayrıca (SMB) gedir, sürət bölünür. DHCP pool-unda 101 ünvan var.

**Bir neçə image (dizayner, rəhbərlik)?**
Mümkündür: hər biri üçün ayrı reference snapshot-u və WIM + Deploy.ps1-də menyu. Amma hər image ayrıca yenilənir.
Alternativ: bir image + rol üzrə proqram skripti.

# 02 — Sıfırdan qurulum bələdçisi (yeni şirkət / yeni sayt)

Bu bələdçi ilə sistem yeni bir şirkətdə **1–2 iş gününə** sıfırdan qurulur. Ən çox vaxtı reference image
(proqramlar + update-lər) aparır.

**Qayda:** hər mərhələ ✅ yoxlama ilə bitir. Yoxlama keçmədən növbəti mərhələyə keçmə.

---

## 0. Kit nədir, nə köçürülür

Kit = skriptlər + şablonlar + bu sənədlər. **VM-lər və image-lər köçürülmür.** Skriptlər hər yerdə eynidir, amma
server, şəbəkə, lisenziyalar və proqramlar hər şirkətin özünəməxsusdur. Hazır VM-i köçürmək köhnə şirkətin adını,
şifrələrini və lisenziyalarını da aparmaq deməkdir.

| Komponent | Köçürülür? | Qeyd |
| --- | --- | --- |
| `scripts/Deploy.ps1` | ✅ olduğu kimi | Yalnız `$Company`, `$Image` |
| `scripts/FirstLogon.ps1` | ✅ olduğu kimi | Yalnız AYARLAR bloku |
| `scripts/startnet.cmd` | ✅ şablon | Server IP, server adı, share hesabı, şifrə |
| `scripts/unattend.template.xml` | ✅ şablon | Admin adı/şifrəsi (2 yerdə), saat, dillər |
| boot.wim (WinPE) | ⚠️ yenidən qurulur | İçində saytın startnet.cmd-i və şifrəsi olur, ~20–30 dəq |
| Hazır image (`Win11-Base.wim`) | ❌ | Şirkətə xas proqramlar və lisenziyalar; hər şirkətə yeni reference |
| Boş Pro (`Win11-Pro.wim`) | ✅ və ya təzədən | Microsoft ISO-sundandır; ən son ISO-dan yenidən çıxarmaq daha yaxşıdır |
| WDS server VM | ❌ | Lisenziya, ad, IP, domain fərqlidir; sıfırdan ~1 saat |
| Firewall/router konfiqi | ❌ | Yalnız qaydaların **məntiqi** köçürülür |

⚠️ İşləyən saytdakı **doldurulmuş** `unattend.xml` və `startnet.cmd`-i heç vaxt kit-ə və ya Git-ə köçürmə, içlərində şifrə var.

---

## 1. Saytın parametrləri (qurulumdan ƏVVƏL doldur)

| Parametr | Fayl / yer | Nümunə dəyər | Bu sayt |
| --- | --- | --- | --- |
| DEPLOY şəbəkəsi | Router/firewall | 172.16.50.0/24, gateway .1 | |
| DHCP pool | Router/firewall | .100–.200, option 60/66/67 YOX | |
| Statik zona | — | .2–.49 (serverlər) | |
| WDS server IP | startnet.cmd (`net use`) | 172.16.50.10 | |
| WDS server adı | startnet.cmd (`/user:<AD>\svc_imaging`) | WDS | |
| Share | startnet.cmd + server | `Deploy` → `E:\Deploy` | |
| Share hesabı + şifrə | startnet.cmd + server | `svc_imaging` (yalnız RX) | |
| Şirkət adı (ekranda) | Deploy.ps1 + FirstLogon.ps1 `$Company` | YOUR COMPANY | |
| Image faylı | Deploy.ps1 `$Image` | `Z:\Images\Win11-Base.wim` | |
| Lokal admin adı + şifrə | unattend.xml (LocalAccount + AutoLogon, **2 yerdə EYNİ**) | `ladmin` | |
| Saat qurşağı | unattend.xml `TimeZone` | Azerbaijan Standard Time | |
| Klaviaturalar | unattend.xml `InputLocale` | `0409:00000409;042c:0000042c;0419:00000419` | |
| Unicode olmayan dil | unattend.xml `SystemLocale` | `ru-RU` (1C kimi kiril proqramlar) | |
| Format | unattend.xml `UserLocale`, FirstLogon `$Culture` | `az-Latn-AZ` | |
| Dil siyahısı | FirstLogon `$Languages` | `en-US`, `az-Latn-AZ`, `ru-RU` | |
| Lokal istifadəçi yaradılsın? | FirstLogon `$CreateLocalUser` | `$true` (AD varsa `$false`) | |
| Image-dəki proqramlar | Reference VM | Office, 1C, brauzerlər, PDF reader, arxivator... | |

Daxili subnet şirkətin mövcud subnet-ləri ilə **üst-üstə düşməməlidir**.

---

## 2. Ön şərtlər

- [ ] Hipervizor (ESXi / Hyper-V) və ya fiziki server; datastore-da **≥ 300 GB boş yer**
- [ ] Boş fiziki NIC və ya ayrıca VLAN + DEPLOY otağı üçün **gigabit switch** (hub yox)
- [ ] DHCP + gateway verə bilən cihaz (OPNsense, pfSense, FortiGate, MikroTik, Windows DHCP)
- [ ] Windows Server 2022/2025 lisenziyası + ISO
- [ ] Ən son Windows 11 ISO
- [ ] Windows ADK + WinPE add-on (**eyni versiya**, ən son)
- [ ] Lisenziyalı proqramların quraşdırıcıları
- [ ] Hədəf PC-lərin siyahısı: model, UEFI/Legacy, TPM 2.0, Intel VMD var/yox

### Mərhələlər və təxmini vaxt

| Mərhələ | Nə | Vaxt |
| --- | --- | --- |
| A | Şəbəkə: izolə subnet, DHCP, firewall | ~1 saat |
| B | WDS server VM + WDS rolu | ~1 saat (+ update-lər) |
| C | Share, hesablar, Defender | ~15 dəq |
| D | Kit fayllarını yerləşdir və doldur | ~15 dəq |
| E | ADK + WinPE + startnet → boot.wim | ~30 dəq |
| F | Reference image: Windows + update + proqramlar + Sysprep + capture | ~3–5 saat |
| G | Test: VM, sonra hər vendor-dan bir fiziki PC | ~1–2 saat |
| H | Təhvil: sənədlər, şifrələr, backup | ~30 dəq |

---

## A. Şəbəkə

**Məqsəd:** yalnız DEPLOY otağındakı kompüterlərin görə bildiyi, internetə çıxan, amma şirkət LAN-ına və lab-a
girə bilməyən ayrıca şəbəkə.

### A1. Hipervizor (ESXi nümunəsi)
1. **Networking → Physical NICs**: link-i "Down" olan boş NIC-i tap (məs. `vmnic1`). Hansı fiziki port olduğunu tapmaq
   üçün laptopu portlara bir-bir qoş, **Refresh** et və link-in "1000 Mbps" olduğu portu etiketlə.
2. **Virtual switches → vSwitch0**: boş NIC-in orada uplink (hətta standby) olmadığını yoxla.
3. **Add standard virtual switch**: ad `Deploy Switch`, uplink = boş NIC, Security: hər üçü Reject.
4. **Add port group**: ad `Deploy-WDS`, VLAN ID `0`, switch `Deploy Switch`.
5. ⚠️ Boş NIC-i mövcud lab/istehsalat vSwitch-inə **qoşma**: tagged trafik fiziki porta çıxar.

### A2. Router / firewall (OPNsense nümunəsi)
1. Firewall VM-i **GUI-dən söndür** → Edit settings → **Add network adapter** → port group `Deploy-WDS`, tip **VMXNET3**
   (FreeBSD-də driver hazırdır) → MAC-ı qeyd et → aç.
   ⚠️ Konsoldakı "1) Assign interfaces" seçimini istifadə etmə: bütün interfeysləri yenidən soruşur.
2. **Interfaces → Assignments**: yeni `vmxN` (MAC-a görə) → Description `DEPLOY` → Add → Save.
3. **Interfaces → [DEPLOY]**: Enable, Static IPv4 `172.16.50.1/24`, IPv6 None, gateway rules **Disabled**,
   Block private/bogon **BOŞ** → Save → Apply.
4. **Services → Kea DHCPv4**:
   - Settings: Interfaces-ə `DEPLOY` əlavə et (digərləri qalsın), Socket Type `raw`, Firewall rules ✅
   - Subnets → (+): `172.16.50.0/24`, Pools `172.16.50.100-172.16.50.200`, Auto collect option data ✅.
     **Next server / TFTP server / TFTP bootfile BOŞ.**
   - Log-da bind xətası olmamalıdır.
5. **Firewall → Aliases**: DEPLOY subnet-ini **daxili şəbəkələr** alias-ına əlavə et (məs. `INTERNAL_NETS`), istehsalat
   alias-ına yox. ⚠️ Səhv alias-a düşsə, DNS və gateway bloklanır.
6. **Firewall → Rules → DEPLOY** (Source = `DEPLOY net`, Direction in, Quick ✅, **bu sıra ilə**):
   1. Block → istehsalat şəbəkəsi (məs. `CORP_LAN`), Log ✅
   2. Pass → This Firewall (DNS, gateway)
   3. Block → digər daxili şəbəkələr (`INTERNAL_NETS`), Log ✅
   4. Pass → any (internet)
7. **Firewall → NAT → Outbound**: Automatic-dirsə heç nə; Hybrid/Manual-dırsa `172.16.50.0/24 → WAN address`.
8. **System → Configuration → Backups**: config-i yüklə.

Başqa cihazlarda (FortiGate, MikroTik) eyni məntiq: ayrıca interfeys/VLAN + DHCP server (option-suz) + 4 qayda + NAT.

### A3. Fiziki
- Gigabit **unmanaged switch** (hub yox), Cat6 kabel: serverin etiketli portu → DEPLOY otağı.
- Switch-in üzərində və patch panel portunda etiket: **"DEPLOY — LAN-a QOŞMA"**. Bu switch şirkət LAN-ına qoşulsa,
  firewall-un DHCP-si bütün şirkətə IP paylayar (rogue DHCP).

✅ **Yoxlama (laptop DEPLOY portunda):**

| Test | Gözlənilən |
| --- | --- |
| `ipconfig` | 172.16.50.1xx, gateway .1 |
| `ping 172.16.50.1` | ✅ |
| `ping 8.8.8.8`, `nslookup google.com` | ✅ |
| İstehsalat IP-si | ❌ (Live View-da "Block ... prod") |
| Lab IP-si | ❌ (Live View-da "Block ... lab") |

---

## B. WDS server

1. **VM:** Windows Server 2025, 2 vCPU, **8 GB RAM**, Disk 1 (C:) **≥ 80 GB**, Disk 2 (E:) **200 GB**, Thin.
   NIC = `Deploy-WDS`. Server üçün VMXNET3 olar, amma əvvəl **VMware Tools** quraşdır, sonra kartı dəyiş.
2. **Statik IP:** `172.16.50.10/24`, gateway `.1`, DNS `.1`. `ping` + `nslookup` yoxla.
3. **Adı dəyiş:** `Rename-Computer -NewName WDS -Restart`. Windows Update → restart.
4. **Disk 2:** `diskmgmt.msc` → Online → GPT → NTFS. Hərf fərqli düşsə (məs. CD-ROM D:-ni tutub), problem deyil.
5. **Rol:** Server Manager → Add Roles → **Windows Deployment Services** (Deployment Server + Transport Server).
6. **Configure Server:** Standalone → `E:\RemoteInstall` → PXE: **Respond to all client computers** → son səhifədə
   **"Add images to the server now" işarəsini götür**.
7. **WDS → Properties:**
   - **DHCP tabı:** "Do not listen on DHCP ports" və "Configure DHCP options..." → **ikisi də BOŞ**
     (DHCP başqa maşındadır; WDS 67-ci portda PXE sorğusunu özü dinləyir. Option 60 yalnız DHCP və WDS eyni serverdə olanda lazımdır.)
   - **Boot tabı:** Known və Unknown → **Require the user to press the F12 key** (təsadüfi formatın qarşısını alır)
   - **TFTP tabı:** Maximum block size **8192**, **Enable Variable Window Extension** ✅
   - OK → WDS üzərində sağ klik → All Tasks → **Restart**

✅ **Yoxlama:** WDS ikonunda yaşıl işarə.

---

## C. Share, hesablar, Defender

PowerShell (admin):
```powershell
New-Item E:\Deploy\Images, E:\Deploy\Images\Archive, E:\Deploy\Scripts, E:\Deploy\Drivers\WinPE -ItemType Directory -Force
net user svc_imaging <GÜCLÜ_ŞİFRƏ> /add
Set-LocalUser -Name svc_imaging -PasswordNeverExpires $true
icacls E:\Deploy /grant "svc_imaging:(OI)(CI)RX"
New-SmbShare -Name Deploy -Path E:\Deploy -ReadAccess svc_imaging -FullAccess Administrators
Add-MpPreference -ExclusionPath "E:\Deploy","E:\RemoteInstall"
```
- `svc_imaging` **Administrators qrupuna əlavə edilmir.** Onun şifrəsi boot.wim-də açıq saxlanacaq, ona görə yalnız oxuya bilər.
- Capture zamanı yazmaq üçün `WDS\Administrator` istifadə olunur.
- Defender istisnası: capture və apply zamanı WIM-in real vaxtda skan edilməsi prosesi xeyli yavaşladır.

✅ **Yoxlama:** E mərhələsindən sonra WinPE-dən `net use Z: \\172.16.50.10\Deploy /user:DEPLOYSRV\svc_imaging` işləyir.
Error 53 olarsa: `Enable-NetFirewallRule -DisplayGroup "File and Printer Sharing"`.

---

## D. Kit faylları

1. `scripts\*` → `E:\Deploy\Scripts\`.
2. `unattend.template.xml` → **Save As** `unattend.xml`:
   - `ADMIN_ADI` → admin adı (**2 yerdə**: `LocalAccount/Name` və `AutoLogon/Username`)
   - `ADMIN_SIFRE` → şifrə (**2 yerdə**). Şifrədə `&`, `<`, `>` istifadə etmə.
   - TimeZone, InputLocale, SystemLocale, UserLocale → saytın dəyərləri.
   - Faylı **Edge-də aç**: XML xətası varsa göstərəcək.
3. `startnet.cmd`: `172.16.50.10` → server IP; `DEPLOYSRV\svc_imaging` → `<SERVER_ADI>\svc_imaging`; `SIFRE_BURAYA` → şifrə.
4. `Deploy.ps1`: `$Company`. `FirstLogon.ps1`: `$Company`, `$Languages`, `$Culture`, `$CreateLocalUser`.
5. Skriptlər **ASCII** (ə, ş, ç yox) və **CRLF** sətir sonu ilə qalmalıdır. Notepad bunu saxlayır.

---

## E. WinPE (boot.wim)

1. **ADK** quraşdır: Install path `E:\ADK\` (C:-ni doldurma), Privacy No, Features: **yalnız Deployment Tools**.
   Sonra **WinPE add-on** (eyni qovluğa).
2. Start → **Deployment and Imaging Tools Environment** → sağ klik → **Run as administrator**:

```cmd
copype amd64 E:\WinPE_amd64
Dism /Mount-Image /ImageFile:"E:\WinPE_amd64\media\sources\boot.wim" /Index:1 /MountDir:"E:\WinPE_amd64\mount"
set OC=E:\ADK\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs
dir "%OC%\WinPE-WMI.cab"
```
Sonuncu əmr faylı göstərməlidir (yol düzgündür). Sonra komponentlər, **sıra ilə**:
```cmd
for %c in (WinPE-WMI WinPE-NetFX WinPE-Scripting WinPE-PowerShell WinPE-StorageWMI WinPE-DismCmdlets) do (Dism /Image:"E:\WinPE_amd64\mount" /Add-Package /PackagePath:"%OC%\%c.cab" && Dism /Image:"E:\WinPE_amd64\mount" /Add-Package /PackagePath:"%OC%\en-us\%c_en-us.cab")
copy /Y E:\Deploy\Scripts\startnet.cmd E:\WinPE_amd64\mount\Windows\System32\startnet.cmd
Dism /Image:"E:\WinPE_amd64\mount" /Add-Driver /Driver:"E:\Deploy\Drivers\WinPE" /Recurse
Dism /Unmount-Image /MountDir:"E:\WinPE_amd64\mount" /Commit
```
Driver sətri yalnız `Drivers\WinPE`-də `.inf` fayllar varsa lazımdır (VMD, yeni NIC-lər). `/Commit` olmasa, bütün əlavələr itir.

| Komponent | Nə üçün |
| --- | --- |
| WMI | Kompüterdən məlumat (model) |
| NetFX | PowerShell üçün lazımdır |
| Scripting | VBScript/WSH |
| PowerShell | Deploy.ps1 |
| StorageWMI | Disk cmdlet-ləri (`Get-Disk`) |
| DismCmdlets | DISM PowerShell əmrləri |

3. **WDS → Boot Images → Add Boot Image** → `E:\WinPE_amd64\media\sources\boot.wim` → ad `WinPE Deploy x64`.

✅ **Yoxlama:** boş test VM — Guest OS Windows 10 64-bit (Win11 seçsən ESXi vTPM istəyir), 2 vCPU / 4 GB,
40–60 GB disk, Firmware **EFI**, Boot Delay 5000, NIC `Deploy-WDS` tipi **E1000E** (WinPE-də VMXNET3 driver-i yoxdur).
Power on → "Press ENTER for network boot" → Enter → "Loading files" → **mavi Deploy ekranı**.

---

## F. Reference image

### F1. Boş Windows 11 Pro-nu hazırla
WDS serverinin CD-sinə Windows 11 ISO-nu tax:
```cmd
copy D:\sources\install.esd E:\Deploy\Images\
dism /Get-WimInfo /WimFile:E:\Deploy\Images\install.esd
```
Siyahıda **Windows 11 Pro**-nun Index-ini tap (Pro N yox):
```cmd
dism /Export-Image /SourceImageFile:E:\Deploy\Images\install.esd /SourceIndex:<N> /DestinationImageFile:E:\Deploy\Images\Win11-Pro.wim /Compress:max /CheckIntegrity
dism /Get-WimInfo /WimFile:E:\Deploy\Images\Win11-Pro.wim
del E:\Deploy\Images\install.esd
```
(ISO-da `install.wim` varsa, eyni əmrlər `install.wim` ilə.)

### F2. Reference VM-ə Windows yaz (TPM yoxlaması olmadan)
Windows 11 installer TPM 2.0 yoxlayır; ESXi-də vCenter olmadan vTPM yoxdur. DISM isə yoxlamır.
1. Reference VM: EFI, E1000E, **70 GB** disk, 4 GB RAM.
2. VM-i PXE ilə aç → mavi Deploy ekranında **SIL YAZMA → Enter** (imtina). ⚠️ Reference üçün Deploy.ps1 istifadə
   **edilmir**: o, unattend.xml-i də köçürür, onda region ekranı çıxmaz və Audit Mode-a girmək olmaz.
3. Komanda pəncərəsində Windows-u **əllə** yaz (`Z:` artıq qoşuludur):
   ```cmd
   diskpart
   select disk 0
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
   dism /Apply-Image /ImageFile:Z:\Images\Win11-Pro.wim /Index:1 /ApplyDir:W:\
   bcdboot W:\Windows /s S: /f UEFI
   wpeutil reboot
   ```
   Restartda "network boot" çıxsa Enter basma.
4. VM açılanda region ekranında **Ctrl+Shift+F3** → Audit Mode → Administrator kimi masaüstü. Sysprep pəncərəsini
   **bağla** (hər restart-da çıxacaq, hər dəfə bağla). Audit Mode restart-dan sonra da qalır.
5. Snapshot: `01-bos-windows-audit` (memory-siz).

### F3. Hazırla
1. Store avtomatik yeniləmələrini söndür (Sysprep xətasının №1 səbəbi):
   ```cmd
   reg add HKLM\SOFTWARE\Policies\Microsoft\WindowsStore /v AutoDownload /t REG_DWORD /d 2 /f
   ```
2. Windows Update → "You're up to date" olana qədər.
3. Proqramlar, hər birində **"for all users"** seçimi ilə. Opera kimi brauzerlərin `Program Files`-da olduğunu yoxla.
4. **YOX:**
   - Microsoft Store tətbiqləri (WhatsApp və s.) → Sysprep xətası
   - Microsoft hesabı ilə giriş
   - Windows-a əl ilə dil paketi əlavə etmək → Sysprep xətası (dil unattend + FirstLogon ilə gəlir)
   - VMware Tools → bütün fiziki PC-lərə gedər
   - Antivirus (Defender kifayətdir), backup agenti (Veeam və s.) → unikal ID-lər eyni olar
   - AnyDesk/TeamViewer-i **işə salmaq** → bütün PC-lərdə eyni ID. Quraşdırıcı faylı `C:\Users\Public\Desktop`-a qoymaq olar.
   - Aktivator alətləri, lisenziyasız proqramlar → hər PC-yə yayılır, Defender karantinə alır
5. Təmizlik: `Downloads`, Recycle Bin.
6. C:-də yer azalsa: snapshot-lar olanda ESXi diski **böyütmür** → snapshot-ları sil → diski böyüt → `diskmgmt` → Extend.

### F4. Sysprep
1. Snapshot: **`Before sysprep`** ← gələcək yeniləmələrin başlanğıc nöqtəsi.
2. Faylları anbardan götür (CMD admin):
   ```cmd
   net use Z: \\172.16.50.10\Deploy /user:DEPLOYSRV\svc_imaging
   mkdir C:\Deploy
   copy Z:\Scripts\FirstLogon.ps1 C:\Deploy\
   copy Z:\Scripts\unattend.xml C:\Windows\System32\Sysprep\
   net use Z: /delete
   ```
   (Sonuncu əmr: anbarın açarı image-də qalmasın.)
3. Sysprep:
   ```cmd
   C:\Windows\System32\Sysprep\sysprep.exe /generalize /oobe /shutdown /unattend:C:\Windows\System32\Sysprep\unattend.xml
   ```
4. VM özü sönür. Xəta olsa → [04-troubleshooting.md](04-troubleshooting.md).
5. Snapshot: **`after sysprep`**. ⚠️ Bu VM-i bir daha Windows ilə **açma**.

### F5. Capture
1. **Edit settings → VM Options → Boot Options → Force BIOS setup** ✅ (ESXi 7-də adı belədir, EFI-də də işləyir).
   Snapshot restore-dan **sonra** et: restore bu ayarı geri qaytarır.
2. Əvvəl konsolu aç → Power on → **Boot Manager → EFI Network** → Enter.
   ⚠️ "EFI VMware Virtual disk" seçsən, Windows açılar və Sysprep boşa gedər → `after sysprep` snapshot-una qayıt.
3. Mavi Deploy ekranında **SIL YAZMA → Enter** (imtina) → komanda pəncərəsi.
4. Yazma hüququ ilə qoşul:
   ```cmd
   net use Z: /delete
   net use Z: \\172.16.50.10\Deploy /user:WDS\Administrator
   diskpart
   list vol
   exit
   ```
   Label `Windows`, NTFS olan hərfə bax (adətən C:).
5. Capture (15–40 dəq). **Pəncərəyə klik etmə** — başlıqda "Select" görünsə Esc:
   ```cmd
   dism /Capture-Image /ImageFile:Z:\Images\Win11-Base.wim /CaptureDir:C:\ /Name:"Win11 Base v1" /Compress:fast
   dism /Get-WimInfo /WimFile:Z:\Images\Win11-Base.wim
   wpeutil shutdown
   ```
   70 GB disk → WIM təxminən 10–15 GB olur (yalnız dolu hissə, sıxılmış).
6. Reference VM-in adını `REF-Win11` qoy. **Silmə** — gələcək yeniləmələr onunla edilir.

---

## G. Test

### G1. Test VM
Boş VM (E bölməsindəki kimi) → PXE → Deploy ekranı → `SIL` → [1/4]…[4/4] → restart ("network boot"-da Enter BASMA):

| Görməli olduğun | Nəyi sübut edir |
| --- | --- |
| Region ekranı çıxmır | unattend.xml işləyir |
| Admin avtomatik daxil olur, "password incorrect" yoxdur | LocalAccount = AutoLogon |
| Mavi pəncərə [1/5]…[5/5], qırmızı xəta yoxdur | FirstLogon.ps1 işləyir |
| Restart → istifadəçi ilə giriş, şifrə dəyişmə tələbi | Standard user yaradıldı |
| Proqramlar yerində, yalnız seçilmiş dillər | Image + dil ayarı düzgündür |
| `net localgroup administrators` → istifadəçi YOX | İstifadəçi admin deyil |

### G2. Fiziki PC (hər vendor-dan bir)
- Boot menyusu → **IPv4** (IPv6 PXE 1–2 dəqiqə itirir). "Loading files" vaxtını ölç.
- Disk görünür? Görünmürsə → Intel VMD: BIOS-da off və ya driver `Drivers\WinPE`-yə + boot.wim yenilə.
- Secure Boot ON ilə açılır?
- Windows aktivasiyası (OEM açarı BIOS-dan; edition uyğun olmalıdır: Home açarı Pro-nu aktivləşdirmir).
- Köhnə PC (Legacy BIOS): BIOS → Save & Exit → Boot Override → "UEFI: IP4 ..." seç.

---

## H. Təhvil

- [ ] [03-runbook-operations.md](03-runbook-operations.md)-in nüsxəsi saytın dəyərləri ilə
- [ ] Şifrələr (lokal admin, svc_imaging, WDS Administrator) password manager-də
- [ ] WDS + REF VM backup job-da; firewall config yüklənib
- [ ] Switch və patch panel etiketi
- [ ] Bu kit-də tapılan düzəlişlər Git-ə qaytarılıb (CHANGELOG)

# 03 — Runbook: gündəlik istifadə və dəyişikliklər

İşləyən sistemdə texnikin bilməli olduğu hər şey: yeni PC qurmaq, skriptləri və image-i dəyişmək, WinPE-ni yeniləmək.

---

## 1. Yeni kompüter necə qurulur (~20–30 dəq)

**Əvvəl:**
- İstifadə olunmuş PC-dirsə, istifadəçinin fayllarının backup-ını al. Disk **tamamilə silinir**.
- Windows 11 üçün PC-də TPM 2.0 olmalıdır (BIOS-da Intel **PTT** / AMD **fTPM** → Enable).

**Addımlar:**
1. PC-ni **DEPLOY switch-inə** və ya serverin DEPLOY portuna qoş. Şirkət LAN-ına qoşulmuş PC WDS-i görmür.
2. PC-ni yandır → boot menyusu (cədvəl aşağıda) → **IPv4 Network / PXE**. IPv6-nı seçmə: IPv6 PXE yoxdur, 1–2 dəqiqə itirir.
3. "Press ENTER for network boot service" → **Enter**.
4. "Loading files..." → gözlə (WinPE RAM-a yüklənir).
5. Mavi ekran: kompüterin modeli və seçilən disk göstərilir. Diskdə Windows varsa, qırmızı xəbərdarlıq çıxır.
   Bir neçə daxili disk varsa, nömrəsini soruşur.
6. Formatlamaq üçün böyük hərflərlə **`SIL`** yaz. Əmin deyilsənsə → sadəcə **Enter** = heç nə silinmir.
7. [1/4] → [4/4]: disk hazırlanır → Windows yazılır (10–15 dəq) → ayarlar köçürülür → açılış faylları.
   **Pəncərəyə klik etmə.** Başlıqda "Select" görünsə → **Esc**.
8. "HAZIRDIR! 15 saniyeye restart" → restart. "network boot" yazısı çıxsa **Enter BASMA**, özü diskdən açılır.
9. Region ekranı çıxmır, admin avtomatik daxil olur. Mavi pəncərə:
   - **PC adı** (max 15 simvol, yalnız hərf/rəqəm/`-`; məs. `MUH-AYTAN`)
   - **İstifadəçi adı** (məs. `aytan.m`) və **müvəqqəti şifrə** (sadəcə Enter = şifrəsiz)
10. Restart → istifadəçi ilə daxil ol → şifrə qoyulubsa, yeni şifrə tələb edir. Proqramları yoxla.
11. Sonra: backup agenti (Veeam Protection Group), Windows aktivasiyasını yoxla (OEM lisenziyası BIOS-dan özü aktivləşir).

### Boot menyusu düymələri

| Vendor | Boot menyusu | BIOS | Qeyd |
| --- | --- | --- | --- |
| HP | F9 | F10 | |
| Lenovo | F12 / Fn+F12 | F1 / F2 | Bəzi modellərdə Novo düyməsi (kiçik deşik) |
| ASUS | F8 / Esc | F2 / Del | |
| Dell | F12 | F2 | |
| Köhnə AMI/Aptio anakartlar | F8 / F11 / F12 | Del | Save & Exit → **Boot Override** → "UEFI: IP4 ..." |

Menyuda şəbəkə seçimi yoxdursa: BIOS → **Network Stack / PXE Boot → Enable**. Secure Boot-a toxunma — WinPE onunla işləyir.

### SSD-ni başqa PC-də yazmaq (PC şəbəkəni görmürsə)
1. SSD-ni işləyən PC-yə tax → yuxarıdakı addımlar 1–7.
2. "HAZIRDIR! 15 saniyeye restart" yazısı çıxanda **power düyməsini basıb saxla** (restartdan əvvəl).
3. SSD-ni hədəf PC-yə tax və aç. İlk açılış (avadanlığın tanınması, unattend, FirstLogon) hədəf PC-də gedir.
4. Sysprep **lazım deyil** — image artıq Sysprep olunub.

15 saniyəni qaçırıb ilk açılışı donor PC-də bitirsən də, adətən işləyir — bax [04-troubleshooting.md](04-troubleshooting.md) → FAQ.

---

## 2. Nəyi harada dəyişirsən

**Qızıl qayda:** dəyişikliklər həmişə **WDS serverində**, `E:\Deploy\Scripts` qovluğunda edilir — klientdə yox.
Hər yeni PC faylları oradan götürür. Artıq qurulmuş PC-lərə təsir etmir.

| Nəyi dəyişirsən | Harada | Nə vaxt qüvvəyə minir |
| --- | --- | --- |
| Admin adı/şifrəsi, dil, klaviatura, saat, LogonCount | `unattend.xml` (ad + şifrə **2 yerdə EYNİ**) | Növbəti PC-dən |
| İlk giriş addımları (PC adı, user, restore, dillər, ikonlar) | `FirstLogon.ps1` | Növbəti PC-dən |
| Disk seçimi, təsdiq, bölmələr, image adı, şirkət adı | `Deploy.ps1` | Növbəti PC-dən |
| Share şifrəsi, server IP-si | `startnet.cmd` → **boot.wim yenidən** | Bölmə 3-dən sonra |
| WinPE driver-ləri (VMD, NIC) | `Drivers\WinPE` → **boot.wim yenidən** | Bölmə 3-dən sonra |
| Proqramlar, Windows update-ləri | Reference VM → yeni WIM | Bölmə 4 |

**Hər dəyişiklikdən əvvəl backup:**
```cmd
xcopy E:\Deploy\Scripts E:\Deploy\Scripts_backup_%date:~-4%%date:~3,2%%date:~0,2%\ /E /I
```
**Hər dəyişiklikdən sonra:** test VM ilə bir tam qurulum. Problem olsa → backup-ı geri köçür (`xcopy ... /E /Y`).

Skriptləri Notepad ilə redaktə et. Yalnız ASCII simvollar (ə, ş, ç yox). unattend.xml-i saxlayandan sonra Edge-də aç —
XML xətası varsa göstərir.

---

## 3. boot.wim-i yeniləmək (startnet.cmd və ya driver dəyişəndə)

"Deployment and Imaging Tools Environment" (admin):
```cmd
Dism /Mount-Image /ImageFile:"E:\WinPE_amd64\media\sources\boot.wim" /Index:1 /MountDir:"E:\WinPE_amd64\mount"
copy /Y E:\Deploy\Scripts\startnet.cmd E:\WinPE_amd64\mount\Windows\System32\startnet.cmd
Dism /Image:"E:\WinPE_amd64\mount" /Add-Driver /Driver:"E:\Deploy\Drivers\WinPE" /Recurse
Dism /Unmount-Image /MountDir:"E:\WinPE_amd64\mount" /Commit
```
Sonra: **WDS → Boot Images → "WinPE Deploy x64" → sağ klik → Replace Image** → həmin `boot.wim`.

- Mount xəta versə (əvvəlki mount açıq qalıb): `Dism /Unmount-Image /MountDir:"E:\WinPE_amd64\mount" /Discard`, sonra `Dism /Cleanup-Mountpoints`.
- C:-də yer azdırsa: əmrə `/ScratchDir:E:\Scratch` əlavə et.

---

## 4. Image-i yeniləmək (rübdə bir, ~1–2 saat)

Heç nə sıfırdan qurulmur: reference VM-in Sysprep-dən **əvvəlki** snapshot-una qayıdılır.

### A. Reference-i hazırla
1. Hipervizor → `REF-Win11` → Manage snapshots → **"Before sysprep"** sətrinə **klik et** → Restore.
   (Düymə bozdursa: əvvəl snapshot-u seç.)
2. Power on → Windows **Audit Mode**-da açılır (Administrator). Sysprep pəncərəsini bağla.
3. Windows Update + proqram dəyişiklikləri. Qaydalar [02-implementation-guide.md](02-implementation-guide.md) F3-dəki kimi
   (Store, dil paketi, VMware Tools, antivirus, backup agenti, AnyDesk-in işə salınması YOX).
4. Yeni snapshot: `Before sysprep vN` (köhnəsini yer üçün silmək olar).
5. CMD (admin):
   ```cmd
   C:\Windows\System32\Sysprep\sysprep.exe /generalize /oobe /shutdown /unattend:C:\Windows\System32\Sysprep\unattend.xml
   ```
6. VM sönür → snapshot `after sysprep vN`.

### B. Capture
1. Edit settings → VM Options → Boot Options → **Force BIOS setup** ✅ (restore-dan SONRA).
2. Konsol → Power on → Boot Manager → **EFI Network**. ⚠️ Virtual disk YOX.
3. Deploy ekranında **Enter** (imtina, SIL yazma).
4. ```cmd
   net use Z: /delete
   net use Z: \\172.16.50.10\Deploy /user:WDS\Administrator
   diskpart
   list vol
   exit
   dism /Capture-Image /ImageFile:Z:\Images\Win11-Base-vN.wim /CaptureDir:C:\ /Name:"Win11 Base vN" /Compress:fast
   dism /Get-WimInfo /WimFile:Z:\Images\Win11-Base-vN.wim
   wpeutil shutdown
   ```

### C. Dövriyyəyə burax
1. Köhnə `Win11-Base.wim` → `E:\Deploy\Images\Archive\`.
2. Yenisinin adı → `Win11-Base.wim` (Deploy.ps1 bu adı oxuyur).
3. Test VM ilə tam test. Problem olsa → arxivdəkini geri qaytar.
4. Test keçəndən sonra arxivdə yalnız bir əvvəlki versiyanı saxla.

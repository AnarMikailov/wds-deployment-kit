# 06 — Təhlükəsizlik və baxım

## 1. Təhlükəsizlik: bilinən risklər

Əsas qoruma DEPLOY şəbəkəsinin izolə olmasıdır. Aşağıdakı risklər bu izolyasiyaya görə qəbul edilib.

| Risk | Niyə var | Hazırkı qoruma | Planlı həll |
| --- | --- | --- | --- |
| Otaq switch-i şirkət LAN-ına qoşulsa | Firewall bütün LAN-a DEPLOY IP-ləri paylayar (rogue DHCP) | Switch və patch panel etiketi "LAN-a QOŞMA" | Managed switch-də DHCP snooping |
| svc_imaging şifrəsi boot.wim-də açıqdır | WinPE-ni TFTP ilə DEPLOY-dakı hər cihaz yükləyə bilər | svc_imaging yalnız oxuma (RX) | — |
| Lokal admin şifrəsi unattend.xml-də (share-də) açıqdır | svc_imaging ilə oxuna bilər | İzolə şəbəkə; yeni PC-də FirstLogon unattend fayllarını və AutoLogon qalıqlarını silir | AD + Windows LAPS |
| Bütün PC-lərdə eyni lokal admin şifrəsi | Bir PC ələ keçsə, şifrə hər yerdə işləyir (lateral movement) | — | AD + Windows LAPS |
| Şifrəsiz istifadəçi seçimi | PC-yə fiziki çıxışı olan hər kəs daxil ola bilər | İstəyə görə (Enter) | Vacib PC-lərdə şifrə |
| Defender istisnaları (WDS-də) | Capture/apply sürəti üçün | Yalnız WDS serverində, yalnız 2 qovluq | — |
| Secure Boot sertifikat keçidi (2011 → 2023) | 2023 sertifikatına keçmiş PC-lər köhnə WinPE-ni açmaya bilər | ADK-nı yeniləmək | Xəta olsa, 2023-imzalı boot faylları |
| WDS rolu deprecated | Microsoft növbəti Windows Server versiyasında WDS-i deprecated edir | Server 2025-də dəstəklənir | Server-i yüksəltməzdən əvvəl alternativə bax |

### Qaydalar
- İstifadəçilər **standard user**-dir, lokal admin deyil.
- Image-ə yalnız **lisenziyalı və pulsuz** proqramlar düşür. Aktivator alətləri image-ə qoyulmur: hər PC-yə yayılır,
  Defender karantinə alır, zərərli kod riski bütün parka yayılır.
- AnyDesk/TeamViewer-in pulsuz versiyaları yalnız şəxsi istifadə üçündür. "Home" antiviruslar şirkətdə
  istifadə edilmir — Windows Defender.
- Şifrələr (lokal admin, svc_imaging, WDS Administrator) **password manager**-də. Git-də, e-poçtda, screenshot-da yox.
- Git-də yalnız **şablonlar** (`ADMIN_ADI`, `ADMIN_SIFRE`, `SIFRE_BURAYA`). Doldurulmuş `unattend.xml` `.gitignore`-dadır.

## 2. Bir dəfəlik səliqə (yeni qurulmuş sistemdən sonra)

- [ ] Qovluqlar: `E:\Deploy\Images\Archive`, `E:\Deploy\Drivers\WinPE`, `E:\Deploy\Drivers\<Vendor>\<Model>`
- [ ] `Win11-Pro.wim` saxla (reference-i sıfırdan qurmaq üçün), lazımsız test WIM-lərini sil
- [ ] VM adları: reference → `REF-Win11`; test VM qalır
- [ ] unattend.xml: admin adı + şifrəsi LocalAccount və AutoLogon-da **eyni**
- [ ] WDS-in C: diski ≥ 10 GB boş (Recovery bölməsi problemi → [04-troubleshooting.md](04-troubleshooting.md))
- [ ] WDS + REF VM backup job-da; firewall config yüklənib
- [ ] Şifrələr password manager-də
- [ ] Switch və patch panel etiketi

## 3. Dövri baxım

| Nə vaxt | Nə | Niyə |
| --- | --- | --- |
| Ayda bir | WDS serverinə Windows Update; C:, E: və datastore boş yeri | Thin disk-lər böyüyür; dolu datastore bütün VM-ləri dayandırır |
| Rübdə bir | Image yeniləməsi (update + proqram versiyaları) + test | Yeni PC ilk açılışda saatlarla update yükləməsin |
| Yeni model gələndə | Bir PC ilə test: PXE, disk görünür (VMD), WinPE-də şəbəkə | Lazım olsa driver → boot.wim |
| İldə bir | Yeni ADK + WinPE add-on; Secure Boot sertifikat dəyişiklikləri | Yeni PC-lərdə WinPE-nin açılmaması riski |
| Hər dəyişiklikdən sonra | Sənədləri yenilə + CHANGELOG | Növbəti dəfə yadda saxlamaq lazım olmasın |

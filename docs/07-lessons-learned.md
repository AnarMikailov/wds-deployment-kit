# 07 — Öyrənilmiş dərslər

İlk qurulumda vaxt itirdiyimiz hər tələ burada. Yeni saytda əvvəlcədən qarşısını al.

| # | Tələ | Nəticəsi | Qarşısını alan |
| --- | --- | --- | --- |
| 1 | WDS server C: 29 GB | ADK quraşdırılmadı, capture zamanı server boğuldu | C: ≥ 80 GB; ADK və image-lər data diskində |
| 2 | DEPLOY subnet-i səhvən istehsalat alias-ına əlavə olundu | Gateway-ə ping və DNS bloklanırdı (internet isə işləyirdi) | Live View-da hansı qaydanın tutduğuna bax; alias adını iki dəfə yoxla |
| 3 | Windows 11 `boot.wim` WDS rejimində bloklanıb | WDS-in "Install Images" yolu işləmir | Custom WinPE + share + DISM |
| 4 | WinPE-ni açan VM-də VMXNET3 | WinPE şəbəkəni görmür | WinPE ilə açılan VM-lərdə E1000E |
| 5 | ESXi-də Windows 11 installer | TPM yoxlaması, vTPM üçün vCenter lazımdır | Windows-u WinPE + DISM ilə yazmaq (yoxlama yoxdur) |
| 6 | CMD pəncərəsinə klik (QuickEdit) | DISM saatlarla "dondu" | Uzun əmrdə pəncərəyə toxunma; başlıqda "Select" → Esc |
| 7 | Reference-də Windows dili əl ilə dəyişdirildi | AZ və RU dil paketləri → Sysprep "not able to validate" | Dil yalnız unattend + FirstLogon ilə |
| 8 | Store tətbiqləri, home antivirus | Sysprep xətası, lisenziya problemi | Store tətbiqi və home antivirus image-də yox |
| 9 | SetupComplete.cmd | OEM açarı olan PC-lərdə (HP/Lenovo/ASUS) işə düşmür | FirstLogonCommands + FirstLogon.ps1 |
| 10 | unattend-də LocalAccount `ladmin`, AutoLogon `itadmin` | "password incorrect" | Ad və şifrə 2 yerdə eyni (şablonda tək yer tutucu) |
| 11 | Sysprep-dən sonra Boot Manager-də disk seçildi | Windows açıldı, Sysprep boşa getdi | Snapshot "after sysprep" + EFI Network |
| 12 | Snapshot olanda VM diskini böyütmək; datastore-da az yer | Disk extend xətası | Datastore-da ≥ 20% boş yer, snapshot-ları vaxtında sil |
| 13 | ESXi 7-də "Force EFI setup" adı | Seçim tapılmadı | ESXi 7-də adı "Force BIOS setup"-dır (EFI-də də işləyir) |
| 14 | PC IPv6 PXE-ni gözləyir | Hər açılışda 1–2 dəqiqə itir | Boot menyusunda IPv4 |
| 15 | Köhnə PC Legacy rejimdə | Windows yazılır, amma açılmır | BIOS-da UEFI şəbəkə seçimi (Boot Override) |
| 16 | startnet.cmd-də şifrə | WinPE-ni yükləyən hər kəs share-ə girə bilər | svc_imaging yalnız RX; capture üçün Administrator |
| 17 | Reference VM-ə Deploy.ps1 ilə Windows yazmaq | unattend də köçür → region ekranı yoxdur → Audit Mode-a girmək olmur | Reference üçün Windows əl ilə (diskpart + dism + bcdboot) |
| 18 | `fs=nfts` | "file system is incompatible" | Skript (əl ilə yazılan əmrlərdə hərf səhvi olur) |
| 19 | install.esd (Media Creation Tool ISO) | Birbaşa işləmək yavaş/çətin | `dism /Export-Image` ilə yalnız Pro → WIM |
| 20 | Defender WDS-də WIM-i skan edir | Capture/apply yavaşlayır | `E:\Deploy` və `E:\RemoteInstall` istisna |

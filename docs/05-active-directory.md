# 05 — Active Directory mühitində tətbiq

AD olan yerdə **PXE, WinPE, image, Sysprep və Deploy.ps1 eyni qalır.** Dəyişən: PC-nin domain-ə qoşulması,
istifadəçilər və lokal admin şifrəsinin idarəsi.

## 1. Domain-ə qoşulma: üç yol

| Yol | Necə | Üstünlük | Diqqət |
| --- | --- | --- | --- |
| **1. Deploy-dan sonra, PC yerinə qoyulanda** (tövsiyə) | PC istifadəçinin LAN-ına qoşulur → admin ilə `Add-Computer` və ya System Properties | DEPLOY şəbəkəsi DC-yə açılmır, izolyasiya qalır | Bir əl addımı |
| **2. FirstLogon.ps1-də, şifrə soruşaraq** | PC adından sonra domain hesabı soruşulur | Ad dəyişmə + join bir restart-da | DEPLOY → DC portları açılmalıdır |
| **3. unattend.xml (UnattendedJoin, specialize pass)** | Join hesabı unattend-in içində | Tam avtomatik | Join şifrəsi share-də açıq qalır — yalnız çox məhdud hesabla |

Yol 2 üçün FirstLogon.ps1-də PC adı blokundan sonra:
```powershell
$cred = Get-Credential -Message 'Domain join hesabi (mes. DOMAIN\svc_join)'
Add-Computer -DomainName 'corp.example.com' -NewName $pc -OUPath 'OU=Workstations,DC=corp,DC=example,DC=com' -Credential $cred -Force
```
və sonundakı `Rename-Computer` sətrini sil (`-NewName` artıq adı dəyişir). `$CreateLocalUser = $false`.

## 2. Yol 2 və ya 3 seçilsə: DEPLOY → DC firewall

| Port | Xidmət |
| --- | --- |
| 53 TCP/UDP | DNS |
| 88 TCP/UDP | Kerberos |
| 123 UDP | NTP |
| 135 TCP | RPC endpoint mapper |
| 389 TCP/UDP | LDAP |
| 445 TCP | SMB |
| 464 TCP/UDP | Kerberos şifrə |
| 49152–65535 TCP | RPC dinamik |

Yalnız DC-lərə. DEPLOY DHCP-sinin DNS serveri **DC** olmalıdır, yoxsa PC domain-i tapmaz.

## 3. Diqqət olunmalı məqamlar

1. **Join hesabı:** Domain Admin **YOX**. Ayrıca hesab (məs. `svc_join`), yalnız Workstations OU-sunda
   "Create/Delete Computer objects" icazəsi (Delegate Control).
2. **Köhnə computer obyekti:** eyni adlı PC yenidən qurulanda AD-də köhnə obyekt qalır və join xəta verə bilər.
   Ya əvvəlcə obyekti sil / **Reset Account**, ya da join hesabına həmin OU-da obyekti yenidən istifadə hüququ ver.
3. **Ad qaydası:** AD-də ad standartı vacibdir (məs. `MUH-PC-012`, max 15 simvol). FirstLogon-dakı ad yoxlamasını
   (regex) standarta uyğun sıxlaşdır.
4. **OU:** PC birbaşa düzgün OU-ya düşsün (`-OUPath`), yoxsa default `Computers` konteynerinə düşür və GPO-lar tətbiq olunmur.
5. **Lokal istifadəçi lazım deyil:** `$CreateLocalUser = $false`. İstifadəçi AD hesabı ilə daxil olur.
6. **Windows LAPS:** GPO ilə aktivləşir → hər PC-nin lokal admin şifrəsi unikal olur və AD-də saxlanır. unattend-dəki
   ümumi şifrə yalnız ilk qurulum üçündür, LAPS onu dəyişir. Eyni şifrə riski (lateral movement) aradan qalxır.
7. **Saat:** Kerberos 5 dəqiqədən çox fərqi qəbul etmir. Saat qurşağı unattend-dən gəlir, saat domain-ə qoşulandan
   sonra DC-dən sinxronlaşır.
8. **Image nazikləşir:** printerlər (qrupa görə), xəritələnmiş disklər, Defender və BitLocker siyasətləri, MSI proqramlar
   GPO ilə gəlir. Image-də yalnız hər kəsə lazım olanlar qalır.
9. **BitLocker:** aktivləşdirilsə, bərpa açarları GPO ilə AD-yə yazılsın.
10. **WDS rejimi:** Standalone qala bilər. WDS domain-ə qoşulub AD-integrated edilsə: prestaged devices və yalnız
    tanınan PC-lərə PXE icazəsi mümkün olur.
11. **DHCP:**
    - Windows DHCP və WDS **eyni serverdə** → WDS DHCP tabında iki checkbox işarələnir (option 60).
    - Fərqli serverlər, **eyni şəbəkə** → bu kitdəki kimi, ikisi də boş.
    - **Fərqli şəbəkələr** → router-də IP helper / DHCP relay həm DHCP-yə, həm WDS-ə.
12. **Backup agenti:** Veeam VBR Protection Group PC-ləri OU-ya görə avtomatik tapır və agenti quraşdırır.

## 4. Tövsiyə olunan axın (AD ilə)

```
DEPLOY otağı: PXE → Deploy.ps1 → ilk açılış → FirstLogon (yalnız PC adı, lokal user yox)
      ↓
PC istifadəçinin masasına → LAN → Add-Computer (düzgün OU)
      ↓
GPO: LAPS, printerlər, proqramlar, BitLocker → Veeam agent (Protection Group)
```

# [Plan B] LM Studio Core Code Reverse Engineering ve M5 Ultimate Entegrasyonu

**Özet**
Kullanıcının talebi üzerine, `dlopen` (Team ID uyuşmazlığı) ve GGUF model yükleme hatalarını kalıcı olarak çözmek için "B Planı"na geçilmiştir. Orijinal dosyaların üzerine yazmak yerine, LM Studio'nun Javascript çekirdek kodlarına (Webpack bundle) derinlemesine kanca (hook) atılacaktır. Böylece LM Studio'nun bellek içi çalışma mantığı değiştirilecek ve Python süreçlerindeki macOS kütüphane doğrulama (Library Validation) engeli aşılacaktır.

---

### Mevcut Durum Analizi ve Hata Tespiti
1. **MLX `dlopen` Hatası:** Önceki denemede, Python çalıştırılabilir dosyasına ad-hoc imza atılırken macOS'in zorunlu tuttuğu `--options runtime` (Hardened Runtime) parametresi kullanılmamıştır. Bu parametre olmadan, eklenen `disable-library-validation` (kütüphane doğrulamasını devre dışı bırakma) yetkisi macOS tarafından tamamen yok sayılmış ve Python süreci bizim eklediğimiz ANE destekli `libmlx.dylib` dosyasını Team ID uyuşmazlığı nedeniyle reddetmiştir.
2. **GGUF Hatası:** Önceki `crack_lmstudio.js` betiği, orijinal `llama-server`'ı geri yüklemiş, ancak JS kancası sadece `--tensor-split 18,20` argümanını eklemekle yetinmiştir. Orijinal `llama-server` Apple Neural Engine (ANE) desteğine sahip olmadığı için hızlandırma çalışmamış ve model yüklemesi başarısız olmuştur.

---

### Önerilen Değişiklikler ve Mimari (Nasıl Çözeceğiz?)

**1. `crack_lmstudio.js` Gelişmiş Hook Enjeksiyonu**
LM Studio'nun `cp.spawn` fonksiyonuna atılan kanca (hook) akıllandırılacaktır:
- **GGUF (llama-server) için Yönlendirme:** 
  LM Studio `llama-server`'ı başlatmak istediğinde, kanca araya girerek çalıştırılacak komutun yolunu `~/.cache/lm-studio/bin/llama-server.ane` olarak değiştirecek ve `--tensor-split 18,20` argümanını ekleyecektir. Bu sayede orijinal dosyaya hiç dokunmadan kendi ANE sunucumuzu çalıştırabileceğiz.
- **MLX (python) için Ortam Değişkeni (Env) Enjeksiyonu:**
  LM Studio `python`'u başlatmak istediğinde, kanca araya girerek Node.js ortam değişkenlerine (env) `DYLD_LIBRARY_PATH=~/.lmstudio/extensions/m5_mlx` yolunu ekleyecektir. Bu sayede Python, orijinal kütüphaneyi bozmadan doğrudan bizim ANE destekli `libmlx.dylib` kütüphanemizi yükleyecektir.

**2. Payload'ların Otomatik Dağıtımı**
`crack_lmstudio.js` betiği, M5 Ultimate uygulaması içindeki payload'ları (özel `llama-server.ane` ve `libmlx.dylib`) otomatik olarak `~/.cache/lm-studio/bin/` ve `~/.lmstudio/extensions/m5_mlx/` dizinlerine kopyalayacaktır.

**3. Python Library Validation (Kütüphane Doğrulaması) Kesin Çözümü**
`crack_lmstudio.js` betiğine yeni bir fonksiyon eklenecektir. Bu fonksiyon, LM Studio'nun indirdiği tüm `python3.11` çalıştırılabilir dosyalarını bulacak ve şu komutla yeniden imzalayacaktır:
```bash
codesign --force --options runtime --sign - --entitlements /tmp/m5_ents.xml <python_yolu>
```
**Kritik Nokta:** `--options runtime` parametresi eklendiği için, macOS artık `m5_ents.xml` içindeki kütüphane doğrulamasını devre dışı bırakma yetkisini tanıyacak ve `dlopen` Team ID hatası bir daha yaşanmayacaktır.

**4. M5 Ultimate Swift Uygulaması ve Build Süreci**
- `App.swift` aynen kalacak (zaten yönetici haklarıyla `crack_lmstudio.js` betiğini çalıştırıyor).
- `build.sh` temizlenecek; artık `inject_lmstudio.sh` betiğine ihtiyaç kalmadığı için bu dosya projeden çıkarılacak.

---

### Gerekli Dosya Düzenlemeleri (Uygulama Adımları)

- **Düzenlenecek Dosya:** `M5UltimateApp/crack_lmstudio.js`
  - JS Hook payload'ı GGUF komut yönlendirmesi ve MLX `DYLD_LIBRARY_PATH` enjeksiyonu yapacak şekilde güncellenecek.
  - Payload dosyalarını kopyalama mantığı eklenecek.
  - `codesign --options runtime` kullanarak Python imzalama mantığı eklenecek.

- **Düzenlenecek Dosya:** `M5UltimateApp/build.sh`
  - Eski `inject_lmstudio.sh` ve gereksiz payload derleme adımları temizlenecek. Sadece Swift derlemesi, `crack_lmstudio.js` kopyalaması ve `llama-server.ane` / `libmlx.dylib` kopyalaması kalacak.

---

### Doğrulama ve Test
1. Terminalde `./build.sh` çalıştırılarak yeni uygulamanın derlenmesi.
2. `M5 Ultimate` uygulamasının açılıp "Inject to LM Studio" butonuna basılması (Yönetici şifresi istenecek).
3. LM Studio'nun tamamen kapatılıp yeniden açılması.
4. GGUF modeli yüklenerek Activity Monitor'den `llama-server.ane`'nin çalışıp çalışmadığının kontrol edilmesi.
5. Apple MLX modeli yüklenerek `dlopen` hatasının giderildiğinin ve modelin başarıyla yüklendiğinin doğrulanması.

# M5 Ultimate: Native LM Studio Engine Integration Plan

Bu belge, M5 Pro (Apple Silicon) için geliştirilen donanıma özel (Zero-Copy & Heterojen Pipelining) LLM motorlarının LM Studio'ya entegrasyon sürecindeki mevcut durumu, karşılaşılan sorunları ve bir sonraki sohbet için yol haritasını içermektedir.

## 1. Mevcut Durum ve Mimari Başarılar
Projenin "App/Dashboard" aşaması tamamlanmış ve `M5 Ultimate/` klasörüne taşınmıştır. Eski çöpler ve hook denemeleri `OLD/` klasörüne arşivlenmiştir. Şu anki odak noktamız `M5 Engines/` klasörüdür.

### Geliştirilen "God-Mode" Teknolojileri:
*   **m5_godmode_interceptor.mm (Objective-C++):** 
    *   **Zero-Copy IOSurface:** Metal API (`newBufferWithLength`) kancalanarak (hook), RAM-to-RAM veri kopyalamasını engellemek için bellek tahsisleri paylaşımlı `IOSurface` üzerinden yapılmaktadır.
    *   **Layer-Based Smart Dispatch:** Model katmanlarının yapısı (Threadgroup topology) analiz edilerek K-V Cache gerektiren "Attention" katmanları **20 çekirdekli GPU'ya**, yüksek TOPS gerektiren "FFN" katmanları ise **ANE ve AMX'e (CPU)** asenkron olarak (pipeline) yönlendirilmektedir.
*   **llama-proxy.cpp:** Orijinal LM Studio motorlarını (llama-server vb.) sarmalayan, ortam değişkeni üzerinden (`DYLD_INSERT_LIBRARIES`) bizim Interceptor kütüphanemizi sisteme zorla enjekte eden başlatıcı.

## 2. Karşılaşılan Sorun (LM Studio 0.4.21 Görünürlük Sorunu)
Yeni motorları LM Studio arayüzünde seçilebilir hale getirmek için `~/.cache/lm-studio/extensions/backends` altına `m5-llama.cpp` ve `m5-mlx` adında özel eklenti klasörleri oluşturduk. 
*   **Sorun:** LM Studio 0.4.21, eklentileri (extensions) doğrulamak için son derece katı bir filtreleme (ve muhtemelen merkezi bir `extensions.json` kayıt defteri) kullanmaktadır. `backend-manifest.json` ve `display-data.json` dosyalarını doğru yapılandırmamıza ve MLX manifest'ine `"targets": ["nax"]` (Neural Accelerator) eklememize rağmen, özel motorlarımız (Özellikle GGUF/llama.cpp) arayüzde görünmemektedir.
*   **Neden:** Yeni LM Studio sürümleri, sadece manuel klasör kopyalamayı kabul etmeyip, eklentilerin `.lmsx` formatında olmasını veya `lms` CLI üzerinden merkezi veritabanına kayıt edilmesini zorunlu kılıyor olabilir.

## 3. Yeni Sohbet İçin Strateji ve Yol Haritası (Next Steps)

Bir sonraki sohbet oturumunda bu belgeden yola çıkarak aşağıdaki 2 stratejiden biri uygulanacaktır:

### Strateji A: Resmi Motoru "Sessizce" Ele Geçirmek (Hijack)
LM Studio'nun eklenti doğrulama sistemiyle savaşmak yerine, halihazırda listelenen ve çalışan resmi motoru kullanacağız.
1. `~/.cache/lm-studio/extensions/backends/llama.cpp-mac-arm64...` (Resmi ve kurulu olan klasör) içine girilecek.
2. Klasör veya manifest isimleri **ASLA** değiştirilmeyecek (Böylece LM Studio UI'da görünmeye devam edecek).
3. Sadece orijinal `llama-server` dosyası `llama-server.orig` yapılacak.
4. Bizim `llama-proxy` (ve `m5_godmode_interceptor.dylib`) o klasöre atılacak ve adı `llama-server` yapılacak.
5. Kullanıcı LM Studio'dan normal `Metal llama.cpp` motorunu seçtiğinde, aslında arka planda bizim Zero-Copy God-Mode proxy'miz uyanacak.

### Strateji B: LM Studio Registry (Kayıt Defteri) Analizi
Eğer mutlaka UI'da "M5 llama.cpp" yazmasını istiyorsak:
1. LM Studio'nun eklentileri kaydettiği veritabanı bulunacak (Örn: `~/.lmstudio/extensions.json`, `~/.cache/lm-studio/state.json` veya LevelDB/SQLite dosyaları).
2. Bizim `m5-llama.cpp` klasörümüz bu kayıt defterine manuel olarak eklenecek.

### Ek Görev: MLX Motoru ve NAX (Neural Accelerator)
Kullanıcı, MLX motorunun kesinlikle M5 Neural Accelerator (ANE) desteği ile çalışmasını istemektedir. `backend-manifest.json` içine `"nax"` etiketi eklenmiştir ancak bunun MLX Python süreçlerinde de (`DYLD_LIBRARY_PATH` ile) doğru yüklendiği ve `libmetal_interceptor`'ın MLX komut kuyruklarını da yakaladığı doğrulanacaktır.

---
**Özet:** Mimarimiz ve C++ kodlarımız hazır ve mükemmel durumda. Tek engel LM Studio 0.4.21'in katı arayüz filtrelemesi. Yeni sohbette Strateji A (Sessiz Hijack) uygulanarak bu sorun 5 dakika içinde kökten çözülebilir.

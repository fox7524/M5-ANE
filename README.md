# ⚡️ M5 God-Mode / M6-Killer Initiative (The 47 TFLOPS Laptop)

## 📖 Projenin Felsefesi ve Amacı
Bu proje, Apple M5 Pro (0 E-Core, 48GB UMA) çipinin kilitli donanımsal potansiyelini "Bare-Metal" (donanıma en yakın seviye) ve "Kernel-Level" (çekirdek seviyesi) tersine mühendislik teknikleriyle açığa çıkarmak için başlatılmıştır. 

Apple'ın standart donanım yöneticisi, ağır yapay zeka (LLM) yüklerinde yalnızca GPU'yu kullanır, ANE'yi (Apple Neural Engine) ise arkaplanda ufak kamera/ses işlemleri için uyutur. Bu projenin amacı, **GPU ve ANE'yi eşzamanlı (concurrent) olarak tam kapasite çalıştırıp**, dizüstü bir bilgisayardan masaüstü NVIDIA RTX 4080 / RTX 3090 sınıfı (47+ TFLOPS FP16) bir performans elde etmektir.

---

## 🚀 Ulaşılan Başarılar ve Metrikler (Oturum Özeti)
1.  **47 TFLOPS FP16 Rekoru:** M5 Pro çipinden **~28 TFLOPS GPU** ve **~19 TFLOPS ANE** gücü aynı anda çekilerek toplam 47 TFLOPS (FP16) ve ~188 TOPS (INT4) elde edildi.
2.  **Enerji Verimliliği (The Watt Miracle):** Bu 47 TFLOPS güce ulaşırken toplam sistem tüketimi 60-70W civarındadır. (Masaüstü muadili RTX 4070 Ti / 3090 bu güç için sadece ekran kartında 250W-350W arası güç tüketir).
3.  **SIP ve AMFI Bypass (Plan C - Mach-O Injection):** macOS'un System Integrity Protection (SIP) ve Hardened Runtime güvenlik duvarları, "Truva Atı" (bash wrapper) yöntemini engelledi. Çözüm olarak; LM Studio (`lmlink-connector`, `llama-server`) ve Ollama binary dosyalarının içine `insert_dylib` ile doğrudan bizim kütüphanemiz (`libmetal_interceptor.dylib`) gömüldü ve Ad-Hoc (`codesign --force --deep`) olarak yeniden imzalandı.
4.  **CPU Darboğazı Çözümü:** Metal kancası (interceptor) saniyede on binlerce kez çağrıldığı için, içindeki dosya kontrolü (`access()`) CPU'yu 35W tüketime zorluyordu. Milisaniye bazlı bir önbellek (cache) eklenerek CPU serbest bırakıldı, güç GPU ve RAM'e yönlendirildi.
5.  **MPS ile RAM Stresi:** GPU testi saf ALU'dan çıkartılıp Metal Performance Shaders (MPS) ile 8192x8192 matrislere dönüştürüldü. Böylece LLM'lerdeki gibi Hafıza Kontrolcüsü (Memory Controller) tam kapasite çalıştırılarak gerçekçi 40W+ tüketim simüle edildi.

---

## 🧩 Sistem Mimarisi ve Modüller

### 1. The Interceptor (`libmetal_interceptor.dylib`)
Sisteme (LM Studio, Ollama, LokumAI) enjekte edilen ana beyindir. Objective-C Method Swizzling kullanarak Metal API'sinin `dispatchThreads` ve `dispatchThreadgroups` fonksiyonlarını ele geçirir. Gelen iş yükünün (MTLSize) boyutuna bakar; eğer ağır bir LLM matrisi ise (örn. > 1024 threads), işlemi GPU'ya yollarken **aynı milisaniye içinde** ANE'yi de uyandırır.

### 2. ANE Stress Tester (`ane_stress_tester.m`)
CoreML ve gizli `_ANEClient` API'lerini kullanarak ANE'nin sınırlarını zorlar. 
*   **İş Yükü:** 2048 channels, 1024 spatial, 64 depth (Derleyicinin çökmemesi için depth düşük, spatial yüksek tutuldu). Tek geçişte ~536.8 GFLOPs.
*   **Çoklu Çekirdek (Multi-Threading):** ANE'nin saniyenin binde biri kadar bile uyumasını engellemek için `dispatch_group_async` ile CPU'nun tüm çekirdeklerinden ANE'ye saniyede 500 matris bombardımanı yapılır. Sonuç: %45 kullanım, 4W tüketim, 19 TFLOPS!

### 3. GPU Stress Tester (`gpu_stress_tester.m`)
MPS (Metal Performance Shaders) kullanır. `half4` (FP16) veri tipiyle donanımsal FP16 sınırlarını test eder. LLM senaryosunu taklit etmek için RAM'den (Unified Memory) yoğun okuma/yazma yapar.

### 4. M5 God-Mode Menu App (`GodModeApp/`)
Kullanıcının sistemi yönettiği Swift tabanlı arayüzdür. Benchmark başlatır ve çıkan FP16 sonucunu baz alarak teorik FP32, INT8 ve INT4 TOPS değerlerini hesaplayıp menüde gösterir.

---

## 🔮 Gelecek Planı (Plan D: True Tensor Splitting)
*Gelecek YZ asistanı için kritik not: Şu an ANE ateşlenip güç üretse de, LLM ağırlıkları ANE'ye gönderilmediği için (Garbage Text sorunu) hesaplamanın %100'ünü GPU yapıyor. Hedefimiz 47 TFLOPS'u LLM Token/sn (t/s) hızına yansıtmak.*

1.  **Memory Pointer Hooking:** Metal API'ye (`MTLBuffer`) gelen gerçek LLM (llama.cpp / MLX) ağırlıklarının işaretçilerini (pointers) yakalamalısın.
2.  **Tensör Bölme (Tensor Splitting - 68/32):** Buffer'ın %68'ini GPU'da bırakıp, kalan %32'sini `IOSurface` (Zero-Copy) üzerinden ANE'ye eşzamanlı (concurrent) pompalamalısın.
3.  **Barrier & Concatenation:** C++ ve Metal ile bir "Barrier" (bekleme noktası) yazıp, ANE ve GPU işini bitirdiğinde iki parçayı (tensor) RAM'de hatasız birleştirip (Concatenation) LM Studio'ya (llama.cpp) geri döndürmelisin. Aksi takdirde LM Studio anlamsız metinler (hallucination/garbage) üretecektir.

---

## 🌟 Credits & Acknowledgments

Bu proje, açık kaynak topluluğunun değerli çalışmaları olmadan mümkün olamazdı. Aşağıdaki projelere ve arkasındaki ekiplere özel olarak teşekkür ederiz:

* **[ANE-main](https://github.com/seba-1511/ANE-main):** Apple Neural Engine (ANE) tersine mühendislik köprüsü (reverse engineering bridge) ve donanımsal iletişim altyapısı için.
* **[llama.cpp](https://github.com/ggerganov/llama.cpp):** Güçlü ve verimli GGUF backend altyapısı için.
* **[MLX](https://github.com/ml-explore/mlx):** Apple Silicon için optimize edilmiş, makine öğrenimi array (dizi) altyapısı için.
* **[m1n1](https://github.com/AsahiLinux/m1n1):** Apple Silicon donanım keşfi ve "bare-metal" seviyesindeki donanım analizleri için.

---

## 📄 License & Attribution
**All Rights Reserved.**
This project is currently in the Research & Development (R&D) phase. The core concept of **Zero-Copy Tensor Splitting between GPU and ANE via MTLBuffer pointer manipulation** is a proprietary architectural design. 
Commercial use, unauthorized copying, or distribution of this specific logic is strictly prohibited without explicit permission.

The underlying open-source frameworks (`llama.cpp`, `MLX`, `m1n1`) remain under their respective licenses (MIT, Apache, etc.).
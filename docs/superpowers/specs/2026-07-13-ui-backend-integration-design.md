# Ultimate LLM Studio - UI ve Backend Entegrasyonu (C++ Llama.cpp) Tasarım Dokümanı

## 1. Genel Bakış
Bu doküman, Ultimate LLM Studio'nun (macOS SwiftUI) mevcut statik arayüzünün, gerçek Llama.cpp C++ motoruna doğrudan (bellek içi) entegre edilmesini açıklar. Bu sayede uygulama, dış bir sunucuya (HTTP) ihtiyaç duymadan doğrudan C++ kütüphanesi üzerinden yapay zeka çıkarımı yapacaktır.

## 2. Mimari ve Bileşenler

### 2.1. Llama.cpp C++ Çekirdeği
- `llama.cpp` projesi (kaynak kod olarak veya statik kütüphane olarak) projeye dahil edilecek.
- Metal hızlandırması (Apple Silicon GPU) aktif olarak derlenecek (`GGML_USE_METAL`).

### 2.2. Objective-C++ Köprüsü (`LLMEngine.mm` & `LLMEngine.h`)
Swift, saf C++ sınıflarını doğrudan kullanamaz (Swift 5.9 C++ interop var fakat C API'leri için ObjC++ daha yaygındır). Bu nedenle bir ObjC++ sarmalayıcı (wrapper) yazılacaktır.
- **Sorumluluklar:**
  - `llama_backend_init` ile motoru başlatmak.
  - `llama_load_model_from_file` ile modeli belleğe almak (Metal offload ayarlarını SwiftUI'dan alarak).
  - Kullanıcı prompt'unu token'lara ayırmak (`llama_tokenize`).
  - Çıkarım döngüsünü (inference loop) başlatmak ve her yeni token üretildiğinde Swift'e bir blok (closure) veya delegasyon (delegate) üzerinden veri göndermek.

### 2.3. Swift Backend Yöneticisi (`BackendManager.swift` Güncellemesi)
- Mevcut `BackendManager.swift` dosyası, `LLMEngine` objesini sarmalayacak şekilde güncellenecek.
- `startLLMServer` yerine `loadModel(path:)` kullanılacak.
- `generateText(prompt: onUpdate:)` şeklinde asenkron bir streaming fonksiyonu eklenecek.

### 2.4. Model Tarama Sistemi (`ModelScanner.swift`)
- Kullanıcının `~/.cache/lm-studio/models` klasöründeki tüm alt klasörleri tarayarak `.gguf` uzantılı dosyaları bulacak bir Swift utility sınıfı.
- Bulunan modeller `ContentView`'daki üst açılır menüye (Dropdown) bağlanacak.

## 3. Veri Akışı (Data Flow)
1. **Model Yükleme:** Kullanıcı üst menüden bir model seçer ve "Load" butonuna basar.
2. SwiftUI -> `BackendManager` -> `LLMEngine` -> `llama.cpp`.
3. `llama.cpp` modeli belleğe yükler (Sağ paneldeki GPU offload slider'ındaki değeri `n_gpu_layers` olarak kullanır).
4. **Sohbet:** Kullanıcı mesaj yazar ve Gönder'e basar.
5. `ContentView` mesajı UI'a ekler ve `BackendManager.generateText`'i çağırır.
6. C++ döngüsü başlar. Her token üretildiğinde Swift closure'u tetiklenir.
7. SwiftUI anlık olarak gelen token'ları ekrandaki mesaja ekler (Streaming).

## 4. Test Stratejisi (TDD)
- `ModelScannerTests`: Klasör tarama mantığının testi.
- `LLMEngineTests`: C++ köprüsünün modeli başarıyla yükleyip yükleyemediğinin testi (Örnek ufak bir model ile).

## 5. Çözülmesi Gereken Zorluklar
- **Threading:** C++ çıkarım döngüsü ana iş parçacığını (Main Thread) bloklamamalıdır. Çıkarım işlemleri GCD (`DispatchQueue.global()`) üzerinde yapılmalı, UI güncellemeleri `DispatchQueue.main.async` ile yapılmalıdır.
- **Memory Management:** ObjC++ köprüsü kapatıldığında (`llama_free`), bellek sızıntılarını önlemek için pointer'ların doğru yönetilmesi.

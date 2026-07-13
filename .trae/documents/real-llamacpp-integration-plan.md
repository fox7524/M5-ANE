# Ultimate LLM Studio - Gerçek Llama.cpp Entegrasyon Planı

## 1. Mevcut Durum Analizi
- UI, Swift `BackendManager` ve ObjC++ `LLMEngine` stub'ı tamamlandı.
- Llama.cpp derlenmiş `.dylib` dosyaları `/Users/fox/Documents/PROJECTS/M5/llama.cpp/build/bin/` dizininde bulunuyor (`libllama.dylib`, `libggml.dylib`, `libggml-metal.dylib`).
- `LLMEngine.mm` şu anda sahte (mock) veri dönüyor. Gerçek `llama.cpp` C API'si ile değiştirilmesi gerekiyor.

## 2. Önerilen Değişiklikler ve Adımlar

### Adım 1: Xcode Proje Konfigürasyonunu (project.yml) Güncelleme
- **Header Search Paths (HEADER_SEARCH_PATHS):**
  - `../llama.cpp/include`
  - `../llama.cpp/ggml/include`
- **Library Search Paths (LIBRARY_SEARCH_PATHS):**
  - `../llama.cpp/build/bin`
- **Linked Frameworks/Libraries:**
  - `llama`
  - `ggml`
  - `ggml-metal`
  - `ggml-base`
  - `ggml-cpu`
  - `Accelerate.framework`
  - `Metal.framework`
  - `MetalPerformanceShaders.framework`
  - `CoreGraphics.framework`

### Adım 2: LLMEngine.mm'in Gerçek llama.cpp C API'si ile Güncellenmesi
- `#include "llama.h"` eklenecek.
- `llama_backend_init()` çağrısı ile motor başlatılacak.
- `loadModelAtPath:gpuLayers:` fonksiyonunda `llama_model_default_params()` ve `llama_load_model_from_file()` kullanılarak model belleğe alınacak. Ardından `llama_new_context_with_model()` ile bir inference context yaratılacak.
- `generateResponseForPrompt:onToken:onComplete:` fonksiyonunda prompt `llama_tokenize()` ile token'lara çevrilecek, ardından `llama_decode()` ile inference döngüsü başlatılacak. Her yeni token `llama_token_to_piece()` ile string'e çevrilip `onToken` bloğu üzerinden SwiftUI'a aktarılacak. Döngü `llama_token_is_eog()` görülene kadar devam edecek.
- `unloadModel` içerisinde `llama_free()` ve `llama_free_model()` çağrılarak bellek temizlenecek.

### Adım 3: xcodegen ile Projenin Yeniden Üretilmesi
- `xcodegen` çalıştırılarak yeni kütüphane bağlantılarının Xcode projesine yansıması sağlanacak.

## 3. Kararlar ve Varsayımlar
- Dışarıdaki (build/bin altındaki) `.dylib` dosyalarına bağımlılık ekleneceği için `rpath` ayarlarının doğru yapılması (örn. `@executable_path/../Frameworks` veya doğrudan `../llama.cpp/build/bin`) uygulamanın çökmemesi için önemlidir. Ancak şimdilik yerel geliştirme ortamı olduğu için `LIBRARY_SEARCH_PATHS` ile idare edeceğiz, rpath ekleyeceğiz.
- Basit bir sampling stratejisi (örn. greedy veya basit temperature) kullanılacak.

## 4. Doğrulama (Verification)
- `xcodebuild clean build` ile başarılı derleme teyit edilecek.
- Uygulama açılıp model yüklendiğinde, Terminal'de llama.cpp'nin donanım tespiti loglarının çıkması beklenecek.
- Prompt gönderildiğinde gerçek modelden anlamlı bir yanıt akışı (streaming) alınacak.

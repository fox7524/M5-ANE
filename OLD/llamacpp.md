# 🚀 Llama.cpp Native ANE Entegrasyon Planı (Plan E)

## 🔍 Mevcut Sorun (Neden Kanca İşe Yaramadı?)
Dışarıdan `.dylib` gömerek yaptığımız "Black-Box" kancalama yöntemi, llama.cpp'nin `mmap` (Memory Mapped Files) özelliğine takıldı. Llama.cpp, GGUF modellerindeki ağırlıkları geleneksel `MTLBuffer` tahsisi yerine, diski doğrudan belleğe haritalayarak (Device Address pointer'ları ile) Metal'e iletir. Bu yüzden bizim `setBuffer:offset:atIndex:` kancamız bu transferleri göremedi ve ANE'yi (Apple Neural Engine) tetikleyemedi.

## 🎯 Hedef
Dışarıdan müdahale etmek yerine, ANE köprümüzü doğrudan llama.cpp'nin Metal arka ucuna (`ggml-metal.m`) "Native" olarak entegre etmek. Bu sayede `mmap` kullanılsa bile doğrudan C++ seviyesindeki RAM pointer'larına ulaşıp, Tensör Bölme (%68 GPU / %32 ANE) işlemini milisaniyelik gecikme olmadan uygulayacağız.

## 🛠️ Adım Adım Entegrasyon Rehberi

### Adım 1: ANE Bridge'in Llama.cpp'ye Eklenmesi
*   Daha önce yazdığımız `ane_bridge.h` ve `ane_bridge.m` dosyalarını, klonladığımız `llama.cpp/ggml/src/` dizinine kopyalayacağız.
*   `CMakeLists.txt` ve `Makefile` dosyalarını güncelleyerek `ane_bridge.m` dosyasının, Apple Neural Engine framework'leri (`-framework AppleNeuralEngine -framework IOSurface`) ile birlikte derlenmesini sağlayacağız.

### Adım 2: ggml-metal.m Modifikasyonu (Matris Çarpımı)
*   **Hedef Fonksiyon:** `ggml-metal.m` içerisindeki matris çarpım operasyonlarını yürüten compute kernel çağrılarını (örn. `ggml_metal_mul_mat` veya `[encoder dispatchThreadgroups...]` çağrılarının yapıldığı döngüleri) bulacağız.
*   **Veri Yakalama:** `ggml_tensor` yapıları (struct) içindeki `src0->data` ve `src1->data` (gerçek donanım pointer'ları) üzerinden matrisin RAM adreslerini alacağız.

### Adım 3: Native Tensor Splitting (Doğal Bölme)
```objc
// Örnek Taslak Kod Mantığı
size_t total_size = ggml_nbytes(src0);
size_t offset_68 = total_size * 0.68;
size_t size_32 = total_size - offset_68;

// 1. ANE Bariyerini Başlat
dispatch_group_enter(ane_barrier);

// 2. ANE'ye %32'lik kısmı asenkron yolla (Zero-Copy)
dispatch_async(dispatch_get_global_queue(0, 0), ^{
    run_ane_with_buffer(src0->data, offset_68, size_32);
    dispatch_group_leave(ane_barrier);
});

// 3. GPU'nun Grid Boyutunu %68'e Düşür
MTLSize truncatedGrid = MTLSizeMake(originalGrid.width * 0.68, originalGrid.height, originalGrid.depth);
[encoder dispatchThreadgroups:truncatedGrid threadsPerThreadgroup:tptg];

// 4. Bariyeri Bekle ve Sonuçları Birleştir
dispatch_group_wait(ane_barrier, DISPATCH_TIME_FOREVER);
```

### Adım 4: Derleme ve Dağıtım
*   Llama.cpp'yi baştan derleyeceğiz: `make LLAMA_METAL=1` veya `cmake` kullanarak kendi `llama-server` binary'mizi üreteceğiz.
*   Ürettiğimiz bu "M5 God-Mode" özellikli `llama-server`'ı, LM Studio'nun arka planındaki orijinal motorla yer değiştireceğiz.

## 📈 Beklenen Sonuç
Llama.cpp, mmap kullanıp kullanmadığına bakılmaksızın tüm ağır matris çarpımlarını eşzamanlı olarak hem GPU hem de ANE üzerinde işleyecek. TFLOPS kapasitemiz tam anlamıyla token üretim hızına (Token/s) yansıyacak.
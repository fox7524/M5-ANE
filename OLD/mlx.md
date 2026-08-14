# 🍏 MLX (LokumAI) Native ANE Entegrasyon Planı

## 🔍 Mevcut Sorun (Neden Kanca İşe Yaramadı?)
MLX, Apple'ın modern ve dinamik makine öğrenimi framework'üdür. `libmetal_interceptor.dylib` ile yazdığımız kanca, matrislerin sadece Index 0 veya 1 üzerinden gönderileceğini varsayıyordu. Oysa MLX, compute shader'larına (kernel) veri yollarken son derece dinamik indeksler (Index 4, 5 vb.) kullanır. Ayrıca küçük konfigürasyon tensörleri için `setBytes:length:atIndex:` metodunu tercih eder. Bu mimari farklılıklar, MLX'in matrislerinin kancamızın altından geçmesine sebep oldu.

## 🎯 Hedef
Apple'ın kendi `mlx` kütüphanesini (LokumAI altyapısı) "Native" olarak modifiye etmek. ANE köprümüzü, MLX'in kalbindeki Metal matris çarpım (GEMM) altyapısına C++ seviyesinde gömeceğiz. Böylece Index takibi yapmak zorunda kalmadan, MLX ne zaman bir `mlx::core::array` oluştursa ve çarpsa, biz doğrudan RAM pointer'ını alıp %32'sini ANE'ye paslayacağız.

## 🛠️ Adım Adım Entegrasyon Rehberi

### Adım 1: ANE Bridge'in MLX'e Eklenmesi
*   `ane_bridge.h` ve `ane_bridge.m` dosyalarını klonladığımız `mlx/mlx/backend/metal/` dizinine yerleştireceğiz.
*   MLX'in `CMakeLists.txt` dosyasına müdahale edip, Metal backend derlenirken Apple Neural Engine ve IOSurface kütüphanelerinin (framework) linklenmesini sağlayacağız.

### Adım 2: matmul.cpp ve metal.cpp Modifikasyonu
*   **Hedef Dosyalar:** MLX'in matris çarpım mantığı `mlx/backend/metal/matmul.cpp` ve genel komut kuyruğu mantığı `mlx/backend/metal/metal.cpp` dosyalarında yatar.
*   **Veri Yakalama:** `mlx::core::array` objelerinin içindeki `.data<void>()` veya `buffer()` metodlarını kullanarak ham RAM adreslerini (raw pointers) çekeceğiz.

### Adım 3: Native Tensor Splitting (Doğal Bölme)
```cpp
// Örnek Taslak Kod Mantığı (C++ / Obj-C Karışımı)

// MLX matmul kernel'i çalışmadan hemen önce:
size_t total_size = a.size() * a.itemsize();
size_t offset_68 = total_size * 0.68;
size_t size_32 = total_size - offset_68;

// ANE Asenkron Çağrısı (IOSurface Zero-Copy)
dispatch_group_enter(ane_barrier);
dispatch_async(dispatch_get_global_queue(0, 0), ^{
    run_ane_with_buffer(a.data<void>(), offset_68, size_32);
    dispatch_group_leave(ane_barrier);
});

// GPU Yükünü Kısma
MTLSize grid = get_matmul_grid(...);
MTLSize truncated_grid = MTLSizeMake(grid.width * 0.68, grid.height, grid.depth);
encoder->dispatchThreads(truncated_grid, group_size);

// Sonuçları Bekle
dispatch_group_wait(ane_barrier, DISPATCH_TIME_FOREVER);
```

### Adım 4: Derleme ve Dağıtım (Python Node / Dylib)
*   Değiştirdiğimiz MLX kaynak kodunu derleyerek kendi `libmlx.dylib` dosyamızı üreteceğiz (`pip install .` veya `cmake` ile).
*   Ürettiğimiz bu kütüphaneyi, LM Studio'nun MLX backend klasöründeki veya sistem Python'undaki orijinal MLX kütüphanesiyle değiştireceğiz.

## 📈 Beklenen Sonuç
MLX tabanlı tüm modeller (LokumAI projeleri, Qwen, Llama vb.), matris işlemlerini saniye sektirmeden Apple Silicon'ın hem GPU hem de ANE (Neural Engine) çekirdeklerine paylaştıracak. MLX'in dinamik Index mantığı artık bir engel olmaktan çıkacak ve saf 47 TFLOPS (FP16) gücüne donanımsal olarak ulaşılacak.
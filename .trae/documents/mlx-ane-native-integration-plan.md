# MLX - ANE (Apple Neural Engine) Native Entegrasyon Planı

## Özet
Kullanıcının "Seçenek B" olarak belirlediği strateji doğrultusunda, MLX kütüphanesinin (Apple'ın makine öğrenimi framework'ü) Metal arka ucuna (backend) ANE Tensor Splitting mantığı "Native" (doğrudan kaynak kod seviyesinde) entegre edilecektir. Dışarıdan `.dylib` kancalamanın yarattığı güvenlik ve kararlılık (Hardened Runtime, SIP) sorunlarını aşmak için, MLX'in C++ matris çarpım operasyonlarında (`matmul.cpp`) `dispatch_threadgroups` çağrıları özelleştirilmiş `dispatch_with_ane` fonksiyonu ile değiştirilecektir.

## Mevcut Durum Analizi
- Proje dizininde `/Users/fox/Documents/PROJECTS/M5/mlx` klasörü altında MLX kaynak kodu bulunmaktadır.
- `ane_bridge.m` ve `ane_bridge.h` dosyaları halihazırda `mlx/mlx/backend/metal/` klasörüne eklenmiş ve `CMakeLists.txt` içerisine derleme adımı olarak dahil edilmiştir.
- `mlx/mlx/backend/metal/matmul.cpp` dosyasında `dispatch_with_ane` adında bir taslak fonksiyon tanımlanmış, ancak bu fonksiyon yalnızca `BlockMaskedMM::eval_gpu` fonksiyonunun en sonunda test amaçlı kullanılmıştır. MLX'in ana yükünü çeken asıl GEMM ve GEMV fonksiyonları hala standart `compute_encoder.dispatch_threadgroups()` kullanmaktadır.

## Önerilen Değişiklikler

### 1. `matmul.cpp` İçerisindeki Kapsamlı Entegrasyon
- **Dosya:** `mlx/mlx/backend/metal/matmul.cpp`
- **Ne Yapılacak:** Ağır matris çarpımı yapan (Compute-intensive) tüm Metal dispatch çağrıları bulunup, ANE köprüsüne (Tensor Splitting) yönlendirilecektir.
- **Nasıl Yapılacak:**
  Aşağıdaki fonksiyonların içerisindeki `compute_encoder.dispatch_threadgroups(grid_dims, group_dims);` satırları `dispatch_with_ane(compute_encoder, grid_dims, group_dims, b);` (b, duruma göre matris veya out buffer olabilir, b parametresinin erişilebilir olmadığı durumlarda alternatif bir buffer geçirilecektir) ile değiştirilecektir:
  - `steel_matmul_regular_axpby_nax`
  - `steel_matmul_regular_axpby`
  - `steel_gemm_splitk_axpby` (ve accum dispatch'leri)
  - `steel_gemm_splitk_axpby_nax`
  - `gemv_axbpy`
  - `gather_mm_rhs` ve `gather_mm_rhs_nax`
  - `gather_mv`
  - `gather_mm`
  - `segmented_mm`

### 2. Derleme (Build) Scriptinin Güncellenmesi
- **Dosya:** `M5UltimateApp/build.sh` (veya MLX build süreci)
- **Ne Yapılacak:** Değiştirilen MLX kodunun derlenip, üretilen `libmlx.dylib` ve `mlx.metallib` dosyalarının `M5UltimateApp/payloads/mlx/` içerisine kopyalanması sağlanacaktır. Gerekirse CMake komutlarıyla temiz bir build süreci oluşturulacaktır.

## Varsayımlar ve Kararlar
- **Mock ANE Mantığı:** Mevcut `ane_bridge.m` içerisindeki `run_ane_with_buffer` fonksiyonu, şu aşamada bir Proof-of-Concept (PoC) olarak çalışmaktadır. Grid boyutunu `%68`'e düşürüp geri kalan veriyi ANE'ye simüle edilmiş bir şekilde kopyalamaktadır. Bu mimariyi tüm MLX fonksiyonlarına yayarak sistemin çökmeden çalıştığı doğrulanacaktır.
- **Metal Encoder Senkronizasyonu:** ANE çağrısı asenkron yapılmaktadır ancak `dispatch_with_ane` içinde çağrıldığında Metal GPU kuyruğuna paralel olarak Host (CPU) üzerinde çalışacaktır. ANE'nin dönüşünü beklemek için `dispatch_group_wait` eklenebilir, ancak MVP aşamasında performansı kesmemek adına mevcut hali korunacaktır.

## Doğrulama Adımları (Verification)
1. `mlx` dizininde C++ kodu değiştirildikten sonra MLX framework'ü baştan derlenecektir.
2. Derleme sırasında hiçbir `dispatch_with_ane` scope veya type hatası alınmamalıdır.
3. `M5UltimateApp/build.sh` çalıştırılarak yeni üretilen MLX dylib dosyaları App Bundle içerisine kopyalanacaktır.
4. LM Studio (MLX backend) veya lokal bir python scripti ile bir model (örneğin Qwen veya Llama) başlatılacak.
5. Çıkarım (Inference) sırasında `ane_bridge.m` içerisindeki `fprintf` logları (örn. `[!] M5 God-Mode: IOSurface created...`) sistem loglarına düşecek ve donanım limitleri başarıyla bölünmüş olacaktır.

# M5 Ultimate Hybrid Engine (CoreML + Metal) Entegrasyon Planı

## 1. Özet ve Hedef
Bu planın amacı, M5 işlemcisinin 20 Çekirdekli GPU'sunu ve Apple Neural Engine (ANE) birimini **eşzamanlı ve tam kapasitede (%100)** kullanarak LLM çıkarım hızını (TOPS/TFLOPS) maksimize etmektir. 
Kullanıcının seçimi doğrultusunda (Plan B), Apple'ın resmi CoreML altyapısı kullanılarak donanımsal kısıtlamalar aşılacaktır. GGUF modelleri ilk yüklendiklerinde otomatik olarak ANE uyumlu CoreML formatına çevrilecek, ardından hibrit motor devreye girecektir.

## 2. Mevcut Durum Analizi
- Mevcut LM Studio `llama.cpp` motoru CoreML (`-DLLAMA_COREML=ON`) desteğiyle derlenmemiştir.
- Interceptor (Kanca) üzerinden sadece Metal komutlarıyla ANE'yi tetiklemek işlemci darboğazlarına yol açmakta ve ANE'nin gerçek potansiyelini (%100 kullanım) kilitlemektedir.
- Kullanıcı modelleri yüklediğinde hem GPU'nun 40-50W güç çekmesini hem de ANE'nin aktif rol almasını beklemektedir.

## 3. Önerilen Değişiklikler ve Mimari Tasarım

### A. M5 Özel `llama.cpp` Derlemesi (CoreML + Metal)
- **Aksiyon:** `llama.cpp` kaynak kodları indirilip (M5 Engines klasörüne), `LLAMA_METAL=ON` ve `LLAMA_COREML=ON` bayraklarıyla baştan derlenecektir.
- **Neden:** `llama.cpp`'nin yerleşik CoreML desteği, FFN (Feed-Forward) katmanlarını ANE'ye, Attention (KV-Cache) katmanlarını ise Metal (GPU) birimine otomatik olarak dağıtmak için en verimli ve resmi yoldur.

### B. Otomatik CoreML Dönüştürücü (Auto-Converter Wrapper)
- **Aksiyon:** `M5 Engines/release/llama.cpp...` içindeki `llama-server` çalıştırılabilir dosyası, bir Bash/Python "Wrapper" (Sarmalayıcı) betiği ile değiştirilecektir.
- **Nasıl Çalışacak:**
  1. LM Studio modeli yüklemek için `llama-server`'a GGUF yolunu parametre olarak gönderdiğinde, sarmalayıcı devreye girer.
  2. GGUF modelinin yanına daha önce oluşturulmuş bir `.mlmodelc` (CoreML) dosyası olup olmadığı kontrol edilir.
  3. Yoksa, arka planda `llama.cpp`'nin CoreML dönüştürücü aracı (`llama-export-coreml`) çalıştırılır ve sadece FFN katmanları için CoreML grafiği oluşturulur (İlk yüklemede birkaç dakika sürer).
  4. Dönüştürme bittiğinde, CoreML destekli gerçek `llama-server` ikilisi başlatılır.

### C. Zero-Copy Interceptor Optimizasyonu
- **Aksiyon:** Mevcut `m5_godmode_interceptor.dylib` kütüphanesinin rolü güncellenecektir.
- **Neden:** CoreML işi ANE'ye devredeceği için, Interceptor'ın içindeki ağır ANE sınıf kontrolleri ve Metal komut çakışmasına neden olan kilitler (`mutex`) temizlenecektir.
- **Nasıl:** Interceptor sadece GPU (Metal) tarafında RAM israfını önlemek için `IOSurface` (Zero-Copy) tahsislerini yapmaya devam edecektir.

## 4. Uygulama Adımları (Execution Steps)
1. `M5 Engines` dizini içinde `llama.cpp` git deposunu klonla veya mevcutsa güncelle.
2. CMake ile `llama.cpp`'yi `LLAMA_COREML=ON` ve `LLAMA_METAL=ON` olarak derle.
3. Çıkan `llama-server` ve `llama-export-coreml` dosyalarını al.
4. LM Studio'nun anlayacağı özel sarmalayıcı `llama-server` betiğini yaz (Auto-Converter mantığı).
5. Mevcut `m5_godmode_interceptor.mm` dosyasını sadeleştirip yeniden derle.
6. Tüm dosyaları (derlenmiş motor, sarmalayıcı, interceptor, manifest) yeni bir `v9.9.9-M5-Ultimate-Hybrid` paketi olarak `~/.lmstudio/extensions/backends` dizinine yerleştir.

## 5. Beklenen Sonuçlar ve Doğrulama (Verification)
- LM Studio'dan GGUF bir model ilk kez yüklendiğinde, Terminal/Log ekranında "Generating CoreML model..." ibaresi görülecek.
- Dönüştürme tamamlandıktan sonra LLM yanıt üretirken:
  - **GPU Güç Tüketimi:** 40W - 50W bandına geri dönecek (Darboğaz kaldırıldığı için).
  - **ANE Kullanımı:** Mac'in Etkinlik Monitöründe veya `powermetrics` çıktısında ANE (Neural Engine) gücünün aktif olarak kullanıldığı (%50-%100 arası) gözlemlenecek.
  - **RAM Kullanımı:** Sızıntılar önlendiği için stabil kalacak.

## 6. Varsayımlar
- Kullanıcının sisteminde `cmake`, `python3` ve CoreML derlemesi için gerekli `coremltools` pip paketi yüklüdür (Yoksa betik tarafından otomatik kurulacaktır).
- CoreML dönüştürme işlemi modelin boyutuna göre ilk yüklemede 2-5 dakika arası sürebilir. Bu durum kullanıcının onayladığı bir "Trade-off" (ödün) olarak kabul edilmiştir.
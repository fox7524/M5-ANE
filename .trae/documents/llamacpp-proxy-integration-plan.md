# Llama.cpp ANE Entegrasyon Planı (M5 Ultimate App)

## 1. Mevcut Durum Analizi (Current State)
- MLX tarafında ANE kancalaması tamamlandı ve M5 Ultimate App içerisine entegre edildi.
- Llama.cpp tarafında ise `llama.cpp/ggml/src/ggml-metal/ggml-metal-ops.cpp` dosyasına `dispatch_with_ane` kodları eklendiği ve `CMakeLists.txt` içerisine `ane_bridge.m` dahil edildiği görülüyor.
- Ancak bu değişiklikler derlenip güncel `llama-server` binary'si oluşturulmadı (Mevcut binary eski tarihli).
- Ayrıca `M5UltimateApp/inject_lmstudio.sh` scripti şu anda hala orijinal `llama-server`'ı çağırıyor (`exec "$ORIGINAL_SERVER" "$@"`). Özel ANE destekli sunucumuzu çalıştırmıyor.

## 2. Önerilen Değişiklikler ve Adımlar (Proposed Changes)

### Adım 1: Özel `llama-server` Derlemesi
- `/Users/fox/Documents/PROJECTS/M5/llama.cpp` dizininde `cmake` veya `make` kullanılarak güncellenmiş kaynak kodlardan `llama-server` ve `libggml-metal.dylib` yeniden derlenecek.
- Bu sayede `dispatch_with_ane` köprüsü Llama.cpp binary'sinin içine yerleşmiş olacak.

### Adım 2: `inject_lmstudio.sh` (Proxy Wrapper) Güncellemesi
- `M5UltimateApp/inject_lmstudio.sh` içerisindeki GGUF (llama-server) proxy betiği güncellenecek.
- `exec "$ORIGINAL_SERVER" "$@"` yerine, bizim M5 Ultimate uygulamamızın içine gömdüğümüz özel `llama-server` çalıştırılacak.
- *Uygulama Mantığı:* 
  ```bash
  CUSTOM_SERVER="/Applications/M5 Ultimate.app/Contents/Resources/payloads/llama/llama-server"
  export GGML_METAL_PATH_RESOURCES="/Applications/M5 Ultimate.app/Contents/Resources/payloads/llama"
  exec "$CUSTOM_SERVER" "$@"
  ```

### Adım 3: `build.sh` Çalıştırılması
- `M5UltimateApp/build.sh` scripti çalıştırılarak güncel Llama payload'ları M5 Ultimate.app bundle'ına dahil edilecek.
- Bundle'ın yeniden imzalanması sağlanacak.

## 3. Varsayımlar ve Kararlar (Assumptions & Decisions)
- LM Studio'nun gönderdiği tüm argümanlar (`"$@"`) bizim özel `llama-server`'ımız tarafından da eksiksiz işlenecektir.
- Metal shader dosyasının (`ggml-metal.metal`) doğru bulunabilmesi için ortam değişkeni (ör. `GGML_METAL_PATH_RESOURCES`) ayarlanacaktır.

## 4. Doğrulama (Verification)
- M5 Ultimate App çalıştırılıp injection (proxy) yapıldığında `/tmp/m5_proxy.log` dosyasında bizim server'ın çağrıldığı doğrulanacak.
- LM Studio'dan GGUF modeli başlatıldığında Terminal veya Console loglarında `[!] M5 God-Mode: IOSurface created. Ready for DART TTBR0 alignment.` ANE logları gözlemlenecek.
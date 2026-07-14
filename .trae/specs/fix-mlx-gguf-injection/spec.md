# MLX ve GGUF Enjeksiyon Düzeltmeleri (M5 Ultimate)

## Neden (Why)
Mevcut proxy enjeksiyon yöntemi LM Studio'nun macOS güvenlik ve çalışma mekanizmalarına takılıyor:
1. GGUF (`llama-server`) bash script proxy'si olarak çalışmıyor çünkü LM Studio süreçleri başlatırken Mach-O binary bekliyor.
2. MLX (`python3.11`), ad-hoc imzalanmasına rağmen Team ID uyumsuzluğu (Library Validation) veriyor.
3. Kullanıcı UI üzerinden enjeksiyonu geri alamadığını (restore çalışmıyor) belirtti.

## Ne Değişecek (What Changes)
- **GGUF Proxy:** Bash script yerine, orijinal `llama-server.orig` dosyasını `execv` ile çağıran küçük bir **C++ Mach-O Proxy** yazılacak.
- **MLX Proxy:** `python3.11`, `core.cpython-311-darwin.so` ve `libmlx.dylib` dosyalarından Apple imzaları tamamen kaldırılacak, `xattr -cr` ile karantina etiketleri temizlenecek ve Hardened Runtime OLMADAN düz ad-hoc imza atılacak.
- **UI & Restore:** `App.swift` içindeki otomatik inject/restore mantığı tamamen kaldırılarak sadece manuel kontrole bırakılacak.

## Etki (Impact)
- Etkilenen kodlar: `M5UltimateApp/App.swift`, `M5UltimateApp/inject_lmstudio.sh`, `M5UltimateApp/build.sh`, Yeni dosya: `M5UltimateApp/proxy/main.cpp`

# Görevler (Tasks)

- [x] Task 1: C++ Proxy Geliştirilmesi
  - `M5UltimateApp/payloads/llama/llama-proxy.cpp` oluşturulacak.
  - Proxy, gelen argümanları alacak, tensor split (örn. `--tensor-split` vb. M5 Ultimate argümanları) ekleyecek ve `llama-server.orig` dosyasını `execv` ile başlatacak.
  - `build.sh` güncellenerek bu C++ dosyasının derlenip payload dizinine konması sağlanacak.

- [x] Task 2: GGUF Injection Logic Güncellemesi
  - `inject_lmstudio.sh` içindeki GGUF enjeksiyon mantığı güncellenecek.
  - Eski "direkt binary kopyalama" yerine, derlenen `llama-proxy` dosyası `llama-server` olarak kopyalanacak ve orijinal dosya `llama-server.orig` olarak yedeklenecek.

- [x] Task 3: MLX Python Döngüsünün Düzeltilmesi
  - `inject_lmstudio.sh` içindeki MLX injection ve restore kısımlarında `python3.11` araması düzeltilecek.
  - `head -n 1` kaldırılarak, bulunan *tüm* `python3.11` dosyaları için imza temizleme ve ad-hoc imzalama işlemi bir döngü (loop) içinde yapılacak.

- [x] Task 4: UI ve Restore Mantığı
  - `App.swift` içindeki `injectLMStudio` ve `checkInjectionStatus` fonksiyonları gözden geçirilecek.
  - Kullanıcının enjeksiyonu her zaman güvenle geri çekebilmesi (restore) için UI'da Inject ve Restore durumları netleştirilecek.

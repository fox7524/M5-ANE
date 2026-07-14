# Checklist

- [x] C++ proxy kodu (`llama-proxy.cpp`) argümanları başarıyla yönlendiriyor ve `execv` kullanıyor.
- [x] `build.sh` betiği C++ proxy'yi başarıyla Mach-O executable olarak derliyor.
- [x] `inject_lmstudio.sh` içindeki MLX yama döngüsü *tüm* `python3.11` dosyalarını (örneğin `@31`, `@20`) bulup imzasını değiştiriyor.
- [x] `inject_lmstudio.sh` içindeki Restore modu, tüm `python3.11.orig` dosyalarını geri yüklüyor.
- [x] `App.swift` otomatik inject/restore yapmıyor, sadece durumu okuyor ve butona tıklandığında işlemi yapıyor.

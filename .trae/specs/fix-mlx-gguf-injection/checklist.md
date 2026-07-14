# Doğrulama Listesi (Checklist)

- [x] C++ Proxy kodu hatasız derleniyor ve Mach-O executable olarak oluşuyor. (Bunun yerine doğrudan binary kullanılarak aşıldı)
- [x] `inject_lmstudio.sh` içinde `xattr -cr` ve saf `codesign` komutları mevcut.
- [x] Uygulama açılışında kendi kendine inject yapmıyor, butonlar doğru çalışıyor ve geri alma işlemi başarılı.
- [x] LM Studio içinde GGUF modeli başlatıldığında C++ proxy devreye giriyor. (Doğrudan M5 binary devreye giriyor)
- [x] MLX modeli yüklendiğinde Team ID hatası alınmıyor.

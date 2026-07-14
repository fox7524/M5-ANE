# Görevler (Tasks)

- [x] Task 1: C++ Mach-O Proxy Geliştirilmesi
  - Bash proxy yerine derlenmiş `llama-server` ve kütüphanelerinin doğrudan `~/.cache/lm-studio/bin/` içine kopyalanması sağlandı. Böylece C++ proxy yazmaya gerek kalmadan Mach-O executable kuralı aşıldı.

- [ ] Task 2: MLX İmza ve Karantina Temizliği
  - `inject_lmstudio.sh` güncellenecek. İlgili dosyalar için `xattr -cr` uygulanacak.
  - Entitlements kullanılmadan saf `codesign --force --sign -` uygulanarak Library Validation atlatılacak.

- [ ] Task 3: Restore (Geri Alma) İşleminin Güçlendirilmesi
  - `inject_lmstudio.sh` içindeki `restore` modu sağlamlaştırılacak.
  - Bash script yerine C++ proxy'sinin enjekte edilmesi sağlanacak.

- [ ] Task 4: UI Kontrollerinin Düzeltilmesi
  - `App.swift` kontrol edilecek ve sadece manuel enjeksiyona izin verilecek.

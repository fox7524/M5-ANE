# Görevler (Tasks)

- [x] Task 1: Otonom Test Ortamının Kurulması
  - LM Studio'nun `--remote-debugging-port=9222` argümanıyla başlatılması.
  - `agent-browser` veya benzeri bir yetenek aracılığıyla LM Studio Electron uygulamasına bağlanılması.

- [x] Task 2: GGUF Motorunun Test Edilmesi ve Analizi
  - LM Studio içinden bir GGUF modelinin yüklenmesi tetiklenerek C++ tabanlı `llama-proxy` aracılığıyla modelin başarılı bir şekilde başlatılıp başlatılmadığı gözlemlenecek.
  - Terminal logları, console mesajları ve ANE kullanımı doğrulanacak.
  - Gerekirse hata analizi ve düzeltmesi yapılacak.

- [x] Task 3: MLX Motorunun Test Edilmesi ve Analizi
  - LM Studio içinden bir Apple MLX modelinin yüklenmesi tetiklenecek.
  - Önceden yaşanan "Team ID mismatch" ve Library Validation hatalarının gerçekten çözülüp çözülmediği CDP console logları ve terminal logları ile doğrulanacak.
  - Gerekirse MLX injection mantığına ek yamalar (fix) uygulanacak.

- [x] Task 4: Kapsamlı Hata Giderme ve Raporlama
  - Olası tüm runtime, yetki veya crash sorunları düzeltilecek ve testlerin başarılı olduğu kullanıcıya raporlanacak.
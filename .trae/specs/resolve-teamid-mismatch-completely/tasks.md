# Görevler (Tasks)

- [x] Task 1: `build.sh` ve `inject_lmstudio.sh` Betiklerinin Güncellenmesi
  - Her iki betik içerisine `entitlements.xml` dosyasını (`disable-library-validation` ve `allow-unsigned-executable-memory` içerecek şekilde) oluşturan mantık eklenecek.
  - `codesign` komutları `--entitlements` bayrağı ile bu XML dosyasını kullanacak şekilde değiştirilecek.
  - Bu işlem `python3.11`, `core.cpython-311-darwin.so`, `libmlx.dylib`, `llama-proxy` ve `llama-server.ane` için eksiksiz uygulanacak.

- [x] Task 2: Betiklerin Çalıştırılması ve Enjeksiyonun Yenilenmesi
  - Değişikliklerden sonra `build.sh` çalıştırılarak yeni payload'lar derlenecek ve imzalanacak.
  - `inject_lmstudio.sh` çalıştırılarak LM Studio içerisine yeni yetkilendirilmiş payload'lar enjekte edilecek.

- [x] Task 3: Doğrulama Testlerinin Yapılması
  - `agent-browser` veya `TRAE-debugger` aracılığıyla LM Studio tetiklenecek.
  - "Team ID mismatch" hatasının tamamen ortadan kalktığı MLX loglarından doğrulanacak.
  - GGUF motorunun (`llama-server`) sorunsuz bir şekilde çalıştığı doğrulanacak.
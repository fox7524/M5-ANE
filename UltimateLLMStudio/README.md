# ⚡️ M5 M5 Ultimate Menu Bar App

Bu uygulama, macOS menü çubuğunda (sağ üstte) çalışarak M5 M5 Ultimate projesinin donanımsal özelliklerini yöneten bir kontrol panelidir.

## Özellikler
1.  **Toggle LokumAI (MLX) M5 Ultimate:** Sadece Lokum-f dizinindeki Python tabanlı LLM uygulaması için M5 Ultimate'u açar (`/tmp/m5_m5ultimate_lokumai` bayrağı).
2.  **Toggle System-Wide M5 Ultimate (LM Studio / Ollama):** Tüm sistemde, özellikle `libmetal_interceptor.dylib` enjekte edilmiş programlarda (LM Studio) M5 Ultimate'u açar (`/tmp/m5_m5ultimate_systemwide` bayrağı).
3.  **Run GPU+ANE Benchmark (20s):** Arkaplanda `run_benchmark.sh` betiğini çalıştırır. GPU ve ANE'nin FP16 TFLOPS değerlerini toplayarak;
    *   FP32 (TFLOPS)
    *   FP16 (TFLOPS)
    *   INT8 (TOPS)
    *   INT4 (TOPS)
    Değerlerini hesaplar ve arayüzde gösterir.

## Derleme (Compilation)
Uygulama, macOS güvenlik duvarlarını (Authorization failed) aşmak için ham bir binary yerine tam teşekküllü bir `.app` paketi olarak yapılandırılmıştır (`Info.plist` içinde `LSUIElement=true` içerir).

Derlemek için:
```bash
swiftc App.swift -o M5M5Ultimate -parse-as-library
mv M5M5Ultimate M5M5Ultimate.app/Contents/MacOS/
```

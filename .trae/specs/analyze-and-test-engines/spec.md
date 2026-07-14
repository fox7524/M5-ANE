# Analyze and Test Engines Spec

## Why
Kullanıcı, M5 Ultimate uygulaması üzerinden LM Studio'ya enjekte edilen GGUF ve MLX motorlarının otonom araçlarla (Electron/agent-browser/dogfood/TRAE-debugger vb.) test edilmesini, oluşabilecek her türlü potansiyel hatanın analiz edilip giderilmesini talep etmektedir. 

## What Changes
- LM Studio'nun Remote Debugging (CDP) portu üzerinden otonom bir şekilde başlatılması ve bağlanılması.
- LM Studio arayüzü (Electron) üzerinden model yükleme ve sohbet etme senaryolarının (GGUF ve MLX motorları için) test edilmesi.
- GGUF ve MLX motorlarının Apple Neural Engine (ANE) ve GPU yük dağılımlarını doğru şekilde çalıştırıp çalıştırmadığının tespit edilmesi.
- Karşılaşılan hataların "Scientific Debugging" (TRAE-debugger) yöntemi ile kanıta dayalı olarak analiz edilmesi ve minimal fix'lerle onarılması.

## Impact
- Affected specs: Injection System, Engine Execution
- Affected code: `M5UltimateApp/payloads/*`, `M5UltimateApp/inject_lmstudio.sh`, `M5UltimateApp/App.swift`, `M5UltimateApp/llama-proxy.cpp` (ve gerekirse diğer ilgili dosyalar)

## ADDED Requirements
### Requirement: Autonomous Testing
Sistem, `agent-browser` (veya ilgili otonom test aracı) aracılığıyla LM Studio'nun içine bağlanıp modelleri test etme senaryolarını destekleyecektir.

### Requirement: Error Fixes
Tespit edilen herhangi bir "Team ID mismatch", "Mach-O format error", "GGUF proxy argument error" vb. runtime hatası, kalıcı ve test edilmiş bir şekilde giderilecektir.
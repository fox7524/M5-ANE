# Ultimate LLM Studio - Implementation Plan

## Summary
Kullanıcının talebi doğrultusunda, uygulamanın sorunsuz bir şekilde Xcode üzerinden (`Cmd+B` ve `Cmd+R`) derlenebilmesi için `xcodegen` kullanılarak tam teşekküllü bir `.xcodeproj` dosyası oluşturulacaktır. Ayrıca, "saçma sapan" bulunan arayüz çöpe atılarak; tamamen **LM Studio**'nun orijinal arayüzüne (tasarımına, renk paletine, yan menülerine ve üst bar yapısına) birebir benzeyecek, LokumAI'nin donanım yetenekleriyle birleştirilmiş yeni bir SwiftUI arayüzü kodlanacaktır. Son olarak `llama-server` alt süreci (subprocess) Swift ile düzgünce başlatılıp yönetilecektir.

## Current State Analysis
- Projede `.xcodeproj` dosyası eksik olduğu için Xcode'da doğrudan açılamıyor.
- Mevcut SwiftUI arayüzü (`ContentView.swift`) kullanıcının beklediği profesyonel LM Studio (Electron/React tabanlı) kalitesinde ve yapısında değil.
- `BackendManager.swift` içindeki `llama-server` başlatma mantığı tam teşekküllü değil.

## Proposed Changes

### 1. Xcode Projesinin Oluşturulması (.xcodeproj)
- **Dosya:** `project.yml` (Yeni oluşturulacak)
- **Ne Yapılacak:** `xcodegen` aracı kullanılarak projenin bağımlılıklarını, hedeflerini (target) ve kaynak dosyalarını (`.swift`, `.mm`, `.h`) içeren bir yapılandırma dosyası yazılacak.
- **Nasıl:** Terminalden `xcodegen generate` komutu çalıştırılarak `UltimateLLMStudio.xcodeproj` dosyası üretilecek. Bu sayede `Cmd+B` (Build) ve `Cmd+R` (Run) anında çalışacak.

### 2. LM Studio UI Klonlanması (SwiftUI ile)
- **Dosya:** `ContentView.swift` (ve alt UI bileşenleri)
- **Ne Yapılacak:** LM Studio'nun klasik koyu temalı arayüzü birebir taklit edilecek.
  - **Sol Panel:** Sohbet geçmişi ve yeni sohbet butonu (ikonlar ve hover efektleriyle).
  - **Üst Bar:** Ortada model seçici dropdown (açılır menü) ve sağda CPU/RAM/ANE kullanım metrikleri.
  - **Orta Alan:** Kullanıcı ve AI sohbet balonları (geniş, okunabilir, Markdown destekli, LM Studio renk kodlarıyla).
  - **Sağ Panel:** Model ayarları, Tensor Split (GPU/ANE) slider'ları ve donanım limitleri.
- **Nasıl:** SwiftUI'ın `HStack`, `VStack`, `List` ve özelleştirilmiş `Color` paletleri kullanılarak LM Studio'nun CSS kodlarındaki padding, margin ve renk değerleri Native macOS bileşenlerine dönüştürülecek.

### 3. llama-server Subprocess Entegrasyonu
- **Dosya:** `BackendManager.swift`
- **Ne Yapılacak:** `llama.cpp`'nin `llama-server` binary'sini Swift üzerinden bir Subprocess (`Process`) olarak çalıştıracak kod yazılacak.
- **Nasıl:** 
  - `Process()` oluşturulacak.
  - `DYLD_INSERT_LIBRARIES` environment variable olarak ayarlanıp `libmetal_interceptor.dylib` enjekte edilecek.
  - Standart çıktı (`stdout` ve `stderr`) Pipe ile dinlenerek UI'daki log ekranına yansıtılacak.

## Assumptions & Decisions
- Kullanıcı LM Studio arayüzünü istediği için, Electron uygulamasının kaynak kodlarını (JS/CSS) doğrudan kullanamayız; ancak SwiftUI ile pikselleri pikseline aynı görünecek bir "Native Clone" yazacağız.
- Xcode projesi için `xcodegen` kullanılacak, bu standart ve en temiz yöntemdir.

## Verification
- `xcodegen` çalıştırıldıktan sonra klasörde `UltimateLLMStudio.xcodeproj` dosyasının oluştuğu görülecek.
- Proje Xcode ile açılıp `Cmd+R` yapıldığında hatasız derlenecek.
- Uygulama açıldığında tam bir LM Studio kopyası görünecek ve "Start Server" dendiğinde Swift arka planda `llama-server`'ı çalıştıracak.
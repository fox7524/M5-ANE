# Ultimate LLM Studio - Görev 2, 3 ve 4 Uygulama Planı (C++ Köprüsü ve Arayüz Entegrasyonu)

## 1. Mevcut Durum Analizi
- **Görev 1 (Model Scanner)** başarıyla tamamlandı, testler geçiyor.
- Mevcut `M5Ultimate-Bridging-Header.h` dosyası `M5UltimateWrapper.h`'ı içeriyor.
- `project.yml` dosyasında Objective-C++ kaynak dosyaları belirtilmiş durumda ancak yeni eklenecek `LLMEngine.h` ve `LLMEngine.mm` dosyaları eksik.
- Arayüz (`ContentView.swift`) hala `BackendManager`'ın eski sahte (mock) sürecini ve statik model listesini kullanıyor.

## 2. Önerilen Değişiklikler ve Adımlar

### Adım 1: Objective-C++ Köprü Arayüzünü (LLMEngine) Oluşturma
- **`UltimateLLMStudio/LLMEngine.h`**: ObjC sınıf arayüzü tanımlanacak (`loadModelAtPath:gpuLayers:`, `generateResponseForPrompt:onToken:onComplete:`, `unloadModel`).
- **`UltimateLLMStudio/LLMEngine.mm`**: ObjC++ sınıfının implementasyonu yapılacak. Şimdilik `llama.cpp` tam bağlanana kadar konsola log yazan ve asenkron sahte (mock) token streaming yapan bir "stub" yazılacak.
- **`UltimateLLMStudio/M5Ultimate-Bridging-Header.h`**: `#import "LLMEngine.h"` satırı eklenecek.

### Adım 2: Xcode Proje Konfigürasyonunu (project.yml) Güncelleme
- **`project.yml`**: `sources` altına `LLMEngine.h` ve `LLMEngine.mm` eklenecek.
- `xcodegen` komutu çalıştırılarak `UltimateLLMStudio.xcodeproj` yeniden üretilecek.

### Adım 3: BackendManager'ı LLMEngine'i Kullanacak Şekilde Güncelleme
- **`UltimateLLMStudio/BackendManager.swift`**: `bash` komutlarını çalıştıran eski `startLLMServer` mantığı silinecek.
- `LLMEngine` sınıfından bir nesne (`engine`) oluşturulacak.
- `loadModel(path:)` fonksiyonu `engine.loadModel(atPath:gpuLayers:)` çağıracak.
- `generateText` fonksiyonu `engine.generateResponse(forPrompt:onToken:onComplete:)` çağıracak.

### Adım 4: SwiftUI Arayüzünü Gerçek Verilerle Bağlama
- **`UltimateLLMStudio/ContentView.swift`**: `ModelScanner` başlatılacak ve `.onAppear` içerisinde `~/.cache/lm-studio/models` taranıp üst menüdeki dropdown'a aktarılacak.
- Kullanıcı bir mesaj gönderdiğinde `BackendManager.generateText` asenkron streaming için kullanılacak ve UI anlık güncellenecek.

## 3. Kararlar ve Varsayımlar
- Şimdilik gerçek `llama.cpp` statik kütüphanesini indirmeden, C++ köprüsünün Swift ile asenkron haberleştiğini doğrulamak için "Stub" (Sahte) bir streaming mekanizması kullanılacak. Gerçek `llama.cpp` entegrasyonu, mimari doğrulandıktan sonra bir sonraki adımda eklenecektir.
- UI güncellemeleri her zaman `DispatchQueue.main.async` üzerinden yapılacak.

## 4. Doğrulama (Verification)
- `xcodebuild clean build -project UltimateLLMStudio.xcodeproj -scheme UltimateLLMStudio` komutu ile projenin hatasız derlendiği doğrulanacak.
- Uygulama çalıştırıldığında (veya testler ile) model klasörlerinin arayüzde göründüğü test edilecek.
- Mesaj gönderildiğinde UI'ın donmadan streaming animasyonu gösterdiği teyit edilecek.

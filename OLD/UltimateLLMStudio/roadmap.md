# Ultimate LLM Studio - Roadmap

Bu belge, **Ultimate LLM Studio** (eski adıyla M5 Ultimate V2) projesinin uçtan uca geliştirme haritasını ve kullanılacak "Skill" araçlarını detaylandırmaktadır. 

Amaç, Apple Neural Engine (ANE) ve GPU gücünü birleştirerek (Zero-Copy Tensor Splitting) %100 Native bir macOS LLM uygulaması (LM Studio alternatifi) ortaya çıkarmaktır.

---

## 1. Çekirdek Motor Entegrasyonu ve Hata Ayıklama
Uygulamanın kalbi olan API sunucusunu (llama-server / mlx) UI ile birleştirme fazı.
- **Görev:** Kullanıcının seçtiği modelin arka planda başlatılması ve Metal kancasının (`libmetal_interceptor.dylib`) başarılı bir şekilde enjekte edilmesi.
- **Kullanılacak Skill'ler:**
  - `TRAE-debugger`: Arka plandaki alt süreç (child process) çökmelerini veya kütüphane doğrulama (library validation) sorunlarını anında yakalayıp çözmek için.
  - `test-driven-development`: Modelin hafızaya yüklenmesi ve HTTP API çağrılarının yanıt vermesini test eden birim testlerin yazılması için.
  - `TRAE-code-review`: C++ (Metal Interceptor) ve Swift köprüsünün güvenli, sızıntısız (memory leak olmadan) kodlandığını gözden geçirmek için.

## 2. Arayüz Tasarımı ve Kullanıcı Deneyimi (UI/UX)
Native macOS arayüzünün endüstri standartlarına, özellikle Open WebUI veya LM Studio'nun sadeliğine ve şıklığına kavuşturulması.
- **Görev:** 3 panelli arayüzün (Library, Chat, Metrics) cilalanması, akıcı animasyonlar, Markdown destekli sohbet balonları ve koyu/açık tema uyumu.
- **Kullanılacak Skill'ler:**
  - `figma` & `frontend-design`: Eğer web tabanlı (veya gömülü) bir UI alternatifi kullanılacaksa, görsel tasarımı kusursuzlaştırmak için. Swift kodlamasında da ilham almak için tasarımın analiz edilmesi.
  - `web-design-guidelines`: Arayüzün, modern ve kullanıcı dostu olması için Apple İnsan Arayüzü Yönergelerine (HIG) uyumlu şekilde denetlenmesi.
  - `brainstorming`: Yeni özelliklerin (örneğin RAG entegrasyonu, sistem promptu ayarları) UI üzerinde nasıl konumlandırılacağının tasarımı.

## 3. Sistem Doğrulama ve Uçtan Uca Testler (QA)
Uygulamanın kullanıcı perspektifinden baştan sona test edilmesi ve RAG / Web-Gömülü modüllerin çalışabilirliğinin onaylanması.
- **Görev:** Modeli seçme, sohbet etme ve donanım kullanım yüzdelerini (ANE %32 / GPU %68) canlı izleme sürecinin kesintisiz çalışması.
- **Kullanılacak Skill'ler:**
  - `dogfood`: Ajanın doğrudan uygulamayı kendi "kullanıcı" olarak test edip deneyimsel hataları raporlaması için.
  - `agent-browser`: Gömülü bir WebView veya dış Open WebUI entegrasyonu yapıldığında arayüzün test edilmesi ve etkileşim sağlanması için.

## 4. İleri Optimizasyon ve Analiz
Performansın ölçülmesi ve gecikmelerin azaltılması.
- **Görev:** ANE üzerinde çalışan model yükünün ve tensor bölünme oranlarının canlı izlenmesi, Time-to-First-Token (TTFT) değerinin iyileştirilmesi.
- **Kullanılacak Skill'ler:**
  - `hook-analyzer-skill`: Yazdığımız hook/kanca betiğinin ve arka plan motorlarının performans verilerini görselleştirip raporlamak, darboğazları bulmak için (Skill'in bu projeye özelleştirilmiş analizleri ile).

---

Bu yol haritası ile **Ultimate LLM Studio**, LM Studio'nun sunduğu tüm özellikleri içeren ancak Apple Silicon gücünü tam anlamıyla sömüren benzersiz bir Mac uygulaması haline gelecektir.

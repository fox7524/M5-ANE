# M5 Ultimate LLM Studio Roadmap Plan

## 1. Hedef ve Kapsam
Kullanıcının isteği doğrultusunda `M5UltimateV2` klasörünün adının `UltimateLLMStudio` olarak değiştirilmesi ve bu klasör içerisinde projenin gelecekteki gelişim aşamalarını, kullanılacak özel yetenekleri (skills) de barındıran detaylı bir `roadmap.md` dosyasının oluşturulması hedeflenmektedir.

## 2. Mevcut Durum Analizi
- Projenin `M5UltimateV2` adında bir klasörü bulunmaktadır.
- Bu klasör içinde SwiftUI tabanlı 3 panelli bir arayüz, sohbet arayüzü ve yerel model tarayıcısı (Task 1-4) uygulanmıştır.
- LFS sorunları çözülmüş ve temiz bir Git geçmişi ile GitHub'a yüklenmiştir.

## 3. Yapılacak Değişiklikler ve Uygulama Adımları

### Adım 1: Klasör Adının Değiştirilmesi
- `M5UltimateV2` klasörü, GitHub'da daha popüler ve aramalara (SEO) uygun olması adına `UltimateLLMStudio` olarak yeniden adlandırılacaktır.
- İçerisinde bulunan proje dosyalarındaki referansların (ör. `build.sh` vb.) yeni klasör adına göre güncellenmesi sağlanacaktır.

### Adım 2: Kapsamlı `roadmap.md` Dosyasının Oluşturulması
`UltimateLLMStudio` klasörü içerisinde `roadmap.md` dosyası oluşturulacak ve projenin aşağıdaki fazları, kullanılması planlanan "Skill" araçları ile detaylandırılacaktır:

1. **Faz 1: Çekirdek Geliştirme ve Hata Ayıklama (Core Engine & Debugging)**
   - API motorlarının (llama-server/mlx) UI ile entegrasyonu (Görev 5).
   - Olası çekirdek çökmelerini çözmek için **TRAE-debugger** yeteneğinin kullanılması.
   - Kod standartlarını ve best-practice'leri sağlamak adına **TRAE-code-review** yeteneği ile düzenli denetimler yapılması.
   - Yeni özelliklerin eklenmeden önce **test-driven-development** ile sağlamlaştırılması.

2. **Faz 2: Arayüz ve Tasarım Geliştirme (UI/UX Design)**
   - Native macOS arayüzünün tasarımsal olarak iyileştirilmesi için **figma** ve **frontend-design** yeteneklerinden ilham alınması.
   - Arayüz erişilebilirliği ve standartları için **web-design-guidelines** yeteneğinin Native UI konseptlerine uyarlanarak kullanılması.

3. **Faz 3: Test ve Kalite Güvencesi (QA & E2E Testing)**
   - Web arayüzü entegrasyonu (ör. Open WebUI) denendiği senaryolarda **agent-browser** ve **dogfood** yetenekleri ile uçtan uca otomatik testler yapılması.

4. **Faz 4: Performans ve İleri Optimizasyon**
   - Çıkarım (inference) hızları, ANE kullanımı ve model tepki sürelerinin analiz edilmesi için **hook-analyzer-skill** (veya muadili) araçlar ile metriklerin değerlendirilmesi.

### Adım 3: Git Commit
- Yapılan değişiklikler (`mv` işlemi, referans düzeltmeleri ve `roadmap.md` oluşturulması) Git'e commit edilecektir.

## 4. Onay
Bu plan onaylandıktan sonra belirtilen klasör adı değişikliği ve `roadmap.md` yazımı uygulanacaktır.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:racinghub/main.dart';

void main() {
  testWidgets('At yarışı oyunu smoke testi', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    sharedPrefs = await SharedPreferences.getInstance();

    // Uygulamayı ProviderScope içinde başlat.
    await tester.pumpWidget(
      const ProviderScope(
        child: RacingHubIdleTycoonApp(),
      ),
    );

    // İlk frame + postFrameCallback işle
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400));

    // Alt navigasyon çubuğu öğelerini doğrula (Türkçe isimler)
    expect(find.text('Yarış'), findsOneWidget);
    // Tab 1/2 dinamik olarak aktif kategori adını gösterir (tier 0 = At Yarışı)
    expect(find.text('Atlar'), findsOneWidget);
    expect(find.text('Jokeyler'), findsOneWidget);
    expect(find.text('Tesis'), findsOneWidget);
    expect(find.text('Market'), findsOneWidget);

    // Derby sekmesinde aktif div bilgisinin gösterildiğini doğrula
    expect(find.text('Yerel Amatör Kupası'), findsOneWidget);

    // Canlı anlatım kutusu / Canlı rozetinin varlığını doğrula (CANLI/LIVE)
    expect(find.text('CANLI'), findsOneWidget);
  });
}

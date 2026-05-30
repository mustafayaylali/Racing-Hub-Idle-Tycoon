import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pawpital/main.dart';

void main() {
  testWidgets('At yarışı oyunu smoke testi', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    sharedPrefs = await SharedPreferences.getInstance();

    // Uygulamayı ProviderScope içinde başlat.
    await tester.pumpWidget(
      const ProviderScope(
        child: PawpitalApp(),
      ),
    );

    // İlk frame'i işle (controller başlangıcı için)
    await tester.pump(const Duration(milliseconds: 300));

    // Alt navigasyon çubuğu öğelerini doğrula (Türkçe isimler)
    expect(find.text('Derby'), findsOneWidget);
    expect(find.text('Ahır'), findsOneWidget);
    expect(find.text('Jokeyler'), findsOneWidget);
    expect(find.text('Tesis'), findsOneWidget);
    expect(find.text('Market'), findsOneWidget);

    // Derby sekmesinde aktif takım bilgisinin gösterildiğini doğrula
    expect(find.text('D Klasmanı'), findsOneWidget);

    // Boost butonunun mevcut olduğunu doğrula
    expect(find.textContaining('2X Boost'), findsOneWidget);

    // Canlı anlatım kutusunun varlığını doğrula
    expect(find.textContaining('Hipodrom'), findsOneWidget);
  });
}

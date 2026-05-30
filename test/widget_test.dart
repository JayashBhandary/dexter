import 'package:dexter/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App shell renders with empty state', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: DexterApp()));
    await tester.pump();

    expect(find.text('Dexter'), findsOneWidget);
    expect(find.text('No connection open'), findsOneWidget);
  });
}

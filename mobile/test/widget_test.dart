import 'package:flutter_test/flutter_test.dart';
import 'package:energy_guard/main.dart';

void main() {
  testWidgets('EnergyGuardApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const EnergyGuardApp());
    expect(find.text('ENERGY GUARD'), findsOneWidget);
    expect(find.text('Acesse sua Conta'), findsOneWidget);
  });
}

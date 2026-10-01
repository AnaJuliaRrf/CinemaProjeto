// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bank/main.dart';

void main() {
  testWidgets('cadastra ingresso e atualiza a lista apos um segundo', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const CinemaApp());
    await tester.tap(find.text('Ver ingressos'));
    await tester.pumpAndSettle();

    expect(find.text('Sala 3'), findsOneWidget);
    expect(find.text('Sala 5'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), '18,90');
    await tester.enterText(find.byType(TextField).at(1), '8');
    await tester.tap(find.text('Salvar ingresso'));
    await tester.pumpAndSettle();

    expect(find.text('Sala 8'), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Sala 8'), findsOneWidget);
    expect(find.textContaining('18,90'), findsOneWidget);
  });
}

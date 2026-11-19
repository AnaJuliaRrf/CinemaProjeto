import 'package:cinema/main.dart';
import 'package:cinema/repository/ingresso_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

/// Testes de interface com banco e API simulados
/// (o sqflite real só roda no emulador/aparelho).
void main() {
  late FakeApi api;
  late IngressoRepository repository;

  setUp(() {
    api = FakeApi();
    repository = IngressoRepository(banco: FakeBanco(), api: api);
  });

  Future<void> abrirLista(WidgetTester tester) async {
    await tester.pumpWidget(CinemaApp(repository: repository));
    await tester.tap(find.text('Ver ingressos'));
    await tester.pumpAndSettle();
  }

  Future<void> cadastrar(WidgetTester tester, String valor, String sala) async {
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), valor);
    await tester.enterText(find.byType(TextField).at(1), sala);
    await tester.tap(find.text('Salvar ingresso'));
    await tester.pumpAndSettle();
  }

  testWidgets('com a API no ar, cadastra e mostra "Sincronizado"',
      (tester) async {
    await abrirLista(tester);
    expect(find.text('Nenhum ingresso cadastrado ainda'), findsOneWidget);

    await cadastrar(tester, '18,90', '8');

    expect(find.text('Sala 8'), findsOneWidget);
    expect(find.textContaining('18,90'), findsOneWidget);
    expect(find.text('Sincronizado'), findsOneWidget);
    expect(find.text('Ingresso cadastrado e sincronizado'), findsOneWidget);
    expect(find.text('1 ingresso · 0 pendentes'), findsOneWidget);
  });

  testWidgets('com a API fora, cadastra e mostra "Pendente"', (tester) async {
    api.online = false;
    await abrirLista(tester);

    await cadastrar(tester, '25', '3');

    expect(find.text('Sala 3'), findsOneWidget);
    expect(find.text('Pendente'), findsOneWidget);
    expect(
      find.text('Sem conexão: ingresso salvo no aparelho como pendente'),
      findsOneWidget,
    );
    expect(find.text('1 ingresso · 1 pendente'), findsOneWidget);
  });

  testWidgets('"Sincronizar pendentes" transforma Pendente em Sincronizado',
      (tester) async {
    api.online = false;
    await abrirLista(tester);
    await cadastrar(tester, '25', '3');
    expect(find.text('Pendente'), findsOneWidget);

    api.online = true; // "volta a baseUrl correta"
    await tester.tap(find.text('Sincronizar pendentes'));
    await tester.pumpAndSettle();

    expect(find.text('Pendente'), findsNothing);
    expect(find.text('Sincronizado'), findsOneWidget);
    expect(find.text('1 ingresso sincronizado'), findsOneWidget);
    expect(find.text('1 ingresso · 0 pendentes'), findsOneWidget);
    expect(api.servidor, hasLength(1));
  });

  testWidgets('valida valor e sala antes de cadastrar', (tester) async {
    await abrirLista(tester);

    await cadastrar(tester, '0', '2.5');

    expect(
      find.text('Informe um valor e um número de sala válidos.'),
      findsOneWidget,
    );
    expect(api.postsRecebidos, 0);
  });
}

import 'package:cinema/repository/ingresso_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  late FakeBanco banco;
  late FakeApi api;
  late IngressoRepository repository;

  setUp(() {
    banco = FakeBanco();
    api = FakeApi();
    repository = IngressoRepository(banco: banco, api: api);
  });

  group('cadastrar', () {
    test('API ok → salvo no SQLite como sincronizado e enviado à API',
        () async {
      final resultado =
          await repository.cadastrar(valor: 18.9, numeroSala: 8);

      expect(resultado.sincronizado, isTrue);
      expect(resultado.erro, isNull);

      final locais = await repository.listar();
      expect(locais, hasLength(1));
      expect(locais.single.sincronizado, isTrue);
      expect(locais.single.idCliente, hasLength(36)); // UUID v4
      expect(api.servidor.keys, [locais.single.idCliente]);
    });

    test('API fora → não perde o cadastro, fica pendente', () async {
      api.online = false;

      final resultado =
          await repository.cadastrar(valor: 25, numeroSala: 3);

      expect(resultado.sincronizado, isFalse);
      expect(resultado.erro, 'sem conexão com a API');

      final locais = await repository.listar();
      expect(locais, hasLength(1));
      expect(locais.single.sincronizado, isFalse);
      expect(locais.single.valor, 25);
      expect(api.servidor, isEmpty);
    });

    test('erro 500 da API → fica pendente', () async {
      api.erroServidor = true;

      final resultado =
          await repository.cadastrar(valor: 12, numeroSala: 2);

      expect(resultado.sincronizado, isFalse);
      expect(resultado.erro, contains('500'));
      expect(await banco.listarPendentes(), hasLength(1));
    });

    test('listar devolve do mais recente para o mais antigo', () async {
      await repository.cadastrar(valor: 10, numeroSala: 1);
      api.online = false;
      await repository.cadastrar(valor: 20, numeroSala: 2);

      final lista = await repository.listar();
      expect(lista.map((i) => i.numeroSala), [2, 1]);
      expect(lista.map((i) => i.sincronizado), [false, true]);
    });
  });
}

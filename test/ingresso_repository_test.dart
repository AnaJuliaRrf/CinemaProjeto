import 'package:cinema/models/ingresso_cinema.dart';
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

  group('sincronizarPendentes', () {
    /// Cadastra [n] ingressos com a API fora (ficam pendentes).
    Future<void> cadastrarOffline(int n) async {
      api.online = false;
      for (var i = 1; i <= n; i++) {
        await repository.cadastrar(valor: 10.0 * i, numeroSala: i);
      }
      api.online = true;
    }

    test('envia os pendentes e marca como sincronizados', () async {
      await cadastrarOffline(2);

      final resultado = await repository.sincronizarPendentes();

      expect(resultado.enviados, 2);
      expect(resultado.pendentes, 0);
      expect(resultado.buscaRemotaOk, isTrue);
      expect(resultado.mensagem, '2 ingressos sincronizados');
      expect(await banco.listarPendentes(), isEmpty);
      expect(api.servidor, hasLength(2));
    });

    test('marca somente os confirmados pela API', () async {
      await cadastrarOffline(2);
      final [primeiro, segundo] = await banco.listarPendentes();
      api.falharPara.add(segundo.idCliente); // API responde 500 para este

      final resultado = await repository.sincronizarPendentes();

      expect(resultado.enviados, 1);
      expect(resultado.pendentes, 1);
      final pendentes = await banco.listarPendentes();
      expect(pendentes.single.idCliente, segundo.idCliente);
      expect(api.servidor.keys, [primeiro.idCliente]);
      expect(
        resultado.mensagem,
        '1 ingresso sincronizado. '
        '1 continua pendente: erro no servidor da API (500)',
      );
    });

    test('sincronizar duas vezes não duplica nada', () async {
      await repository.cadastrar(valor: 18.9, numeroSala: 8);
      await cadastrarOffline(2);

      await repository.sincronizarPendentes();
      final segunda = await repository.sincronizarPendentes();

      expect(segunda.enviados, 0);
      expect(segunda.pendentes, 0);
      expect(api.servidor, hasLength(3));
      final locais = await repository.listar();
      expect(locais, hasLength(3));
      expect(locais.map((i) => i.idCliente).toSet(), hasLength(3));
      expect(locais.every((i) => i.sincronizado), isTrue);
    });

    test('API fora: não lança exceção e mantém os pendentes', () async {
      await cadastrarOffline(3);
      api.online = false;

      final resultado = await repository.sincronizarPendentes();

      expect(resultado.enviados, 0);
      expect(resultado.pendentes, 3);
      expect(resultado.buscaRemotaOk, isFalse);
      expect(resultado.sucesso, isFalse);
      expect(
        resultado.mensagem,
        '3 continuam pendentes: sem conexão com a API',
      );
      expect(await repository.listar(), hasLength(3));
    });

    test('busca os ingressos remotos e grava no SQLite sem duplicar',
        () async {
      // Ingresso que existe só no PostgreSQL (ex.: cadastrado pelo Postman).
      api.servidor['remoto-1'] = const IngressoCinema(
        idCliente: 'remoto-1',
        valor: 30,
        numeroSala: 5,
        sincronizado: true,
      );

      final primeira = await repository.sincronizarPendentes();
      await repository.sincronizarPendentes();

      expect(primeira.recebidosDaApi, 1);
      expect(
        primeira.mensagem,
        'Nenhum ingresso pendente. Lista atualizada com a API',
      );
      final locais = await repository.listar();
      expect(locais, hasLength(1));
      expect(locais.single.idCliente, 'remoto-1');
      expect(locais.single.sincronizado, isTrue);
    });
  });
}

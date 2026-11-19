import 'package:cinema/models/ingresso_cinema.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IngressoCinema', () {
    test('novo() gera UUID v4 e começa pendente', () {
      final a = IngressoCinema.novo(valor: 18.9, numeroSala: 8);
      final b = IngressoCinema.novo(valor: 18.9, numeroSala: 8);

      expect(a.idCliente, isNot(b.idCliente));
      expect(a.idCliente, matches(RegExp(r'^[0-9a-f-]{36}$')));
      expect(a.sincronizado, isFalse);
    });

    test('toJson envia camelCase (idCliente, valor, numeroSala)', () {
      const ingresso =
          IngressoCinema(idCliente: 'abc', valor: 18.9, numeroSala: 8);

      expect(ingresso.toJson(), {
        'idCliente': 'abc',
        'valor': 18.9,
        'numeroSala': 8,
      });
    });

    test('fromJson lê snake_case e valor como String (numeric do Postgres)', () {
      final ingresso = IngressoCinema.fromJson({
        'id': 1,
        'id_cliente': 'abc',
        'valor': '18.90',
        'numero_sala': 8,
      });

      expect(ingresso.idCliente, 'abc');
      expect(ingresso.valor, 18.9);
      expect(ingresso.numeroSala, 8);
      expect(ingresso.sincronizado, isTrue);
      expect(ingresso.id, isNull, reason: 'id remoto não é a chave local');
    });

    test('fromJson também aceita valor numérico', () {
      final ingresso = IngressoCinema.fromJson(
        {'id_cliente': 'abc', 'valor': 25, 'numero_sala': 3},
      );
      expect(ingresso.valor, 25.0);
    });

    test('toMap/fromMap preservam os dados e o estado de sincronização', () {
      const original = IngressoCinema(
        id: 7,
        idCliente: 'abc',
        valor: 30,
        numeroSala: 5,
        sincronizado: true,
      );

      final map = original.toMap();
      expect(map['sincronizado'], 1);
      expect(map['id_cliente'], 'abc');

      final lido = IngressoCinema.fromMap(map);
      expect(lido.id, 7);
      expect(lido.valor, 30.0);
      expect(lido.numeroSala, 5);
      expect(lido.sincronizado, isTrue);
    });
  });
}

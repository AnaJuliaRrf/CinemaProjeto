import 'dart:convert';

import 'package:cinema/models/ingresso_cinema.dart';
import 'package:cinema/services/api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _url = 'https://teste.local';
const _ingresso = IngressoCinema(idCliente: 'abc', valor: 18.9, numeroSala: 8);

http.Response _json(Object corpo, int status) => http.Response(
      jsonEncode(corpo),
      status,
      headers: {'content-type': 'application/json'},
    );

void main() {
  test('GET /ingressos converte snake_case e valor em String', () async {
    final api = ApiService(
      baseUrl: _url,
      cliente: MockClient((req) async {
        expect(req.method, 'GET');
        expect(req.url.toString(), '$_url/ingressos');
        return _json([
          {'id': 1, 'id_cliente': 'abc', 'valor': '18.90', 'numero_sala': 8},
        ], 200);
      }),
    );

    final lista = await api.buscarIngressos();

    expect(lista, hasLength(1));
    expect(lista.first.valor, 18.9);
    expect(lista.first.numeroSala, 8);
    expect(lista.first.sincronizado, isTrue);
  });

  test('POST /ingressos envia camelCase com Content-Type JSON (201)', () async {
    final api = ApiService(
      baseUrl: _url,
      cliente: MockClient((req) async {
        expect(req.method, 'POST');
        expect(req.headers['Content-Type'], startsWith('application/json'));
        expect(jsonDecode(req.body), {
          'idCliente': 'abc',
          'valor': 18.9,
          'numeroSala': 8,
        });
        return _json({
          'mensagem': 'Ingresso cadastrado com sucesso',
          'ingresso': {
            'id': 1,
            'id_cliente': 'abc',
            'valor': '18.90',
            'numero_sala': 8,
          },
        }, 201);
      }),
    );

    final salvo = await api.enviarIngresso(_ingresso);
    expect(salvo.idCliente, 'abc');
  });

  test('POST com 200 (idCliente já existia) também é sucesso', () async {
    final api = ApiService(
      baseUrl: _url,
      cliente: MockClient((_) async => _json({
            'mensagem': 'Ingresso já estava sincronizado',
            'ingresso': {
              'id': 1,
              'id_cliente': 'abc',
              'valor': '18.90',
              'numero_sala': 8,
            },
          }, 200)),
    );

    expect((await api.enviarIngresso(_ingresso)).idCliente, 'abc');
  });

  test('status 400/500 lança ApiException com a mensagem da API', () async {
    for (final status in [400, 500]) {
      final api = ApiService(
        baseUrl: _url,
        cliente: MockClient((_) async => _json({'erro': 'falhou'}, status)),
      );

      await expectLater(
        api.enviarIngresso(_ingresso),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', status)
            .having((e) => e.mensagem, 'mensagem', 'falhou')),
      );
    }
  });
}

import 'dart:io';

import 'package:cinema/database/database_helper.dart';
import 'package:cinema/models/ingresso_cinema.dart';
import 'package:cinema/services/api_service.dart';
import 'package:sqflite/sqflite.dart';

/// Banco simulado em memória, com as mesmas regras do SQLite real
/// (id_cliente único, lista do mais recente para o mais antigo).
class FakeBanco implements DatabaseHelper {
  final List<IngressoCinema> linhas = [];
  int _proximoId = 1;

  @override
  Future<Database> get database => throw UnimplementedError();

  @override
  Future<int> inserir(IngressoCinema ingresso) async {
    if (linhas.any((l) => l.idCliente == ingresso.idCliente)) {
      throw StateError('UNIQUE constraint failed: id_cliente');
    }
    final id = _proximoId++;
    linhas.add(ingresso.copyWith(id: id));
    return id;
  }

  @override
  Future<List<IngressoCinema>> listarTodos() async =>
      linhas.reversed.toList();

  @override
  Future<List<IngressoCinema>> listarPendentes() async =>
      linhas.where((l) => !l.sincronizado).toList();

  @override
  Future<int> marcarComoSincronizado(String idCliente) async {
    final i = linhas.indexWhere((l) => l.idCliente == idCliente);
    if (i < 0) return 0;
    linhas[i] = linhas[i].copyWith(sincronizado: true);
    return 1;
  }

  @override
  Future<void> inserirOuAtualizar(IngressoCinema ingresso) async {
    final i = linhas.indexWhere((l) => l.idCliente == ingresso.idCliente);
    if (i >= 0) {
      linhas[i] = IngressoCinema(
        id: linhas[i].id,
        idCliente: ingresso.idCliente,
        valor: ingresso.valor,
        numeroSala: ingresso.numeroSala,
        sincronizado: ingresso.sincronizado,
      );
    } else {
      linhas.add(ingresso.copyWith(id: _proximoId++));
    }
  }
}

/// API simulada: guarda os ingressos como o PostgreSQL faria
/// (sem duplicar idCliente) e permite simular API fora do ar.
class FakeApi implements ApiService {
  final Map<String, IngressoCinema> servidor = {};

  /// false = simula URL inválida / sem internet.
  bool online = true;

  /// true = a API responde 500 a todo POST (servidor no ar, mas com erro).
  bool erroServidor = false;

  /// idClientes que a API vai recusar com erro 500.
  final Set<String> falharPara = {};

  int postsRecebidos = 0;

  @override
  Future<IngressoCinema> enviarIngresso(IngressoCinema ingresso) async {
    if (!online) throw const SocketException('Failed host lookup');
    postsRecebidos++;
    if (erroServidor || falharPara.contains(ingresso.idCliente)) {
      throw const ApiException('Erro Interno do Servidor...', statusCode: 500);
    }
    // on conflict (id_cliente) do nothing → idempotente
    return servidor.putIfAbsent(
      ingresso.idCliente,
      () => ingresso.copyWith(sincronizado: true),
    );
  }

  @override
  Future<List<IngressoCinema>> buscarIngressos() async {
    if (!online) throw const SocketException('Failed host lookup');
    return servidor.values
        .map((i) => IngressoCinema(
              idCliente: i.idCliente,
              valor: i.valor,
              numeroSala: i.numeroSala,
              sincronizado: true,
            ))
        .toList();
  }
}

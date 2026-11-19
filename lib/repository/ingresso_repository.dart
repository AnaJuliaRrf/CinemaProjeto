import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../database/database_helper.dart';
import '../models/ingresso_cinema.dart';
import '../services/api_service.dart';

/// Resultado de um cadastro, para a tela mostrar a mensagem certa.
class ResultadoCadastro {
  final IngressoCinema ingresso;

  /// Motivo de ter ficado pendente (null quando sincronizou).
  final String? erro;

  const ResultadoCadastro(this.ingresso, {this.erro});

  bool get sincronizado => ingresso.sincronizado;
}

/// Ponto único de acesso aos dados de ingressos.
///
/// As telas só falam com o Repository. É aqui (e só aqui) que se decide
/// entre o SQLite do aparelho e a API (que grava no PostgreSQL).
/// Estratégia offline-first: a lista vem sempre do SQLite.
class IngressoRepository {
  final DatabaseHelper _banco;
  final ApiService _api;

  IngressoRepository({DatabaseHelper? banco, ApiService? api})
      : _banco = banco ?? DatabaseHelper.instance,
        _api = api ?? ApiService();

  /// Lista sempre do SQLite (funciona sem internet).
  Future<List<IngressoCinema>> listar() => _banco.listarTodos();

  /// Cadastra um ingresso sem nunca perdê-lo:
  /// 1. gera o idCliente (UUID v4) e grava no SQLite como pendente;
  /// 2. tenta enviar à API;
  /// 3. se a API confirmou (200/201), marca como sincronizado;
  ///    se falhou (sem rede, timeout, erro do servidor), continua pendente.
  ///
  /// Gravar antes de enviar garante que o registro não se perde nem se o
  /// app for fechado durante a chamada de rede.
  Future<ResultadoCadastro> cadastrar({
    required double valor,
    required int numeroSala,
  }) async {
    final novo = IngressoCinema.novo(valor: valor, numeroSala: numeroSala);
    final id = await _banco.inserir(novo);
    final pendente = novo.copyWith(id: id);

    try {
      await _api.enviarIngresso(pendente);
      await _banco.marcarComoSincronizado(pendente.idCliente);
      return ResultadoCadastro(pendente.copyWith(sincronizado: true));
    } on Exception catch (e) {
      return ResultadoCadastro(pendente, erro: descreverErro(e));
    }
  }

  /// Mensagem curta e amigável para cada tipo de falha.
  static String descreverErro(Object erro) {
    if (erro is SocketException || erro is http.ClientException) {
      return 'sem conexão com a API';
    }
    if (erro is TimeoutException) return 'a API demorou para responder';
    if (erro is ApiException) {
      return erro.statusCode != null && erro.statusCode! >= 500
          ? 'erro no servidor da API (${erro.statusCode})'
          : 'a API recusou os dados: ${erro.mensagem}';
    }
    if (erro is FormatException) return 'resposta inválida da API';
    return 'falha ao falar com a API';
  }
}

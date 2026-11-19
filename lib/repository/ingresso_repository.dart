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

/// Resumo da sincronização manual, para a tela exibir num SnackBar.
class ResultadoSincronizacao {
  /// Pendentes enviados e confirmados pela API nesta rodada.
  final int enviados;

  /// Quantos continuam pendentes no aparelho depois da rodada.
  final int pendentes;

  /// Se o GET /ingressos (busca dos registros remotos) funcionou.
  final bool buscaRemotaOk;

  /// Quantos ingressos a API devolveu no GET /ingressos.
  final int recebidosDaApi;

  /// Motivo da falha mais relevante (null se deu tudo certo).
  final String? erro;

  const ResultadoSincronizacao({
    required this.enviados,
    required this.pendentes,
    required this.buscaRemotaOk,
    this.recebidosDaApi = 0,
    this.erro,
  });

  bool get sucesso => pendentes == 0 && buscaRemotaOk;

  String get mensagem {
    final partes = <String>[];
    if (enviados > 0) {
      partes.add(enviados == 1
          ? '1 ingresso sincronizado'
          : '$enviados ingressos sincronizados');
    }
    if (pendentes > 0) {
      final texto = pendentes == 1
          ? '1 continua pendente'
          : '$pendentes continuam pendentes';
      partes.add(erro == null ? texto : '$texto: $erro');
    } else if (!buscaRemotaOk) {
      partes.add('não foi possível buscar os ingressos da API'
          '${erro == null ? '' : ': $erro'}');
    }
    if (partes.isEmpty) {
      partes.add('Nenhum ingresso pendente. Lista atualizada com a API');
    }
    final frase = partes.join('. ');
    return frase[0].toUpperCase() + frase.substring(1);
  }
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
    } catch (e) {
      return ResultadoCadastro(pendente, erro: descreverErro(e));
    }
  }

  /// Sincronização manual (botão "Sincronizar pendentes"):
  /// 1. envia, um por um, os ingressos com sincronizado = 0;
  /// 2. marca como sincronizado apenas os que a API confirmou;
  /// 3. busca os ingressos remotos (GET /ingressos) e grava no SQLite
  ///    com sincronizado = 1, usando id_cliente como chave (sem duplicar).
  ///
  /// Nunca lança exceção por falha de rede: devolve um resumo. Se a API
  /// estiver inacessível, para na primeira falha de conexão (não adianta
  /// esperar o timeout de cada pendente) e mantém os demais pendentes.
  Future<ResultadoSincronizacao> sincronizarPendentes() async {
    final pendentes = await _banco.listarPendentes();
    var enviados = 0;
    String? erro;
    var semConexao = false;

    for (final ingresso in pendentes) {
      try {
        await _api.enviarIngresso(ingresso);
        await _banco.marcarComoSincronizado(ingresso.idCliente);
        enviados++;
      } catch (e) {
        erro = descreverErro(e);
        if (_ehFalhaDeConexao(e)) {
          semConexao = true;
          break;
        }
        // Erro só deste registro (ex.: 400/500): segue para o próximo.
      }
    }

    var buscaRemotaOk = false;
    var recebidos = 0;
    if (!semConexao) {
      try {
        final remotos = await _api.buscarIngressos();
        for (final remoto in remotos) {
          await _banco.inserirOuAtualizar(remoto);
        }
        buscaRemotaOk = true;
        recebidos = remotos.length;
      } catch (e) {
        erro ??= descreverErro(e);
      }
    }

    final restantes = await _banco.listarPendentes();
    return ResultadoSincronizacao(
      enviados: enviados,
      pendentes: restantes.length,
      buscaRemotaOk: buscaRemotaOk,
      recebidosDaApi: recebidos,
      erro: erro,
    );
  }

  static bool _ehFalhaDeConexao(Object erro) =>
      erro is SocketException ||
      erro is http.ClientException ||
      erro is TimeoutException;

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

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/ingresso_cinema.dart';

/// URL base da API cinema-api publicada no Render.
/// Troque aqui (e só aqui). No Teste 2, coloque um endereço inválido,
/// por exemplo 'https://api-invalida.onrender.com', para simular a API fora.
const String urlBaseApi = 'https://cinemaprojeto.onrender.com';

/// Erro de resposta da API (status diferente de 200/201 ou corpo inesperado).
class ApiException implements Exception {
  final String mensagem;
  final int? statusCode;

  const ApiException(this.mensagem, {this.statusCode});

  @override
  String toString() => statusCode == null
      ? 'ApiException: $mensagem'
      : 'ApiException($statusCode): $mensagem';
}

/// Somente comunicação HTTP com a API: sem regra de negócio e sem SQLite.
/// Erros de rede (SocketException, TimeoutException, http.ClientException)
/// são repassados para quem chamou (o Repository) decidir o que fazer.
class ApiService {
  static const Duration tempoLimite = Duration(seconds: 8);
  static const Map<String, String> _cabecalhos = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  final http.Client _cliente;
  final String _baseUrl;

  ApiService({http.Client? cliente, String baseUrl = urlBaseApi})
      : _cliente = cliente ?? http.Client(),
        _baseUrl = baseUrl;

  Uri get _uriIngressos => Uri.parse('$_baseUrl/ingressos');

  /// GET /ingressos → lista de ingressos gravados no PostgreSQL.
  Future<List<IngressoCinema>> buscarIngressos() async {
    final resposta = await _cliente
        .get(_uriIngressos, headers: _cabecalhos)
        .timeout(tempoLimite);
    _verificarStatus(resposta);

    final dados = _decodificar(resposta);
    if (dados is! List) {
      throw const ApiException('Resposta inesperada do GET /ingressos');
    }
    // Registros sem id_cliente (gravados antes dessa coluna existir) são
    // ignorados: sem a chave não dá para relacioná-los sem duplicar.
    return dados
        .whereType<Map<String, dynamic>>()
        .where((item) =>
            item['id_cliente'] is String &&
            (item['id_cliente'] as String).isNotEmpty)
        .map(IngressoCinema.fromJson)
        .toList();
  }

  /// POST /ingressos. A API responde 201 (criado) ou 200 (idCliente já
  /// existia, não duplica); os dois são sucesso.
  Future<IngressoCinema> enviarIngresso(IngressoCinema ingresso) async {
    final resposta = await _cliente
        .post(
          _uriIngressos,
          headers: _cabecalhos,
          body: jsonEncode(ingresso.toJson()),
        )
        .timeout(tempoLimite);
    _verificarStatus(resposta);

    // 200/201 = a API confirmou a gravação. Não dependemos do corpo da
    // resposta (versões antigas da API não devolvem id_cliente).
    return ingresso.copyWith(sincronizado: true);
  }

  void _verificarStatus(http.Response resposta) {
    if (resposta.statusCode == 200 || resposta.statusCode == 201) return;
    throw ApiException(
      _mensagemDeErro(resposta),
      statusCode: resposta.statusCode,
    );
  }

  String _mensagemDeErro(http.Response resposta) {
    try {
      final dados = _decodificar(resposta);
      if (dados is Map && dados['erro'] != null) return '${dados['erro']}';
    } on FormatException {
      // corpo não é JSON (ex.: página de erro do Render)
    }
    return 'Erro HTTP ${resposta.statusCode}';
  }

  dynamic _decodificar(http.Response resposta) =>
      jsonDecode(utf8.decode(resposta.bodyBytes));
}

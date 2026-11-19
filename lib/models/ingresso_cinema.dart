import 'package:uuid/uuid.dart';

/// Ingresso de cinema: valor do ingresso + número da sala.
///
/// - [id]: chave local do SQLite (nula enquanto não foi salvo no aparelho).
/// - [idCliente]: UUID v4 gerado no app. É a chave que liga o registro local
///   ao registro da API/PostgreSQL e evita duplicatas na sincronização.
/// - [sincronizado]: true quando a API confirmou o recebimento.
class IngressoCinema {
  final int? id;
  final String idCliente;
  final double valor;
  final int numeroSala;
  final bool sincronizado;

  const IngressoCinema({
    this.id,
    required this.idCliente,
    required this.valor,
    required this.numeroSala,
    this.sincronizado = false,
  });

  /// Cria um ingresso novo com um UUID v4 gerado no aparelho (ainda pendente).
  factory IngressoCinema.novo({required double valor, required int numeroSala}) {
    return IngressoCinema(
      idCliente: const Uuid().v4(),
      valor: valor,
      numeroSala: numeroSala,
    );
  }

  IngressoCinema copyWith({int? id, bool? sincronizado}) {
    return IngressoCinema(
      id: id ?? this.id,
      idCliente: idCliente,
      valor: valor,
      numeroSala: numeroSala,
      sincronizado: sincronizado ?? this.sincronizado,
    );
  }

  // ---------- SQLite (colunas em snake_case, sincronizado como 0/1) ----------

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'id_cliente': idCliente,
      'valor': valor,
      'numero_sala': numeroSala,
      'sincronizado': sincronizado ? 1 : 0,
    };
  }

  factory IngressoCinema.fromMap(Map<String, Object?> map) {
    return IngressoCinema(
      id: map['id'] as int?,
      idCliente: map['id_cliente'] as String,
      valor: _lerDouble(map['valor']),
      numeroSala: _lerInt(map['numero_sala']),
      sincronizado: map['sincronizado'] == 1,
    );
  }

  // ---------- API (POST envia camelCase; GET devolve snake_case) ----------

  /// Corpo do POST /ingressos.
  Map<String, dynamic> toJson() {
    return {
      'idCliente': idCliente,
      'valor': valor,
      'numeroSala': numeroSala,
    };
  }

  /// Objeto vindo da API: {"id", "id_cliente", "valor", "numero_sala"}.
  /// O "id" remoto é do PostgreSQL e não é usado como chave local.
  /// Se veio da API, por definição já está sincronizado.
  factory IngressoCinema.fromJson(Map<String, dynamic> json) {
    return IngressoCinema(
      idCliente: json['id_cliente'] as String,
      valor: _lerDouble(json['valor']),
      numeroSala: _lerInt(json['numero_sala']),
      sincronizado: true,
    );
  }

  /// O Postgres devolve numeric como String ("18.90"); aceita número também.
  static double _lerDouble(Object? valor) {
    if (valor is num) return valor.toDouble();
    if (valor is String) {
      final convertido = double.tryParse(valor.replaceAll(',', '.'));
      if (convertido != null) return convertido;
    }
    throw FormatException('Valor inválido: $valor');
  }

  static int _lerInt(Object? valor) {
    if (valor is int) return valor;
    if (valor is num) return valor.toInt();
    if (valor is String) {
      final convertido = int.tryParse(valor);
      if (convertido != null) return convertido;
    }
    throw FormatException('Número de sala inválido: $valor');
  }

  @override
  String toString() {
    return 'IngressoCinema{id: $id, idCliente: $idCliente, valor: $valor, '
        'numeroSala: $numeroSala, sincronizado: $sincronizado}';
  }
}

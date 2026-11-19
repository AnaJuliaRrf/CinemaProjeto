import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/ingresso_cinema.dart';

/// Acesso ao SQLite do aparelho (só SQL, nenhuma regra de negócio).
///
/// Singleton: use [DatabaseHelper.instance].
/// Observação: o sqflite não funciona no Flutter Web; rode no Android.
class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();

  static const String _nomeBanco = 'cinema.db';

  /// No 1º bimestre os ingressos ficavam só em memória (não havia SQLite),
  /// por isso o banco começa na versão 1. Se a estrutura mudar no futuro,
  /// aumente a versão e trate a migração em [_atualizar].
  static const int _versao = 1;

  static const String tabela = 'ingressos';

  Future<Database>? _banco;

  /// Abre o banco uma única vez (mesmo com chamadas simultâneas).
  Future<Database> get database => _banco ??= _abrir();

  Future<Database> _abrir() async {
    final caminho = join(await getDatabasesPath(), _nomeBanco);
    return openDatabase(
      caminho,
      version: _versao,
      onCreate: _criar,
      onUpgrade: _atualizar,
    );
  }

  Future<void> _criar(Database db, int versao) async {
    await db.execute('''
      CREATE TABLE $tabela (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        id_cliente TEXT UNIQUE NOT NULL,
        valor REAL NOT NULL,
        numero_sala INTEGER NOT NULL,
        sincronizado INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<void> _atualizar(Database db, int versaoAntiga, int versaoNova) async {
    // Exemplo para uma futura versão 2, sem perder dados:
    // if (versaoAntiga < 2) {
    //   await db.execute('ALTER TABLE $tabela ADD COLUMN nova_coluna TEXT');
    // }
  }

  /// Insere um ingresso novo. Retorna o id local gerado.
  Future<int> inserir(IngressoCinema ingresso) async {
    final db = await database;
    final dados = ingresso.toMap()..remove('id');
    return db.insert(tabela, dados, conflictAlgorithm: ConflictAlgorithm.abort);
  }

  /// Todos os ingressos, do mais recente para o mais antigo.
  Future<List<IngressoCinema>> listarTodos() async {
    final db = await database;
    final linhas = await db.query(tabela, orderBy: 'id DESC');
    return linhas.map(IngressoCinema.fromMap).toList();
  }

  /// Ingressos que ainda não foram confirmados pela API (sincronizado = 0),
  /// na ordem em que foram cadastrados.
  Future<List<IngressoCinema>> listarPendentes() async {
    final db = await database;
    final linhas = await db.query(
      tabela,
      where: 'sincronizado = ?',
      whereArgs: [0],
      orderBy: 'id ASC',
    );
    return linhas.map(IngressoCinema.fromMap).toList();
  }

  Future<int> marcarComoSincronizado(String idCliente) async {
    final db = await database;
    return db.update(
      tabela,
      {'sincronizado': 1},
      where: 'id_cliente = ?',
      whereArgs: [idCliente],
    );
  }

  /// Grava usando id_cliente como chave, sem criar duplicatas:
  /// se já existe, atualiza (mantendo o id local); se não existe, insere.
  Future<void> inserirOuAtualizar(IngressoCinema ingresso) async {
    final db = await database;
    final dados = ingresso.toMap()..remove('id');
    await db.transaction((txn) async {
      final alterados = await txn.update(
        tabela,
        dados,
        where: 'id_cliente = ?',
        whereArgs: [ingresso.idCliente],
      );
      if (alterados == 0) {
        await txn.insert(
          tabela,
          dados,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }
}

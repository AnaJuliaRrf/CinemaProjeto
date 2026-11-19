import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../components/indicador_sincronizacao.dart';
import '../../models/ingresso_cinema.dart';
import '../../repository/ingresso_repository.dart';
import 'formulario_ingresso.dart';

/// Listagem dos ingressos. Os dados vêm sempre do Repository (que lê do
/// SQLite do aparelho), então a lista funciona mesmo sem internet.
class ListaIngressos extends StatefulWidget {
  final IngressoRepository? repository;

  const ListaIngressos({super.key, this.repository});

  @override
  State<ListaIngressos> createState() => _ListaIngressosState();
}

class _ListaIngressosState extends State<ListaIngressos> {
  late final IngressoRepository _repository =
      widget.repository ?? IngressoRepository();

  final NumberFormat _formato = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
    decimalDigits: 2,
  );

  List<IngressoCinema> _ingressos = [];
  bool _carregando = true;

  int get _pendentes => _ingressos.where((i) => !i.sincronizado).length;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final ingressos = await _repository.listar();
    if (!mounted) return;
    setState(() {
      _ingressos = ingressos;
      _carregando = false;
    });
  }

  void _mostrarMensagem(String texto, {required bool sucesso}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(texto),
          backgroundColor:
              sucesso ? Colors.green.shade700 : Colors.orange.shade800,
        ),
      );
  }

  Future<void> _abreFormulario() async {
    final resultado = await Navigator.push<ResultadoCadastro>(
      context,
      MaterialPageRoute(
        builder: (context) => FormularioIngresso(repository: _repository),
      ),
    );

    if (resultado == null || !mounted) return;

    await _carregar();
    if (!mounted) return;

    _mostrarMensagem(
      resultado.sincronizado
          ? 'Ingresso cadastrado e sincronizado'
          : 'Sem conexão: ingresso salvo no aparelho como pendente',
      sucesso: resultado.sincronizado,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ingressos de Cinema')),
      body: Column(
        children: [
          _Resumo(total: _ingressos.length, pendentes: _pendentes),
          Expanded(child: _conteudo()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _abreFormulario,
        tooltip: 'Cadastrar ingresso',
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _conteudo() {
    if (_carregando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_ingressos.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.movie, size: 64, color: Colors.grey),
            SizedBox(height: 8),
            Text('Nenhum ingresso cadastrado ainda'),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: _ingressos.length,
      itemBuilder: (context, indice) {
        final ingresso = _ingressos[indice];

        return Card(
          child: ListTile(
            leading: const Icon(Icons.movie),
            title: Text('Sala ${ingresso.numeroSala}'),
            subtitle: Text(_formato.format(ingresso.valor)),
            trailing:
                IndicadorSincronizacao(sincronizado: ingresso.sincronizado),
          ),
        );
      },
    );
  }
}

/// Faixa com o total de ingressos e quantos ainda estão pendentes.
class _Resumo extends StatelessWidget {
  final int total;
  final int pendentes;

  const _Resumo({required this.total, required this.pendentes});

  @override
  Widget build(BuildContext context) {
    final temPendentes = pendentes > 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: temPendentes ? Colors.orange.shade50 : Colors.red.shade50,
      child: Text(
        '$total ${total == 1 ? 'ingresso' : 'ingressos'} · '
        '$pendentes ${pendentes == 1 ? 'pendente' : 'pendentes'}',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: temPendentes ? Colors.orange.shade900 : Colors.red.shade900,
        ),
      ),
    );
  }
}

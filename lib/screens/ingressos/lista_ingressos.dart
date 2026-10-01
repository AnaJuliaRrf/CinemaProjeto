import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/ingresso_cinema.dart';
import 'formulario_ingresso.dart';

class ListaIngressos extends StatefulWidget {
  const ListaIngressos({super.key});

  @override
  State<ListaIngressos> createState() => _ListaIngressosState();
}

class _ListaIngressosState extends State<ListaIngressos> {
  final List<IngressoCinema> _ingressos = [
    IngressoCinema(25.00, 3),
    IngressoCinema(30.00, 5),
  ];

  Future<void> _abreFormulario() async {
    final IngressoCinema? novoIngresso = await Navigator.push<IngressoCinema>(
      context,
      MaterialPageRoute(builder: (context) => const FormularioIngresso()),
    );

    if (novoIngresso == null || !mounted) return;

    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;

    setState(() {
      _ingressos.add(novoIngresso);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ingressos de Cinema')),
      body: ListView.builder(
        itemCount: _ingressos.length,
        itemBuilder: (context, indice) {
          final ingresso = _ingressos[indice];
          final formato = NumberFormat.currency(
            locale: 'pt_BR',
            symbol: 'R\$',
            decimalDigits: 2,
          );

          return Card(
            child: ListTile(
              leading: const Icon(Icons.movie),
              title: Text('Sala ${ingresso.numeroSala}'),
              subtitle: Text(formato.format(ingresso.ingresso)),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _abreFormulario,
        tooltip: 'Cadastrar ingresso',
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

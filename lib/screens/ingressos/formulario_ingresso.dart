import 'package:flutter/material.dart';
import '../../components/editor.dart';
import '../../models/ingresso_cinema.dart';

class FormularioIngresso extends StatefulWidget {
  const FormularioIngresso({super.key});

  @override
  State<FormularioIngresso> createState() => _FormularioIngressoState();
}

class _FormularioIngressoState extends State<FormularioIngresso> {
  final TextEditingController _controladorCampoIngresso =
      TextEditingController();
  final TextEditingController _controladorCampoNumeroSala =
      TextEditingController();

  @override
  void dispose() {
    _controladorCampoIngresso.dispose();
    _controladorCampoNumeroSala.dispose();
    super.dispose();
  }

  void _salvarIngresso() {
    final double? ingresso = double.tryParse(
      _controladorCampoIngresso.text.trim().replaceAll(',', '.'),
    );
    final int? numeroSala = int.tryParse(
      _controladorCampoNumeroSala.text.trim(),
    );

    if (ingresso == null ||
        ingresso <= 0 ||
        numeroSala == null ||
        numeroSala <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe um valor e um número de sala válidos.'),
        ),
      );
      return;
    }

    final novoIngresso = IngressoCinema(ingresso, numeroSala);
    Navigator.pop(context, novoIngresso);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Novo Ingresso')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Editor(
              controlador: _controladorCampoIngresso,
              rotulo: 'Valor do ingresso',
              dica: '25,00',
              icone: Icons.attach_money,
            ),
            Editor(
              controlador: _controladorCampoNumeroSala,
              rotulo: 'Número da sala',
              dica: '3',
              icone: Icons.movie,
            ),
            ElevatedButton(
              onPressed: _salvarIngresso,
              child: const Text('Salvar ingresso'),
            ),
          ],
        ),
      ),
    );
  }
}

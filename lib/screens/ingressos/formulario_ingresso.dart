import 'package:flutter/material.dart';
import '../../components/editor.dart';
import '../../repository/ingresso_repository.dart';

/// Formulário de cadastro. Valida os campos e pede ao Repository para
/// cadastrar; devolve o [ResultadoCadastro] para a lista mostrar a mensagem.
class FormularioIngresso extends StatefulWidget {
  final IngressoRepository repository;

  const FormularioIngresso({super.key, required this.repository});

  @override
  State<FormularioIngresso> createState() => _FormularioIngressoState();
}

class _FormularioIngressoState extends State<FormularioIngresso> {
  final TextEditingController _controladorCampoIngresso =
      TextEditingController();
  final TextEditingController _controladorCampoNumeroSala =
      TextEditingController();

  bool _salvando = false;

  @override
  void dispose() {
    _controladorCampoIngresso.dispose();
    _controladorCampoNumeroSala.dispose();
    super.dispose();
  }

  Future<void> _salvarIngresso() async {
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

    setState(() => _salvando = true);
    try {
      final resultado = await widget.repository.cadastrar(
        valor: ingresso,
        numeroSala: numeroSala,
      );
      if (!mounted) return;
      Navigator.pop(context, resultado);
    } catch (_) {
      // Só chega aqui se falhar o próprio SQLite do aparelho.
      if (!mounted) return;
      setState(() => _salvando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível salvar o ingresso no aparelho.'),
        ),
      );
    }
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
              onPressed: _salvando ? null : _salvarIngresso,
              child: _salvando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Salvar ingresso'),
            ),
          ],
        ),
      ),
    );
  }
}

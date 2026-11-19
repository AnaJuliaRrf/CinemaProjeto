import 'package:flutter/material.dart';

/// Etiqueta de estado do ingresso:
/// verde "Sincronizado" (já está na API) ou laranja "Pendente" (só no aparelho).
class IndicadorSincronizacao extends StatelessWidget {
  final bool sincronizado;

  const IndicadorSincronizacao({super.key, required this.sincronizado});

  @override
  Widget build(BuildContext context) {
    final cor = sincronizado ? Colors.green.shade700 : Colors.orange.shade800;
    final icone = sincronizado ? Icons.cloud_done : Icons.cloud_upload_outlined;
    final texto = sincronizado ? 'Sincronizado' : 'Pendente';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.12),
        border: Border.all(color: cor),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 16, color: cor),
          const SizedBox(width: 4),
          Text(
            texto,
            style: TextStyle(
              color: cor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

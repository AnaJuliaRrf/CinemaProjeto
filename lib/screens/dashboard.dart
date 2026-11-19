import 'package:flutter/material.dart';
import '../repository/ingresso_repository.dart';
import './ingressos/lista_ingressos.dart';

class Dashboard extends StatelessWidget {
  final IngressoRepository? repository;

  const Dashboard({super.key, this.repository});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cinema')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.movie, size: 88, color: Colors.red.shade900),
            const SizedBox(height: 16),
            const Text(
              'Ingressos de Cinema',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        ListaIngressos(repository: repository),
                  ),
                );
              },
              icon: const Icon(Icons.movie),
              label: const Text('Ver ingressos'),
            ),
          ],
        ),
      ),
    );
  }
}

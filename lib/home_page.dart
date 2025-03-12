import 'package:flutter/material.dart';
import 'package:transcriber_whisper/new_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home Page'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'Bienvenido a la aplicación de transcripción',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => NewPage()),
                );
              },
              child: const Text('Ir a Nueva Página'),
            ),
          ],
        ),
      ),
    );
  }
}
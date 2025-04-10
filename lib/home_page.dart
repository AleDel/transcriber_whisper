import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //appBar: AppBar(title: Text('Audio Transcriber')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              // botones transcribir, etc
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                runAlignment: WrapAlignment.center,
                spacing: 20,runSpacing: 20,
                children: [
                  ElevatedButton(onPressed: () async => Navigator.pushNamed(context, '/testCompare'), child: const Text('prueba_diff')),
                  ElevatedButton(onPressed: () async => Navigator.pushNamed(context, '/EUTextPage'), child: const Text('ITSAS IZARRAK*')),
                  ElevatedButton(onPressed: () async => Navigator.pushNamed(context, '/EUPage'), child: const Text('ITSAS IZARRAK')),
                  ElevatedButton(onPressed: () async => Navigator.pushNamed(context, '/ESPage'), child: const Text('LA TORTUGA KALI')),
                  ElevatedButton(onPressed: () async => Navigator.pushNamed(context, '/TrascribePage'), child: const Text('TrascribePage')),
                  ElevatedButton(onPressed: () async => Navigator.pushNamed(context, '/DemoPage'), child: const Text('DemoPage')),
                  ElevatedButton(onPressed: () async => Navigator.pushNamed(context, '/DiffTextPage'), child: const Text('DiffTextPage')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

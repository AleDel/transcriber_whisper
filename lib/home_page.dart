import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';

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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            // botones transcribir, etc
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(onPressed: () async => Navigator.pushNamed(context, '/EUTextPage'), child: const Text('ITSAS IZARRAK*')),
                ElevatedButton(onPressed: () async => Navigator.pushNamed(context, '/EUPage'), child: const Text('ITSAS IZARRAK')),
                ElevatedButton(onPressed: () async => Navigator.pushNamed(context, '/ESPage'), child: const Text('LA TORTUGA KALI')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

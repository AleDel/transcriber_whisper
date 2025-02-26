/*
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
  List<Map<String, dynamic>> _transcription = [];
  bool _isLoading = false;

  Future<void> _transcribeAudio(File audioFile) async {
    setState(() {
      _isLoading = true;
      _transcription = [];
    });

    try {
      var request = http.MultipartRequest('POST', Uri.parse('http://127.0.0.1:5000/transcribe'));
      request.files.add(await http.MultipartFile.fromPath('audio', audioFile.path));

      var response = await request.send();

      if (response.statusCode == 200) {
        var responseBody = await response.stream.bytesToString();
        var data = jsonDecode(responseBody);
        setState(() {
          _transcription = List<Map<String, dynamic>>.from(data['transcription']);
        });
      } else {
        print('Error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickAudioFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.audio);

    if (result != null) {
      File file = File(result.files.single.path!);
      _transcribeAudio(file);
    } else {
      // User canceled the picker
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Audio Transcriber')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ElevatedButton(onPressed: _pickAudioFile, child: Text('Pick Audio File')),
            SizedBox(height: 20),
            _isLoading
                ? CircularProgressIndicator()
                : Expanded(
                  child: ListView.builder(
                    itemCount: _transcription.length,
                    itemBuilder: (context, index) {
                      var wordData = _transcription[index];
                      return ListTile(title: Text('${wordData['word']}'), subtitle: Text('Start: ${wordData['start'].toStringAsFixed(2)}, End: ${wordData['end'].toStringAsFixed(2)}, Probability: ${wordData['probability'].toStringAsFixed(4)}'));
                    },
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
*/

import 'package:flutter/material.dart';
import 'package:transcriber_whisper/models/transcription_model.dart';

class SimpleWordsWidget extends StatelessWidget {
  final Transcription transcription;

  const SimpleWordsWidget({Key? key, required this.transcription}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Palabras del texto escrito (realsegments)
        if (transcription.realsegments != null)
          Wrap(
            children: transcription.realsegments!.map((segment) {
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  segment.word,
                  style: const TextStyle(fontSize: 18),
                ),
              );
            }).toList(),
          ),
        const SizedBox(height: 20), // Espacio entre las filas
        // Palabras de la transcripción (segments)
        Wrap(
          children: transcription.transsegments.map((segment) {
            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                segment.word,
                style: const TextStyle(fontSize: 16, color: Colors.blue),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
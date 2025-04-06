import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:transcriber_whisper/transcription_cubit.dart';
import 'package:transcriber_whisper/transcription_state.dart';
import 'package:transcriber_whisper/models/word_with_spans.dart';

import '../models/segment.dart';

class FormattedTextWidget extends StatelessWidget {
  const FormattedTextWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TranscriptionCubit, TranscriptionState>(
      builder: (context, state) {
        // Asegúrate de que el texto formateado esté disponible
        if (state.textoRealformadoparrafos == null || state.textoRealformadoparrafos!.isEmpty) {
          return const Center(child: Text('No hay texto para mostrar'));
        }
        if (state.transcription == null || state.transcription!.audioTranscriptionSegments.isEmpty) {
          return const Center(child: Text('No hay transcripción para mostrar'));
        }
        final formattedText = state.textoRealformadoparrafos!;
        final transsegments = state.transcription!.audioTranscriptionSegments;
        // 1. Dividir el Texto Real en Párrafos
        final paragraphs = formattedText.split('\n\n');

        // 2. Construir los Widgets de los Párrafos
        List<Widget> paragraphWidgets = [];
        for (String paragraph in paragraphs) {
          // 3. Dividir cada Párrafo en Palabras
          final realWords = paragraph.split(RegExp(r'\s+'));

          // 4. Asociar Palabras con WordWithSpans
          List<Widget> wordWidgets = [];
          int transIndex = 0;
          for (int i = 0; i < realWords.length; i++) {
            String realWord = realWords[i];
            String transWord = "";
            if (transIndex < transsegments.length) {
              transWord = transsegments[transIndex].word;
            }
            // Buscar la correspondencia en el resultado de diff
            var wordWithSpan = transsegments.firstWhere(
              (element) => element.word.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '') == realWord.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), ''),
              orElse: () => Segment(start: 0, end: 0, word: "", probability: 0),
            );
            if (wordWithSpan.word.isEmpty) {
              wordWithSpan = transsegments.firstWhere(
                (element) => element.word.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '') == realWord.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), ''),
                orElse: () => Segment(start: 0, end: 0, word: "", probability: 0),
              );
            }
            if (wordWithSpan.word.isNotEmpty) {
              transIndex++;
            }
            // 5. Construir el Widget de la Palabra
            wordWidgets.add(
              Column(
                children: [
                  Text(realWord, style: const TextStyle(fontSize: 16.0)),
                  Text(wordWithSpan.word.isEmpty ? "" : wordWithSpan.word, style: const TextStyle(fontSize: 12.0, color: Colors.grey)),
                ],
              ),
            );
            wordWidgets.add(const SizedBox(width: 5));
          }

          // 6. Añadir el Wrap de Palabras al Párrafo
          paragraphWidgets.add(Wrap(alignment: WrapAlignment.start, children: wordWidgets));
          paragraphWidgets.add(const SizedBox(height: 26)); // Espacio entre párrafos
        }

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: paragraphWidgets)),
          ),
        );
      },
    );
  }
}

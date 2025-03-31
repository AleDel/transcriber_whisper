import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:transcriber_whisper/transcribe_cubit.dart';
import 'package:transcriber_whisper/transcribe_state.dart';
import 'package:transcriber_whisper/models/word_with_spans.dart';

class FormattedTextWidget extends StatelessWidget {
  const FormattedTextWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TranscribeCubit, TranscribeState>(
      builder: (context, state) {
        // Asegúrate de que el texto formateado esté disponible
        if (state.textoRealformadoparrafos == null ||
            state.textoRealformadoparrafos!.isEmpty) {
          return const Center(child: Text('No hay texto para mostrar'));
        }
        if (state.transcription == null ||
            state.transcription!.transsegments.isEmpty) {
          return const Center(child: Text('No hay transcripción para mostrar'));
        }
        final formattedText = state.textoRealformadoparrafos!;
        final wordsWithSpans = state.wordsWithSpans; // Accedemos a wordsWithSpans directamente
        // 1. Dividir el Texto Real en Párrafos
        final paragraphs = formattedText.split('\n\n');

        // 2. Construir los Widgets de los Párrafos
        List<Widget> paragraphWidgets = [];
        int wordWithSpansIndex = 0; // Mantenemos el índice fuera del bucle de párrafos
        for (String paragraph in paragraphs) {
          // 3. Dividir cada Párrafo en Palabras y Signos de Puntuación
          final realWords = paragraph.split(RegExp(r"\b"));

          // Imprimir el inicio del párrafo en la consola
          print("-------------------- Inicio del Párrafo --------------------");

          // 4. Asociar Palabras con WordWithSpans
          List<Widget> wordWidgets = [];
          for (int i = 0; i < realWords.length; i++) {
            String realWord = realWords[i];
            if (realWord.trim().isEmpty) continue;
            WordWithSpans? wordWithSpan;
            if (wordWithSpansIndex < wordsWithSpans.length) {
              wordWithSpan = wordsWithSpans[wordWithSpansIndex];
            }

            // Imprimir las palabras en la consola
            String transWord = wordWithSpan == null ? "" : wordWithSpan.spans.map((e) => e.toPlainText()).join();
            print("Real: '$realWord' - Transcripción: '$transWord'");
            Widget? transWordWidget;
            if (RegExp(r"[.,!?;:—]").hasMatch(realWord)) {
              transWordWidget = const Text("");
            } else {
              transWordWidget = wordWithSpan == null
                  ? const Text("")
                  : Column(
                children: wordWithSpan.spans
                    .map((span) => Text.rich(span,
                    style: const TextStyle(fontSize: 12.0)))
                    .toList(),
              );
              if (wordWithSpansIndex < wordsWithSpans.length) {
                wordWithSpansIndex++;
              }
            }

            // 5. Construir el Widget de la Palabra
            wordWidgets.add(
              Column(
                children: [
                  Text(realWord, style: const TextStyle(fontSize: 16.0)),
                  transWordWidget,
                ],
              ),
            );
            wordWidgets.add(const SizedBox(width: 5));
          }

          // Imprimir el fin del párrafo en la consola
          print("-------------------- Fin del Párrafo --------------------\n");

          // 6. Añadir el Wrap de Palabras al Párrafo
          paragraphWidgets.add(
              Wrap(alignment: WrapAlignment.start, children: wordWidgets));
          paragraphWidgets.add(const SizedBox(height: 26)); // Espacio entre párrafos
        }

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: paragraphWidgets)),
          ),
        );
      },
    );
  }
}
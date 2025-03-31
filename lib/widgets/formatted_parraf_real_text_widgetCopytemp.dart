import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:transcriber_whisper/transcribe_cubit.dart';
import 'package:transcriber_whisper/transcribe_state.dart';
import 'package:transcriber_whisper/models/word_with_spans.dart';

class FormattedTextWidget extends StatefulWidget {
  const FormattedTextWidget({Key? key}) : super(key: key);

  @override
  State<FormattedTextWidget> createState() => _FormattedTextWidgetState();
}

class _FormattedTextWidgetState extends State<FormattedTextWidget> {
  final GlobalKey _textKey = GlobalKey();
  List<int> _wordStartPositions = [];

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
        for (String paragraph in paragraphs) {
          int wordWithSpansIndex = 0;
          // 3. Dividir cada Párrafo en Palabras y Signos de Puntuación
          final realWords = paragraph.split(RegExp(r"\b"));

          // Imprimir el inicio del párrafo en la consola
          print("-------------------- Inicio del Párrafo --------------------");

          // 4. Asociar Palabras con WordWithSpans
          List<Widget> wordWidgets = [];
          for (int i = 0; i < realWords.length; i++) {
            String realWord = realWords[i];
            if (realWord.trim().isEmpty) continue;

            // Buscar el WordWithSpans asociado a esta realWord
            WordWithSpans? associatedWord;
            int associatedWordIndex = -1;
            for (int j = wordWithSpansIndex; j < wordsWithSpans.length; j++) {
              WordWithSpans currentWordWithSpan = wordsWithSpans[j];
              if (currentWordWithSpan.realWord.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '') ==
                  realWord.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '')) {
                associatedWord = currentWordWithSpan;
                associatedWordIndex = j;
                wordWithSpansIndex = j + 1;
                break;
              }
            }

            // Imprimir las palabras en la consola
            String transWord = associatedWord == null
                ? ""
                : associatedWord.spans.map((e) => e.toPlainText()).join();
            print("Real: '$realWord' - Transcripción: '$transWord' - Index: $associatedWordIndex");

            Widget? transWordWidget;
            if (RegExp(r"[.,!?;:—]").hasMatch(realWord)) {
              transWordWidget = const Text("");
            } else {
              if (associatedWord != null) {
                transWordWidget = Column(
                  children: associatedWord.spans
                      .asMap()
                      .entries
                      .map((entry) {
                    final spanIndex = entry.key;
                    final span = entry.value;
                    return GestureDetector(
                      onTapDown: (details) {
                        final RenderObject? renderObject = _textKey.currentContext?.findRenderObject();
                        if (renderObject is RenderBox) {
                          final localPosition = renderObject.globalToLocal(details.globalPosition);
                          final int wordIndex = associatedWordIndex;
                          if(wordIndex != -1){
                            final String word = associatedWord!.spans[spanIndex].toPlainText();
                            print("Clicked word: '$word' - Index: $wordIndex");
                            context.read<TranscribeCubit>().forceCurrentWord(wordIndex);
                          }
                        }
                      },
                      child: Text.rich(
                        TextSpan(
                          text: span.toPlainText(),
                          style: span.style,
                          children: [
                            TextSpan(
                              text: '[$associatedWordIndex]',
                              style: const TextStyle(
                                  fontSize: 10.0, color: Colors.grey),
                            ),
                          ],
                        ),
                        style: const TextStyle(fontSize: 12.0),
                      ),
                    );
                  }).toList(),
                );
              } else {
                transWordWidget = const Text("");
              }
            }

            // 5. Construir el Widget de la Palabra
            wordWidgets.add(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(realWord, style: const TextStyle(fontSize: 16.0)),
                      Text(
                        associatedWordIndex != -1 ? '[$associatedWordIndex]' : '',
                        style: const TextStyle(fontSize: 10.0, color: Colors.grey),
                      ),
                    ],
                  ),
                  transWordWidget ?? const SizedBox.shrink(),
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
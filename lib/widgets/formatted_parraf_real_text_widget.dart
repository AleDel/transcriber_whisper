import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:transcriber_whisper/transcription_cubit.dart';
import 'package:transcriber_whisper/transcription_state.dart';
import 'package:transcriber_whisper/models/word_with_spans.dart';
import 'package:get_it/get_it.dart';

import '../transcription_widget_abstract.dart';

final getIt = GetIt.instance;

class FormattedTextWidget extends TranscriptionWidget {
  const FormattedTextWidget({Key? key, required super.transcription, required super.audioPosition, required super.currentWordIndex, required super.onWordTap}) : super(key: key);

  @override
  State<FormattedTextWidget> createState() => _FormattedTextWidgetState();
}

class _FormattedTextWidgetState extends TranscriptionWidgetState<FormattedTextWidget> {
  final GlobalKey _currentWordKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();
  int? _selectionStart;
  int? _selectionEnd;

  @override
  void initState() {
    super.initState();
  }

  bool _isWordSelected(int index) {
    if (_selectionStart == null || _selectionEnd == null) {
      return false;
    }
    final int start = _selectionStart!;
    final int end = _selectionEnd!;
    final int lower = start < end ? start : end;
    final int upper = start > end ? start : end;
    return index >= lower && index <= upper;
  }

  Color? _getWordBackgroundColor(int index, int associatedWordIndex) {
    if (associatedWordIndex == widget.currentWordIndex) {
      return Colors.yellow;
    }
    final bool isSelected = _isWordSelected(associatedWordIndex);
    final state = context.read<TranscriptionCubit>().state;
    if (state.transcription == null || associatedWordIndex < 0 || associatedWordIndex >= state.transcription!.transcribedSegments.length) {
      return isSelected ? Colors.grey.withOpacity(0.5) : null;
    }
    final List<String> tags = state.transcription!.transcribedSegments[associatedWordIndex].tags;
    if (tags.isNotEmpty) {
      return getMixedTagColor(tags);
    }
    if (isSelected) {
      return Colors.grey.withOpacity(0.5);
    }
    return null;
  }

  @override
  void didUpdateWidget(covariant FormattedTextWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentWordIndex != oldWidget.currentWordIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        scrollToCurrentWord();
      });
    }
  }

  @override
  void scrollToCurrentWord() {
    if (_currentWordKey.currentContext != null) {
      final RenderBox box = _currentWordKey.currentContext!.findRenderObject() as RenderBox;
      final Offset offset = box.localToGlobal(Offset.zero);
      final double currentWordY = offset.dy;
      final double screenHeight = MediaQuery.of(context).size.height;
      final double scrollOffset = _scrollController.offset;
      final double targetScrollOffset = currentWordY - (screenHeight / 2) + (box.size.height / 2);
      _scrollController.animateTo(targetScrollOffset + scrollOffset, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
    }
    /*if (widget.currentWordIndex == -1) return;

    final RenderObject? renderObject = _textKey.currentContext?.findRenderObject();
    if (renderObject is RenderBox) {
      final RenderBox box = renderObject;
      final Offset offset = box.localToGlobal(Offset.zero);
      final double wordY = offset.dy;
      final double wordHeight = box.size.height;

      final double screenHeight = MediaQuery.of(context).size.height;
      final double scrollOffset = _scrollController.offset;

      final double top = wordY - scrollOffset;
      final double bottom = top + wordHeight;

      if (top < 0) {
        _scrollController.animateTo(scrollOffset + top, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      } else if (bottom > screenHeight) {
        _scrollController.animateTo(scrollOffset + (bottom - screenHeight), duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      }
    }*/
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TranscriptionCubit, TranscriptionState>(
      builder: (context, state) {
        // Asegúrate de que el texto formateado esté disponible
        if (state.textoRealformadoparrafos == null || state.textoRealformadoparrafos!.isEmpty) {
          return const Center(child: Text('No hay texto para mostrar'));
        }
        if (state.transcription == null || state.transcription!.transcribedSegments.isEmpty) {
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
          //print("-------------------- Inicio del Párrafo --------------------");

          // 4. Asociar Palabras con WordWithSpans
          List<Widget> wordWidgets = [];
          for (int i = 0; i < realWords.length; i++) {
            String realWord = realWords[i];
            if (realWord.trim().isEmpty) continue;

            // Buscar el WordWithSpans asociado a esta realWord
            WordWithSpans? associatedWord;
            int associatedWordIndex = -1;
            for (int j = wordWithSpansIndex; j < wordsWithSpans.length; j++) {
              if (wordWithSpansIndex >= wordsWithSpans.length) break;
              WordWithSpans currentWordWithSpan = wordsWithSpans[j];
              if (currentWordWithSpan.realWord.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '') == realWord.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '')) {
                associatedWord = currentWordWithSpan;
                associatedWordIndex = j;
                wordWithSpansIndex = j + 1;
                break;
              }
            }

            // Imprimir las palabras en la consola
            String transWord = associatedWord == null ? "" : associatedWord.spans.map((e) => e.toPlainText()).join();
            //print("Real: '$realWord' - Transcripción: '$transWord' - Index: $associatedWordIndex");

            Widget? transWordWidget;
            if (RegExp(r"[.,!?;:—]").hasMatch(realWord)) {
              transWordWidget = const Text("");
            } else {
              if (associatedWord != null) {
                transWordWidget = Column(
                  children:
                      associatedWord.spans.asMap().entries.map((entry) {
                        final spanIndex = entry.key;
                        final span = entry.value;
                        return Text.rich(
                          TextSpan(
                            text: span.toPlainText(),
                            style: span.style?.copyWith(backgroundColor: _getWordBackgroundColor(spanIndex, associatedWordIndex)),
                            children: [TextSpan(text: '[$associatedWordIndex]', style: const TextStyle(fontSize: 10.0, color: Colors.grey))],
                          ),
                          style: const TextStyle(fontSize: 12.0),
                        );
                      }).toList(),
                );
              } else {
                transWordWidget = const Text("");
              }
            }

            // 5. Construir el Widget de la Palabra
            wordWidgets.add(
              GestureDetector(
                onTapDown: (details) {
                  print("Clicked word: '$realWord' - Index: $associatedWordIndex");
                  widget.onWordTap(associatedWordIndex);
                },
                onSecondaryTapDown: (details) {
                  super.showContextMenu(details.globalPosition, wordIndexes: [associatedWordIndex]);
                },
                onLongPressStart: (details) {
                  setState(() {
                    _selectionStart = associatedWordIndex;
                    _selectionEnd = associatedWordIndex;
                  });
                },
                onLongPressMoveUpdate: (details) {
                  setState(() {
                    _selectionEnd = associatedWordIndex;
                  });
                },
                onLongPressEnd: (details) {
                  final int lower = _selectionStart! < _selectionEnd! ? _selectionStart! : _selectionEnd!;
                  final int upper = _selectionStart! > _selectionEnd! ? _selectionStart! : _selectionEnd!;
                  final List<int> selectedIndexes = List.generate(upper - lower + 1, (i) => lower + i);
                  super.showContextMenu(details.globalPosition, wordIndexes: selectedIndexes);
                },
                onLongPressCancel: () {
                  setState(() {
                    _selectionStart = null;
                    _selectionEnd = null;
                  });
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(realWord, style: TextStyle(fontSize: 16.0, backgroundColor: _getWordBackgroundColor(0, associatedWordIndex))),
                        Text(associatedWordIndex != -1 ? '[$associatedWordIndex]' : '', style: const TextStyle(fontSize: 10.0, color: Colors.grey)),
                      ],
                    ),
                    transWordWidget ?? const SizedBox.shrink(),
                  ],
                ),
              ),
            );
            wordWidgets.add(const SizedBox(width: 5));
          }

          // Imprimir el fin del párrafo en la consola
          //print("-------------------- Fin del Párrafo --------------------\n");

          // 6. Añadir el Wrap de Palabras al Párrafo
          paragraphWidgets.add(Wrap(alignment: WrapAlignment.start, children: wordWidgets));
          paragraphWidgets.add(const SizedBox(height: 26)); // Espacio entre párrafos
        }
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(controller: _scrollController, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: paragraphWidgets)),
          ),
        );
      },
    );
  }
}

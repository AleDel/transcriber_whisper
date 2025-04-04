/*import 'dart:html' as html; // Importa la librería dart:html
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:transcriber_whisper/models/alignment_mfa_data.dart';
import 'package:transcriber_whisper/models/comparation_model.dart';
import 'package:transcriber_whisper/models/transcription_model.dart';

import '../../transcription_widget_abstract.dart';
import '../models/segment.dart';
import '../transcription_cubit.dart';
import '../transcription_state.dart';
import 'comparation_widget.dart';

class TextDisplayWidget extends TranscriptionWidget {
  final Function(Duration, int) onSeek;

  const TextDisplayWidget({
    Key? key,
    required super.transcription,
    required super.audioPosition,
    required super.currentWordIndex,
    required this.onSeek,
    super.autoScrollEnabled = true,
    super.onAutoScrollChanged,
    required super.onWordTap,
  }) : super(key: key);

  @override
  _TextDisplayWidgetState createState() => _TextDisplayWidgetState();
}

class _TextDisplayWidgetState extends TranscriptionWidgetState<TextDisplayWidget> {
  final ScrollController scrollController = ScrollController();
  final TextEditingController _textEditingController = TextEditingController();
  late final AlignmentMFAData? textoEscritoAlineado;



  @override
  void initState() {
    //compara = getIt<TranscribeCubit>().compararActualTranscription();
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      //scrollToCurrentWord();
    });
    // Previene el menú contextual del navegador
    html.document.onContextMenu.listen((html.Event event) {
      event.preventDefault();
    });
  }

  @override
  void dispose() {
    scrollController.dispose();
    _textEditingController.dispose();
    super.dispose();
  }

  Color _getSegmentColor(String segment) {
    if (segment.trim().isEmpty) {
      return Colors.grey.withOpacity(0.5); // Salto de línea
    } else if (segment.contains(',')) {
      return Colors.orange.withOpacity(0.5); // Coma
    } else if (segment.contains('.')) {
      return Colors.purple[100]!; // Punto (malva flojo)
    } else if (segment.contains('!')) {
      return Colors.lightBlue.withOpacity(0.5); // Exclamación
    } else if (segment.contains('?')) {
      return Colors.green.withOpacity(0.5); // Interrogación
    } else {
      return Colors.transparent; // Sin signo de puntuación
    }
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      final offset = event.scrollDelta.dy;
      scrollController.jumpTo(scrollController.offset + offset);
    }
  }

  @override
  void didUpdateWidget(covariant TextDisplayWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentWordIndex != oldWidget.currentWordIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        //scrollToCurrentWord();
      });
    }
  }

  @override
  void scrollToCurrentWord() {
    if (!internalAutoScrollEnabled) return;
    if (widget.currentWordIndex == -1 || widget.transcription.segments.isEmpty || !scrollController.hasClients) {
      return;
    }
    if (!scrollController.hasClients) return; // Comprobación adicional

    final index = widget.currentWordIndex;
    final totalDuration = widget.transcription.segments.last.end;
    final totalTextWidth = (totalDuration / 1) * 200;

    final currentWordStart = widget.transcription.segments[index].start;
    final currentWordEnd = widget.transcription.segments[index].end;
    final currentWordPosition = (currentWordStart / totalDuration) * totalTextWidth;
    final currentWordWidth = ((currentWordEnd - currentWordStart) / totalDuration) * totalTextWidth;
    final currentWordCenter = currentWordPosition + (currentWordWidth / 2);

    final viewportWidth = scrollController.position.viewportDimension;
    final scrollOffset = currentWordCenter - (viewportWidth / 2);

    scrollController.animateTo(scrollOffset > 0 ? scrollOffset : 0, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      child: BlocBuilder<TranscribeCubit, TranscribeState>(
        builder: (context, state) {
          if (state.transcription == null) {
            return const Center(child: Text("No hay datos de transcripción"));
          }

          final transcription = state.transcription!;
          double transcription_totalDuration = widget.transcription.segments.last.end;
          double transcription_totalTextWidth = (transcription_totalDuration / 1) * 300;

          final textoescritoalineado = state.textoEscritoAlineado!;
          final palabras_textoescritoalineado = textoescritoalineado.tiers["words"]!.entries;
          double textoescritoalineado_totalDuration = textoescritoalineado.end;
          double textoescritoalineado_totalTextWidth = (textoescritoalineado_totalDuration / 1) * 300;



          // Determine the minimum length
          final int minLength =
              transcription.realsegments != null
                  ? transcription.realsegments!.length < transcription.segments.length
                      ? transcription.realsegments!.length
                      : transcription.segments.length
                  : transcription.segments.length;

          return Listener(
            onPointerSignal: _handlePointerSignal,
            child: ScrollConfiguration(
              behavior: MyCustomScrollBehavior(),
              child: Column(
                children: [
                  ComparacionHorizontalWidget(comparacion:compara ),
                  Container(
                    width: transcription_totalTextWidth,
                    height: 150,
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
                    child: ListView.builder(
                      controller: scrollController,
                      scrollDirection: Axis.horizontal,
                      itemCount: minLength, // Use the minimum length
                      itemBuilder: (context, index) {
                        final Segment segment = transcription.segments[index];
                        // Conditionally access segmentreal
                        final Segment? segmentreal = transcription.realsegments != null && index < transcription.realsegments!.length ? transcription.realsegments![index] : null;

                        return Listener(
                          onPointerDown: (event) {
                            if (event.kind == PointerDeviceKind.mouse && event.buttons == kSecondaryMouseButton) {
                              // Clic secundario (clic derecho)
                              showContextMenu(event.position, wordIndexes: [index]);
                            }
                          },
                          child: GestureDetector(
                            onLongPressStart: (details) {
                              showContextMenu(details.globalPosition, wordIndexes: [index]);
                            },
                            onTap: () {
                              widget.onWordTap(index);
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(0.0),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(minWidth: 20),
                                child: Container(
                                  decoration: BoxDecoration(color: _getSegmentColor(segment.word)),
                                  child: IntrinsicWidth(
                                    child: SizedBox(
                                      height: 100,
                                      child: Column(mainAxisAlignment: MainAxisAlignment.start,
                                        children: [

                                          // Fila 1: texto escrito (palabra, signo o nada)
                                          Container(
                                            height: 40,
                                            width: 100,
                                            alignment: Alignment.center,
                                            child: GestureDetector(
                                              onTap: () {
                                                widget.onWordTap(index);
                                              },
                                              child: Padding(
                                                padding: const EdgeInsets.all(0.0),
                                                child: Text(
                                                  segmentreal != null
                                                      ? segmentreal.word.trim().isEmpty
                                                          ? "Salto de linea"
                                                          : segmentreal.word
                                                      : "", // Display empty string if segmentreal is null
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(fontSize: 16,
                                                      backgroundColor: index == widget.currentWordIndex ? Colors.yellow : Colors.white
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          // Fila 2: Texto transcrito (palabra, signo o nada)
                                          Container(
                                            height: 35,
                                            alignment: Alignment.center,
                                            child: GestureDetector(
                                              onTap: () {
                                                widget.onWordTap(index);
                                              },
                                              child: Padding(
                                                padding: const EdgeInsets.all(8.0),
                                                child: Text(
                                                  segment.word.trim().isEmpty ? "Salto de linea" : segment.word,
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(fontSize: 12, backgroundColor: index == widget.currentWordIndex ? Colors.yellow : Colors.grey),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// MyCustomScrollBehavior
class MyCustomScrollBehavior extends MaterialScrollBehavior {
  // Override behavior methods and getters like dragDevices
  @override
  Set<PointerDeviceKind> get dragDevices => {PointerDeviceKind.touch, PointerDeviceKind.mouse};
}*/

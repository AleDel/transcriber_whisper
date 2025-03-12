import 'dart:html' as html; // Importa la librería dart:html
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:transcriber_whisper/cubits/session_cubit.dart';
import 'package:transcriber_whisper/models/transcription_model.dart';

import '../../transcription_widget_abstract.dart';

class TextDisplayWidget extends TranscriptionWidget {
  const TextDisplayWidget({Key? key}) : super(key: key);

  @override
  _TextDisplayWidgetState createState() => _TextDisplayWidgetState();
}

class _TextDisplayWidgetState extends TranscriptionWidgetState<TextDisplayWidget> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textEditingController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Previene el menú contextual del navegador
    html.document.onContextMenu.listen((html.Event event) {
      event.preventDefault();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
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
      _scrollController.jumpTo(_scrollController.offset + offset);
    }
  }

  @override
  void scrollToCurrentWord() {
    // TODO: implement scrollToCurrentWord
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SessionCubit, SessionState>(
      builder: (context, state) {
        if (state.sessionData == null || state.sessionData!.transcription == null) {
          return const Center(child: Text("No hay datos de transcripción"));
        }
        //print("Transcription: ${state.sessionData?.transcription}");
        final transcription = state.sessionData!.transcription!;
        return Listener(
          onPointerSignal: _handlePointerSignal,
          child: ScrollConfiguration(
            behavior: MyCustomScrollBehavior(),
            child: ListView.builder(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              itemCount: transcription.segments.length,
              itemBuilder: (context, index) {
                final Segment segment = transcription.segments[index];
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
                      onWordTap(index);
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(0.0),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 20),
                        child: Container(
                          decoration: BoxDecoration(
                            color: _getSegmentColor(segment.word),
                          ),
                          child: IntrinsicWidth(
                            child: SizedBox(
                              height: 100,
                              child: DottedBorder(
                                color: Colors.grey,
                                strokeWidth: 1.0,
                                child: Column(
                                  children: [
                                    // Fila 1: Texto (palabra, signo o nada)
                                    Container(
                                      height: 30,
                                      alignment: Alignment.center,
                                      child: GestureDetector(
                                        onTap: () {
                                          onWordTap(index);
                                        },
                                        child: Text(
                                          segment.word.trim().isEmpty // Usamos segment.word
                                              ? "Salto de linea"
                                              : segment.word, // Usamos segment.word
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Fila 2: Opciones (desplegable)
                                    Container(
                                      height: 30,
                                      alignment: Alignment.center,
                                      child: Wrap(
                                        alignment: WrapAlignment.center,
                                        children: segment.tags.map((tag) {
                                          final String symbol = SessionCubit.tagToSymbol[tag] ?? tag;
                                          return Padding(
                                            padding: const EdgeInsets.all(2.0),
                                            child: GestureDetector(
                                              onTap: () {
                                                if (segment.tags.contains(tag)) {
                                                  getIt<SessionCubit>().removeTagFromSegment(state.sessionData!, index, tag);
                                                } else {
                                                  getIt<SessionCubit>().addTagToSegment(state.sessionData!, index, tag);
                                                }
                                              },
                                              child: Chip(
                                                label: Text(symbol),
                                                backgroundColor: SessionCubit.availableTags[tag],
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                    // Fila 3: Entrada de texto
                                    Container(
                                      height: 30,
                                      alignment: Alignment.center,
                                      child: TextField(
                                        textAlign: TextAlign.center,
                                        controller: TextEditingController(text: segment.word),
                                        decoration: const InputDecoration(
                                          hintText: '',
                                          border: InputBorder.none,
                                        ),
                                        onSubmitted: (value) {
                                          final newSegment = segment.copyWith(word: value);
                                          getIt<SessionCubit>().editSegment(state.sessionData!, newSegment);
                                        },
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
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

// MyCustomScrollBehavior
class MyCustomScrollBehavior extends MaterialScrollBehavior {
  // Override behavior methods and getters like dragDevices
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
      };
}

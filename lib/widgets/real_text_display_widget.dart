import 'dart:html' as html;
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:transcriber_whisper/models/transcription_model.dart';
import 'package:transcriber_whisper/transcription_cubit.dart';

import '../models/segment.dart';
import '../transcription_state.dart';
import '../transcription_widget_abstract.dart';

class RealTextDisplayWidget extends TranscriptionWidget {
  const RealTextDisplayWidget({
    Key? key,
    required Transcription transcription,
    required Duration audioPosition,
    required int currentWordIndex,
    required Function(int) onWordTap,
    bool autoScrollEnabled = true,
    ValueChanged<bool>? onAutoScrollChanged,
  }) : super(
         key: key,
         transcription: transcription,
         audioPosition: audioPosition,
         currentWordIndex: currentWordIndex,
         onWordTap: onWordTap,
         autoScrollEnabled: autoScrollEnabled,
         onAutoScrollChanged: onAutoScrollChanged,
       );

  @override
  State<RealTextDisplayWidget> createState() => RealTextDisplayWidgetState();
}

class RealTextDisplayWidgetState extends TranscriptionWidgetState<RealTextDisplayWidget> {
  final ScrollController _scrollController = ScrollController();

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
    super.dispose();
  }

  Color _getSegmentColor(String segment) {
    if (segment.trim().isEmpty) {
      return Colors.grey.withOpacity(0.5); // Salto de línea
    } else if (segment == ',') {
      return Colors.orange.withOpacity(0.5); // Coma
    } else if (segment == '.') {
      return Colors.purple[100]!; // Punto (malva flojo)
    } else if (segment == '!') {
      return Colors.lightBlue.withOpacity(0.5); // Exclamación
    } else if (segment == '?') {
      return Colors.green.withOpacity(0.5); // Interrogación
    } else if (segment == ' ') {
      return Colors.transparent; // Espacio
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
  Widget build(BuildContext context) {
    return BlocBuilder<TranscriptionCubit, TranscriptionState>(
      builder: (context, state) {
        if (state.transcription == null || state.transcription!.referenceText == null) {
          return const Center(child: Text("No hay datos para mostrar."));
        }
        final transcription = state.transcription!;
        // Usar rawRealTextSegments en lugar de crear nuevos segmentos
        List<Segment> segments = transcription.rawReferenceTextSegments ?? [];

        return Listener(
          onPointerSignal: _handlePointerSignal,
          child: ScrollConfiguration(
            behavior: MyCustomScrollBehavior(),
            child: ListView.builder(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              itemCount: segments.length,
              itemBuilder: (context, index) {
                final Segment segment = segments[index];
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
                              child: DottedBorder(
                                color: Colors.grey,
                                strokeWidth: 1.0,
                                child: Column(
                                  children: [
                                    // Fila 1: Texto (palabra, signo o nada)
                                    Container(
                                      height: 30,
                                      alignment: Alignment.center,
                                      child: SelectableText(segment.word, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
                                    ),
                                    // Fila 2: Opciones (desplegable)
                                    Container(
                                      height: 30,
                                      alignment: Alignment.center,
                                      child: Wrap(
                                        alignment: WrapAlignment.center,
                                        children:
                                            segment.tags.map((tag) {
                                              final String symbol = TranscriptionCubit.tagToSymbol[tag] ?? tag;
                                              return Padding(
                                                padding: const EdgeInsets.all(2.0),
                                                child: GestureDetector(
                                                  onTap: () {
                                                    if (segment.tags.contains(tag)) {
                                                      getIt<TranscriptionCubit>().removeTagFromSegment(index, tag);
                                                    } else {
                                                      getIt<TranscriptionCubit>().addTagToSegment(index, tag);
                                                    }
                                                  },
                                                  child: Chip(label: Text(symbol), backgroundColor: TranscriptionCubit.availableTags[tag]),
                                                ),
                                              );
                                            }).toList(),
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

  @override
  void scrollToCurrentWord() {
    // TODO: implement scrollToCurrentWord
  }
}

// MyCustomScrollBehavior
class MyCustomScrollBehavior extends MaterialScrollBehavior {
  // Override behavior methods and getters like dragDevices
  @override
  Set<PointerDeviceKind> get dragDevices => {PointerDeviceKind.touch, PointerDeviceKind.mouse};
}

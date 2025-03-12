import 'dart:html' as html; // Importa la librería dart:html
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:transcriber_whisper/cubits/session_cubit.dart';
import 'package:transcriber_whisper/models/transcription_model.dart';
import 'package:transcriber_whisper/models/alignment_mfa_data.dart';

import '../../transcription_widget_abstract.dart';

class TextDisplayFonemasWidget extends TranscriptionWidget {
  const TextDisplayFonemasWidget({Key? key}) : super(key: key);

  @override
  _TextDisplayFonemasWidgetState createState() => _TextDisplayFonemasWidgetState();
}

class _TextDisplayFonemasWidgetState extends TranscriptionWidgetState<TextDisplayFonemasWidget> {
  final ScrollController _scrollController = ScrollController();
  final GetIt getIt = GetIt.instance;

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

        final alignmentData = state.sessionData!.alignmentMFAData;
        // Comprobamos si alignmentData es null o si no tiene la tier phones
        if (alignmentData == null || alignmentData.tiers['phones'] == null) {
          return const Center(child: Text("No hay datos de alineamiento de fonemas"));
        }
        final List<Entry> phonemes = alignmentData.tiers['phones']!.entries;
        return Listener(
          onPointerSignal: _handlePointerSignal,
          child: ScrollConfiguration(
            behavior: MyCustomScrollBehavior(),
            child: ListView.builder(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              itemCount: phonemes.length, // Usamos la longitud de la lista de fonemas
              itemBuilder: (context, index) {
                final Entry phoneme = phonemes[index]; // Accedemos directamente al fonema
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
                            color: _getSegmentColor(phoneme.value),
                          ),
                          child: IntrinsicWidth(
                            child: SizedBox(
                              height: 30,
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
                                          phoneme.value, // Usamos segment.word
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontSize: 16,
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
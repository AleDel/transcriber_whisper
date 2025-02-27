import 'dart:convert';
import 'dart:typed_data';
import 'dart:html' as html; // Importa la librería dart:html

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:transcriber_whisper/models/transcription_model.dart';
import 'package:transcriber_whisper/transcribe_cubit.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';

import '../transcribe_state.dart';

class SlidingText extends StatefulWidget {
  final Transcription transcription;
  final Duration audioPosition;
  final int currentWordIndex;
  final String? waveformImageBase64;
  final ScrollController scrollController;
  final Function(int) onWordTap;
  final bool autoScrollEnabled;
  final ValueChanged<bool>? onAutoScrollChanged;

  const SlidingText({
    Key? key,
    required this.transcription,
    required this.audioPosition,
    required this.currentWordIndex,
    this.waveformImageBase64,
    required this.scrollController,
    required this.onWordTap,
    this.autoScrollEnabled = true,
    this.onAutoScrollChanged,
  }) : super(key: key);

  @override
  State<SlidingText> createState() => _SlidingTextState();
}

class _SlidingTextState extends State<SlidingText> {
  late bool _internalAutoScrollEnabled = true;

  @override
  void initState() {
    super.initState();
    _internalAutoScrollEnabled = widget.autoScrollEnabled;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentWord();
    });
    // Previene el menú contextual del navegador
    html.document.onContextMenu.listen((event) => event.preventDefault());
  }

  @override
  void didUpdateWidget(covariant SlidingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentWordIndex != oldWidget.currentWordIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToCurrentWord();
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _scrollToCurrentWord() {
    if (!_internalAutoScrollEnabled) return;
    if (widget.currentWordIndex == -1 || widget.transcription.segments.isEmpty || !widget.scrollController.hasClients) {
      return;
    }
    if (!widget.scrollController.hasClients) return; // Comprobación adicional

    final index = widget.currentWordIndex;
    final totalDuration = widget.transcription.segments.last.end;
    final totalTextWidth = (totalDuration / 1) * 200;

    final currentWordStart = widget.transcription.segments[index].start;
    final currentWordEnd = widget.transcription.segments[index].end;
    final currentWordPosition = (currentWordStart / totalDuration) * totalTextWidth;
    final currentWordWidth = ((currentWordEnd - currentWordStart) / totalDuration) * totalTextWidth;
    final currentWordCenter = currentWordPosition + (currentWordWidth / 2);

    final viewportWidth = widget.scrollController.position.viewportDimension;
    final scrollOffset = currentWordCenter - (viewportWidth / 2);

    widget.scrollController.animateTo(scrollOffset > 0 ? scrollOffset : 0, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  // Función para calcular el color de fondo en función de la probabilidad
  Color _getBackgroundColor(double probability) {
    // Puedes ajustar estos valores para cambiar la gradación de colores
    const Color colorLow = Colors.red;
    const Color colorHigh = Colors.green;

    // Asegurarse de que la probabilidad esté entre 0 y 1
    probability = probability.clamp(0.0, 1.0);

    // Calcular el color interpolando entre colorLow y colorHigh
    return Color.lerp(colorLow, colorHigh, probability)!;
  }

  Color _getMixedTagColor(List<String> tags) {
    if (tags.isEmpty) {
      return Colors.transparent;
    }

    if (tags.length == 1) {
      return TranscribeCubit.availableTags[tags.first] ?? Colors.transparent;
    }

    List<Color> tagColors = tags.map((tag) => TranscribeCubit.availableTags[tag] ?? Colors.transparent).toList();
    return _mixMultipleColors(tagColors);
  }

  Color _mixMultipleColors(List<Color> colors) {
    if (colors.isEmpty) {
      return Colors.transparent;
    }

    if (colors.length == 1) {
      return colors.first;
    }

    int totalRed = 0;
    int totalGreen = 0;
    int totalBlue = 0;

    for (Color color in colors) {
      totalRed += color.red;
      totalGreen += color.green;
      totalBlue += color.blue;
    }

    return Color.fromARGB(255, totalRed ~/ colors.length, totalGreen ~/ colors.length, totalBlue ~/ colors.length);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.transcription.segments.isEmpty) {
      return Container();
    }

    double totalDuration = widget.transcription.segments.last.end;

    return BlocBuilder<TranscribeCubit, TranscribeState>(
      buildWhen: (previous, current) => previous.transcription != current.transcription || previous.editMode != current.editMode,
      builder: (context, state) {
        return LayoutBuilder(
          builder: (context, constraints) {
            double totalTextWidth = (totalDuration / 1) * 200;
            return Column(
              children: [
                /*Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Text("Edit Mode"), // Nuevo: Switch para modo edición
                    Switch(
                      value: state.editMode,
                      onChanged: (value) {
                        context.read<TranscribeCubit>().toggleEditMode();
                      },
                    ),
                  ],
                ),*/
                Container(
                  width: totalTextWidth,
                  height: 60, // Altura fija
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
                  child: Stack(
                    children: [
                      // Fondo con la imagen de la forma de onda
                      if (widget.waveformImageBase64 != null)
                        Positioned(
                          left: 0,
                          top: 0,
                          child: Container(
                            width: totalTextWidth,
                            height: 30, // Altura fija de 30
                            color: const Color.fromARGB(255, 255, 255, 255).withOpacity(0.5),
                            child: Image.memory(base64Decode(widget.waveformImageBase64!), gaplessPlayback: true, fit: BoxFit.fill, isAntiAlias: true),
                          ),
                        ),

                      // Barra de progreso
                      Positioned(
                        left: 0,
                        top: 0,
                        child: Container(
                          width: totalTextWidth * (widget.audioPosition.inMilliseconds / (totalDuration * 1000)),
                          height: 60, // Altura fija de 30
                          color: Colors.blue.withOpacity(0.5),
                        ),
                      ),

                      // Palabras
                      ...widget.transcription.segments.map((wordData) {
                        double wordStart = wordData.start;
                        double wordEnd = wordData.end;
                        double wordPosition = (wordStart / totalDuration) * totalTextWidth;
                        double wordWidth = ((wordEnd - wordStart) / totalDuration) * totalTextWidth;

                        // Calcular el color de fondo en función de la probabilidad
                        Color backgroundColor = _getBackgroundColor(wordData.probability);
                        Color tagColor = _getMixedTagColor(wordData.tags);
                        return Positioned(
                          left: wordPosition,
                          top: 0,
                          height: 60,
                          child: Listener(
                            onPointerDown: (event) {
                              if (event.kind == PointerDeviceKind.mouse && event.buttons == kSecondaryMouseButton) {
                                // Clic secundario (clic derecho)
                                context.read<TranscribeCubit>().showContextMenu(context, event.position, [widget.transcription.segments.indexOf(wordData)]);
                              }
                            },
                            child: GestureDetector(
                              onTap: () {
                                widget.onWordTap(widget.transcription.segments.indexOf(wordData));
                              },
                              onLongPressStart: (details) {
                                context.read<TranscribeCubit>().showContextMenu(context, details.globalPosition, [widget.transcription.segments.indexOf(wordData)]);
                              },
                              child: Column(
                                children: [
                                  Expanded(
                                    child: Container(
                                      width: wordWidth,
                                      color: tagColor.withOpacity(0.5),
                                      alignment: Alignment.center,
                                      child: Text(
                                        wordData.word,
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: widget.transcription.segments.indexOf(wordData) == widget.currentWordIndex ? Colors.blue : Colors.black,
                                        ),
                                        textAlign: TextAlign.center,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  //probabilidad
                                  Container(
                                    width: wordWidth,
                                    color: backgroundColor,
                                    child: Text("${wordData.probability.toStringAsFixed(2)}", textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

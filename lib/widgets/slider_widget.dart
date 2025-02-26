import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:transcriber_whisper/models/transcription_model.dart';

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
    if (widget.currentWordIndex == -1 ||
        widget.transcription.segments.isEmpty ||
        !widget.scrollController.hasClients) {
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

    widget.scrollController.animateTo(
      scrollOffset > 0 ? scrollOffset : 0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
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

  @override
  Widget build(BuildContext context) {
    if (widget.transcription.segments.isEmpty) {
      return Container();
    }

    double totalDuration = widget.transcription.segments.last.end;

    return LayoutBuilder(
      builder: (context, constraints) {
        double totalTextWidth = (totalDuration / 1) * 200;
        return Container(
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
                    /*child: Image.memory(
                    base64Decode(widget.waveformImageBase64!),
                    gaplessPlayback: true,
                    fit: BoxFit.fill,
                    isAntiAlias: true,
                  ),*/
                  ),
                ),

              // Barra de progreso
              Positioned(
                left: 0,
                top: 0,
                child: Container(
                  width:
                      totalTextWidth *
                      (widget.audioPosition.inMilliseconds / (totalDuration * 1000)),
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
                return Positioned(
                  left: wordPosition,
                  top: 0,
                  height: 60,
                  child: GestureDetector(
                    onTap: () {
                      widget.onWordTap(widget.transcription.segments.indexOf(wordData));
                    },
                    child: Column(
                      children: [
                        Expanded(
                          child: Container(
                            width: wordWidth,
                            color:
                                widget.transcription.segments.indexOf(wordData) % 2 == 0
                                    ? Colors.grey.withAlpha(40)
                                    : Colors.grey.withAlpha(30),
                            alignment: Alignment.center,
                            child: Text(
                              wordData.word,
                              style: TextStyle(
                                fontSize: 16,
                                color:
                                    widget.transcription.segments.indexOf(wordData) ==
                                            widget.currentWordIndex
                                        ? Colors.blue
                                        : Colors.black,
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
                          child: Text(
                            "${wordData.probability.toStringAsFixed(2)}",
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }
}

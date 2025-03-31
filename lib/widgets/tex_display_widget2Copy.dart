import 'dart:html' as html; // Importa la librería dart:html
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:transcriber_whisper/models/transcription_model.dart';

import '../../transcription_widget_abstract.dart';
import '../models/comparation_model.dart';
import '../models/segment.dart';
import '../transcribe_cubit.dart';
import '../transcribe_state.dart';

class TextDisplayWidget2 extends TranscriptionWidget {
  final Function(Duration, int) onSeek;
  final List<ComparacionSegmento> comparacionlist;

  const TextDisplayWidget2({
    Key? key,
    required super.transcription,
    required super.audioPosition,
    required super.currentWordIndex,
    required this.onSeek,
    required this.comparacionlist,
    super.autoScrollEnabled = true,
    super.onAutoScrollChanged,
    required super.onWordTap,
  }) : super(key: key);

  @override
  _TextDisplayWidgetState createState() => _TextDisplayWidgetState();
}

class _TextDisplayWidgetState extends TranscriptionWidgetState<TextDisplayWidget2> {
  final ScrollController scrollController = ScrollController();
  double _dragStart = 0;
  double _currentOffset = 0;
  static const double segmentWidth = 100.0; // Ancho fijo para cada segmento

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
    scrollController.dispose();
    super.dispose();
  }

  Color _getColor(String estado) {
    switch (estado) {
      case "acierto":
        return Colors.green.withOpacity(0.5);
      case "sustitucion":
        return Colors.yellow.withOpacity(0.5);
      case "inserción":
        return Colors.blue.withOpacity(0.5);
      case "omisión":
        return Colors.red.withOpacity(0.5);
      default:
        return Colors.transparent;
    }
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      final offset = event.scrollDelta.dy;
      _currentOffset += offset;
      if (scrollController.hasClients && mounted) {
        scrollController.jumpTo(_currentOffset);
      }
    }
  }

  void _handlePointerDown(PointerDownEvent event) {
    _dragStart = event.position.dx;
  }

  void _handlePointerMove(PointerMoveEvent event) {
    final double offset = _dragStart - event.position.dx;
    _dragStart = event.position.dx;
    _currentOffset += offset;
    if (scrollController.hasClients && mounted) {
      scrollController.jumpTo(_currentOffset);
    }
  }

  double _calculateTextWidth(String text) {
    final TextPainter textPainter = TextPainter(text: TextSpan(text: text), maxLines: 1, textDirection: TextDirection.ltr)..layout(minWidth: 0, maxWidth: double.infinity);
    return textPainter.size.width;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      child: BlocBuilder<TranscribeCubit, TranscribeState>(
        builder: (context, state) {
          if (state.transcription == null) {
            return const Center(child: Text("No hay datos de transcripción"));
          }
          return Listener(
            onPointerSignal: _handlePointerSignal,
            onPointerDown: _handlePointerDown,
            onPointerMove: _handlePointerMove,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              controller: scrollController,
              physics: const ClampingScrollPhysics(),
              child: Column(
                children: [
                  // Fila del texto real con scroll horizontal
                  Row(
                    children:
                        widget.comparacionlist.map((comparacionSegmento) {
                          return GestureDetector(
                            onTap: () {
                              if (comparacionSegmento.indexTranscrito != -1) {
                                widget.onWordTap(comparacionSegmento.indexTranscrito);
                              }
                            },
                            child: Container(
                              width: segmentWidth, // Ancho fijo
                              padding: const EdgeInsets.all(4.0),
                              margin: const EdgeInsets.all(2.0),
                              decoration: BoxDecoration(
                                color: comparacionSegmento.palabraReal != null ? _getColor(comparacionSegmento.estado) : Colors.transparent,
                                border: Border.all(color: Colors.grey),
                              ),
                              child: SizedBox(
                                width: segmentWidth - 16, // Restar el padding y el margen
                                child: Text(
                                  comparacionSegmento.palabraReal ?? "",
                                  overflow: TextOverflow.ellipsis, // Truncar con puntos suspensivos
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                  ),
                  // Fila del texto transcrito con scroll horizontal
                  Row(
                    children:
                        widget.comparacionlist.map((comparacionSegmento) {
                          return GestureDetector(
                            onTap: () {
                              if (comparacionSegmento.indexTranscrito != -1) {
                                widget.onWordTap(comparacionSegmento.indexTranscrito);
                              }
                            },
                            child: Container(
                              width: segmentWidth, // Ancho fijo
                              padding: const EdgeInsets.all(4.0),
                              margin: const EdgeInsets.all(2.0),
                              decoration: BoxDecoration(color: _getColor(comparacionSegmento.estado), border: Border.all(color: Colors.grey)),
                              child: SizedBox(
                                width: segmentWidth - 16, // Restar el padding y el margen
                                child: Text(
                                  comparacionSegmento.segmentoTranscrito.word,
                                  overflow: TextOverflow.ellipsis, // Truncar con puntos suspensivos
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                  ),
                  // Fila de etiquetas de estado
                  Row(
                    children:
                        widget.comparacionlist.map((comparacionSegmento) {
                          return Container(
                            width: segmentWidth, // Ancho fijo
                            padding: const EdgeInsets.all(4.0),
                            margin: const EdgeInsets.all(2.0),
                            child: SizedBox(
                              width: segmentWidth - 16, // Restar el padding y el margen
                              child: Text(comparacionSegmento.estado, textAlign: TextAlign.center),
                            ),
                          );
                        }).toList(),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void scrollToCurrentWord() {
    if (!internalAutoScrollEnabled) return;
    if (widget.currentWordIndex == -1 || widget.transcription.transsegments.isEmpty || !scrollController.hasClients || !mounted) {
      return;
    }

    final index = widget.currentWordIndex;
    final totalDuration = widget.transcription.transsegments.last.end;
    final totalTextWidth = (totalDuration / 1) * 200;

    final currentWordStart = widget.transcription.transsegments[index].start;
    final currentWordEnd = widget.transcription.transsegments[index].end;
    final currentWordPosition = (currentWordStart / totalDuration) * totalTextWidth;
    final currentWordWidth = ((currentWordEnd - currentWordStart) / totalDuration) * totalTextWidth;
    final currentWordCenter = currentWordPosition + (currentWordWidth / 2);

    final viewportWidth = scrollController.position.viewportDimension;
    final scrollOffset = currentWordCenter - (viewportWidth / 2);
    _currentOffset = scrollOffset > 0 ? scrollOffset : 0;
    if (mounted) {
      scrollController.jumpTo(_currentOffset);
    }
  }
}

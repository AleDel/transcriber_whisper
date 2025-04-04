import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:transcriber_whisper/models/transcription_model.dart';
import 'package:collection/collection.dart'; // Importa la extensión

import '../../transcription_widget_abstract.dart';
import '../models/comparation_model.dart';
import '../models/segment.dart';
import '../transcription_cubit.dart';
import '../transcription_state.dart';

class TextDisplayWidget extends TranscriptionWidget {
  final Function(Duration, int) onSeek;
  final List<Object> comparacionlist;

  const TextDisplayWidget({
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

class _TextDisplayWidgetState extends TranscriptionWidgetState<TextDisplayWidget> {
  final ScrollController scrollController = ScrollController();
  double _currentOffset = 0;

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

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      child: BlocBuilder<TranscriptionCubit, TranscriptionState>(
        builder: (context, state) {
          if (state.transcription == null) {
            return const Center(child: Text("No hay datos de transcripción"));
          }
          return LayoutBuilder(
            builder: (context, constraints) {
              final availableWidth = constraints.maxWidth;
              final List<Widget> wordWidgets = [];
              for (int i = 0; i < widget.transcription.realTextSegments!.length; i++) {
                final realSegment = widget.transcription.realTextSegments![i];
                final transcritoSegment = i < widget.transcription.transcribedSegments.length ? widget.transcription.transcribedSegments[i] : Segment(start: 0, end: 0, word: "", probability: 0);
                final ComparacionSegmento? comparacion = widget.comparacionlist.firstWhereOrNull((element) {
                  if (element is ComparacionSegmento) {
                    return element.indexReal == i;
                  }
                  return false;
                }) as ComparacionSegmento?;
                final realWord = realSegment.word;
                final transcritoWord = transcritoSegment.word;
                final estado = comparacion?.estado ?? "";
                final realWordWidget = GestureDetector(
                  onTap: () {
                    widget.onWordTap(i);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4.0),
                    margin: const EdgeInsets.all(2.0),
                    decoration: BoxDecoration(
                      color: comparacion?.palabraReal != null ? _getColor(estado) : Colors.transparent,
                      border: Border.all(color: Colors.grey),
                    ),
                    child: Text(
                      realWord,
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
                final transcritoWordWidget = GestureDetector(
                  onTap: () {
                    widget.onWordTap(i);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4.0),
                    margin: const EdgeInsets.all(2.0),
                    decoration: BoxDecoration(
                      color: _getColor(estado),
                      border: Border.all(color: Colors.grey),
                    ),
                    child: Text(
                      transcritoWord,
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
                final estadoWidget = Container(
                  padding: const EdgeInsets.all(4.0),
                  margin: const EdgeInsets.all(2.0),
                  child: Text(estado, textAlign: TextAlign.center),
                );
                wordWidgets.add(Column(
                  children: [
                    realWordWidget,
                    transcritoWordWidget,
                    estadoWidget,
                  ],
                ));
              }
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                controller: scrollController,
                physics: const ClampingScrollPhysics(),
                child: Wrap(
                  children: wordWidgets,
                ),
              );
            },
          );
        },
      ),
    );
  }

  @override
  void scrollToCurrentWord() {
    if (!internalAutoScrollEnabled) return;
    if (widget.currentWordIndex == -1 || widget.transcription.transcribedSegments.isEmpty || !scrollController.hasClients || !mounted) {
      return;
    }
    final index = widget.currentWordIndex;
    double offset = 0;
    for (int i = 0; i < index; i++) {
      final realSegment = widget.transcription.realTextSegments![i];
      final textPainter = TextPainter(
        text: TextSpan(text: realSegment.word),
        textDirection: TextDirection.ltr,
      )..layout();
      offset += textPainter.width + 8;
    }
    _currentOffset = offset;
    if (mounted) {
      scrollController.jumpTo(_currentOffset);
    }
  }
}
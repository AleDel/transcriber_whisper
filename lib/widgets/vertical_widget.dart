import 'dart:html' as html; // Importa la librería dart:html
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:transcriber_whisper/models/transcription_model.dart';
import 'package:transcriber_whisper/transcribe_cubit.dart';
import 'package:transcriber_whisper/transcribe_state.dart';
import 'package:transcriber_whisper/transcription_widget_abstract.dart';

class VerticalTranscription extends TranscriptionWidget {
  final Function(Duration, int) onSeek;

  const VerticalTranscription({
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
  State<VerticalTranscription> createState() => _VerticalTranscriptionState();
}

class _VerticalTranscriptionState extends TranscriptionWidgetState<VerticalTranscription> {
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener = ItemPositionsListener.create();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      scrollToCurrentWord();
    });
    // Previene el menú contextual del navegador
    html.document.onContextMenu.listen((event) => event.preventDefault());
  }

  @override
  void didUpdateWidget(covariant VerticalTranscription oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentWordIndex != oldWidget.currentWordIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        scrollToCurrentWord();
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void scrollToCurrentWord() {
    if (!internalAutoScrollEnabled) return;
    if (widget.currentWordIndex == -1 || widget.transcription.segments.isEmpty) return;
    _itemScrollController.scrollTo(
      index: widget.currentWordIndex,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
      alignment: 0.5,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TranscribeCubit, TranscribeState>(
      builder: (context, state) {
        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text("Auto Scroll"),
                Switch(
                  value: internalAutoScrollEnabled,
                  onChanged: (value) {
                    setAutoScroll(value);
                  },
                ),
              ],
            ),
            Expanded(
              child: ScrollablePositionedList.builder(
                itemScrollController: _itemScrollController,
                itemPositionsListener: _itemPositionsListener,
                itemCount: widget.transcription.segments.length,
                itemBuilder: (context, index) {
                  final wordData = widget.transcription.segments[index];
                  final isCurrentWord = index == widget.currentWordIndex;
                  final startMillis = (wordData.start * 1000).toInt();
                  final endMillis = (wordData.end * 1000).toInt();
                  return Listener(
                    onPointerDown: (event) {
                      if (event.kind == PointerDeviceKind.mouse && event.buttons == kSecondaryMouseButton) {
                        // Clic secundario (clic derecho)
                        showContextMenu(event.position, wordIndexes: [index]);
                      }
                    },
                    child: GestureDetector(
                      onTap: () {
                        widget.onSeek(Duration(milliseconds: startMillis), index);
                        widget.onWordTap(index);
                      },
                      onLongPressStart: (details) {
                        // Long press
                        showContextMenu(details.globalPosition,wordIndexes: [index]);
                      },
                      child: Container(
                        color: isCurrentWord ? Colors.yellow.withOpacity(0.5) : null,
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                        child: Text(
                          '[${startMillis}ms -> ${endMillis}ms] ${wordData.word} ${wordData.probability.toStringAsFixed(10)} ${wordData.tags.isNotEmpty ? wordData.tags.join(', ') : ''}',
                          style: TextStyle(fontWeight: isCurrentWord ? FontWeight.bold : FontWeight.normal, color: isCurrentWord ? Colors.blue : Colors.black),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
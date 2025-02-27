import 'dart:html' as html; // Importa la librería dart:html
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:transcriber_whisper/models/transcription_model.dart';
import 'package:transcriber_whisper/transcribe_cubit.dart';
import 'package:transcriber_whisper/transcribe_state.dart';

class VerticalTranscription extends StatefulWidget {
  final Transcription transcription;
  final Duration audioPosition;
  final int currentWordIndex;
  final Function(Duration, int) onSeek;
  final bool autoScrollEnabled;
  final ValueChanged<bool>? onAutoScrollChanged;

  const VerticalTranscription({
    Key? key,
    required this.transcription,
    required this.audioPosition,
    required this.currentWordIndex,
    required this.onSeek,
    this.autoScrollEnabled = true,
    this.onAutoScrollChanged,
  }) : super(key: key);

  @override
  State<VerticalTranscription> createState() => _VerticalTranscriptionState();
}

class _VerticalTranscriptionState extends State<VerticalTranscription> {
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener = ItemPositionsListener.create();
  late bool _internalAutoScrollEnabled = true;
  final GetIt getIt = GetIt.instance;

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
  void didUpdateWidget(covariant VerticalTranscription oldWidget) {
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
    if (widget.currentWordIndex == -1 || widget.transcription.segments.isEmpty) return;
    _itemScrollController.scrollTo(index: widget.currentWordIndex, duration: const Duration(milliseconds: 300), curve: Curves.easeInOutCubic, alignment: 0.5);
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
                  value: _internalAutoScrollEnabled,
                  onChanged: (value) {
                    setState(() {
                      _internalAutoScrollEnabled = value;
                    });
                    getIt<TranscribeCubit>().setAutoScroll(value);
                    if (widget.onAutoScrollChanged != null) {
                      widget.onAutoScrollChanged!(value);
                    }
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
                        getIt<TranscribeCubit>().showContextMenu(context, event.position, [index]);
                      }
                    },
                    child: GestureDetector(
                      onTap: () {
                        widget.onSeek(Duration(milliseconds: startMillis), index);
                      },
                      onLongPressStart: (details) {
                        // Long press
                        getIt<TranscribeCubit>().showContextMenu(context, details.globalPosition, [index]);
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

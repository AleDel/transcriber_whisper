import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:transcriber_whisper/models/transcription_model.dart';

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

  @override
  void initState() {
    super.initState();
    _internalAutoScrollEnabled = widget.autoScrollEnabled;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentWord();
    });
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
    if (widget.currentWordIndex == -1 || widget.transcription.segments.isEmpty) {
      return;
    }

    _itemScrollController.scrollTo(
      index: widget.currentWordIndex,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      alignment: 0.5, // Centrar el item
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.transcription.segments.isEmpty) {
      return Container();
    }

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
                widget.onAutoScrollChanged?.call(value);
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
              final segment = widget.transcription.segments[index];
              final isCurrentWord = index == widget.currentWordIndex;
              final startMillis = (segment.start * 1000).toInt();
              final endMillis = (segment.end * 1000).toInt();

              return InkWell(
                key: Key('segment-${segment.start}'),
                onTap: () {
                  widget.onSeek(Duration(milliseconds: startMillis), index);
                },
                child: Container(
                  color: isCurrentWord ? Colors.yellow.withOpacity(0.5) : null,
                  padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                  child: Text(
                    '[${startMillis}ms -> ${endMillis}ms] ${segment.word} ${segment.probability.toStringAsFixed(10)}',
                    style: TextStyle(
                      fontWeight: isCurrentWord ? FontWeight.bold : FontWeight.normal,
                      color: isCurrentWord ? Colors.blue : Colors.black,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

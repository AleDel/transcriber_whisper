import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:transcriber_whisper/models/transcription_model.dart';
import 'package:transcriber_whisper/transcribe_cubit.dart';

import '../transcribe_state.dart';

class SelectableRichText extends StatefulWidget {
  final List<Segment> segments;
  final int currentWordIndex;
  final Function(int) onWordTap;

  const SelectableRichText({Key? key, required this.segments, required this.currentWordIndex, required this.onWordTap}) : super(key: key);

  @override
  State<SelectableRichText> createState() => _SelectableRichTextState();
}

class _SelectableRichTextState extends State<SelectableRichText> {
  final GlobalKey _textKey = GlobalKey();
  final GetIt getIt = GetIt.instance;
  bool _internalPlayAndStopWordOnSelect = true;
  int? _selectionStart;
  int? _selectionEnd;

  bool _isWordSelected(int index) {
    if (_selectionStart == null || _selectionEnd == null) {
      return false;
    }
    final int start = _selectionStart!;
    final int end = _selectionEnd!;
    final int lower = start < end ? start : end;
    final int upper = start > end ? start : end;
    return index >= lower && index <= upper;
  }

  int _findWordIndexFromOffset(Offset localPosition) {
    final RenderObject? renderObject = _textKey.currentContext?.findRenderObject();
    if (renderObject is RenderParagraph) {
      final TextPosition textPosition = renderObject.getPositionForOffset(localPosition);
      return _findWordIndexFromTextPosition(textPosition);
    }
    return -1;
  }

  Color? _getWordBackgroundColor(int index) {
    final bool isSelected = _isWordSelected(index);
    final bool hasTags = widget.segments[index].tags.isNotEmpty;

    if (isSelected && hasTags) {
      final Color tagColor = _getMixedTagColor(widget.segments[index].tags);
      final Color selectionColor = Colors.grey.withOpacity(0.5);
      return _blendColors(tagColor, selectionColor);
    } else if (isSelected) {
      return Colors.grey.withOpacity(0.5);
    } else if (hasTags) {
      return _getMixedTagColor(widget.segments[index].tags);
    }

    return null;
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

  Color _blendColors(Color color1, Color color2) {
    return Color.fromARGB(255, (color1.red + color2.red) ~/ 2, (color1.green + color2.green) ~/ 2, (color1.blue + color2.blue) ~/ 2);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TranscribeCubit, TranscribeState>(
      builder: (context, state) {
        _internalPlayAndStopWordOnSelect = state.extradata!.playAndStopWordOnSelect;
        return SingleChildScrollView(
          child: SizedBox(
            width: 500,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Text("Play and Stop on Select"),
                      Switch(
                        value: _internalPlayAndStopWordOnSelect,
                        onChanged: (value) {
                          setState(() {
                            _internalPlayAndStopWordOnSelect = value;
                          });
                          getIt<TranscribeCubit>().togglePlayAndStopWordOnSelect();
                        },
                      ),
                    ],
                  ),
                  Listener(
                    onPointerDown: (event) {
                      if (event.kind == PointerDeviceKind.mouse && event.buttons == kSecondaryMouseButton) {
                        final RenderObject? renderObject = _textKey.currentContext?.findRenderObject();
                        if (renderObject is RenderBox) {
                          final localPosition = renderObject.globalToLocal(event.position);
                          final int wordIndex = _findWordIndexFromOffset(localPosition);
                          getIt<TranscribeCubit>().showContextMenu(context, event.position, [wordIndex]);
                        }
                      }
                    },
                    child: GestureDetector(
                      onTapDown: (details) {
                        // Detectar clic izquierdo
                        final RenderObject? renderObject = _textKey.currentContext?.findRenderObject();
                        if (renderObject is RenderBox) {
                          final localPosition = renderObject.globalToLocal(details.globalPosition);
                          final int wordIndex = _findWordIndexFromOffset(localPosition);
                          widget.onWordTap(wordIndex);
                        }
                      },
                      onLongPressStart: (details) {
                        final RenderObject? renderObject = _textKey.currentContext?.findRenderObject();
                        if (renderObject is RenderBox) {
                          final localPosition = renderObject.globalToLocal(details.globalPosition);
                          final int wordIndex = _findWordIndexFromOffset(localPosition);
                          setState(() {
                            _selectionStart = wordIndex;
                            _selectionEnd = wordIndex;
                          });
                        }
                      },
                      onLongPressMoveUpdate: (details) {
                        final RenderObject? renderObject = _textKey.currentContext?.findRenderObject();
                        if (renderObject is RenderBox) {
                          final localPosition = renderObject.globalToLocal(details.globalPosition);
                          final int wordIndex = _findWordIndexFromOffset(localPosition);
                          setState(() {
                            _selectionEnd = wordIndex;
                          });
                        }
                      },
                      onLongPressEnd: (details) {
                        final RenderObject? renderObject = _textKey.currentContext?.findRenderObject();
                        if (renderObject is RenderBox) {
                          final localPosition = renderObject.globalToLocal(details.globalPosition);
                          final int wordIndex = _findWordIndexFromOffset(localPosition);
                          final int lower = _selectionStart! < _selectionEnd! ? _selectionStart! : _selectionEnd!;
                          final int upper = _selectionStart! > _selectionEnd! ? _selectionStart! : _selectionEnd!;
                          final List<int> selectedIndexes = List.generate(upper - lower + 1, (i) => lower + i);
                          getIt<TranscribeCubit>().showContextMenu(context, details.globalPosition, selectedIndexes);
                        }
                      },
                      onLongPressCancel: () {
                        setState(() {
                          _selectionStart = null;
                          _selectionEnd = null;
                        });
                      },
                      child: Text.rich(
                        key: _textKey,
                        TextSpan(
                          children:
                              widget.segments.asMap().entries.map((entry) {
                                int index = entry.key;
                                var wordData = entry.value;
                                return TextSpan(
                                  text: '${wordData.word} ',
                                  style: TextStyle(backgroundColor: index == widget.currentWordIndex ? Colors.yellow : _getWordBackgroundColor(index)),
                                );
                              }).toList(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  int _findWordIndexFromTextPosition(TextPosition textPosition) {
    int wordIndex = 0;
    int currentPosition = 0;
    for (int i = 0; i < widget.segments.length; i++) {
      currentPosition += widget.segments[i].word.length + 1;
      if (textPosition.offset <= currentPosition) {
        wordIndex = i;
        break;
      }
    }
    return wordIndex;
  }
}

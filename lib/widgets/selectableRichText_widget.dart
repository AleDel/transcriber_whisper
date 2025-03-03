import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:transcriber_whisper/models/transcription_model.dart';
import 'package:transcriber_whisper/transcribe_cubit.dart';
import 'package:transcriber_whisper/transcribe_state.dart';
import 'package:transcriber_whisper/transcription_widget_abstract.dart';

class SelectableRichText extends TranscriptionWidget {
  const SelectableRichText({Key? key, required super.transcription, required super.audioPosition, required super.currentWordIndex, required super.onWordTap}) : super(key: key);

  @override
  State<SelectableRichText> createState() => _SelectableRichTextState();
}

class _SelectableRichTextState extends TranscriptionWidgetState<SelectableRichText> {
  final GlobalKey _textKey = GlobalKey();
  bool _internalPlayAndStopWordOnSelect = true;
  //int? _selectionStart; // Eliminado: Ahora se gestiona en la clase base
  //int? _selectionEnd; // Eliminado: Ahora se gestiona en la clase base
  List<int> _selectedIndexes = [];

  bool _isWordSelected(int index) {
    return _selectedIndexes.contains(index);
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
    final bool hasTags = widget.transcription.segments[index].tags.isNotEmpty;

    if (isSelected && hasTags) {
      final Color tagColor = getMixedTagColor(widget.transcription.segments[index].tags);
      final Color selectionColor = Colors.grey.withOpacity(0.5);
      return _blendColors(tagColor, selectionColor);
    } else if (isSelected) {
      return Colors.grey.withOpacity(0.5);
    } else if (hasTags) {
      return getMixedTagColor(widget.transcription.segments[index].tags);
    }

    return null;
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
                          showContextMenu(event.position, wordIndexes: [wordIndex]);
                        }
                      }
                    },
                    child: GestureDetector(
                      onTapDown: (details) {
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
                            _selectedIndexes = [wordIndex];
                          });
                        }
                      },
                      onLongPressMoveUpdate: (details) {
                        final RenderObject? renderObject = _textKey.currentContext?.findRenderObject();
                        if (renderObject is RenderBox) {
                          final localPosition = renderObject.globalToLocal(details.globalPosition);
                          final int wordIndex = _findWordIndexFromOffset(localPosition);
                          setState(() {
                            if (!_selectedIndexes.contains(wordIndex)) {
                              _selectedIndexes.add(wordIndex);
                            }
                            _selectedIndexes.sort();
                          });
                        }
                      },
                      onLongPressEnd: (details) {
                        final RenderObject? renderObject = _textKey.currentContext?.findRenderObject();
                        if (renderObject is RenderBox) {
                          final localPosition = renderObject.globalToLocal(details.globalPosition);
                          final int wordIndex = _findWordIndexFromOffset(localPosition);
                          setState(() {
                            if (!_selectedIndexes.contains(wordIndex)) {
                              _selectedIndexes.add(wordIndex);
                            }
                            _selectedIndexes.sort();
                          });
                          showContextMenu(details.globalPosition, wordIndexes: _selectedIndexes);
                        }
                      },
                      onLongPressCancel: () {
                        setState(() {
                          _selectedIndexes = [];
                        });
                      },
                      child: Text.rich(
                        key: _textKey,
                        TextSpan(
                          children:
                              widget.transcription.segments.asMap().entries.map((entry) {
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
    for (int i = 0; i < widget.transcription.segments.length; i++) {
      currentPosition += widget.transcription.segments[i].word.length + 1;
      if (textPosition.offset <= currentPosition) {
        wordIndex = i;
        break;
      }
    }
    return wordIndex;
  }

  @override
  void scrollToCurrentWord() {
    // TODO: implement scrollToCurrentWord
  }
}

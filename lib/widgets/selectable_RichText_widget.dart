import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:transcriber_whisper/transcription_widget_abstract.dart';

import '../cubits/session_cubit.dart';

class SelectableRichText extends TranscriptionWidget {
  const SelectableRichText({Key? key}) : super(key: key);

  @override
  _SelectableRichTextState createState() => _SelectableRichTextState();
}

class _SelectableRichTextState extends TranscriptionWidgetState<SelectableRichText> {
  final GlobalKey _textKey = GlobalKey();
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

  Color? _getWordBackgroundColor(int index, int? currentWordIndex) {
    final sessionCubit = context.read<SessionCubit>();
    final sessionState = sessionCubit.state;
    final bool isSelected = _isWordSelected(index);
    final bool hasTags = sessionState.sessionData!.transcription!.segments[index].tags.isNotEmpty;
    final bool isCurrentWord = index == currentWordIndex;

    if (isCurrentWord) {
      return Colors.yellow;
    } else if (isSelected && hasTags) {
      final Color tagColor = getMixedTagColor(sessionState.sessionData!.transcription!.segments[index].tags);
      final Color selectionColor = Colors.grey.withOpacity(0.5);
      return _blendColors(tagColor, selectionColor);
    } else if (isSelected) {
      return Colors.grey.withOpacity(0.5);
    } else if (hasTags) {
      return getMixedTagColor(sessionState.sessionData!.transcription!.segments[index].tags);
    }

    return null;
  }

  Color _blendColors(Color color1, Color color2) {
    return Color.fromARGB(255, (color1.red + color2.red) ~/ 2, (color1.green + color2.green) ~/ 2, (color1.blue + color2.blue) ~/ 2);
  }

  @override
  Widget build(BuildContext context) {
    final sessionCubit = context.read<SessionCubit>();
    return BlocBuilder<SessionCubit, SessionState>(
      builder: (context, state) {
        //final currentSessionStatus = state.playerStatusData;
        if (state.sessionData == null || state.sessionData!.transcription == null) {
          return const SizedBox.shrink();
        }
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
                        value: state.sessionData!.playAndStopWordOnSelect,
                        onChanged: (value) {
                          sessionCubit.togglePlayAndStopWordOnSelect();
                          setState(() {

                          });
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
                          onWordTap(wordIndex);
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
                          state.sessionData!.transcription!.segments.asMap().entries.map((entry) {
                            int index = entry.key;
                            var wordData = entry.value;
                            return TextSpan(
                              text: '${wordData.word} ',
                              style: TextStyle(backgroundColor: _getWordBackgroundColor(index, currentWordIndex)),
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
    final sessionCubit = context.read<SessionCubit>();
    final sessionState = sessionCubit.state;
    int wordIndex = 0;
    int currentPosition = 0;
    for (int i = 0; i < sessionState.sessionData!.transcription!.segments.length; i++) {
      currentPosition += sessionState.sessionData!.transcription!.segments[i].word.length + 1;
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
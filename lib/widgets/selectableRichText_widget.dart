import 'dart:html' as html;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:transcriber_whisper/models/transcription_model.dart';
import 'package:transcriber_whisper/transcribe_cubit.dart';

class SelectableRichText extends StatefulWidget {
  final List<Segment> segments;
  final int currentWordIndex;
  final Function(int) onWordTap;

  const SelectableRichText({
    Key? key,
    required this.segments,
    required this.currentWordIndex,
    required this.onWordTap,
  }) : super(key: key);

  @override
  State<SelectableRichText> createState() => _SelectableRichTextState();
}

class _SelectableRichTextState extends State<SelectableRichText> {
  int? _selectionStart;
  int? _selectionEnd;
  bool _tagSelected = false;
  bool _internalPlayAndStopWordOnSelect = false;
  final Map<String, Color> _availableTags = {
    "Omisión": Colors.red,
    "Relectura": Colors.green,
    "Repetición": Colors.blue,
    "Corrección": Colors.purple,
  };
  final GlobalKey _textKey = GlobalKey();
  GetIt getIt = GetIt.instance;

  void _showContextMenu(Offset position, {int? wordIndex}) async {
    _tagSelected = false;
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    if (wordIndex != null) {
      _selectionStart = wordIndex;
      _selectionEnd = wordIndex;
    }
    final List<String> selectedTags = _getSelectedTags();
    await showMenu(
      context: context,
      position: RelativeRect.fromRect(position & const Size(40, 40), Offset.zero & overlay.size),
      items:
          _availableTags.entries.map((entry) {
            final String tag = entry.key;
            final Color color = entry.value;
            final bool isSelected = selectedTags.contains(tag);
            return PopupMenuItem<String>(
              value: tag,
              child: CheckboxListTile(
                title: Text(tag),
                activeColor: color,
                value: isSelected,
                onChanged: (bool? newValue) {
                  _tagSelected = true;
                  if (newValue == true) {
                    _applyTagToSelection(tag);
                  } else {
                    _removeTagFromSelection(tag);
                  }
                  Navigator.pop(context);
                },
              ),
            );
          }).toList(),
    );
    if (!_tagSelected) {
      setState(() {
        _selectionStart = null;
        _selectionEnd = null;
      });
    }
  }

  List<String> _getSelectedTags() {
    if (_selectionStart == null || _selectionEnd == null) {
      return [];
    }
    Set<String> tags = {};
    final int start = _selectionStart!;
    final int end = _selectionEnd!;
    final int lower = start < end ? start : end;
    final int upper = start > end ? start : end;
    for (int i = lower; i <= upper; i++) {
      tags.addAll(widget.segments[i].tags);
    }
    return tags.toList();
  }

  void _applyTagToSelection(String tag) {
    if (_selectionStart != null && _selectionEnd != null) {
      final int start = _selectionStart!;
      final int end = _selectionEnd!;
      final int lower = start < end ? start : end;
      final int upper = start > end ? start : end;
      setState(() {
        for (int i = lower; i <= upper; i++) {
          if (!widget.segments[i].tags.contains(tag)) {
            widget.segments[i].tags.add(tag);
          }
        }
      });
    }
  }

  void _removeTagFromSelection(String tag) {
    if (_selectionStart != null && _selectionEnd != null) {
      final int start = _selectionStart!;
      final int end = _selectionEnd!;
      final int lower = start < end ? start : end;
      final int upper = start > end ? start : end;
      setState(() {
        for (int i = lower; i <= upper; i++) {
          widget.segments[i].tags.remove(tag);
        }
      });
    }
  }

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
      return _availableTags[tags.first] ?? Colors.transparent;
    }

    List<Color> tagColors = tags.map((tag) => _availableTags[tag] ?? Colors.transparent).toList();
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

    return Color.fromARGB(
      255,
      totalRed ~/ colors.length,
      totalGreen ~/ colors.length,
      totalBlue ~/ colors.length,
    );
  }

  Color _blendColors(Color color1, Color color2) {
    return Color.fromARGB(
      255,
      (color1.red + color2.red) ~/ 2,
      (color1.green + color2.green) ~/ 2,
      (color1.blue + color2.blue) ~/ 2,
    );
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
                  RawGestureDetector(
                    gestures: {
                      LongPressGestureRecognizer:
                          GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
                            () => LongPressGestureRecognizer(),
                            (LongPressGestureRecognizer instance) {
                              instance
                                ..onLongPressStart = (details) {
                                  final RenderObject? renderObject =
                                      _textKey.currentContext?.findRenderObject();
                                  if (renderObject is RenderBox) {
                                    final localPosition = renderObject.globalToLocal(
                                      details.globalPosition,
                                    );
                                    final int wordIndex = _findWordIndexFromOffset(localPosition);
                                    setState(() {
                                      _selectionStart = wordIndex;
                                      _selectionEnd = wordIndex;
                                    });
                                  }
                                }
                                ..onLongPressMoveUpdate = (details) {
                                  final RenderObject? renderObject =
                                      _textKey.currentContext?.findRenderObject();
                                  if (renderObject is RenderBox) {
                                    final localPosition = renderObject.globalToLocal(
                                      details.globalPosition,
                                    );
                                    final int wordIndex = _findWordIndexFromOffset(localPosition);
                                    setState(() {
                                      _selectionEnd = wordIndex;
                                    });
                                  }
                                }
                                ..onLongPressEnd = (details) {
                                  _showContextMenu(details.globalPosition);
                                }
                                ..onLongPressCancel = () {
                                  setState(() {
                                    _selectionStart = null;
                                    _selectionEnd = null;
                                  });
                                };
                            },
                          ),
                    },
                    child: MouseRegion(
                      child: Listener(
                        onPointerDown: (event) {
                          if (event.kind == PointerDeviceKind.mouse &&
                              event.buttons == kSecondaryMouseButton) {
                            final RenderObject? renderObject =
                                _textKey.currentContext?.findRenderObject();
                            if (renderObject is RenderBox) {
                              final localPosition = renderObject.globalToLocal(event.position);
                              final int wordIndex = _findWordIndexFromOffset(localPosition);
                              _showContextMenu(event.position, wordIndex: wordIndex);
                              html.document.onContextMenu.listen((html.Event event) {
                                event.preventDefault();
                              });
                            }
                          }
                        },
                        child: GestureDetector(
                          onTapUp: (details) {
                            final RenderObject? renderObject =
                                _textKey.currentContext?.findRenderObject();
                            if (renderObject is RenderBox) {
                              final localPosition = renderObject.globalToLocal(
                                details.globalPosition,
                              );
                              final int wordIndex = _findWordIndexFromOffset(localPosition);
                              widget.onWordTap(wordIndex);
                            }
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
                                      style: TextStyle(
                                        backgroundColor:
                                            index == widget.currentWordIndex
                                                ? Colors.yellow
                                                : _getWordBackgroundColor(index),
                                      ),
                                    );
                                  }).toList(),
                            ),
                          ),
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

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:transcriber_whisper/transcription_cubit.dart';
import 'package:transcriber_whisper/transcription_state.dart';
import 'package:transcriber_whisper/transcription_widget_abstract.dart';
import 'package:get_it/get_it.dart';

class SelectableRichText extends TranscriptionWidget {
  const SelectableRichText({
    Key? key,
    required super.transcription,
    required super.audioPosition,
    required super.currentWordIndex,
    required super.onWordTap,
    super.autoScrollEnabled = true,
    super.onAutoScrollChanged,
  }) : super(key: key);

  @override
  State<SelectableRichText> createState() => _SelectableRichTextState();
}

class _SelectableRichTextState extends TranscriptionWidgetState<SelectableRichText> {
  final GlobalKey _currentWordKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();
  bool _internalPlayAndStopWordOnSelect = true;
  int? _selectionStart;
  int? _selectionEnd;
  List<int> _wordStartPositions = [];

  @override
  void initState() {
    super.initState();
    _calculateWordStartPositions();
  }

  void _calculateWordStartPositions() {
    _wordStartPositions.clear();
    int currentPosition = 0;
    for (int i = 0; i < widget.transcription.transcribedSegments.length; i++) {
      _wordStartPositions.add(currentPosition);
      currentPosition += widget.transcription.transcribedSegments[i].word.length + 1; // +1 for the space
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
    final RenderObject? renderObject = _currentWordKey.currentContext?.findRenderObject();
    if (renderObject is RenderParagraph) {
      final TextPosition textPosition = renderObject.getPositionForOffset(localPosition);
      return _findWordIndexFromTextPosition(textPosition);
    }
    return -1;
  }

  int _findWordIndexFromTextPosition(TextPosition textPosition) {
    for (int i = 0; i < _wordStartPositions.length; i++) {
      if (textPosition.offset < _wordStartPositions[i]) {
        return i - 1;
      }
    }
    return _wordStartPositions.length - 1;
  }

  /**/
  Color? _getWordBackgroundColor(int index) {
    if (index == widget.currentWordIndex) {
      return Colors.yellow;
    }
    final bool isSelected = _isWordSelected(index);
    final bool hasTags = widget.transcription.transcribedSegments[index].tags.isNotEmpty;

    if (isSelected && hasTags) {
      final Color tagColor = getMixedTagColor(widget.transcription.transcribedSegments[index].tags);
      final Color selectionColor = Colors.grey.withOpacity(0.5);
      return mixMultipleColors([tagColor, selectionColor]);
    } else if (isSelected) {
      return Colors.grey.withOpacity(0.5);
    } else if (hasTags) {
      return getMixedTagColor(widget.transcription.transcribedSegments[index].tags);
    }

    return null;
  }

  @override
  void scrollToCurrentWord() {
    /*if (_currentWordKey.currentContext != null) {
      final RenderBox box = _currentWordKey.currentContext!.findRenderObject() as RenderBox;
      final Offset offset = box.localToGlobal(Offset.zero);
      final double currentWordY = offset.dy;
      final double screenHeight = MediaQuery.of(context).size.height;
      final double scrollOffset = _scrollController.offset;
      final double targetScrollOffset = currentWordY - (screenHeight / 2) + (box.size.height / 2);
      _scrollController.animateTo(
        targetScrollOffset + scrollOffset,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }*/
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TranscriptionCubit, TranscriptionState>(
      builder: (context, state) {
        _internalPlayAndStopWordOnSelect = state.extradata!.playAndStopWordOnSelect;
        //_calculateWordStartPositions();
        List<InlineSpan> textSpans = [];
        for (int i = 0; i < widget.transcription.transcribedSegments.length; i++) {
          final segment = widget.transcription.transcribedSegments[i];
          String wordToDisplay = segment.word;
          TextStyle? wordStyle = TextStyle(backgroundColor: _getWordBackgroundColor(i));

          if (segment.wordAssociation != null) {
            wordToDisplay = segment.wordAssociation!.realWord ?? segment.word;
            wordStyle = wordStyle.copyWith(color: Colors.blue); // Resaltar palabras asociadas
          }
          textSpans.add(TextSpan(text: wordToDisplay, style: wordStyle));
          if (i < widget.transcription.transcribedSegments.length - 1) {
            textSpans.add(const TextSpan(text: " "));
          }
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          scrollToCurrentWord();
        });
        return SingleChildScrollView(
          controller: _scrollController,
          child: SizedBox(
            width: 500,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Listener(
                onPointerDown: (event) {
                  if (event.kind == PointerDeviceKind.mouse && event.buttons == kSecondaryMouseButton) {
                    final RenderObject? renderObject = _currentWordKey.currentContext?.findRenderObject();
                    if (renderObject is RenderBox) {
                      final localPosition = renderObject.globalToLocal(event.position);
                      final int wordIndex = _findWordIndexFromOffset(localPosition);
                      showContextMenu(event.position, wordIndexes: [wordIndex]);
                    }
                  }
                },
                child: GestureDetector(
                  onTapDown: (details) {
                    final RenderObject? renderObject = _currentWordKey.currentContext?.findRenderObject();
                    if (renderObject is RenderBox) {
                      final localPosition = renderObject.globalToLocal(details.globalPosition);
                      final int wordIndex = _findWordIndexFromOffset(localPosition);
                      if (wordIndex != -1) {
                        final String word = widget.transcription.transcribedSegments[wordIndex].word;
                        print("Clicked word: '$word' - Index: $wordIndex");
                        widget.onWordTap(wordIndex);
                      }
                    }
                  },
                  onLongPressStart: (details) {
                    final RenderObject? renderObject = _currentWordKey.currentContext?.findRenderObject();
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
                    final RenderObject? renderObject = _currentWordKey.currentContext?.findRenderObject();
                    if (renderObject is RenderBox) {
                      final localPosition = renderObject.globalToLocal(details.globalPosition);
                      final int wordIndex = _findWordIndexFromOffset(localPosition);
                      setState(() {
                        _selectionEnd = wordIndex;
                      });
                    }
                  },
                  onLongPressEnd: (details) {
                    final RenderObject? renderObject = _currentWordKey.currentContext?.findRenderObject();
                    if (renderObject is RenderBox) {
                      final localPosition = renderObject.globalToLocal(details.globalPosition);
                      final int wordIndex = _findWordIndexFromOffset(localPosition);
                      final int lower = _selectionStart! < _selectionEnd! ? _selectionStart! : _selectionEnd!;
                      final int upper = _selectionStart! > _selectionEnd! ? _selectionStart! : _selectionEnd!;
                      final List<int> selectedIndexes = List.generate(upper - lower + 1, (i) => lower + i);
                      showContextMenu(details.globalPosition, wordIndexes: selectedIndexes);
                    }
                  },
                  onLongPressCancel: () {
                    setState(() {
                      _selectionStart = null;
                      _selectionEnd = null;
                    });
                  },
                  child: Text.rich(key: _currentWordKey, TextSpan(children: textSpans)),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

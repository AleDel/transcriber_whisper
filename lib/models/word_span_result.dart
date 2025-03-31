import 'package:flutter/material.dart';
import 'package:transcriber_whisper/models/word_with_spans.dart';



class WordSpansResult {
  final List<TextSpan> spans;
  final DiffType diffType;
  final Color wordColor;

  WordSpansResult({
    required this.spans,
    required this.diffType,
    required this.wordColor,
  });
}
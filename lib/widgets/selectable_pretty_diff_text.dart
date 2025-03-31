import 'package:diff_match_patch/diff_match_patch.dart';
import 'package:flutter/material.dart';
import 'package:pretty_diff_text/pretty_diff_text.dart';

import '../models/word_with_spans.dart';

class SelectablePrettyDiffText extends StatefulWidget {
  final String oldText;
  final String newText;
  final double diffTimeout;
  final int diffEditCost;
  final TextAlign textAlign;

  const SelectablePrettyDiffText({
    Key? key,
    required this.oldText,
    required this.newText,
    this.diffTimeout = 1.0,
    this.diffEditCost = 4,
    this.textAlign = TextAlign.start,
  }) : super(key: key);

  @override
  _SelectablePrettyDiffTextState createState() => _SelectablePrettyDiffTextState();
}

class _SelectablePrettyDiffTextState extends State<SelectablePrettyDiffText> {
  List<WordWithSpans> _wordsWithSpans = [];

  ({List<TextSpan> spans, DiffType diffType, Color wordColor}) _buildWordSpans(String oldWord, String newWord) {
    final diffs = diff(oldWord, newWord);
    final spans = <TextSpan>[];
    DiffType diffType = DiffType.equal;
    Color wordColor = Colors.green.withOpacity(0.5);
    bool hasInsert = false;
    bool hasDelete = false;
    for (final diff in diffs) {
      Color color = Colors.transparent;
      if (diff.operation == DIFF_DELETE) {
        color = Colors.red.withOpacity(0.5);
        hasDelete = true;
      } else if (diff.operation == DIFF_INSERT) {
        color = Colors.blue.withOpacity(0.5);
        hasInsert = true;
      } else if (diff.operation == DIFF_EQUAL) {
        color = Colors.green.withOpacity(0.5);
      }
      spans.add(
        TextSpan(
          text: diff.text,
          style: TextStyle(backgroundColor: color),
        ),
      );
    }
    if (hasInsert && hasDelete) {
      diffType = DiffType.both;
      wordColor = Colors.purple.withOpacity(0.5);
    } else if (hasInsert) {
      diffType = DiffType.insert;
      wordColor = Colors.blue.withOpacity(0.5);
    } else if (hasDelete) {
      diffType = DiffType.delete;
      wordColor = Colors.red.withOpacity(0.5);
    } else {
      diffType = DiffType.equal;
      wordColor = Colors.green.withOpacity(0.5);
    }
    return (spans: spans, diffType: diffType, wordColor: wordColor);
  }

  @override
  Widget build(BuildContext context) {
    final diffs = diff(widget.oldText, widget.newText);
    final allSpans = <TextSpan>[];
    String formattedText = "";
    for (final diff in diffs) {
      Color color = Colors.transparent;
      if (diff.operation == DIFF_DELETE) {
        color = Colors.red.withOpacity(0.5);
      } else if (diff.operation == DIFF_INSERT) {
        color = Colors.blue.withOpacity(0.5);
      } else if (diff.operation == DIFF_EQUAL) {
        color = Colors.green.withOpacity(0.0);
      }
      allSpans.add(
        TextSpan(
          text: diff.text,
          style: TextStyle(backgroundColor: color),
        ),
      );
      formattedText += diff.text;
    }
    final formattedWords = formattedText.split(" ");
    final oldWords = widget.oldText.split(" ");
    final newWords = widget.newText.split(" ");
    int index = 0;
    _wordsWithSpans = [];
    for (int i = 0; i < formattedWords.length; i++) {
      String formattedWord = formattedWords[i];
      String oldWord = "";
      String newWord = "";
      if (i < oldWords.length) {
        oldWord = oldWords[i];
      }
      if (i < newWords.length) {
        newWord = newWords[i];
      }

      final result = _buildWordSpans(oldWord, newWord);
      _wordsWithSpans.add(WordWithSpans(word: oldWord,realWord: newWord, index: index, spans: result.spans, diffType: result.diffType, wordColor: result.wordColor));
      index++;
    }

    //print(_wordsWithSpans[14].word);
    //print(_wordsWithSpans[14].diffType);
    //print(_wordsWithSpans[14].wordColor);
    return SelectableText.rich(
      TextSpan(children: allSpans),
      textAlign: widget.textAlign,
    );
  }

  List<WordWithSpans> getWordsWithSpans() {
    return _wordsWithSpans;
  }
}
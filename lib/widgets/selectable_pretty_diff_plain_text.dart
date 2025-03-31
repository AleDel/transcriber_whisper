import 'package:diff_match_patch/diff_match_patch.dart';
import 'package:flutter/material.dart';

class ColoredTextPart {
  final String text;
  final Color color;

  ColoredTextPart(this.text, this.color);
}

class FormattedWord {
  final String originalWord;
  final List<ColoredTextPart> parts;

  FormattedWord(this.originalWord, this.parts);
}

class SelectablePrettyDiffPlaintText {
  final String oldText;
  final String newText;
  final double diffTimeout;
  final int diffEditCost;
  final TextAlign textAlign;

  const SelectablePrettyDiffPlaintText({
    required this.oldText,
    required this.newText,
    this.diffTimeout = 1.0,
    this.diffEditCost = 4,
    this.textAlign = TextAlign.start,
  });

  List<Diff> getDiffs() {
    final dmp = DiffMatchPatch();
    dmp.diffTimeout = diffTimeout;
    dmp.diffEditCost = diffEditCost;
    final diffs = dmp.diff(oldText, newText);
    dmp.diffCleanupSemantic(diffs);
    return diffs;
  }

  static String diffsToPlainText(List<Diff> diffs) {
    String plainText = "";
    for (final diff in diffs) {
      plainText += diff.text;
    }
    return plainText;
  }

  static List<FormattedWord> diffsToFormattedWords(List<Diff> diffs, List<String> originalWords, List<String> transcribedWords) {
    List<FormattedWord> formattedWords = [];
    for (int i = 0; i < originalWords.length; i++) {
      String originalWord = originalWords[i];
      String transcribedWord = "";
      if (i < transcribedWords.length) {
        transcribedWord = transcribedWords[i];
      }
      formattedWords.add(_buildFormattedWord(originalWord, transcribedWord));
    }
    return formattedWords;
  }

  static FormattedWord _buildFormattedWord(String originalWord, String transcribedWord) {
    List<ColoredTextPart> parts = [];
    if (originalWord == transcribedWord) {
      // Si las palabras son iguales, mostrar una sola palabra con color verde
      parts.add(ColoredTextPart(originalWord, Colors.green.withOpacity(0.5)));
    } else {
      // Si las palabras son diferentes, mostrar la palabra original arriba y la transcrita abajo
      final dmp = DiffMatchPatch();
      final diffs = dmp.diff(originalWord, transcribedWord);
      dmp.diffCleanupSemantic(diffs);

      for (final diff in diffs) {
        Color color = Colors.transparent;
        if (diff.operation == DIFF_DELETE) {
          color = Colors.red.withOpacity(0.5);
        } else if (diff.operation == DIFF_INSERT) {
          color = Colors.blue.withOpacity(0.5);
        } else if (diff.operation == DIFF_EQUAL) {
          color = Colors.green.withOpacity(0.5);
        }
        parts.add(ColoredTextPart(diff.text, color));
      }
    }
    return FormattedWord(originalWord, parts);
  }
}
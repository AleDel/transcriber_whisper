import 'package:flutter/material.dart';
import 'package:diff_match_patch/diff_match_patch.dart';
import 'package:pretty_diff_text/pretty_diff_text.dart'; // Importa diff_match_patch

class WordComparisonWidget extends StatelessWidget {
  final List<String> text1Words;
  final List<String> text2Words;
  final List<String> originalTextWords; // Nueva lista para el texto original
  final DiffCleanupType diffCleanupType;
  final double diffTimeout;
  final int diffEditCost;

  const WordComparisonWidget({
    Key? key,
    required this.text1Words,
    required this.text2Words,
    required this.originalTextWords, // Añadido al constructor
    this.diffCleanupType = DiffCleanupType.SEMANTIC,
    this.diffTimeout = 1.0,
    this.diffEditCost = 4,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    List<Widget> wordWidgets = [];

    for (int i = 0; i < originalTextWords.length; i++) {
      String originalWord = originalTextWords[i];
      String transcribedWord = "";
      if (i < text2Words.length) {
        transcribedWord = text2Words[i];
      }
      wordWidgets.add(_buildWordComparison(originalWord, transcribedWord));
      if (i < originalTextWords.length - 1) {
        wordWidgets.add(SizedBox(width: 8)); // Añadir espacio entre palabras
      }
    }

    return Wrap(
      children: wordWidgets,
    );
  }

  Widget _buildWordWidget(String word, Color color) {
    return Container(
      padding: const EdgeInsets.all(4.0),
      margin: const EdgeInsets.all(2.0),
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: Colors.grey),
      ),
      child: Text(
        word,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12),
      ),
    );
  }

  Widget _buildWordComparison(String originalWord, String transcribedWord) {
    if (originalWord == transcribedWord) {
      // Si las palabras son iguales, mostrar una sola palabra con color verde
      return Padding(
        padding: const EdgeInsets.all(2.0),
        child: _buildWordWidget(originalWord, Colors.green.withOpacity(0.5)),
      );
    } else {
      // Si las palabras son diferentes, mostrar la palabra original arriba y la transcrita abajo
      final dmp = DiffMatchPatch();
      dmp.diffTimeout = diffTimeout;
      dmp.diffEditCost = diffEditCost;
      final diffs = dmp.diff(originalWord, transcribedWord);
      dmp.diffCleanupSemantic(diffs);

      List<Widget> diffWidgets = [];
      for (final diff in diffs) {
        Color color = Colors.transparent;
        if (diff.operation == DIFF_DELETE) {
          color = Colors.red.withOpacity(0.5);
        } else if (diff.operation == DIFF_INSERT) {
          color = Colors.blue.withOpacity(0.5);
        } else if (diff.operation == DIFF_EQUAL) {
          color = Colors.green.withOpacity(0.5);
        }
        diffWidgets.add(
          _buildWordWidget(diff.text, color),
        );
      }

      return Padding(
        padding: const EdgeInsets.all(2.0),
        child: Column(
          children: [
            Text(
              originalWord,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (transcribedWord.isNotEmpty) Wrap(
              children: diffWidgets,
            ),
          ],
        ),
      );
    }
  }
}
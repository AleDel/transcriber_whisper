import 'package:diff_match_patch/diff_match_patch.dart';
import 'package:flutter/material.dart';

class SelectablePrettyDiffText extends StatelessWidget {
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
  Widget build(BuildContext context) {
    List<String> oldWords = oldText.split(" ");
    List<String> newWords = newText.split(" ");

    List<Widget> wordWidgets = [];
    for (int i = 0; i < oldWords.length; i++) {
      String oldWord = oldWords[i];
      String newWord = "";
      if (i < newWords.length) {
        newWord = newWords[i];
      }
      wordWidgets.add(_buildWordComparison(oldWord, newWord));
      if (i < oldWords.length - 1) {
        wordWidgets.add(SizedBox(width: 8)); // Añadir espacio entre palabras
      }
    }

    return Wrap(
      alignment: WrapAlignment.start,
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
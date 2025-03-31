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
    // Convertir las listas de palabras a cadenas de texto
    String text1 = text1Words.join(" ");
    String text2 = text2Words.join(" ");

    // Calcular las diferencias usando diff_match_patch
    final dmp = DiffMatchPatch();
    final diffs = dmp.diff(text1, text2);
    dmp.diffCleanupSemantic(diffs);

    // Crear una lista de widgets para cada palabra
    List<Widget> text1Widgets = [];
    List<Widget> text2Widgets = [];
    List<Widget> originalTextWidgets = []; // Nueva lista para el texto original

    for (final diff in diffs) {
      if (diff.operation == DIFF_EQUAL) {
        // Si las palabras son iguales, añadirlas a ambas listas
        _addWidgets(diff.text, Colors.green.withOpacity(0.5), text1Widgets, text2Widgets);
      } else if (diff.operation == DIFF_DELETE) {
        // Si la palabra está en text1 pero no en text2, añadirla a text1 con color rojo
        _addWidgets(diff.text, Colors.red.withOpacity(0.5), text1Widgets, text2Widgets, isDelete: true);
      } else if (diff.operation == DIFF_INSERT) {
        // Si la palabra está en text2 pero no en text1, añadirla a text2 con color azul
        _addWidgets(diff.text, Colors.blue.withOpacity(0.5), text1Widgets, text2Widgets, isInsert: true);
      }
    }

    // Ajustar la longitud de las listas si es necesario
    while (text1Widgets.length < text2Widgets.length) {
      text1Widgets.add(_buildWordWidget("", Colors.transparent));
    }
    while (text2Widgets.length < text1Widgets.length) {
      text2Widgets.add(_buildWordWidget("", Colors.transparent));
    }
    // Añadir las palabras del texto original a la lista de widgets
    for (int i = 0; i < originalTextWords.length; i++) {
      String originalWord = originalTextWords[i];
      String transcribedWord = "";
      if (i < text2Words.length) {
        transcribedWord = text2Words[i];
      }
      originalTextWidgets.add(_buildOriginalWordWidget(originalWord, transcribedWord));
    }

    return Column(
      children: [
        Wrap(
          children: originalTextWidgets, // Mostrar el texto original primero
        ),
        Wrap(
          children: text1Widgets,
        ),
        Wrap(
          children: text2Widgets,
        ),
      ],
    );
  }

  void _addWidgets(String text, Color color, List<Widget> text1Widgets, List<Widget> text2Widgets, {bool isDelete = false, bool isInsert = false}) {
    if (isDelete) {
      text1Widgets.add(_buildWordWidget(text, color));
      text2Widgets.add(_buildWordWidget("", Colors.transparent));
    } else if (isInsert) {
      text1Widgets.add(_buildWordWidget("", Colors.transparent));
      text2Widgets.add(_buildWordWidget(text, color));
    } else {
      List<String> words = text.split(" ");
      for (String word in words) {
        if (word.isNotEmpty) {
          text1Widgets.add(_buildWordWidget(word, color));
          text2Widgets.add(_buildWordWidget(word, color));
        }
      }
    }
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
      ),
    );
  }

  Widget _buildOriginalWordWidget(String originalWord, String transcribedWord) {
    final dmp = DiffMatchPatch();
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

    return Column(
      children: [
        _buildWordWidget(originalWord, Colors.transparent),
        Wrap(
          children: diffWidgets,
        ),
      ],
    );
  }
}
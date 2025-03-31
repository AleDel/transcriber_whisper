import 'package:flutter/material.dart';
import 'package:pretty_diff_text/pretty_diff_text.dart';
import 'package:diff_match_patch/diff_match_patch.dart'; // Importa diff_match_patch

class WordComparisonWidget extends StatelessWidget {
  final List<String> text1Words;
  final List<String> text2Words;
  final DiffCleanupType diffCleanupType;
  final double diffTimeout;
  final int diffEditCost;

  const WordComparisonWidget({
    Key? key,
    required this.text1Words,
    required this.text2Words,
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
    int text1Index = 0;
    int text2Index = 0;

    for (final diff in diffs) {
      if (diff.operation == DIFF_EQUAL) {
        // Si las palabras son iguales, añadirlas a ambas listas
        List<String> words = diff.text.split(" ");
        for (String word in words) {
          if (word.isNotEmpty) {
            text1Widgets.add(
              _buildWordWidget(word, Colors.green.withOpacity(0.5)),
            );
            text2Widgets.add(
              _buildWordWidget(word, Colors.green.withOpacity(0.5)),
            );
            text1Index++;
            text2Index++;
          }
        }
      } else if (diff.operation == DIFF_DELETE) {
        // Si la palabra está en text1 pero no en text2, añadirla a text1 con color rojo
        List<String> words = diff.text.split(" ");
        for (String word in words) {
          if (word.isNotEmpty) {
            text1Widgets.add(
              _buildWordWidget(word, Colors.red.withOpacity(0.5)),
            );
            text2Widgets.add(
              _buildWordWidget("", Colors.transparent),
            );
            text1Index++;
          }
        }
      } else if (diff.operation == DIFF_INSERT) {
        // Si la palabra está en text2 pero no en text1, añadirla a text2 con color azul
        List<String> words = diff.text.split(" ");
        for (String word in words) {
          if (word.isNotEmpty) {
            text1Widgets.add(
              _buildWordWidget("", Colors.transparent),
            );
            text2Widgets.add(
              _buildWordWidget(word, Colors.blue.withOpacity(0.5)),
            );
            text2Index++;
          }
        }
      }
    }

    // Ajustar la longitud de las listas si es necesario
    while (text1Widgets.length < text2Widgets.length) {
      text1Widgets.add(_buildWordWidget("", Colors.transparent));
    }
    while (text2Widgets.length < text1Widgets.length) {
      text2Widgets.add(_buildWordWidget("", Colors.transparent));
    }

    return Column(
      children: [
        Wrap(
          children: text1Widgets,
        ),
        Wrap(
          children: text2Widgets,
        ),
      ],
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
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:diff_match_patch/diff_match_patch.dart';

//teniendo el texto transcrito como verdad
enum DiffType {
  equal, // existe completamente toda la palabra  en la transcripcion y en el texto real
  insert, // existe la palabra en la transcripcion y texto real, pero tiene letra nueva en texto real
  delete, // existe la palabra en la transcripcion y texto real, pero tiene letra borrada en texto real
  both,
  change,
  insertWord, // existe toda la palabra en el texto real pero no en la transcipcion
  deleteWord, move  // existe toda la palabra en la transcripcion pero no en el texto real
}

class WordWithSpans {
  String word; // Palabra de la transcripción
  String realWord; // Palabra del texto real
  int index; // Índice de la palabra en la lista original
  List<TextSpan> spans; // Lista de TextSpan para la palabra
  DiffType diffType; // Tipo de diferencia (insert, delete, move, equal)
  Color wordColor; // Color de la palabra

  WordWithSpans({
    required this.word,
    required this.realWord,
    required this.index,
    required this.spans,
    required this.diffType,
    required this.wordColor,
  });

  WordWithSpans copyWith({
    String? word,
    String? realWord,
    int? index,
    List<TextSpan>? spans,
    DiffType? diffType,
    Color? wordColor,
  }) {
    return WordWithSpans(
      word: word ?? this.word,
      realWord: realWord ?? this.realWord,
      index: index ?? this.index,
      spans: spans ?? this.spans,
      diffType: diffType ?? this.diffType,
      wordColor: wordColor ?? this.wordColor,
    );
  }
}
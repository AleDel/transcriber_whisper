import 'package:diff_match_patch/diff_match_patch.dart';
import 'package:flutter/material.dart';

class DiffText extends StatelessWidget {
  final String originalText;
  final String transcribedText;

  const DiffText({
    Key? key,
    required this.originalText,
    required this.transcribedText,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dmp = DiffMatchPatch();
    final diffs = dmp.diff(originalText, transcribedText);
    return RichText(
      text: TextSpan(
        children: diffs.map((diff) {
          switch (diff.operation) {
            case DIFF_EQUAL:
              return TextSpan(text: diff.text, style: const TextStyle(color: Colors.black));
            case DIFF_INSERT:
              return TextSpan(
                text: diff.text,
                style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
              );
            case DIFF_DELETE:
              return TextSpan(
                text: diff.text,
                style: const TextStyle(
                  color: Colors.red,
                  decoration: TextDecoration.lineThrough,
                ),
              );
            default:
              return const TextSpan(text: '');
          }
        }).toList(),
      ),
    );
  }
}
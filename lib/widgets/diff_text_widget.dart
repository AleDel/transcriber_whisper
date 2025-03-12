import 'package:diff_match_patch/diff_match_patch.dart';
import 'package:flutter/material.dart';

class DiffText extends StatefulWidget {
  final String originalText;
  final String transcribedText;
  final TextStyle textStyle;

  const DiffText({
    Key? key,
    required this.originalText,
    required this.transcribedText,
    required this.textStyle,
  }) : super(key: key);

  @override
  State<DiffText> createState() => _DiffTextState();
}

class _DiffTextState extends State<DiffText> {
  List<int> modifiedLines = [];

  @override
  void initState() {
    super.initState();
    _calculateModifiedLines();
  }

  void _calculateModifiedLines() {
    final originalLines = widget.originalText;
    final transcribedLines = widget.transcribedText;

    for (int i = 0; i < originalLines.length; i++) {
      final originalLine = originalLines[i];
      final transcribedLine = i < transcribedLines.length ? transcribedLines[i] : '';

      if (originalLine.trim() != transcribedLine.trim()) {
        modifiedLines.add(i + 1);
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    final dmp = DiffMatchPatch();
    final diffs = dmp.diff(widget.originalText, widget.transcribedText);
    _calculateModifiedLines();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          softWrap: false,
          text: TextSpan(
            children: diffs.map((diff) {
              switch (diff.operation) {
                case DIFF_EQUAL:
                  return TextSpan(text: diff.text, style: widget.textStyle.copyWith(color: Colors.black));
                case DIFF_INSERT:
                  return TextSpan(
                    text: diff.text,
                    style: widget.textStyle.copyWith(color: Colors.green, fontWeight: FontWeight.bold),
                  );
                case DIFF_DELETE:
                  return TextSpan(
                    text: diff.text,
                    style: widget.textStyle.copyWith(
                      color: Colors.red,
                      decoration: TextDecoration.lineThrough,
                    ),
                  );
                default:
                  return const TextSpan(text: '');
              }
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        Text('Lineas Modificadas: ${modifiedLines.join(', ')}', style: const TextStyle(color: Colors.blue)),
      ],
    );
  }
}
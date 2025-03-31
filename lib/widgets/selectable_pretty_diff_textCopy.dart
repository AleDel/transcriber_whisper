import 'package:diff_match_patch/diff_match_patch.dart';
import 'package:flutter/material.dart';
import 'package:pretty_diff_text/pretty_diff_text.dart';

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
    final diffs = diff(
      oldText,
      newText,
    );

    final spans = <TextSpan>[];
    for (final diff in diffs) {
      Color color = Colors.transparent;
      if (diff.operation == DIFF_DELETE) {
        color = Colors.red.withOpacity(0.5);
      } else if (diff.operation == DIFF_INSERT) {
        color = Colors.blue.withOpacity(0.5);
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

    return SelectableText.rich(
      TextSpan(children: spans),
      textAlign: textAlign,
    );
  }
}
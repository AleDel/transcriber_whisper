import 'package:flutter/material.dart';
import 'package:transcriber_whisper/widgets/selectable_pretty_diff_plain_text.dart';

class FormattedWordsWidget extends StatelessWidget {
  final List<FormattedWord> formattedWords;

  const FormattedWordsWidget({Key? key, required this.formattedWords}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Wrap(
      children: formattedWords.map((formattedWord) {
        return _buildFormattedWordWidget(formattedWord);
      }).toList(),
    );
  }

  Widget _buildFormattedWordWidget(FormattedWord formattedWord) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.0),
      child: Wrap(
        children: formattedWord.parts.map((part) {
          return Text(
            part.text,
            style: TextStyle(backgroundColor: part.color),
          );
        }).toList(),
      ),
    );
  }
}
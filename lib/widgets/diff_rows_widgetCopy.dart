// diff_rows_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:transcriber_whisper/models/word_with_spans.dart';
import 'package:transcriber_whisper/transcribe_cubit.dart';
import 'package:transcriber_whisper/transcribe_state.dart';

class DiffRowsWidget extends StatelessWidget {
  const DiffRowsWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TranscribeCubit, TranscribeState>(
      builder: (context, state) {
        if (state.status == TranscribeStatus.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.wordsWithSpans.isEmpty || state.realtextComoTranscription == null) {
          return const Center(child: Text("No data available"));
        }

        // Create a map to quickly find the corresponding WordWithSpans for each real word
        final Map<String, WordWithSpans> wordMap = {};
        for (final wordWithSpans in state.wordsWithSpans) {
          wordMap[wordWithSpans.word] = wordWithSpans;
        }

        return Column(
          children: [
            // Row for real text with corresponding wordWithSpans
            Wrap(
              alignment: WrapAlignment.center,
              children: state.realtextComoTranscription!.transsegments.map((segment) {
                final correspondingWord = wordMap.containsKey(segment.word) ? wordMap[segment.word] : null;
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Text(segment.word, style: const TextStyle(fontSize: 18)),
                    ),
                    if (correspondingWord != null)
                      Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Text.rich(
                          TextSpan(
                            text: correspondingWord.word,
                            style: TextStyle(fontSize: 14, color: correspondingWord.wordColor),
                          ),
                        ),
                      )
                    else
                      const SizedBox.shrink(), // Empty space if no corresponding word
                  ],
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            // Row for inserted words
            Wrap(
              alignment: WrapAlignment.center,
              children: state.wordsWithSpans.where((wordWithSpans) => !wordMap.containsKey(wordWithSpans.word)).map((wordWithSpans) {
                return Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Text.rich(
                    TextSpan(
                      text: wordWithSpans.word,
                      style: TextStyle(fontSize: 14, color: wordWithSpans.wordColor),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }
}
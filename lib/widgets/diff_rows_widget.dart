import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:transcriber_whisper/models/word_with_spans.dart';
import 'package:transcriber_whisper/transcription_cubit.dart';
import 'package:transcriber_whisper/transcription_state.dart';

class DiffRowsWidget extends StatelessWidget {
  const DiffRowsWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TranscriptionCubit, TranscriptionState>(
      builder: (context, state) {
        if (state.status == TranscriptionStatus.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.wordsWithSpans.isEmpty || state.transcription == null) {
          return const Center(child: Text("No data available"));
        }

        return Column(
          children: [
            // Row for real text with corresponding wordWithSpans
            Wrap(
              alignment: WrapAlignment.center,
              children:
              state.transcription!.referenceTextSegments!.asMap().entries.map((entry) {
                    final int index = entry.key;
                    final segment = entry.value;
                    final correspondingWord = state.wordsWithSpans.firstWhere(
                      (wordWithSpans) => wordWithSpans.index == index,
                      orElse: () => WordWithSpans(word: "",realWord: "", index: -1, spans: [], diffType: DiffType.equal, wordColor: Colors.transparent),
                    );

                    return Column(
                      children: [
                        Padding(padding: const EdgeInsets.all(4.0), child: Text("$index: ${segment.word}", style: const TextStyle(fontSize: 18))),
                        if (correspondingWord.index != -1)
                          Padding(padding: const EdgeInsets.all(4.0), child: Text.rich(TextSpan(children: correspondingWord.spans)))
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
              children:
                  state.wordsWithSpans
                      .where(
                        (wordWithSpans) =>
                            state.transcription!.referenceTextSegments!.indexWhere(
                              (segment) =>
                                  segment.word.toLowerCase().trim().replaceAll(RegExp(r'[^\w\s]'), '') ==
                                  wordWithSpans.word.toLowerCase().trim().replaceAll(RegExp(r'[^\w\s]'), ''),
                            ) ==
                            -1,
                      )
                      .map((wordWithSpans) {
                        return Padding(padding: const EdgeInsets.all(4.0), child: Text.rich(TextSpan(children: wordWithSpans.spans)));
                      })
                      .toList(),
            ),
          ],
        );
      },
    );
  }
}

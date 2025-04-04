import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:transcriber_whisper/models/word_with_spans.dart';
import 'package:transcriber_whisper/transcription_cubit.dart';
import 'package:transcriber_whisper/transcription_state.dart';

class TwoRowsWithSharedScrollWidget extends StatefulWidget {
  const TwoRowsWithSharedScrollWidget({Key? key}) : super(key: key);

  @override
  _TwoRowsWithSharedScrollWidgetState createState() => _TwoRowsWithSharedScrollWidgetState();
}

class _TwoRowsWithSharedScrollWidgetState extends State<TwoRowsWithSharedScrollWidget> {
  final ScrollController _scrollController = ScrollController();

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      final double scrollDelta = event.scrollDelta.dx;
      _scrollController.animateTo(
        _scrollController.position.pixels + scrollDelta,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: MyCustomScrollBehavior(),
      child: BlocBuilder<TranscriptionCubit, TranscriptionState>(
        builder: (context, state) {
          if (state.status == TranscriptionStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.wordsWithSpans.isEmpty || state.transcription == null) {
            return const Center(child: Text("No data available"));
          }

          return Listener(
            onPointerSignal: _handlePointerSignal,
            child: SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row for transcription.segments (transcription words)
                  /*Row(
                    mainAxisSize: MainAxisSize.min,
                    children: state.transcription!.transsegments.map((segment) => segment.word).toList().map((word) => _buildRawWordWidget(word)).toList(),
                  ),*/
                  // Row for transcription.realsegments (real words)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: state.transcription!.realTextSegments!.map((segment) => segment.word).toList().map((word) => _buildRawWordWidget(word)).toList(),
                  ),
                  /*Row(
                    mainAxisSize: MainAxisSize.min,
                    children: state.realtextComoTranscription!.realsegments!.map((segment) => segment.word).toList().map((word) => _buildRawWordWidget(word)).toList(),
                  ),*/
                  // Row for wordsWithSpans spans only
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: state.wordsWithSpans.map((wordWithSpans) => _buildWordWithSpansWidget(wordWithSpans)).toList(),
                  ),
                  // Row for wordsWithSpans word only
                  /*Row(
                    mainAxisSize: MainAxisSize.min,
                    children: state.wordsWithSpans.map((segment) => segment.word).toList().map((word) => _buildRawWordWidget(word)).toList(),
                  ),*/

                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Widget builder for raw words (top and second rows)
  Widget _buildRawWordWidget(String word) {
    return SizedBox(
      width: 100,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: Text(
            word,
            style: const TextStyle(fontSize: 18, color: Colors.black),
          ),
        ),
      ),
    );
  }

  // Widget builder for words with spans (third row)
  Widget _buildWordWidget(String word, WordWithSpans correspondingWord) {
    Color wordColor = Colors.black;
    if (correspondingWord.diffType == DiffType.insert) {
      wordColor = Colors.blue;
    }
    if (correspondingWord.diffType == DiffType.delete) {
      wordColor = Colors.red;
    }
    return SizedBox(
      width: 100,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: Text.rich(
            TextSpan(
              text: word,
              style: TextStyle(fontSize: 18, color: wordColor),
              children: correspondingWord.spans,
            ),
          ),
        ),
      ),
    );
  }

  // Widget builder for wordsWithSpans spans only (fourth row)
  Widget _buildWordWithSpansWidget(WordWithSpans wordWithSpans) {
    return SizedBox(
      width: 100,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          // Use Text.rich to display multiple spans
          child: Text.rich(
            TextSpan(
              children: wordWithSpans.spans, // Display only the spans
            ),
          ),
        ),
      ),
    );
  }

  // Widget builder for processed words (fifth row)
  Widget _buildProcessedWordWidget(String word) {
    return SizedBox(
      width: 100,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: Text(
            word,
            style: const TextStyle(fontSize: 18, color: Colors.black),
          ),
        ),
      ),
    );
  }
}

class MyCustomScrollBehavior extends MaterialScrollBehavior {
  // Override behavior methods and getters like dragDevices
  @override
  Set<PointerDeviceKind> get dragDevices => {PointerDeviceKind.touch, PointerDeviceKind.mouse};
}
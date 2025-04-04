import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:transcriber_whisper/models/segment.dart';
import 'package:transcriber_whisper/transcription_cubit.dart';
import 'package:transcriber_whisper/transcription_state.dart';

class PunctuationErrorLegendWidget extends StatelessWidget {
  const PunctuationErrorLegendWidget({Key? key}) : super(key: key);

  Color _getSegmentColor(String segment) {
    if (segment.trim().isEmpty) {
      return Colors.grey.withOpacity(0.5); // Salto de línea
    } else if (segment == ',') {
      return Colors.orange.withOpacity(0.5); // Coma
    } else if (segment == '.') {
      return Colors.purple[100]!; // Punto (malva flojo)
    } else if (segment == '!') {
      return Colors.lightBlue.withOpacity(0.5); // Exclamación
    } else if (segment == '?') {
      return Colors.green.withOpacity(0.5); // Interrogación
    } else if (segment == ' ') {
      return Colors.transparent; // Espacio
    } else {
      return Colors.transparent; // Sin signo de puntuación
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TranscriptionCubit, TranscriptionState>(
      builder: (context, state) {
        if (state.transcription == null) {
          return const Center(child: Text("No hay datos para mostrar."));
        }
        final transcription = state.transcription!;
        final Map<String, int> punctuationTagCounts = _calculatePunctuationTagCounts(transcription.rawRealTextSegments ?? []);
        final int totalPunctuationErrors = punctuationTagCounts.values.fold(0, (sum, count) => sum + count);

        final List<String> punctuationSymbols = [',', '.', '!', '?'];

        return Card(
          margin: const EdgeInsets.all(8.0),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      "Puntuazio Akatsak",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 4),
                    Text("($totalPunctuationErrors)", style: const TextStyle(fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 4.0,
                  runSpacing: 2.0,
                  children: punctuationSymbols.map((symbol) {
                    final int count = punctuationTagCounts[symbol] ?? 0;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Chip(
                          label: Text(symbol, style: const TextStyle(fontSize: 12)),
                          backgroundColor: _getSegmentColor(symbol),
                          visualDensity: VisualDensity.compact,
                          labelPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                        ),
                        Text("$count", style: const TextStyle(fontSize: 10)),
                      ],
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Map<String, int> _calculatePunctuationTagCounts(List<Segment> segments) {
    final Map<String, int> punctuationTagCounts = {};
    for (final segment in segments) {
      if (_isPunctuationSegment(segment.word)) {
        for (final tag in segment.tags) {
          punctuationTagCounts[segment.word] = (punctuationTagCounts[segment.word] ?? 0) + 1;
        }
      }
    }
    return punctuationTagCounts;
  }

  bool _isPunctuationSegment(String word) {
    return [',', '.', '!', '?'].contains(word);
  }
}
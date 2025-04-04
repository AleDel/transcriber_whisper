import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:transcriber_whisper/models/segment.dart';
import 'package:transcriber_whisper/transcription_cubit.dart';
import 'package:transcriber_whisper/transcription_state.dart';

class CompactTagLegendWidget extends StatelessWidget {
  const CompactTagLegendWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TranscriptionCubit, TranscriptionState>(
      builder: (context, state) {
        if (state.transcription == null) {
          return const Center(child: Text("No hay datos para mostrar."));
        }
        final transcription = state.transcription!;
        final Map<String, int> tagCounts = _calculateTagCounts(transcription.rawRealTextSegments ?? []);
        final int totalErrors = tagCounts.values.fold(0, (sum, count) => sum + count);
        // Ordenar los tags alfabéticamente
        final sortedTags = TranscriptionCubit.availableTags.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

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
                      "Irakurketaren zehaztasuna",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 4),
                    Text("($totalErrors)", style: const TextStyle(fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 4.0,
                  runSpacing: 2.0,
                  children: sortedTags.map((entry) {
                    final String tag = entry.key;
                    final Color color = entry.value;
                    final String symbol = TranscriptionCubit.tagToSymbol[tag] ?? tag;
                    final int count = tagCounts[tag] ?? 0; // Obtener el contador
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Chip(
                          label: Text(symbol, style: const TextStyle(fontSize: 12)),
                          backgroundColor: color,
                          visualDensity: VisualDensity.compact,
                          labelPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                        ),
                        Text("$count", style: const TextStyle(fontSize: 10)), // Mostrar el contador
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

  Map<String, int> _calculateTagCounts(List<Segment> segments) {
    final Map<String, int> tagCounts = {};
    for (final segment in segments) {
      for (final tag in segment.tags) {
        tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
      }
    }
    return tagCounts;
  }
}
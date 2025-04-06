import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:transcriber_whisper/models/segment.dart';
import 'package:transcriber_whisper/transcription_cubit.dart';
import 'package:transcriber_whisper/transcription_state.dart';

class TagLegendWidget extends StatefulWidget {
  final Function(List<Map<String, dynamic>>) onSegmentDataChanged;
  const TagLegendWidget({Key? key, required this.onSegmentDataChanged}) : super(key: key);

  @override
  State<TagLegendWidget> createState() => _TagLegendWidgetState();
}

class _TagLegendWidgetState extends State<TagLegendWidget> {
  bool _isExpanded = false;
  List<Map<String, dynamic>>? _segmentData;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateSegmentData();
  }

  void _updateSegmentData() {
    final state = context.read<TranscriptionCubit>().state;
    if (state.transcription == null) return;
    final transcription = state.transcription!;
    final segmentData = _getSegmentData(transcription.rawReferenceTextSegments ?? []);
    if (_segmentData != segmentData) {
      _segmentData = segmentData;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onSegmentDataChanged(segmentData);
      });
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
        final Map<String, int> tagCounts = _calculateTagCounts(transcription.rawReferenceTextSegments ?? []);
        // Calcular el total de errores
        final int totalErrors = tagCounts.values.fold(0, (sum, count) => sum + count);
        // Ordenar los tags alfabéticamente
        final sortedTags = TranscriptionCubit.availableTags.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

        return Card(
          margin: const EdgeInsets.all(8.0),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: ExpansionTile(
              title: Row(
                children: [
                  const Text(
                    "Akatsak",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 4),
                  Text("($totalErrors)", style: const TextStyle(fontSize: 14)),
                ],
              ),
              initiallyExpanded: _isExpanded,
              onExpansionChanged: (expanded) {
                setState(() {
                  _isExpanded = expanded;
                });
              },
              children: [
                Wrap(
                  spacing: 4.0,
                  runSpacing: 2.0,
                  children: sortedTags.map((entry) {
                    final String tag = entry.key;
                    final Color color = entry.value;
                    final String symbol = TranscriptionCubit.tagToSymbol[tag] ?? tag;
                    final int count = tagCounts[tag] ?? 0;
                    final List<String> taggedWords = _findTaggedWords(transcription.rawReferenceTextSegments ?? [], tag);
                    return _buildTagItem(context, tag, symbol, color, count, taggedWords);
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTagItem(BuildContext context, String tag, String symbol, Color color, int count, List<String> taggedWords) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 120),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Chip(
            label: Text(symbol, style: const TextStyle(fontSize: 12)),
            backgroundColor: color,
            visualDensity: VisualDensity.compact,
            labelPadding: const EdgeInsets.symmetric(horizontal: 4.0),
          ),
          const SizedBox(width: 2),
          Text("$tag ($count)", style: const TextStyle(fontSize: 12)),
          if (taggedWords.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.arrow_drop_down, size: 16),
              padding: EdgeInsets.zero,
              onSelected: (String value) {
                // No es necesario hacer nada aquí, ya que el menú solo muestra la lista
              },
              itemBuilder: (BuildContext context) {
                return taggedWords.map((word) {
                  return PopupMenuItem<String>(
                    value: word,
                    child: Text(word, style: const TextStyle(fontSize: 12)),
                  );
                }).toList();
              },
            ),
        ],
      ),
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

  List<String> _findTaggedWords(List<Segment> segments, String tag) {
    final List<String> taggedWords = [];
    for (final segment in segments) {
      if (segment.tags.contains(tag)) {
        taggedWords.add(segment.word);
      }
    }
    return taggedWords;
  }
  List<Map<String, dynamic>> _getSegmentData(List<Segment> segments) {
    final List<Map<String, dynamic>> segmentData = [];
    for (final segment in segments) {
      segmentData.add({
        'word': segment.word,
        'tags': segment.tags,
      });
    }
    return segmentData;
  }
}
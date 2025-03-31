import 'package:flutter/material.dart';
import 'package:transcriber_whisper/models/segment.dart';

class AssociatedSegmentsWidget extends StatelessWidget {
  final List<Segment> alignedSegments;

  const AssociatedSegmentsWidget({Key? key, required this.alignedSegments}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: alignedSegments.length,
      itemBuilder: (context, index) {
        final segment = alignedSegments[index];
        return AssociatedSegmentItem(segment: segment);
      },
    );
  }
}

class AssociatedSegmentItem extends StatelessWidget {
  final Segment segment;

  const AssociatedSegmentItem({Key? key, required this.segment}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Palabra Real
            if (segment.realWord != null)
              Text('Palabra Real: ${segment.realWord}', style: const TextStyle(fontWeight: FontWeight.bold)),
            // Insercion
            if (segment.realWord == null)
              Text('Insercion: ${segment.word}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8.0),
            // Palabras Transcritas Asociadas
            if (segment.transcribedWords != null && segment.transcribedWords!.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Palabras Transcritas Asociadas:'),
                  Wrap(
                    spacing: 8.0,
                    children: segment.transcribedWords!.map((word) {
                      final index = segment.transcribedWords!.indexOf(word);
                      final probability = index < segment.transcribedWordsProbabilities!.length ? segment.transcribedWordsProbabilities![index] : 0.0;
                      return Chip(label: Text('$word (${probability.toStringAsFixed(2)})'));
                    }).toList(),
                  ),
                ],
              ),
            const SizedBox(height: 8.0),
            // Tipo de Asociación
            if (segment.associationType != null)
              Text('Tipo de Asociación: ${segment.associationType ?? 'N/A'}'),
            const SizedBox(height: 8.0),
            // Distancia de Levenshtein
            if (segment.levenshteinDistance != null)
              Text('Distancia de Levenshtein: ${segment.levenshteinDistance ?? 'N/A'}'),
          ],
        ),
      ),
    );
  }
}

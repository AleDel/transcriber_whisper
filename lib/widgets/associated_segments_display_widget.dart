import 'package:flutter/material.dart';
import 'package:transcriber_whisper/models/segment.dart';
import '../models/word_association.dart';
import 'package:flutter_bloc/flutter_bloc.dart';


import '../transcription_cubit.dart';

class AssociatedSegmentsDisplayWidget extends StatelessWidget {
  final List<Segment> associatedSegments;

  const AssociatedSegmentsDisplayWidget({Key? key, required this.associatedSegments}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return associatedSegments.isEmpty
        ? const Center(child: Text("No hay segmentos asociados."))
        : SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(associatedSegments.length, (index) {
          final segment = associatedSegments[index];
          return AssociatedSegmentCard(
            segment: segment,
            index: index,
            onTap: (index) {
              // Llamar al Cubit para reproducir el audio del segmento
              context.read<TranscriptionCubit>().forceCurrentAssociatedWord(index);
            },
          );
        }),
      ),
    );
  }
}

class AssociatedSegmentCard extends StatelessWidget {
  final Segment segment;
  final int index;
  final Function(int) onTap; // Nuevo: Callback para el clic en la tarjeta

  const AssociatedSegmentCard({Key? key, required this.segment, required this.index, required this.onTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(index), // Llamar al callback al hacer clic
      child: Card(
        margin: const EdgeInsets.all(8.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Segmento ${index + 1}", // Mostrar el índice del segmento
                style: Theme.of(context).textTheme.titleMedium!.copyWith(fontWeight: FontWeight.bold),
              ),
              const Divider(),
              _buildInfoRow("Palabra Real", segment.realWord ?? "N/A"),
              _buildInfoRow("Palabra Transcrita", segment.word),
              _buildInfoRow("Tipo de Asociación", segment.associationType.name ?? ""),
              _buildInfoRow("Distancia Levenshtein", segment.levenshteinDistance.toString()),
              _buildInfoRow("Probabilidad", segment.probability.toStringAsFixed(2)),
              Row(children: [_buildInfoRow("Inicio", segment.start.toString()), const SizedBox(width: 16), _buildInfoRow("Fin", segment.end.toString())]),
              const SizedBox(height: 8),
              if (segment.transcribedWords != null && segment.transcribedWords!.isNotEmpty) _buildListInfo("Palabras Transcritas Asociadas", segment.transcribedWords!),
              if (segment.transcribedWordsProbabilities != null && segment.transcribedWordsProbabilities!.isNotEmpty)
                _buildListInfo("Probabilidades Asociadas", segment.transcribedWordsProbabilities!.map((prob) => prob.toStringAsFixed(2)).toList()),
              const SizedBox(height: 8),
              if (segment.wordAssociation != null) _buildWordAssociationInfo(segment.wordAssociation!),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(children: [Text("$label: ", style: const TextStyle(fontWeight: FontWeight.bold)), Text(value)]);
  }

  Widget _buildListInfo(String label, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [Text("$label:", style: const TextStyle(fontWeight: FontWeight.bold)), Wrap(children: items.map((item) => Text("$item ")).toList())],
    );
  }

  Widget _buildWordAssociationInfo(WordAssociation wordAssociation) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Asociación:", style: TextStyle(fontWeight: FontWeight.bold)),
        if (wordAssociation.realWord != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Palabra Real: ", style: TextStyle(fontWeight: FontWeight.bold)),
                Text(wordAssociation.realWord!, style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        if (wordAssociation.transcribedWords.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text("Palabras Transcritas:", style: TextStyle(fontWeight: FontWeight.bold)),
                Wrap(alignment: WrapAlignment.center, children: wordAssociation.transcribedWords.map((word) => Text("$word ")).toList()),
              ],
            ),
          ),
        if (wordAssociation.transcribedWordsProbabilities.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text("Probabilidades:", style: TextStyle(fontWeight: FontWeight.bold)),
                Wrap(alignment: WrapAlignment.center, children: wordAssociation.transcribedWordsProbabilities.map((prob) => Text("${prob.toStringAsFixed(2)} ")).toList()),
              ],
            ),
          ),
      ],
    );
  }
}

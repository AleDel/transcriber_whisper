import 'package:flutter/material.dart';
import '../models/transcription_model.dart';

class AnalysisSummaryCard extends StatelessWidget {
  final Transcription transcription;

  const AnalysisSummaryCard({Key? key, required this.transcription}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /*Text(
              'Analysis Summary',
              style: Theme.of(context).textTheme.headlineSmall,
            ),*/
            //const SizedBox(height: 12.0),
            _buildInfoRow(context, 'Reference Words:', transcription.countReferenceWords.toString()),
            _buildInfoRow(context, 'Transcription Words:', transcription.countTranscriptionWords.toString()),
            _buildInfoRow(context, 'Insertions:', transcription.countDiffInsertions.toString()),
            _buildInfoRow(context, 'Deletions:', transcription.countDiffDeletions.toString()),
            _buildInfoRow(context, 'Matches:', transcription.countDiffMatches.toString()),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall,//?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
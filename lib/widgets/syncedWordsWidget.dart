import 'package:flutter/material.dart';
import 'package:transcriber_whisper/models/transcription_model.dart';

import '../models/segment.dart';

class SyncedWordsWidget extends StatefulWidget {
  final Transcription transcription;
  final double currentTime;

  const SyncedWordsWidget({
    Key? key,
    required this.transcription,
    required this.currentTime,
  }) : super(key: key);

  @override
  State<SyncedWordsWidget> createState() => _SyncedWordsWidgetState();
}

class _SyncedWordsWidgetState extends State<SyncedWordsWidget> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.transcription.referenceTextSegments != null)
          Wrap(
            children: widget.transcription.referenceTextSegments!.map((realSegment) {
              final matchingSegment = widget.transcription.audioTranscriptionSegments.firstWhere(
                    (segment) =>
                widget.currentTime >= segment.start &&
                    widget.currentTime <= segment.end,
                orElse: () => Segment(start: 0, end: 0, word: "", probability: 0),
              );
              return Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      realSegment.word,
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                  if (matchingSegment.word.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2.0),
                      child: Text(
                        matchingSegment.word,
                        style: const TextStyle(fontSize: 12, color: Colors.blue),
                      ),
                    ),
                ],
              );
            }).toList(),
          ),
      ],
    );
  }
}
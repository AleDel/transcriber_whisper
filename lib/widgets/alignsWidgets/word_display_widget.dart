import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:transcriber_whisper/cubits/session_cubit.dart';
import 'package:transcriber_whisper/models/transcription_model.dart';
import 'package:transcriber_whisper/models/alignment_mfa_data.dart';
import 'phoneme_display_widget.dart';

class WordDisplayWidget extends StatelessWidget {
  final Segment segment;
  final int index;
  final Function(int) onWordTap;
  final Color Function(String) getSegmentColor;
  final List<Entry> phonemes;

  const WordDisplayWidget({
    Key? key,
    required this.segment,
    required this.index,
    required this.onWordTap,
    required this.getSegmentColor,
    required this.phonemes,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final getIt = GetIt.instance;
    return Container(
      decoration: BoxDecoration(
        color: getSegmentColor(segment.word),
        border: Border.all(color: Colors.grey.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(4.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Fila 1: Texto (palabra)
            Container(
              height: 30,
              alignment: Alignment.center,
              child: GestureDetector(
                onTap: () {
                  onWordTap(index);
                },
                child: Text(
                  segment.word.trim().isEmpty ? "Salto de linea" : segment.word,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            // Fila 2: Opciones (desplegable)
            Container(
              child: Wrap(
                alignment: WrapAlignment.center,
                children: segment.tags.map((tag) {
                  final String symbol = SessionCubit.tagToSymbol[tag] ?? tag;
                  return Padding(
                    padding: const EdgeInsets.all(2.0),
                    child: GestureDetector(
                      onTap: () {
                        final sessionCubit = getIt<SessionCubit>();
                        if (segment.tags.contains(tag)) {
                          sessionCubit.removeTagFromSegment(sessionCubit.state.sessionData!, index, tag);
                        } else {
                          sessionCubit.addTagToSegment(sessionCubit.state.sessionData!, index, tag);
                        }
                      },
                      child: Chip(
                        label: Text(symbol),
                        backgroundColor: SessionCubit.availableTags[tag],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            // Fila 3: Entrada de texto
            Container(
              child: TextField(
                textAlign: TextAlign.center,
                controller: TextEditingController(text: segment.word),
                decoration: const InputDecoration(
                  hintText: '',
                  border: InputBorder.none,
                ),
                onSubmitted: (value) {
                  final newSegment = segment.copyWith(word: value);
                  getIt<SessionCubit>().editSegment(getIt<SessionCubit>().state.sessionData!, newSegment);
                },
              ),
            ),
            // Fila 4: Fonemas
            PhonemeDisplayWidget(phonemes: phonemes),
          ],
        ),
      ),
    );
  }
}
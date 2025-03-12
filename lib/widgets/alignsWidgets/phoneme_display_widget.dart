import 'package:flutter/material.dart';
import 'package:transcriber_whisper/models/alignment_mfa_data.dart';

class PhonemeDisplayWidget extends StatelessWidget {
  final List<Entry> phonemes;

  const PhonemeDisplayWidget({Key? key, required this.phonemes}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Wrap(
        alignment: WrapAlignment.center,
        children: phonemes.map((phoneme) {
          return Container(
            height: 30,
            alignment: Alignment.center,
            child: GestureDetector(
              onTap: () {
                // TODO: Acción al tocar el fonema
                print("Fonema ${phoneme.value} tocado");
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Text(
                  '${phoneme.value} (${phoneme.start.toStringAsFixed(2)} - ${phoneme.end.toStringAsFixed(2)})',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
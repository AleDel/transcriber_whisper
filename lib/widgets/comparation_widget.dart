

import 'package:flutter/material.dart';

import '../models/comparation_model.dart';

class ComparacionHorizontalWidget extends StatelessWidget {
  final List<ComparacionSegmento> comparacion;

  const ComparacionHorizontalWidget({Key? key, required this.comparacion}) : super(key: key);

  Color _getColor(String estado) {
    switch (estado) {
      case "acierto":
        return Colors.green.withOpacity(0.5);
      case "sustitucion":
        return Colors.yellow.withOpacity(0.5);
      case "insercion":
        return Colors.blue.withOpacity(0.5);
      case "omision":
        return Colors.red.withOpacity(0.5);
      default:
        return Colors.transparent;
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> filaReal = [];
    List<Widget> filaTranscrita = [];

    for (ComparacionSegmento segmento in comparacion) {
      // Fila Real
      filaReal.add(
        Container(
          padding: const EdgeInsets.all(4.0),
          margin: const EdgeInsets.all(2.0),
          decoration: BoxDecoration(
            color: segmento.palabraReal != null ? _getColor(segmento.estado) : Colors.transparent,
            border: Border.all(color: Colors.grey),
          ),
          child: Text(segmento.palabraReal ?? ""),
        ),
      );

      // Fila Transcrita
      filaTranscrita.add(
        Container(
          padding: const EdgeInsets.all(4.0),
          margin: const EdgeInsets.all(2.0),
          decoration: BoxDecoration(
            color: _getColor(segmento.estado),
            border: Border.all(color: Colors.grey),
          ),
          child: Text(segmento.segmentoTranscrito.word),
        ),
      );
    }

    return Column(
      children: [
        Wrap(
          children: filaReal,
        ),
        Wrap(
          children: filaTranscrita,
        ),
      ],
    );
  }
}
import 'package:flutter/material.dart';
import 'package:transcriber_whisper/models/transcription_model.dart';

class SegmentEditor extends StatefulWidget {
  final Segment segment;
  final Function(Segment) onSave;

  const SegmentEditor({
    Key? key,
    required this.segment,
    required this.onSave,
  }) : super(key: key);

  @override
  _SegmentEditorState createState() => _SegmentEditorState();
}

class _SegmentEditorState extends State<SegmentEditor> {
  late TextEditingController _wordController;
  late TextEditingController _startController;
  late TextEditingController _endController;

  @override
  void initState() {
    super.initState();
    _wordController = TextEditingController(text: widget.segment.word);
    _startController = TextEditingController(text: (widget.segment.start * 1000).toStringAsFixed(0));
    _endController = TextEditingController(text: (widget.segment.end * 1000).toStringAsFixed(0));
  }

  @override
  void dispose() {
    _wordController.dispose();
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar Segmento'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _wordController,
              decoration: const InputDecoration(labelText: 'Texto'),
            ),
            TextField(
              controller: _startController,
              decoration: const InputDecoration(labelText: 'Inicio (ms)'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _endController,
              decoration: const InputDecoration(labelText: 'Fin (ms)'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () {
            final newSegment = widget.segment.copyWith(
              word: _wordController.text,
              start: double.parse(_startController.text) / 1000,
              end: double.parse(_endController.text) / 1000,
            );
            widget.onSave(newSegment);
            Navigator.of(context).pop();
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
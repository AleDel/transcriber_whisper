import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:transcriber_whisper/cubits/session_cubit.dart';
import 'package:transcriber_whisper/models/session_data.dart';
import '../models/transcription_model.dart';
import 'diff_text_widget.dart';

class TranscriptionDiff extends StatefulWidget {
  final SessionData session;

  const TranscriptionDiff({Key? key, required this.session}) : super(key: key);

  @override
  State<TranscriptionDiff> createState() => _TranscriptionDiffState();
}

class _TranscriptionDiffState extends State<TranscriptionDiff> {
  String defaultText = "";
  final ScrollController _scrollController = ScrollController();
  final TextStyle _textStyle = const TextStyle(fontSize: 24, height: 1.0); // Define the TextStyle here

  @override
  void initState() {
    super.initState();
    _loadDefaultText();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadDefaultText() async {
    try {
      String text = await rootBundle.loadString('assets/texto_ITSAS_IZARRAK.txt');
      // Remove punctuation
      text = text.replaceAll(RegExp(r'[^\w\s]'), '');
      // Convert to lowercase
      text = text.toLowerCase();
      // Replace multiple spaces with single space
      text = text.replaceAll(RegExp(r'\s+'), ' ');
      // Replace newlines with single space
      text = text.replaceAll(RegExp(r'[\r\n]+'), ' ');
      // Trim leading and trailing whitespace
      text = text.trim();
      // Put each word on a new line
      text = text.split(' ').where((word) => word.isNotEmpty).join('\n');
      setState(() {
        defaultText = text;
      });
    } catch (e) {
      print('Error loading default text: $e');
      setState(() {
        defaultText = "Error al cargar el texto por defecto.";
      });
    }
  }

  String _getFullText(Transcription? transcription) {
    if (transcription == null || transcription.segments.isEmpty) {
      return '';
    }
    return transcription.segments.map((segment) => segment.word).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SessionCubit, SessionState>(
      builder: (context, sessionState) {
        final currentSession = sessionState.sessionData;
        if (currentSession == null) {
          return const Center(child: Text('No hay sesión disponible.'));
        }
        final transcribedText = currentSession.transcription!.textcolumna;
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row for Titles
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Expanded(
                    child: Text('Texto Lectura:', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Text('Comparación:', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // SingleChildScrollView for Content
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Column for Original Text
                      Expanded(
                        child: Text(defaultText, style: _textStyle), // Apply the TextStyle here
                      ),
                      const SizedBox(width: 16),
                      // Column for Comparison
                      Expanded(
                        child: DiffText(
                          originalText: defaultText,
                          transcribedText: transcribedText,
                          textStyle: _textStyle, // Pass the TextStyle to DiffText
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
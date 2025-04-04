import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:transcriber_whisper/widgets/associated_segments_display_widget.dart';
import 'package:transcriber_whisper/widgets/real_text_display_widget.dart';
import 'package:transcriber_whisper/widgets/sliding_text_widget.dart';

import '../models/segment.dart';
import '../transcription_cubit.dart';
import '../transcription_state.dart';
import 'highlighted_real_text_widget.dart';

class AssociatedSegmentsTable extends StatefulWidget {
  final List<Segment>? associatedSegments;
  final List<Segment>? realTextSegments;
  final List<String>? realTextWords;
  final List<String>? transcribedWords;

  const AssociatedSegmentsTable({Key? key, required this.associatedSegments, required this.realTextSegments, required this.realTextWords, required this.transcribedWords})
    : super(key: key);

  @override
  State<AssociatedSegmentsTable> createState() => _AssociatedSegmentsTableState();
}

class _AssociatedSegmentsTableState extends State<AssociatedSegmentsTable> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _realTextEditingController = TextEditingController();
  final TextEditingController _transcriptionTextEditingController = TextEditingController();
  final TextEditingController _associatedTextEditingController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  GetIt getIt = GetIt.instance;

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      final double scrollDelta = event.scrollDelta.dx;
      _scrollController.animateTo(_scrollController.position.pixels + scrollDelta, duration: const Duration(milliseconds: 100), curve: Curves.easeOut);
    }
  }

  void _search(String query, TranscriptionState state) {
    setState(() {
      _searchResults.clear();
      if (query.isEmpty) return;

      // Buscar en el texto real
      if (state.transcription?.realTextWords != null) {
        for (int i = 0; i < state.transcription!.realTextWords!.length; i++) {
          String word = state.transcription!.realTextWords![i];
          if (word.toLowerCase().contains(query.toLowerCase())) {
            String context = _getContext(state.transcription!.realTextWords!, i);
            _searchResults.add({"word": word, "type": "real", "context": context, "position": i});
          }
        }
      }

      // Buscar en el texto transcrito
      if (widget.associatedSegments != null) {
        for (int i = 0; i < widget.associatedSegments!.length; i++) {
          Segment segment = widget.associatedSegments![i];
          if (segment.word.toLowerCase().contains(query.toLowerCase())) {
            String context = _getContext(widget.associatedSegments!.map((s) => s.word).toList(), i);
            _searchResults.add({"word": segment.word, "type": "transcribed", "segment": segment, "context": context, "position": i});
          }
        }
      }
    });
  }

  String _getContext(List<String> words, int index) {
    int start = (index - 2) < 0 ? 0 : index - 2;
    int end = (index + 2) >= words.length ? words.length - 1 : index + 2;
    return words.sublist(start, end + 1).join(" ");
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _realTextEditingController.dispose();
    _transcriptionTextEditingController.dispose();
    _associatedTextEditingController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TranscriptionCubit, TranscriptionState>(
      builder: (context, state) {
        //_realTextEditingController.text = state.transcription?.realTextWords?.join(" ").trim() ?? "";
        // Inicializar los TextField con el texto real y el texto transcrito
        _realTextEditingController.text =
            widget.realTextSegments
                ?.asMap()
                .entries
                .map((entry) {
                  int index = entry.key;
                  Segment segment = entry.value;
                  return "$index. ${segment.word}";
                })
                .join(" ") ??
            "";
        /**/
        _transcriptionTextEditingController.text =
            state.transcription?.transcribedSegments
                ?.asMap()
                .entries
                .map((entry) {
                  int index = entry.key;
                  Segment segment = entry.value;
                  return "$index. ${segment.word}";
                })
                .join(" ") ??
            "";
        _associatedTextEditingController.text = widget.associatedSegments?.map((segment) => segment.word).join(" ") ?? "";
        if (widget.associatedSegments == null || widget.realTextSegments == null) {
          return const Center(child: Text("No hay datos para mostrar."));
        }

        // Contar palabras insertadas
        int insertedWordsCount = widget.associatedSegments!.where((segment) => segment.associationType == "inserted").length;

        return ScrollConfiguration(
          behavior: MyCustomScrollBehavior(),
          child: Column(
            mainAxisSize: MainAxisSize.min, // Usamos mainAxisSize.min en el Column principal
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Resumen
              Padding(padding: const EdgeInsets.all(8.0), child: Text("Palabras Insertadas: $insertedWordsCount")),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _realTextEditingController,
                        maxLines: 5,
                        onChanged: (string) {
                          setState(() {});
                        },
                        decoration: InputDecoration(labelText: "Real Text", fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0))),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: TextField(
                        controller: _transcriptionTextEditingController,
                        maxLines: 5,
                        onChanged: (string) {
                          setState(() {});
                        },
                        decoration: InputDecoration(
                          labelText: "Transcription Text",
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0)),
                        ),
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _associatedTextEditingController,
                        maxLines: 5,
                        onChanged: (string) {
                          setState(() {});
                        },
                        decoration: InputDecoration(labelText: "Associated Text", fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0))),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                child: SlidingText(
                  transcription: state.transcription!,
                  audioPosition: state.extradata!.audioPosition,
                  currentWordIndex: state.extradata!.currentWordIndex,
                  waveformImageBase64: state.waveformImageBase64,
                  scrollController: _scrollController,
                  onWordTap: (index) {
                    getIt<TranscriptionCubit>().forceCurrentWord(index);
                  },
                ),
              ),
              SizedBox(height: 100, child: RealTextDisplayWidget(transcription: state.transcription!, audioPosition: Duration(), currentWordIndex: 0, onWordTap: (int) {})),
              // Nuevo: Row para los dos widgets
              SizedBox(height: 500,
                child: Row(
                  children: [
                    Expanded(
                      child: HighlightedRealTextWidget(
                        currentWordIndex: state.extradata?.currentWordIndex ?? -1,
                        onWordTap: (index) {
                          getIt<TranscriptionCubit>().forceCurrentWord(index);
                        },
                        transcription: state.transcription!,
                        audioPosition: state.extradata!.audioPosition,
                        scrollController: ScrollController(),
                        onShowAssociatedWordsChanged: (bool value) {},
                        onShowOnlyDifferentWordsChanged: (bool value) {},
                        onHighlightDifferencesChanged: (bool value) {},
                      ),
                    ),
                    const SizedBox(width: 10), // Espacio entre los widgets
                    Expanded(child: SizedBox(height: 500, width: 200, child: AssociatedSegmentsDisplayWidget(associatedSegments: state.transcription!.associatedSegments!))),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class MyCustomScrollBehavior extends MaterialScrollBehavior {
  // Override behavior methods and getters like dragDevices
  @override
  Set<PointerDeviceKind> get dragDevices => {PointerDeviceKind.touch, PointerDeviceKind.mouse};
}

// Buscador
/* Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => _search(value, state),
                  decoration: const InputDecoration(labelText: "Buscar palabra", border: OutlineInputBorder()),
                ),
              ),
              // Dos columnas
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Columna izquierda: Resultados de la búsqueda
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text("Resultados de la busqueda"),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) {
                            final result = _searchResults[index];
                            return ListTile(
                              title: Text(result["word"]),
                              subtitle: Text(
                                "Tipo: ${result["type"]}${result["segment"] != null ? ", Tipo de Asociación: ${result["segment"].associationType}, Distancia: ${result["segment"].levenshteinDistance}" : ""}, Posicion: ${result["position"]}, Contexto: ${result["context"]}",
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),


                  // Columna derecha: Scroll horizontal de los segmentos
    /*Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text("Segmentos"),
                        Listener(
                          onPointerSignal: _handlePointerSignal,
                          child: SingleChildScrollView(
                            physics: const ClampingScrollPhysics(),
                            controller: _scrollController,
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [for (int i = 0; i < widget.associatedSegments!.length; i++) _buildSegmentColumn(context, state, widget.associatedSegments![i], i)],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ), */
                ],
              ), */
/*
  Widget _buildSegmentColumn(BuildContext context, TranscribeState state, Segment segment, int index) {
    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [SelectableText("Real: ${segment.realWord ?? ""}"), SelectableText("Índice Real: ${realWordIndex != -1 ? realWordIndex : 'N/A'}")],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText("Transcrita: ${segment.word}"),
                SelectableText("Índice Transcrita: ${transcribedWordIndex != -1 ? transcribedWordIndex : 'N/A'}"),
                SelectableText("Probabilidad: ${segment.probability.toStringAsFixed(2)}"),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [SelectableText("Tipo: ${segment.associationType ?? 'N/A'}"), SelectableText("Distancia: ${segment.levenshteinDistance?.toString() ?? 'N/A'}")],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [SelectableText("Start: ${segment.start.toStringAsFixed(2)}"), SelectableText("End: ${segment.end.toStringAsFixed(2)}")],
            ),
          ),
        ],
      ),
    );
  }
 */

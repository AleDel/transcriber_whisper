import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:transcriber_whisper/transcribe_cubit.dart';
import 'package:transcriber_whisper/transcribe_state.dart';
import 'package:transcriber_whisper/widgets/associated_segments_widget.dart';
import 'package:transcriber_whisper/widgets/audioPlayer_widget.dart';
import 'package:transcriber_whisper/widgets/formatted_parraf_real_text_widget.dart';
import 'package:transcriber_whisper/widgets/formatted_parraf_real_text_widget_Normal.dart';
import 'package:transcriber_whisper/widgets/highlighted_real_text_widget.dart';
import 'package:transcriber_whisper/widgets/hybrid_text_widget.dart';
import 'package:transcriber_whisper/widgets/selectableRichText_widget.dart';
import 'package:transcriber_whisper/widgets/sliding_text_widget.dart';

class EUTextPage2 extends StatefulWidget {
  const EUTextPage2({super.key});

  @override
  State<EUTextPage2> createState() => _EUTextPage2State();
}

class _EUTextPage2State extends State<EUTextPage2> {
  final ScrollController _scrollController = ScrollController();
  final ScrollController _scrollController2 = ScrollController();
  final ScrollController _scrollController3 = ScrollController();
  GetIt getIt = GetIt.instance;

  late final TextEditingController _transcriptionTextEditingController;
  late final TextEditingController _newTextEditingController;

  @override
  void initState() {
    super.initState();
    getIt<TranscribeCubit>().useMockTranscriptionEU();
    //getIt<TranscribeCubit>().loadAlignmentMFAData();
    _transcriptionTextEditingController = TextEditingController();
    _newTextEditingController = TextEditingController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _scrollController2.dispose();
    _scrollController3.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ITSAS IZARRAK*')),
      body: Stack(
        children: [
          BlocBuilder<TranscribeCubit, TranscribeState>(
            builder: (context, state) {
              if (state.status == TranscribeStatus.error) {
                return const Center(child: Text('Error al transcribir el audio'));
              }
              if (state.status == TranscribeStatus.noserver) {
                return const Center(child: Text('No se pudo conectar con el servidor'));
              }
              if (state.status == TranscribeStatus.loading) {
                return const Center(child: CircularProgressIndicator());
              }
              final listaword_transcription = state.transcription!.transsegments.map((e) => e.word).toList();
              final listaword_real = state.transcription!.realsegments!.map((e) => e.word).toList();

              _transcriptionTextEditingController.text = state.transcription!.fulltext!; //state.transcription!.listWordsTrascription!.join(" ").trim();
              _newTextEditingController.text = state.transcription!.listWordsTexto!.join(" ").trim();

              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: <Widget>[
                    if (state.transcription != null)
                      Expanded(
                        child: Column(
                          children: [
                            AudioPlayerWidget(),
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
                                  getIt<TranscribeCubit>().forceCurrentWord(index);
                                },
                              ),
                            ),
                            SingleChildScrollView(
                              controller: _scrollController2,
                              scrollDirection: Axis.horizontal,
                              child: HybridTextWidget(
                                transcription: state.transcription!,
                                audioPosition: state.extradata!.audioPosition,
                                currentWordIndex: state.extradata!.currentWordIndex,
                                waveformImageBase64: state.waveformImageBase64,
                                scrollController: _scrollController2,
                                onWordTap: (index) {
                                  getIt<TranscribeCubit>().forceCurrentWord(index);
                                },
                              ),
                            ),
                            /*PrettyDiffText(
                              textAlign: TextAlign.center,
                              oldText: state.transcription!.transsegments.map((e) => e.word).toList().join(" "),
                              newText: state.transcription!.realsegments!.map((e) => e.word).toList().join(" "),
                              diffTimeout: 1.0,
                              diffEditCost: 4,
                            ),
                            SizedBox(height: 20),
                            SelectablePrettyDiffText(
                              textAlign: TextAlign.start,
                              //oldText: _transcriptionTextEditingController.text,
                              //newText: _newTextEditingController.text,
                              oldText: _newTextEditingController.text,
                              newText: _transcriptionTextEditingController.text,
                              //diffCleanupType: _diffCleanupType ?? DiffCleanupType.SEMANTIC,
                              diffTimeout: 1.0,
                              diffEditCost: 4,
                            ),*/
                            Expanded(
                              child: Row(
                                children: [
                                  // Usamos Expanded para que FormattedTextWidget ocupe el espacio disponible
                                  FormattedTextWidget(
                                    currentWordIndex: state.extradata?.currentWordIndex ?? -1,
                                    onWordTap: (index) {
                                      getIt<TranscribeCubit>().forceCurrentWord(index);
                                    },
                                    transcription: state.transcription!,
                                    audioPosition: state.extradata!.audioPosition,
                                  ),
                                  //FormattedTextNormalWidget(),
                                  Expanded(
                                    child: HighlightedRealTextWidget(
                                      currentWordIndex: state.extradata?.currentWordIndex ?? -1,
                                      onWordTap: (index) {
                                        getIt<TranscribeCubit>().forceCurrentWord(index);
                                      },
                                      transcription: state.transcription!,
                                      audioPosition: state.extradata!.audioPosition,
                                      scrollController: _scrollController3,
                                      onShowAssociatedWordsChanged: (bool value) {},
                                      onShowOnlyDifferentWordsChanged: (bool value) {},
                                      onHighlightDifferencesChanged: (bool value) {},
                                    ),
                                  ),
                                  // Usamos Expanded para que SelectableRichText ocupe el espacio disponible
                                  Expanded(
                                    child: Column(
                                      children: [
                                        TextField(
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
                                        /*Expanded(
                                          child: SelectableRichText(
                                            currentWordIndex: state.extradata?.currentWordIndex ?? -1,
                                            onWordTap: (index) {
                                              getIt<TranscribeCubit>().forceCurrentWord(index);
                                            },
                                            transcription: state.transcription!,
                                            audioPosition: state.extradata!.audioPosition,
                                          ),
                                        ),*/
                                        Expanded(child: AssociatedSegmentsWidget(alignedSegments: state.transcription!.alignedSegments!))
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      const SizedBox.shrink(),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:transcriber_whisper/models/comparation_model.dart';
import 'package:transcriber_whisper/transcribe_cubit.dart';
import 'package:transcriber_whisper/transcribe_state.dart';
import 'package:transcriber_whisper/widgets/audioPlayer_widget.dart';
import 'package:transcriber_whisper/widgets/comparation_widget.dart';
import 'package:transcriber_whisper/widgets/selectableRichText_widget.dart';
import 'package:transcriber_whisper/widgets/simpleWordsWidget.dart';
import 'package:transcriber_whisper/widgets/sliding_text_widget.dart';
import 'package:transcriber_whisper/widgets/tex_display_widget.dart';
import 'package:transcriber_whisper/widgets/tex_display_widget2.dart';
import 'package:transcriber_whisper/widgets/tex_display_widget2Copy.dart';

class EUTextPage extends StatefulWidget {
  const EUTextPage({super.key});

  @override
  State<EUTextPage> createState() => _EUTextPageState();
}

class _EUTextPageState extends State<EUTextPage> {
  final ScrollController _scrollController = ScrollController();
  GetIt getIt = GetIt.instance;

  @override
  void initState() {
    super.initState();
    getIt<TranscribeCubit>().useMockTranscriptionEU();
    //getIt<TranscribeCubit>().loadAlignmentMFAData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
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
                return Center(child: CircularProgressIndicator());
              }
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    // botones transcribir, etc
                    /*Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(onPressed: () async => getIt<TranscribeCubit>().pickAudioFile(), child: const Text('Cargar Audio')),
                        ElevatedButton(onPressed: () async => getIt<TranscribeCubit>().useMockTranscription(), child: const Text('Usar Mock data')),
                      ],
                    ),*/
                    // interfaz grafica principal
                    if (state.transcription != null)
                      Expanded(
                        child: Column(
                          children: [
                            AudioPlayerWidget(),
                            //SimpleWordsWidget(transcription:  state.transcription!,),
                            /*SingleChildScrollView(
                              controller: _scrollController,
                              scrollDirection: Axis.horizontal,
                              child: ComparacionHorizontalWidget(
                                comparacion: getIt<TranscribeCubit>().compararSegmentos(state.transcription!.segments, state.transcription!.realsegments!),
                              ),
                            ),*/
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
                            TextDisplayWidget2(
                              transcription: state.transcription!,
                              comparacionlist: state.comparacion!,
                              //textoEscritoAlineado: state.textoEscritoAlineado,
                              audioPosition: state.extradata!.audioPosition,
                              currentWordIndex: state.extradata!.currentWordIndex,
                              onSeek: (Duration d, int index) {
                                getIt<TranscribeCubit>().forceCurrentWord(index);
                              },
                              onWordTap: (int index) {
                                getIt<TranscribeCubit>().forceCurrentWord(index);
                              },
                            ),
                            /**/
                            /*SingleChildScrollView(
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
                            ),*/
                            Expanded(
                              child: Row(
                                children: [
                                  SelectableRichText(
                                    currentWordIndex: state.extradata?.currentWordIndex ?? -1,
                                    onWordTap: (index) {
                                      getIt<TranscribeCubit>().forceCurrentWord(index);
                                    },
                                    transcription: state.realtextComoTranscription!,
                                    audioPosition: state.extradata!.audioPosition,
                                  ),

                                  SelectableRichText(
                                    currentWordIndex: state.extradata?.currentWordIndex ?? -1,
                                    onWordTap: (index) {
                                      getIt<TranscribeCubit>().forceCurrentWord(index);
                                    },
                                    transcription: state.transcription!,
                                    audioPosition: state.extradata!.audioPosition,
                                  ),
                                ],
                              ),
                            ) /**/,
                          ],
                        ),
                      )
                    else
                      Container(),
                  ],
                ),
              );
            },
          ),
          //FloatingWindow(title: "MFA Logs", initialX: 10, initialY: 10, initialWidth: 300, initialHeight: 100, child: MfaLogsWidget()),
        ],
      ),
    );
  }
}

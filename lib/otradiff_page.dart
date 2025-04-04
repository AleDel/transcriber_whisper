import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:pretty_diff_text/pretty_diff_text.dart';
import 'package:transcriber_whisper/transcription_cubit.dart';
import 'package:transcriber_whisper/transcription_state.dart';
import 'package:transcriber_whisper/widgets/diff_rows_widget.dart';
import 'package:transcriber_whisper/widgets/formatted_words_widget.dart';
import 'package:transcriber_whisper/widgets/selectable_pretty_diff_plain_text.dart';
import 'package:transcriber_whisper/widgets/selectable_pretty_diff_text.dart';
import 'package:transcriber_whisper/widgets/simpleWordsWidget.dart';
import 'package:transcriber_whisper/widgets/sliding_text_widget.dart';
import 'package:transcriber_whisper/widgets/syncedWordsWidget.dart';
import 'package:transcriber_whisper/widgets/tex_display_widget2.dart';
import 'package:transcriber_whisper/widgets/two_rows_with_shared_scroll_widget.dart';
import 'package:transcriber_whisper/widgets/word_comparison_widget.dart';

class OtraDiffPage extends StatefulWidget {
  OtraDiffPage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  _OtraDiffPageState createState() => _OtraDiffPageState();
}

class _OtraDiffPageState extends State<OtraDiffPage> {
  late final TextEditingController _transcriptionTextEditingController;
  late final TextEditingController _newTextEditingController;
  late final TextEditingController _diffTimeoutEditingController;
  late final TextEditingController _editCostEditingController;
  DiffCleanupType? _diffCleanupType = DiffCleanupType.SEMANTIC;
  GetIt getIt = GetIt.instance;

  @override
  void initState() {
    getIt<TranscriptionCubit>().useMockTranscriptionEU();

    _transcriptionTextEditingController = TextEditingController();
    _newTextEditingController = TextEditingController();
    _diffTimeoutEditingController = TextEditingController();
    _editCostEditingController = TextEditingController();
    _transcriptionTextEditingController.text = "Let's go to Hatay and eat something delicious. Because everything there is super delicious";
    _newTextEditingController.text = "Let's go to Antakya eat something very delicious and unique. Because everything(especially kebabs and kunefe) super delicious!!!";
    _diffTimeoutEditingController.text = "1.0";
    _editCostEditingController.text = "4";
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: BlocBuilder<TranscriptionCubit, TranscriptionState>(
        builder: (context, state) {
          List<FormattedWord> formattedWords = [];
          // Check if transcription and listWordsTrascription are not null
          if (state.transcription != null && state.transcription!.transcribedWords != null) {
            _transcriptionTextEditingController.text = state.transcription!.transcribedWords!.join(" ").trim();
            _newTextEditingController.text = state.transcription!.realTextWords!.join(" ").trim();
            //_oldTextEditingController.text = state.transcription!.realTextWords!.join(" ");
            //_newTextEditingController.text = state.transcription!.listWordsTrascription!.join(" ");

            final selectablePrettyDiffText = SelectablePrettyDiffPlaintText(
              oldText: _newTextEditingController.text,
              newText: _transcriptionTextEditingController.text,
              diffTimeout: diffTimeoutToDouble(),
              diffEditCost: editCostToDouble(),
            );
            final diffs = selectablePrettyDiffText.getDiffs();
            final plainText = SelectablePrettyDiffPlaintText.diffsToPlainText(diffs);
            final words = plainText.split(" ");
            //print(plainText);
            formattedWords = SelectablePrettyDiffPlaintText.diffsToFormattedWords(
              diffs,
              _newTextEditingController.text.split(" "),
              _transcriptionTextEditingController.text.split(" "),
            );
            //print(formattedWords[6].originalWord);
            //print(formattedWords);
          }
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                Expanded(child: TwoRowsWithSharedScrollWidget()),
                Expanded(
                  child: ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _newTextEditingController,
                                maxLines: 5,
                                onChanged: (string) {
                                  setState(() {});
                                },
                                decoration: InputDecoration(labelText: "New Text", fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0))),
                              ),
                            ),

                            Container(width: 5),
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
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Container(
                          decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.all(Radius.circular(10))),
                          margin: EdgeInsets.only(top: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(10.0),
                            child: Column(
                              children: [
                                //const DiffRowsWidget(),
                                //SimpleWordsWidget(transcription: state.transcription!,),
                                Center(
                                  child: Padding(padding: const EdgeInsets.only(bottom: 10), child: Text("--- PrettyDiffText OUTPUT ---", style: TextStyle(fontWeight: FontWeight.bold))),
                                ),
                                Center(
                                  child: SelectablePrettyDiffText(
                                    textAlign: TextAlign.center,
                                    //oldText: _transcriptionTextEditingController.text,
                                    //newText: _newTextEditingController.text,
                                    oldText: _newTextEditingController.text,
                                    newText: _transcriptionTextEditingController.text,
                                    //diffCleanupType: _diffCleanupType ?? DiffCleanupType.SEMANTIC,
                                    diffTimeout: diffTimeoutToDouble(),
                                    diffEditCost: editCostToDouble(),
                                  ),
                                ),
                                /*Center(
                                  child: SelectablePrettyDiffPlaintText(oldText: _newTextEditingController.text,
                                      newText: _transcriptionTextEditingController.text,
                                    diffTimeout: diffTimeoutToDouble(), diffEditCost:editCostToDouble(),textAlign: TextAlign.center ),
                                ),*/
                                Center(
                                  child: PrettyDiffText(
                                    textAlign: TextAlign.center,
                                    //oldText: _transcriptionTextEditingController.text,
                                    //newText: _newTextEditingController.text,
                                    oldText: _newTextEditingController.text,
                                    newText: _transcriptionTextEditingController.text,
                                    diffCleanupType: _diffCleanupType ?? DiffCleanupType.SEMANTIC,
                                    diffTimeout: diffTimeoutToDouble(),
                                    diffEditCost: editCostToDouble(),
                                  ),
                                ),
                                SizedBox(height: 16),
                                FormattedWordsWidget(formattedWords: formattedWords),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Aquí añadimos el WordComparisonWidget
                      if (state.transcription != null && state.transcription!.transcribedWords != null && state.transcription!.realTextWords != null)
                        WordComparisonWidget(
                          text1Words: state.transcription!.realTextWords!,
                          text2Words: state.transcription!.transcribedWords!,
                          diffCleanupType: _diffCleanupType ?? DiffCleanupType.SEMANTIC,
                          diffTimeout: diffTimeoutToDouble(),
                          diffEditCost: editCostToDouble(),
                          originalTextWords: state.transcription!.realTextWords!,
                        ),
                      Padding(
                        padding: const EdgeInsets.only(top: 25.0),
                        child: Row(
                          children: [
                            Text("Diff timeout: ", style: TextStyle(fontWeight: FontWeight.bold)),
                            SizedBox(
                              width: 40,
                              height: 30,
                              child: TextField(
                                keyboardType: TextInputType.number,
                                controller: _diffTimeoutEditingController,
                                onChanged: (string) {
                                  setState(() {});
                                },
                                decoration: InputDecoration(contentPadding: EdgeInsets.all(5), fillColor: Colors.white, border: OutlineInputBorder()),
                              ),
                            ),
                            Text(" seconds"),
                          ],
                        ),
                      ),
                      Text(
                        "If the mapping phase of the diff computation takes longer than this, then the computation is truncated and the best solution to date is returned. While guaranteed to be correct, it may not be optimal. A timeout of '0' allows for unlimited computation.",
                      ),
                      Padding(padding: const EdgeInsets.only(top: 15, bottom: 3), child: Text("Post-diff cleanup:", style: TextStyle(fontWeight: FontWeight.bold))),
                      RadioListTile(
                        title: Text("Semantic Cleanup"),
                        subtitle: Text("Increase human readability by factoring out commonalities which are likely to be coincidental"),
                        value: DiffCleanupType.SEMANTIC,
                        groupValue: _diffCleanupType,
                        onChanged: (DiffCleanupType? value) {
                          setState(() {
                            _diffCleanupType = value;
                          });
                        },
                      ),
                      RadioListTile(
                        title: Row(
                          children: [
                            Text("Efficiency Cleanup. Edit cost: "),
                            SizedBox(
                              width: 40,
                              height: 30,
                              child: TextField(
                                keyboardType: TextInputType.number,
                                controller: _editCostEditingController,
                                onChanged: (string) {
                                  setState(() {});
                                },
                                decoration: InputDecoration(contentPadding: EdgeInsets.all(5), fillColor: Colors.white, border: OutlineInputBorder()),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          "Increase computational efficiency by factoring out short commonalities which are not worth the overhead. The larger the edit cost, the more aggressive the cleanup",
                        ),
                        value: DiffCleanupType.EFFICIENCY,
                        groupValue: _diffCleanupType,
                        onChanged: (DiffCleanupType? value) {
                          setState(() {
                            _diffCleanupType = value;
                          });
                        },
                      ),
                      RadioListTile(
                        title: Text("No Cleanup"),
                        subtitle: Text("Raw output"),
                        value: DiffCleanupType.NONE,
                        groupValue: _diffCleanupType,
                        onChanged: (DiffCleanupType? value) {
                          setState(() {
                            _diffCleanupType = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  double diffTimeoutToDouble() {
    try {
      final response = double.parse(_diffTimeoutEditingController.text);
      ScaffoldMessenger.of(context).clearSnackBars();
      return response;
    } catch (e) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Enter a valid double value for edit cost")));
      });
      return 1.0; // default value for timeout
    }
  }

  int editCostToDouble() {
    try {
      final response = int.parse(_editCostEditingController.text);
      ScaffoldMessenger.of(context).clearSnackBars();
      return response;
    } catch (e) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Enter a valid integer value for edit cost")));
      });
      return 4; // default value for edit cost
    }
  }
}

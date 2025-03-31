import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:pretty_diff_text/pretty_diff_text.dart';
import 'package:transcriber_whisper/transcribe_cubit.dart';
import 'package:transcriber_whisper/transcribe_state.dart';
import 'package:transcriber_whisper/widgets/selectable_pretty_diff_plain_text.dart';
import 'package:transcriber_whisper/widgets/selectable_pretty_diff_text.dart';
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
    getIt<TranscribeCubit>().useMockTranscriptionEU();

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
      body: BlocBuilder<TranscribeCubit, TranscribeState>(
        builder: (context, state) {
          // Check if transcription and listWordsTrascription are not null
          if (state.transcription != null && state.transcription!.listWordsTrascription != null) {
            _transcriptionTextEditingController.text = state.transcription!.listWordsTrascription!.join(" ").trim();
            _newTextEditingController.text = state.transcription!.listWordsTexto!.join(" ").trim();
            //_oldTextEditingController.text = state.transcription!.listWordsTexto!.join(" ");
            //_newTextEditingController.text = state.transcription!.listWordsTrascription!.join(" ");
          }
          return Padding(
            padding: const EdgeInsets.all(8.0),
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
                        ],
                      ),
                    ),
                  ),
                ),
                // Aquí añadimos el WordComparisonWidget
                if (state.transcription != null && state.transcription!.listWordsTrascription != null && state.transcription!.listWordsTexto != null)
                  WordComparisonWidget(
                    text1Words: state.transcription!.listWordsTexto!,
                    text2Words: state.transcription!.listWordsTrascription!,
                    diffCleanupType: _diffCleanupType ?? DiffCleanupType.SEMANTIC,
                    diffTimeout: diffTimeoutToDouble(),
                    diffEditCost: editCostToDouble(),
                    originalTextWords: state.transcription!.listWordsTexto!,
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

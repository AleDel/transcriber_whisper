import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:pretty_diff_text/pretty_diff_text.dart';
import 'package:transcriber_whisper/transcribe_cubit.dart';
import 'package:transcriber_whisper/transcribe_state.dart';
import 'package:transcriber_whisper/widgets/selectable_pretty_diff_plain_text.dart';
import 'package:transcriber_whisper/widgets/word_comparison_widget.dart';
import 'package:transcriber_whisper/widgets/selectable_pretty_diff_text.dart'; // Importa el nuevo widget

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
  final String originalText =
      "itsas izarrak bazen behin hondartzatik egunero paseatzen zuen gizona goiz hartan itsasertza itsas izarrez beteta ikusi zuen milaka zeuden eguraldi txarragatik edo olatu asko zeudelako izango zela pentsatu zuen triste jarri zen bazekielako izar txikiak ezin zirela uretara itzuli eta hondarretan hil egingo zirela denbora gutxian orduan neska bat ikusi zuen itsas izarren artean neskatoa alde batetik bestera zebilen eta oso lanpetuta zirudien zertan ari zara galdetu zion gizonak ahal dudan izar guztiak biltzen ditut eta itsasora botatzen ditut ez hiltzeko salbatu egin behar ditugu orain konturatu naiz erantzun zuen gizonak hala ere zure ahaleginak ez du merezi oso urrutitik nator ibiltzen eta izar gehiegi dago hondar gainean milioika agian batzuk salbatu ahal izango dituzu baina gehienak hil egingo dira zure lanak ez du ezertarako balioko egiten duzunak ez du zentzurik neskak harrituta begiratu zion gizonari gero izar bat hartu eta gizonari erakutsi zion esanez izar honentzat badu zentzua gizonak ulertu zuen neskatoak arrazoi zuela ahal zuten izar gehienak salbatzen saiatu behar zuten eta neskatoari laguntzen hasi zitzaion handik gutxira beste pertsona batzuk hurbildu zitzaizkien eta izarrak uretara eramaten hasi ziren izar asko erreskatatu zituzten";
  final String transcriptionText =
      "itsas izarrak bazen behin hondartzatik egunero pasatzen zuen gizonak goiz hartan itsastzertza itsas izarrez eta beteta ikusi zuen milaka zeuden egburlaldi txarragatik edo olnartu asko zeuden lakou izango zela pentsatu zuen triste jarri zen bazekielako izar txikiak ezin zirela ahal ureitara itzuli eta hondarretan hil egingo zirela denbora gutxian orduan neska bat ikusi zuen itsas izarren artean neskat doa alde beti irupe batetik bestera zersebilen eta oso lanpertuta zirudrien zertan ari zara galdetu zioren gizonak ahal dudan izar guztiak ibiltzen zertan ari ziren gizonak ahal ditut eta itsasora botatzen ditut ez hbiltzeko szalbatldu egin behar ditugu orain konturatu naiz erantzun zuen gizonak hala ere zure ahalegina zer gizonak ez dituen mberezi oso urrutitik nator ibiltzen eta iztsars geihiegi dago hondar gaineahon milioikdar gaginean batzuk szalbatldu ahal izango dituzu baina gehienak hil egingo dira zure lanak ez du ezertarako balioko egiten duzuenak ez du zentzurik neskak harrituta begiratu zion gizonarik gero izar bat hartu eta gizonari eirakutsi zion hegazkina esanez izar honentzat badu zentzua gizonak ulertu ez zuen gizonak ulertu zuen neskatoak arrazoi zuela ahal zuten izar gehienak erakutsi zion inork albaltzen sailatu behar zuten eta neskatoari laguntzen hasi zitzaion handik gutxira beste pertsona batzuk hurbildu z";

  @override
  void initState() {
    super.initState();
    _transcriptionTextEditingController = TextEditingController(text: transcriptionText);
    _newTextEditingController = TextEditingController(text: originalText);
    _diffTimeoutEditingController = TextEditingController(text: '1.0');
    _editCostEditingController = TextEditingController(text: '4');
  }

  @override
  void dispose() {
    _transcriptionTextEditingController.dispose();
    _newTextEditingController.dispose();
    _diffTimeoutEditingController.dispose();
    _editCostEditingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _newTextEditingController,
                decoration: InputDecoration(labelText: 'Texto Original'),
                maxLines: null,
              ),
              SizedBox(height: 16),
              TextField(
                controller: _transcriptionTextEditingController,
                decoration: InputDecoration(labelText: 'Texto Transcrito'),
                maxLines: null,
              ),
              SizedBox(height: 16),
              TextField(
                controller: _diffTimeoutEditingController,
                decoration: InputDecoration(labelText: 'Diff Timeout'),
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: 16),
              TextField(
                controller: _editCostEditingController,
                decoration: InputDecoration(labelText: 'Edit Cost'),
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: 16),
              DropdownButton<DiffCleanupType>(
                value: _diffCleanupType,
                onChanged: (DiffCleanupType? newValue) {
                  setState(() {
                    _diffCleanupType = newValue;
                  });
                },
                items: DiffCleanupType.values.map<DropdownMenuItem<DiffCleanupType>>((DiffCleanupType value) {
                  return DropdownMenuItem<DiffCleanupType>(
                    value: value,
                    child: Text(value.toString().split('.').last),
                  );
                }).toList(),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  final diffTimeout = double.tryParse(_diffTimeoutEditingController.text) ?? 1.0;
                  final editCost = int.tryParse(_editCostEditingController.text) ?? 4;
                  final selectablePrettyDiffText = SelectablePrettyDiffPlaintText(
                    oldText: _newTextEditingController.text,
                    newText: _transcriptionTextEditingController.text,
                    diffTimeout: diffTimeout,
                    diffEditCost: editCost,
                  );
                  final diffs = selectablePrettyDiffText.getDiffs();
                  final plainText = SelectablePrettyDiffPlaintText.diffsToPlainText(diffs);
                  final words = plainText.split(" ");
                  print(words);
                  setState(() {

                  });
                },
                child: Text('Calcular Diferencias'),
              ),
              SizedBox(height: 16),
              WordComparisonWidget(
                text1Words: _newTextEditingController.text.split(" "),
                text2Words: _transcriptionTextEditingController.text.split(" "),
                originalTextWords: _newTextEditingController.text.split(" "),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
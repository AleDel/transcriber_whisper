import 'package:flutter/material.dart';

class ReadingModeForm extends StatefulWidget {
  final Function(List<String>) onModesChanged;
  const ReadingModeForm({Key? key, required this.onModesChanged}) : super(key: key);

  @override
  State<ReadingModeForm> createState() => _ReadingModeFormState();
}

class _ReadingModeFormState extends State<ReadingModeForm> {
  final Map<String, bool> _readingModes = {
    'Espresiboa': false,
    'Arrunta': false,
    'Hitzez hitzekoa': false,
    'Silabikoa': false,
  };

  @override
  void initState() {
    super.initState();
    // Delay the call to _updateParent until after the build process
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateParent();
    });
  }

  void _updateParent() {
    final selectedModes = _readingModes.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();
    widget.onModesChanged(selectedModes);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(4.0),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Irakurtzeko modua",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ..._readingModes.keys.map((mode) {
              return SizedBox(
                height: 30,
                child: CheckboxListTile(
                  title: Text(mode, style: const TextStyle(fontSize: 12)),
                  value: _readingModes[mode],
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (bool? value) {
                    setState(() {
                      _readingModes[mode] = value!;
                      _updateParent();
                    });
                  },
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}
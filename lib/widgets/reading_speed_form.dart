import 'package:flutter/material.dart';

class ReadingSpeedForm extends StatefulWidget {
  final Function(double) onTimeChanged;
  const ReadingSpeedForm({Key? key, required this.onTimeChanged}) : super(key: key);

  @override
  State<ReadingSpeedForm> createState() => _ReadingSpeedFormState();
}

class _ReadingSpeedFormState extends State<ReadingSpeedForm> {
  final _formKey = GlobalKey<FormState>();
  final _timeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _timeController.addListener(_onTimeChanged);
  }

  @override
  void dispose() {
    _timeController.removeListener(_onTimeChanged);
    _timeController.dispose();
    super.dispose();
  }

  void _onTimeChanged() {
    if (_formKey.currentState!.validate()) {
      final time = double.tryParse(_timeController.text);
      if (time != null) {
        widget.onTimeChanged(time);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(4.0),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Irakurtzeko abiadura",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 40,
                child: TextFormField(
                  controller: _timeController,
                  decoration: const InputDecoration(
                    labelText: "Denbora",
                    hintText: "Introduce el tiempo en segundos",
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  ),
                  style: const TextStyle(fontSize: 12),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Por favor, introduce el tiempo";
                    }
                    if (double.tryParse(value) == null) {
                      return "Por favor, introduce un número válido";
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
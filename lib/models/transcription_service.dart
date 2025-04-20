class TranscriptionService{

  //Simulamos una base de datos
  final Map<String, String> audiosDatabase = {
    'audiotest1': 'audiotest1.wav',
    'audiotest2': 'audiotest2.wav',
    'audiotest3': 'audiotest3.wav',
  };

  bool checkAudio(String nombreAudio) {
    print('Verificando audio: $nombreAudio');
    // Aquí va tu lógica para verificar el audio
    // ...
    // Por ejemplo, podrías emitir un nuevo estado
    // emit(TranscriptionAudioChecked(nombreAudio));
    final audioFile = audiosDatabase[nombreAudio];
    if (audioFile != null) {
      print('El audio $audioFile existe en la base de datos.');
      return true;
    } else {
      print('El audio $nombreAudio no existe en la base de datos.');
      return false;
    }
  }
}
import 'package:file_picker/file_picker.dart';

class AudioFileInfo {
  final PlatformFile file;
  final Duration? duration;

  AudioFileInfo({required this.file, this.duration});

  AudioFileInfo copyWith({
    PlatformFile? file,
    Duration? duration,
  }) {
    return AudioFileInfo(
      file: file ?? this.file,
      duration: duration ?? this.duration,
    );
  }
}
import 'package:equatable/equatable.dart';
import 'package:transcriber_whisper/models/session.dart';

class Project extends Equatable {
  final String id;
  final String name;
  final List<Session> sessions;

  const Project({
    required this.id,
    required this.name,
    this.sessions = const [],
  });

  Project copyWith({
    String? id,
    String? name,
    List<Session>? sessions,
  }) {
    return Project(
      id: id ?? this.id,
      name: name ?? this.name,
      sessions: sessions != null ? List.from(sessions) : this.sessions,
    );
  }

  @override
  List<Object?> get props => [id, name, sessions];
}
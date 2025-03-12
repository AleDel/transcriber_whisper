part of 'session_cubit.dart';

class SessionState extends Equatable {
  final String? errorMessage;
  final SessionData? sessionData;

  const SessionState({
    this.errorMessage,
    this.sessionData,
  });

  SessionState copyWith({
    String? errorMessage,
    SessionData? sessionData,
  }) {
    return SessionState(
      errorMessage: errorMessage ?? this.errorMessage,
      sessionData: sessionData ?? this.sessionData,
    );
  }

  @override
  List<Object?> get props => [errorMessage, sessionData];
}
part of 'session_bloc.dart';

sealed class SessionState {
  const SessionState();
}

final class SessionLoading extends SessionState {
  const SessionLoading();

  @override
  bool operator ==(Object other) => other is SessionLoading;

  @override
  int get hashCode => 0;
}

final class NoSession extends SessionState {
  const NoSession({this.notice});
  final String? notice;

  @override
  bool operator ==(Object other) =>
      other is NoSession && other.notice == notice;

  @override
  int get hashCode => Object.hash(NoSession, notice);
}

final class ResumePrompt extends SessionState {
  const ResumePrompt(this.session, {this.failure});
  final Session session;
  final Failure? failure;

  @override
  bool operator ==(Object other) =>
      other is ResumePrompt &&
      other.session == session &&
      other.failure == failure;

  @override
  int get hashCode => Object.hash(ResumePrompt, session, failure);
}

final class SessionActive extends SessionState {
  const SessionActive({
    required this.session,
    this.spinning = false,
    this.spinPlan,
    this.orientation = 0,
    this.failure,
    this.replayCount = 0,
  });

  final Session session;
  final bool spinning;

  /// Non-null exactly while spinning.
  final SpinPlan? spinPlan;

  /// Radians, memory only.
  final double orientation;
  final Failure? failure;

  /// Bumped by ReplayRequested; Phase 3's Announcer watches it.
  final int replayCount;

  @override
  bool operator ==(Object other) =>
      other is SessionActive &&
      other.session == session &&
      other.spinning == spinning &&
      other.spinPlan == spinPlan &&
      other.orientation == orientation &&
      other.failure == failure &&
      other.replayCount == replayCount;

  @override
  int get hashCode => Object.hash(
    session,
    spinning,
    spinPlan,
    orientation,
    failure,
    replayCount,
  );
}

final class SessionSummary extends SessionState {
  const SessionSummary(this.game);
  final GameRecord game;

  @override
  bool operator ==(Object other) =>
      other is SessionSummary && other.game == game;

  @override
  int get hashCode => Object.hash(SessionSummary, game);
}

part of 'session_bloc.dart';

sealed class SessionEvent {
  const SessionEvent();
}

final class AppStarted extends SessionEvent {
  const AppStarted();
}

final class ResumeConfirmed extends SessionEvent {
  const ResumeConfirmed();
}

final class SessionStarted extends SessionEvent {
  const SessionStarted(this.count, this.names);
  final int count;
  final List<String?> names;
}

final class SpinRequested extends SessionEvent {
  const SpinRequested();
}

final class SpinAnimationFinished extends SessionEvent {
  const SpinAnimationFinished();
}

final class ModeChosen extends SessionEvent {
  const ModeChosen(this.mode);
  final Mode mode;
}

final class Passed extends SessionEvent {
  const Passed();
}

final class NextRoundRequested extends SessionEvent {
  const NextRoundRequested();
}

final class PlayersEdited extends SessionEvent {
  const PlayersEdited(this.count, this.names);
  final int count;
  final List<String?> names;
}

final class EndConfirmed extends SessionEvent {
  const EndConfirmed();
}

final class AppBackgrounded extends SessionEvent {
  const AppBackgrounded();
}

final class SessionLinkOpened extends SessionEvent {
  const SessionLinkOpened(this.id);
  final String id;
}

final class ReplayRequested extends SessionEvent {
  const ReplayRequested();
}

final class SummaryDismissed extends SessionEvent {
  const SummaryDismissed();
}

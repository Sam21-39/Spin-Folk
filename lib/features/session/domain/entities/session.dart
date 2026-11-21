import '../rules/labels.dart';
import '../rules/selection.dart';

enum Phase { ready, revealed, challenge } // .name is the SQL value

enum Mode { truth, dare } // .name is the SQL value

final class Player {
  const Player({required this.seat, this.name});
  final int seat;
  final String? name;

  @override
  bool operator ==(Object other) =>
      other is Player && other.seat == seat && other.name == name;

  @override
  int get hashCode => Object.hash(seat, name);
}

final class Outcome {
  const Outcome({required this.taker, required this.giver});
  final int taker, giver;

  @override
  bool operator ==(Object other) =>
      other is Outcome && other.taker == taker && other.giver == giver;

  @override
  int get hashCode => Object.hash(taker, giver);
}

enum RoundResult { truth, dare, pass } // .name is the SQL value

final class RoundEntry {
  const RoundEntry({
    required this.round,
    required this.taker,
    required this.giver,
    required this.result,
  });
  final int round, taker, giver;
  final RoundResult result;

  @override
  bool operator ==(Object other) =>
      other is RoundEntry &&
      other.round == round &&
      other.taker == taker &&
      other.giver == giver &&
      other.result == result;

  @override
  int get hashCode => Object.hash(round, taker, giver, result);
}

final class Session {
  const Session({
    required this.id,
    required this.startedAtMs,
    required this.players,
    this.round = 1,
    this.phase = Phase.ready,
    this.outcome,
    this.mode,
    this.log = const [],
  });

  final String id;

  /// Epoch ms UTC.
  final int startedAtMs;

  /// Index == seat.
  final List<Player> players;
  final int round;
  final Phase phase;
  final Outcome? outcome;
  final Mode? mode;

  /// Ascending by round; the current round's entry, if any, is last.
  final List<RoundEntry> log;

  int get playerCount => players.length;

  /// Single source of the invariants: SQL's CHECKs plus what SQL cannot say.
  bool get isValid {
    final n = playerCount;
    if (n < 2 || n > 60 || round < 1) return false;
    for (var i = 0; i < n; i++) {
      final p = players[i];
      if (p.seat != i || p.name != normalizeName(p.name)) return false;
    }
    var prev = 0;
    for (final e in log) {
      if (e.round <= prev ||
          e.round > round ||
          e.taker == e.giver ||
          e.taker < 0 ||
          e.taker > 59 ||
          e.giver < 0 ||
          e.giver > 59) {
        return false;
      }
      prev = e.round;
    }
    final o = outcome;
    if (o != null && !isValidPair(n, o.taker, o.giver)) return false;
    return switch (phase) {
      Phase.ready => o == null && mode == null,
      Phase.revealed => o != null && mode == null,
      Phase.challenge => o != null && mode != null,
    };
  }

  Session revealed(Outcome o) => _copy(phase: Phase.revealed, outcome: o);

  Session chose(Mode m) => _copy(
    phase: Phase.challenge,
    outcome: outcome,
    mode: m,
    log: _logged(m == Mode.dare ? RoundResult.dare : RoundResult.truth),
  );

  Session passed() => _copy(
    round: round + 1,
    phase: Phase.ready,
    log: _logged(RoundResult.pass),
  );

  Session nextRound() => _copy(round: round + 1, phase: Phase.ready);

  Session withPlayers(List<Player> p) => _copy(
    players: p,
    round: round,
    phase: phase,
    outcome: outcome,
    mode: mode,
  );

  List<RoundEntry> _logged(RoundResult r) => [
    ...log.where((e) => e.round != round),
    RoundEntry(
      round: round,
      taker: outcome!.taker,
      giver: outcome!.giver,
      result: r,
    ),
  ];

  // Nullable fields are cleared unless passed: no copyWith that cannot clear.
  Session _copy({
    List<Player>? players,
    int? round,
    Phase? phase,
    Outcome? outcome,
    Mode? mode,
    List<RoundEntry>? log,
  }) => Session(
    id: id,
    startedAtMs: startedAtMs,
    players: players ?? this.players,
    round: round ?? this.round,
    phase: phase ?? this.phase,
    outcome: outcome,
    mode: mode,
    log: log ?? this.log,
  );

  @override
  bool operator ==(Object other) {
    if (other is! Session ||
        other.id != id ||
        other.startedAtMs != startedAtMs ||
        other.round != round ||
        other.phase != phase ||
        other.outcome != outcome ||
        other.mode != mode ||
        other.players.length != players.length ||
        other.log.length != log.length) {
      return false;
    }
    for (var i = 0; i < players.length; i++) {
      if (other.players[i] != players[i]) return false;
    }
    for (var i = 0; i < log.length; i++) {
      if (other.log[i] != log[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    id,
    startedAtMs,
    round,
    phase,
    outcome,
    mode,
    Object.hashAll(players),
    Object.hashAll(log),
  );
}

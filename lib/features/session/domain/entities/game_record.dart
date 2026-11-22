import 'session.dart';

final class GameRecord {
  const GameRecord({
    required this.id,
    required this.startedAtMs,
    required this.endedAtMs,
    required this.players,
    required this.rounds,
  });
  final String id;
  final int startedAtMs, endedAtMs; // epoch ms UTC

  /// Index == seat.
  final List<Player> players;

  /// Ascending by round.
  final List<RoundEntry> rounds;

  int get playerCount => players.length;
  int get durationMs => endedAtMs - startedAtMs;

  // A record never changes after archive.
  @override
  bool operator ==(Object other) =>
      other is GameRecord &&
      other.id == id &&
      other.endedAtMs == endedAtMs &&
      other.players.length == players.length &&
      other.rounds.length == rounds.length;

  @override
  int get hashCode => Object.hash(id, endedAtMs, players.length, rounds.length);
}

final class GameStats {
  const GameStats({
    required this.truths,
    required this.dares,
    required this.passes,
    this.topTaker,
    this.topGiver,
  });
  final int truths, dares, passes;

  /// Over all rounds.
  final ({int seat, int count})? topTaker;

  /// Over truth + dare rounds only ("asked most").
  final ({int seat, int count})? topGiver;

  /// Ties go to the lowest seat; null when no qualifying round.
  factory GameStats.of(List<RoundEntry> rounds) {
    var t = 0, d = 0, p = 0;
    final takers = <int, int>{}, givers = <int, int>{};
    for (final e in rounds) {
      switch (e.result) {
        case RoundResult.truth:
          t++;
        case RoundResult.dare:
          d++;
        case RoundResult.pass:
          p++;
      }
      takers[e.taker] = (takers[e.taker] ?? 0) + 1;
      if (e.result != RoundResult.pass) {
        givers[e.giver] = (givers[e.giver] ?? 0) + 1;
      }
    }
    return GameStats(
      truths: t,
      dares: d,
      passes: p,
      topTaker: _top(takers),
      topGiver: _top(givers),
    );
  }

  static ({int seat, int count})? _top(Map<int, int> m) {
    ({int seat, int count})? best;
    for (final e in m.entries) {
      if (best == null ||
          e.value > best.count ||
          (e.value == best.count && e.key < best.seat)) {
        best = (seat: e.key, count: e.value);
      }
    }
    return best;
  }
}

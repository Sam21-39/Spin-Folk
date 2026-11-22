import '../entities/session.dart';

/// Trim; empty -> null; longer than 40 code points -> first 40.
String? normalizeName(String? raw) {
  final t = raw?.trim();
  if (t == null || t.isEmpty) return null;
  // ponytail: truncates by rune, can split an emoji ZWJ sequence; switch to
  // grapheme clusters if that ever matters. Runes match SQLite length().
  final runes = t.runes;
  return runes.length <= 40 ? t : String.fromCharCodes(runes.take(40));
}

/// "Player 7" or "Riya · P7". Seat number is always kept.
String displayLabel(Player p) {
  final n = p.seat + 1;
  return p.name == null ? 'Player $n' : '${p.name} · P$n';
}

/// Name only if non-null and unique among all players (trimmed,
/// case-insensitive), else "Player N".
String spokenName(Session s, int seat) {
  final name = s.players[seat].name?.trim();
  if (name != null && name.isNotEmpty) {
    final key = name.toLowerCase();
    var same = 0;
    for (final p in s.players) {
      if (p.name?.trim().toLowerCase() == key) same++;
    }
    if (same == 1) return name;
  }
  return 'Player ${seat + 1}';
}

/// revealed: "GIVER, give a challenge to TAKER."
/// challenge: "TAKER chose Truth." / "TAKER chose Dare."
/// ready: null.
String? speechLine(Session s) {
  final o = s.outcome;
  if (o == null) return null;
  final taker = spokenName(s, o.taker);
  return switch (s.phase) {
    Phase.ready => null,
    Phase.revealed => '${spokenName(s, o.giver)}, give a challenge to $taker.',
    Phase.challenge =>
      s.mode == Mode.dare ? '$taker chose Dare.' : '$taker chose Truth.',
  };
}

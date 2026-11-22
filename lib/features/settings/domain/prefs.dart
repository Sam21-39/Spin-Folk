final class Prefs {
  const Prefs({this.announce = true, this.voiceId, this.rate = defaultRate});

  // AVSpeechUtterance rate units (0…1, 0.5 = normal). The usable band is a
  // judgement; tune on a real device.
  static const double minRate = 0.35, maxRate = 0.65, defaultRate = 0.5;

  final bool announce;

  /// null = system default voice.
  final String? voiceId;
  final double rate;

  /// Trust boundary for stored or native values.
  factory Prefs.sanitized({bool? announce, String? voiceId, double? rate}) {
    final id = voiceId?.trim();
    return Prefs(
      announce: announce ?? true,
      voiceId: id == null || id.isEmpty ? null : id,
      rate: rate == null || !rate.isFinite
          ? defaultRate
          : rate.clamp(minRate, maxRate),
    );
  }

  Prefs withAnnounce(bool value) =>
      Prefs.sanitized(announce: value, voiceId: voiceId, rate: rate);
  Prefs withVoice(String? id) =>
      Prefs.sanitized(announce: announce, voiceId: id, rate: rate);
  Prefs withRate(double value) =>
      Prefs.sanitized(announce: announce, voiceId: voiceId, rate: value);

  @override
  bool operator ==(Object other) =>
      other is Prefs &&
      other.announce == announce &&
      other.voiceId == voiceId &&
      other.rate == rate;

  @override
  int get hashCode => Object.hash(announce, voiceId, rate);
}

/// Wire: default | enhanced | premium.
enum VoiceQuality { standard, enhanced, premium }

final class Voice {
  const Voice({
    required this.id,
    required this.name,
    required this.language,
    this.quality = VoiceQuality.standard,
  });

  final String id, name, language;
  final VoiceQuality quality;

  /// "Samantha", "Samantha (Enhanced)", "Samantha (Premium)"
  String get label => switch (quality) {
    VoiceQuality.standard => name,
    VoiceQuality.enhanced => '$name (Enhanced)',
    VoiceQuality.premium => '$name (Premium)',
  };

  @override
  bool operator ==(Object other) =>
      other is Voice &&
      other.id == id &&
      other.name == name &&
      other.language == language &&
      other.quality == quality;

  @override
  int get hashCode => Object.hash(id, name, language, quality);
}

/// "Slow" below 0.45, "Fast" above 0.55, else "Normal".
String rateLabel(double rate) => rate < 0.45
    ? 'Slow'
    : rate > 0.55
    ? 'Fast'
    : 'Normal';

/// premium → enhanced → standard, then name (case-insensitive). New list.
List<Voice> sortVoices(Iterable<Voice> voices) => voices.toList()
  ..sort((a, b) {
    final q = b.quality.index.compareTo(a.quality.index);
    return q != 0 ? q : a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });

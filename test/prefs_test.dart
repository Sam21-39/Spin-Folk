import 'package:flutter_test/flutter_test.dart';
import 'package:spinfolk/features/settings/domain/prefs.dart';

void main() {
  test('defaults', () {
    const p = Prefs();
    expect((p.announce, p.voiceId, p.rate), (true, null, 0.5));
  });

  test('sanitized clamps and cleans', () {
    expect(Prefs.sanitized(rate: 0).rate, 0.35);
    expect(Prefs.sanitized(rate: 1).rate, 0.65);
    expect(Prefs.sanitized(rate: double.nan).rate, 0.5);
    expect(Prefs.sanitized(rate: double.infinity).rate, 0.5);
    expect(Prefs.sanitized(voiceId: '  ').voiceId, isNull);
    expect(Prefs.sanitized(voiceId: ' v ').voiceId, 'v');
    expect(Prefs.sanitized(), const Prefs());
  });

  test('with* and equality', () {
    final p = const Prefs().withVoice('v').withAnnounce(false).withRate(0.6);
    expect(p, const Prefs(announce: false, voiceId: 'v', rate: 0.6));
    expect(
      p.hashCode,
      const Prefs(announce: false, voiceId: 'v', rate: 0.6).hashCode,
    );
    expect(p.withVoice(null).voiceId, isNull);
    expect(p.withRate(9).rate, 0.65);
  });

  test('rateLabel', () {
    expect(rateLabel(0.35), 'Slow');
    expect(rateLabel(0.5), 'Normal');
    expect(rateLabel(0.65), 'Fast');
    expect(rateLabel(0.45), 'Normal');
    expect(rateLabel(0.55), 'Normal');
  });

  test('Voice.label', () {
    Voice v(VoiceQuality q) =>
        Voice(id: 'i', name: 'Samantha', language: 'en-US', quality: q);
    expect(v(VoiceQuality.standard).label, 'Samantha');
    expect(v(VoiceQuality.enhanced).label, 'Samantha (Enhanced)');
    expect(v(VoiceQuality.premium).label, 'Samantha (Premium)');
    expect(v(VoiceQuality.premium), v(VoiceQuality.premium));
  });

  test('sortVoices: quality then name, input untouched', () {
    const a = Voice(id: '1', name: 'bob', language: 'en');
    const b = Voice(id: '2', name: 'Al', language: 'en');
    const c = Voice(
      id: '3',
      name: 'Zed',
      language: 'en',
      quality: VoiceQuality.premium,
    );
    const d = Voice(
      id: '4',
      name: 'Y',
      language: 'en',
      quality: VoiceQuality.enhanced,
    );
    final input = [a, b, c, d];
    expect(sortVoices(input).map((v) => v.id), ['3', '4', '2', '1']);
    expect(input.map((v) => v.id), ['1', '2', '3', '4']);
  });
}

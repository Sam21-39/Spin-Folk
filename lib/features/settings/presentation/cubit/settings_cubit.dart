import 'dart:ui';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/failure.dart';
import '../../../../platform/native_bridge.dart';
import '../../domain/prefs.dart';
import '../../domain/prefs_repository.dart';

final class SettingsState {
  const SettingsState({
    required this.prefs,
    this.voices = const [],
    this.voiceListOpen = false,
    this.failure,
  });

  final Prefs prefs;

  /// Sorted.
  final List<Voice> voices;
  final bool voiceListOpen;

  /// Last save failed; shown inline in the sheet.
  final Failure? failure;

  /// "Default" when voiceId is null or not installed any more.
  String get voiceLabel {
    for (final v in voices) {
      if (v.id == prefs.voiceId) return v.label;
    }
    return 'Default';
  }

  @override
  bool operator ==(Object other) {
    if (other is! SettingsState ||
        other.prefs != prefs ||
        other.voiceListOpen != voiceListOpen ||
        other.failure != failure ||
        other.voices.length != voices.length) {
      return false;
    }
    for (var i = 0; i < voices.length; i++) {
      if (other.voices[i] != voices[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode =>
      Object.hash(prefs, voiceListOpen, failure, Object.hashAll(voices));
}

@lazySingleton
class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit(this._repo, this._bridge)
    : super(SettingsState(prefs: _repo.load()));

  final PrefsRepository _repo;
  final NativeBridge _bridge;

  /// Sheet is opening: refresh the installed-voice list.
  Future<void> opened() async {
    emit(SettingsState(prefs: state.prefs, voices: state.voices));
    final voices = sortVoices(
      await _bridge.voices(PlatformDispatcher.instance.locale.languageCode),
    );
    if (isClosed) return;
    emit(
      SettingsState(
        prefs: state.prefs,
        voices: voices,
        voiceListOpen: state.voiceListOpen,
        failure: state.failure,
      ),
    );
  }

  Future<void> announceToggled(bool on) => _save(state.prefs.withAnnounce(on));

  void voiceRowTapped() => emit(
    SettingsState(
      prefs: state.prefs,
      voices: state.voices,
      voiceListOpen: !state.voiceListOpen,
      failure: state.failure,
    ),
  );

  /// null = Default; closes the list.
  Future<void> voiceSelected(String? id) =>
      _save(state.prefs.withVoice(id), closeList: true);

  /// Slider tick: emit only.
  void rateChanged(double rate) => emit(
    SettingsState(
      prefs: state.prefs.withRate(rate),
      voices: state.voices,
      voiceListOpen: state.voiceListOpen,
      failure: state.failure,
    ),
  );

  /// Slider released: save.
  Future<void> rateCommitted() => _save(state.prefs);

  Future<void> _save(Prefs next, {bool closeList = false}) async {
    final open = closeList ? false : state.voiceListOpen;
    emit(SettingsState(prefs: next, voices: state.voices, voiceListOpen: open));
    try {
      await _repo.save(next);
    } on Failure catch (f) {
      emit(
        SettingsState(
          prefs: state.prefs,
          voices: state.voices,
          voiceListOpen: state.voiceListOpen,
          failure: f,
        ),
      );
    }
  }
}

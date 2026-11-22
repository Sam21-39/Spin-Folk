// TEMP(phase-1): glass proof harness. Delete in Phase 2.
import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

final class ProofState {
  const ProofState({
    this.spinning = false,
    this.choices = false,
    this.lastTap = '-',
    this.flutterTaps = 0,
    this.frames = '',
  });

  final bool spinning;
  final bool choices;
  final String lastTap;
  final int flutterTaps;
  final String frames;

  ProofState copyWith({
    bool? spinning,
    bool? choices,
    String? lastTap,
    int? flutterTaps,
    String? frames,
  }) => ProofState(
    spinning: spinning ?? this.spinning,
    choices: choices ?? this.choices,
    lastTap: lastTap ?? this.lastTap,
    flutterTaps: flutterTaps ?? this.flutterTaps,
    frames: frames ?? this.frames,
  );

  @override
  bool operator ==(Object other) =>
      other is ProofState &&
      other.spinning == spinning &&
      other.choices == choices &&
      other.lastTap == lastTap &&
      other.flutterTaps == flutterTaps &&
      other.frames == frames;

  @override
  int get hashCode =>
      Object.hash(spinning, choices, lastTap, flutterTaps, frames);
}

class ProofCubit extends Cubit<ProofState> {
  ProofCubit() : super(const ProofState()) {
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  final List<Duration> _spans = [];
  bool _collecting = false;

  void _onTimings(List<FrameTiming> timings) {
    if (!_collecting) return;
    for (final t in timings) {
      _spans.add(t.totalSpan);
    }
  }

  void tapped(String id) {
    emit(state.copyWith(lastTap: id));
    switch (id) {
      case 'spin':
        spinRequested();
      case 'choices':
        emit(state.copyWith(choices: true));
      case 'truth' || 'dare':
        emit(state.copyWith(choices: false));
    }
  }

  void flutterTapped() =>
      emit(state.copyWith(flutterTaps: state.flutterTaps + 1));

  void spinRequested() {
    if (state.spinning) return;
    _spans.clear();
    _collecting = true;
    emit(state.copyWith(spinning: true));
  }

  Future<void> spinFinished() async {
    emit(state.copyWith(spinning: false));
    // Timings arrive in batches up to about a second late.
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (isClosed) return;
    _collecting = false;
    final ms = [for (final s in _spans) s.inMicroseconds / 1000];
    final worst = ms.isEmpty ? 0.0 : ms.reduce((a, b) => a > b ? a : b);
    final over16 = ms.where((m) => m > 16.7).length;
    final over33 = ms.where((m) => m > 33).length;
    emit(
      state.copyWith(
        frames:
            'Frames: ${ms.length} · worst ${worst.toStringAsFixed(1)} ms · '
            '>16.7ms: $over16 · >33ms: $over33',
      ),
    );
  }

  @override
  Future<void> close() {
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    return super.close();
  }
}

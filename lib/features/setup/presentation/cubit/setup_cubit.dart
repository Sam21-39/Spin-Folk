import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

final class SetupState {
  const SetupState({this.count = 8}); // artboards centre the wheel on 8
  final int count;

  @override
  bool operator ==(Object other) => other is SetupState && other.count == count;

  @override
  int get hashCode => count.hashCode;
}

@injectable
class SetupCubit extends Cubit<SetupState> {
  SetupCubit() : super(const SetupState());

  static const int minPlayers = 2;
  static const int maxPlayers = 60;

  /// Input comes from a native channel, so out-of-range values are ignored.
  void countChanged(int count) {
    if (count < minPlayers || count > maxPlayers) return;
    emit(SetupState(count: count));
  }
}

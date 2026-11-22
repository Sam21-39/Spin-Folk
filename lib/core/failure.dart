sealed class Failure implements Exception {
  const Failure(this.message);

  /// User-facing, shown inline.
  final String message;
}

final class StorageFailure extends Failure {
  const StorageFailure() : super("Couldn't save. Try again.");
}

final class CorruptSession extends Failure {
  const CorruptSession() : super("Couldn't restore the last game");
}

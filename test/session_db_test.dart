import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:spinfolk/features/session/data/session_db.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('spinfolk_db'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('transient open error rethrows and keeps the file', () async {
    final path = '${dir.path}/spinfolk.db';
    File(path).writeAsStringSync('keep me');
    await expectLater(
      openSessionDb(factory: _Failing(_Busy()), path: path),
      throwsA(isA<DatabaseException>()),
    );
    expect(File(path).readAsStringSync(), 'keep me');
    expect(File('$path.corrupt').existsSync(), isFalse);
  });

  test(
    'relative name resolves under databases path; sidecars follow',
    () async {
      await databaseFactoryFfi.setDatabasesPath(dir.path);
      final full = '${dir.path}/rel.db';
      File(full).writeAsBytesSync(List.filled(4096, 7));
      File('$full-journal').writeAsBytesSync(List.filled(600, 9));
      final db = await openSessionDb(
        factory: databaseFactoryFfi,
        path: 'rel.db',
      );
      expect(
        await db.rawQuery("SELECT name FROM sqlite_master WHERE name = 'game'"),
        isNotEmpty,
      );
      await db.close();
      expect(File('$full.corrupt').existsSync(), isTrue);
      expect(File('$full-journal').existsSync(), isFalse);
    },
  );

  test('corrupt file is renamed and a fresh db opens', () async {
    final path = '${dir.path}/spinfolk.db';
    File(path).writeAsBytesSync(List.filled(4096, 7));
    final db = await openSessionDb(factory: databaseFactoryFfi, path: path);
    expect(
      await db.rawQuery("SELECT name FROM sqlite_master WHERE name = 'game'"),
      isNotEmpty,
    );
    await db.close();
    expect(File('$path.corrupt').readAsBytesSync(), List.filled(4096, 7));
  });
}

class _Failing implements DatabaseFactory {
  _Failing(this.error);
  final DatabaseException error;
  @override
  Future<Database> openDatabase(String path, {OpenDatabaseOptions? options}) =>
      Future.error(error);
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Busy implements DatabaseException {
  @override
  int? getResultCode() => 5; // SQLITE_BUSY
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

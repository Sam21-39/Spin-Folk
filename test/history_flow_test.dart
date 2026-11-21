import 'package:flutter_test/flutter_test.dart';
import 'package:spinfolk/app/app_navigator.dart';
import 'package:spinfolk/features/history/presentation/pages/history_page.dart';
import 'package:spinfolk/features/history/presentation/widgets/game_row.dart';
import 'package:spinfolk/features/session/domain/entities/game_record.dart';
import 'package:spinfolk/features/session/domain/entities/session.dart';
import 'package:flutter/widgets.dart';

import 'support/harness.dart';

const _day = 24 * 3600 * 1000;

GameRecord game(String id, {int daysAgo = 0, int n = 4, int rounds = 2}) {
  final end = DateTime.now().millisecondsSinceEpoch - daysAgo * _day;
  return GameRecord(
    id: id,
    startedAtMs: end - 20 * 60000,
    endedAtMs: end,
    players: [for (var i = 0; i < n; i++) Player(seat: i)],
    rounds: [
      for (var r = 1; r <= rounds; r++)
        RoundEntry(round: r, taker: 0, giver: 2, result: RoundResult.truth),
    ],
  );
}

/// pump() advances fake time; pumpAndSettle would run the whole 5 s toast.
Future<void> frames(WidgetTester tester, [int ms = 600]) async {
  for (var t = 0; t < ms; t += 100) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> toHistory(WidgetTester tester) async {
  read<AppNavigator>(tester).history();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('empty state offers Start a game', (tester) async {
    await pumpApp(tester);
    await toHistory(tester);
    expect(find.text('No past games yet'), findsOneWidget);
    expect(find.text('Clear all'), findsNothing);
    await tapBar(tester, 'start');
    await tester.pumpAndSettle();
    expect(find.text('New game'), findsOneWidget);
  });

  testWidgets('list is grouped by date', (tester) async {
    await pumpApp(
      tester,
      history: [game('a'), game('b', daysAgo: 3), game('c', daysAgo: 60)],
    );
    await toHistory(tester);
    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text('THIS WEEK'), findsOneWidget);
    expect(find.byType(GameRow), findsNWidgets(3));
    expect(find.text('Clear all'), findsOneWidget);
    expect(find.textContaining('Stored only on this iPhone'), findsOneWidget);
  });

  testWidgets('swipe deletes, toast, Undo restores', (tester) async {
    await pumpApp(tester, history: [game('a'), game('b')]);
    await toHistory(tester);
    await tester.drag(find.byType(Dismissible).first, const Offset(-400, 0));
    await frames(tester);
    expect(find.byType(GameRow), findsOneWidget);
    expect(find.text('Game deleted'), findsOneWidget);
    expect(historyRepo().deleted, {'a'});
    await tapLabel(tester, 'Undo');
    await frames(tester, 300);
    expect(find.byType(GameRow), findsNWidgets(2));
    expect(find.text('Game deleted'), findsNothing);
    expect(historyRepo().deleted, isEmpty);
  });

  testWidgets('no undo: the row is purged and the toast leaves', (
    tester,
  ) async {
    await pumpApp(tester, history: [game('a'), game('b')]);
    await toHistory(tester);
    await tester.drag(find.byType(Dismissible).last, const Offset(-400, 0));
    await frames(tester);
    expect(find.text('Game deleted'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    await frames(tester, 300);
    expect(find.text('Game deleted'), findsNothing);
    expect(historyRepo().rows.map((g) => g.id), ['a']);
    expect(historyRepo().deleted, isEmpty);
  });

  testWidgets('delete from detail: confirm, back on the list with the toast', (
    tester,
  ) async {
    await pumpApp(tester, history: [game('a'), game('b')]);
    await toHistory(tester);
    await tester.tap(find.byType(GameRow).first);
    await tester.pumpAndSettle();
    expect(find.text('ROUND LOG'), findsOneWidget);
    expect(find.text('Play again with this circle'), findsNothing); // native
    await tapLabel(tester, 'Delete game');
    await tester.pumpAndSettle();
    expect(find.text('Delete this game?'), findsOneWidget);
    await tapBar(tester, 'cancel');
    await tester.pumpAndSettle();
    expect(find.text('Delete this game?'), findsNothing);
    expect(find.text('ROUND LOG'), findsOneWidget);
    await tapLabel(tester, 'Delete game');
    await tester.pumpAndSettle();
    await tapBar(tester, 'confirm');
    await frames(tester);
    expect(find.byType(HistoryPage), findsOneWidget);
    expect(find.byType(GameRow), findsOneWidget);
    expect(find.text('Game deleted'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('Clear all: confirm, toast with count, Undo restores all', (
    tester,
  ) async {
    await pumpApp(
      tester,
      history: [game('a'), game('b'), game('c', daysAgo: 2)],
    );
    await toHistory(tester);
    await tapLabel(tester, 'Clear all');
    await tester.pumpAndSettle();
    expect(find.text('Clear all history?'), findsOneWidget);
    await tapBar(tester, 'confirm');
    await frames(tester);
    expect(find.byType(GameRow), findsNothing);
    expect(find.text('3 games deleted'), findsOneWidget);
    await tapLabel(tester, 'Undo');
    await frames(tester, 300);
    expect(find.byType(GameRow), findsNWidgets(3));
    expect(find.text('3 games deleted'), findsNothing);
  });

  testWidgets('detail of an unknown id says so', (tester) async {
    await pumpApp(tester, history: [game('a')]);
    read<AppNavigator>(tester).historyDetail('nope');
    await tester.pumpAndSettle();
    expect(find.text('This game is no longer in History.'), findsOneWidget);
  });

  testWidgets('Play again from detail archives the game in progress', (
    tester,
  ) async {
    final repo = await pumpApp(
      tester,
      history: [game('a', n: 3)],
      stored: Session(
        id: 'live',
        startedAtMs: 0,
        players: [for (var i = 0; i < 4; i++) Player(seat: i)],
        round: 2,
        log: const [
          RoundEntry(round: 1, taker: 0, giver: 2, result: RoundResult.dare),
        ],
      ),
    );
    await toHistory(tester);
    await tester.tap(find.byType(GameRow).first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Starting a new game ends'), findsOneWidget);
    await tapBar(tester, 'again');
    await tester.pumpAndSettle();
    expect(find.text('Round 1 · 3 players'), findsOneWidget);
    expect(historyRepo().rows.map((g) => g.id), contains('live'));
    expect(historyRepo().rows, hasLength(2));
    expect(repo.stored!.playerCount, 3);
  });
}

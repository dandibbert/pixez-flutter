import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pixez/component/search_date_filter.dart';
import 'package:pixez/src/generated/i18n/app_localizations.dart';

void main() {
  test('date shortcuts retain upstream rolling-day ranges', () {
    final now = DateTime.utc(2026, 9, 20);
    const days = {
      SearchDatePreset.day1: 1,
      SearchDatePreset.week1: 7,
      SearchDatePreset.month1: 30,
      SearchDatePreset.month6: 180,
      SearchDatePreset.year1: 365,
    };
    for (final entry in days.entries) {
      final range = entry.key.rangeEndingAt(now)!;
      expect(range.end, now);
      expect(range.start, now.subtract(Duration(days: entry.value)));
    }
    expect(SearchDatePreset.none.rangeEndingAt(now), isNull);
  });

  Widget buildButton(ValueChanged<DateTimeRange?> onChanged) {
    return MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SearchDateFilterButton(
          value: DateTimeRange(
            start: DateTime(2024, 1, 1),
            end: DateTime(2024, 1, 31),
          ),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Future<void> selectPreset(
    WidgetTester tester,
    SearchDatePreset preset,
  ) async {
    await tester.tap(find.byType(PopupMenuButton<SearchDatePreset>));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byWidgetPredicate(
        (widget) =>
            widget is PopupMenuItem<SearchDatePreset> && widget.value == preset,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('unlimited clears a restored date range', (tester) async {
    final changes = <DateTimeRange?>[];
    await tester.pumpWidget(buildButton(changes.add));
    await selectPreset(tester, SearchDatePreset.none);
    expect(changes, [null]);
  });

  testWidgets('cancelling the custom picker preserves the query', (
    tester,
  ) async {
    final changes = <DateTimeRange?>[];
    await tester.pumpWidget(buildButton(changes.add));
    await selectPreset(tester, SearchDatePreset.custom);
    expect(find.byType(DateRangePickerDialog), findsOneWidget);
    final dialogContext = tester.element(find.byType(DateRangePickerDialog));
    Navigator.of(dialogContext).pop();
    await tester.pumpAndSettle();
    expect(changes, isEmpty);
  });
}

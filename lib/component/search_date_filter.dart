import 'package:material_ui/material_ui.dart';
import 'package:pixez/i18n.dart';

enum SearchDatePreset {
  none,
  day1,
  week1,
  month1,
  month6,
  year1,
  custom;

  DateTimeRange? rangeEndingAt(DateTime now) {
    final days = switch (this) {
      SearchDatePreset.day1 => 1,
      SearchDatePreset.week1 => 7,
      SearchDatePreset.month1 => 30,
      SearchDatePreset.month6 => 180,
      SearchDatePreset.year1 => 365,
      SearchDatePreset.none || SearchDatePreset.custom => null,
    };
    return days == null
        ? null
        : DateTimeRange(
            start: now.subtract(Duration(days: days)),
            end: now,
          );
  }

  String label(BuildContext context) {
    final l10n = I18n.of(context);
    return switch (this) {
      SearchDatePreset.none => l10n.date_preset_none,
      SearchDatePreset.day1 => l10n.date_preset_1day,
      SearchDatePreset.week1 => l10n.date_preset_1week,
      SearchDatePreset.month1 => l10n.date_preset_1month,
      SearchDatePreset.month6 => l10n.date_preset_6months,
      SearchDatePreset.year1 => l10n.date_preset_1year,
      SearchDatePreset.custom => l10n.date_preset_custom,
    };
  }
}

/// The search query owns the selected range, including clearing/restoring it.
class SearchDateFilterButton extends StatelessWidget {
  const SearchDateFilterButton({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final DateTimeRange? value;
  final ValueChanged<DateTimeRange?> onChanged;

  Future<void> _select(BuildContext context, SearchDatePreset preset) async {
    if (preset != SearchDatePreset.custom) {
      onChanged(preset.rangeEndingAt(DateTime.now()));
      return;
    }
    final range = await showDateRangePicker(
      context: context,
      initialDateRange: value,
      firstDate: DateTime(2007, 8),
      lastDate: DateTime.now(),
    );
    if (context.mounted && range != null) {
      onChanged(range);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<SearchDatePreset>(
      tooltip: I18n.of(context).date_duration,
      icon: Icon(
        Icons.date_range,
        color: value != null ? Theme.of(context).colorScheme.primary : null,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      onSelected: (preset) => _select(context, preset),
      itemBuilder: (context) => [
        for (final preset in SearchDatePreset.values)
          PopupMenuItem<SearchDatePreset>(
            value: preset,
            child: Text(preset.label(context)),
          ),
      ],
    );
  }
}

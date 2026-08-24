import 'package:intl/intl.dart';

/// Zeitraum einer Kassenauswertung.
enum PeriodKind { day, week, month, year }

/// Ein konkreter Auswertungszeitraum mit Anfangs- und Endtag.
///
/// Rechnet ausschliesslich mit Tagesschluesseln im Format yyyy-MM-dd, weil die
/// Verkaufsdokumente ihr Datum so fuehren.
class ReportPeriod {
  final PeriodKind kind;

  /// Beliebiger Tag innerhalb des Zeitraums; daraus werden die Grenzen bestimmt.
  final DateTime anchor;

  const ReportPeriod(this.kind, this.anchor);

  factory ReportPeriod.today() => ReportPeriod(PeriodKind.day, DateTime.now());

  static final DateFormat _key = DateFormat('yyyy-MM-dd');
  static final DateFormat _dayLabel = DateFormat('EEEE, d. MMMM yyyy', 'de_DE');
  static final DateFormat _shortDay = DateFormat('d. MMM', 'de_DE');
  static final DateFormat _monthLabel = DateFormat('MMMM yyyy', 'de_DE');

  DateTime get _anchorDate => DateTime(anchor.year, anchor.month, anchor.day);

  DateTime get startDate {
    final a = _anchorDate;
    switch (kind) {
      case PeriodKind.day:
        return a;
      case PeriodKind.week:
        // DateTime.weekday: Montag = 1
        return a.subtract(Duration(days: a.weekday - 1));
      case PeriodKind.month:
        return DateTime(a.year, a.month, 1);
      case PeriodKind.year:
        return DateTime(a.year, 1, 1);
    }
  }

  DateTime get endDate {
    final a = _anchorDate;
    switch (kind) {
      case PeriodKind.day:
        return a;
      case PeriodKind.week:
        return startDate.add(const Duration(days: 6));
      case PeriodKind.month:
        // Tag 0 des Folgemonats ist der letzte Tag dieses Monats
        return DateTime(a.year, a.month + 1, 0);
      case PeriodKind.year:
        return DateTime(a.year, 12, 31);
    }
  }

  String get fromKey => _key.format(startDate);
  String get toKey => _key.format(endDate);

  /// True, wenn der Zeitraum genau einen Tag umfasst.
  bool get isSingleDay => kind == PeriodKind.day;

  /// Menschenlesbare Bezeichnung fuer Kopfzeilen und Dateinamen.
  String get label {
    switch (kind) {
      case PeriodKind.day:
        return _dayLabel.format(startDate);
      case PeriodKind.week:
        return 'KW ${_isoWeek(startDate)} · ${_shortDay.format(startDate)} bis ${_shortDay.format(endDate)} ${endDate.year}';
      case PeriodKind.month:
        return _monthLabel.format(startDate);
      case PeriodKind.year:
        return 'Jahr ${startDate.year}';
    }
  }

  /// Kurzform ohne Sonderzeichen, geeignet als Dateiname.
  String get fileLabel {
    switch (kind) {
      case PeriodKind.day:
        return fromKey;
      case PeriodKind.week:
        return '${startDate.year}-KW${_isoWeek(startDate).toString().padLeft(2, '0')}';
      case PeriodKind.month:
        return DateFormat('yyyy-MM').format(startDate);
      case PeriodKind.year:
        return '${startDate.year}';
    }
  }

  String get kindLabel {
    switch (kind) {
      case PeriodKind.day:
        return 'Tag';
      case PeriodKind.week:
        return 'Woche';
      case PeriodKind.month:
        return 'Monat';
      case PeriodKind.year:
        return 'Jahr';
    }
  }

  /// Verschiebt den Zeitraum um [steps] Einheiten nach vorne oder hinten.
  ReportPeriod shift(int steps) {
    final a = _anchorDate;
    switch (kind) {
      case PeriodKind.day:
        return ReportPeriod(kind, a.add(Duration(days: steps)));
      case PeriodKind.week:
        return ReportPeriod(kind, a.add(Duration(days: 7 * steps)));
      case PeriodKind.month:
        return ReportPeriod(kind, DateTime(a.year, a.month + steps, 1));
      case PeriodKind.year:
        return ReportPeriod(kind, DateTime(a.year + steps, 1, 1));
    }
  }

  ReportPeriod withKind(PeriodKind k) => ReportPeriod(k, anchor);
  ReportPeriod withAnchor(DateTime d) => ReportPeriod(kind, d);

  /// True, wenn der Zeitraum in der Zukunft beginnt.
  bool get isFuture => startDate.isAfter(DateTime.now());

  /// Kalenderwoche nach ISO 8601.
  static int _isoWeek(DateTime date) {
    final thursday = date.add(Duration(days: 4 - (date.weekday == 7 ? 7 : date.weekday)));
    final firstJan = DateTime(thursday.year, 1, 1);
    return ((thursday.difference(firstJan).inDays) / 7).floor() + 1;
  }
}

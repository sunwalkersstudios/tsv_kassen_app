/// Kassentag: Startbestand, Einlagen und Entnahmen eines einzelnen Tages.
///
/// Frueher lagen diese Werte in SharedPreferences und damit nur auf einem
/// Geraet. Jetzt liegen sie in Firestore unter `cashDays/{yyyy-MM-dd}`, sind
/// also auf jedem Geraet sichtbar und ueberstehen eine Neuinstallation.
///
/// Alle Betraege in ganzzahligen Cent.
class CashDay {
  /// Tagesschluessel im Format yyyy-MM-dd, zugleich die Dokument-ID.
  final String day;

  /// Wechselgeld beim Oeffnen der Kasse.
  final int openingCents;

  /// Nachtraeglich eingelegtes Bargeld.
  final int depositCents;

  /// Entnommenes Bargeld.
  final int withdrawalCents;

  /// Freitext, etwa fuer Differenzen oder Besonderheiten des Tages.
  final String note;

  final DateTime? updatedAt;
  final String? updatedBy;

  const CashDay({
    required this.day,
    this.openingCents = 0,
    this.depositCents = 0,
    this.withdrawalCents = 0,
    this.note = '',
    this.updatedAt,
    this.updatedBy,
  });

  /// Leerer Tag, wenn in Firestore noch nichts hinterlegt ist.
  factory CashDay.empty(String day) => CashDay(day: day);

  factory CashDay.fromMap(String day, Map<String, dynamic>? m) {
    final map = m ?? const <String, dynamic>{};
    int asCents(String key) => (map[key] as num?)?.round() ?? 0;
    final ts = map['updatedAt'];
    return CashDay(
      day: day,
      openingCents: asCents('openingCents'),
      depositCents: asCents('depositCents'),
      withdrawalCents: asCents('withdrawalCents'),
      note: (map['note'] as String?) ?? '',
      updatedAt: ts != null && ts is! String ? (ts as dynamic).toDate() as DateTime? : null,
      updatedBy: map['updatedBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'day': day,
        'openingCents': openingCents,
        'depositCents': depositCents,
        'withdrawalCents': withdrawalCents,
        'note': note,
      };

  /// Rechnerischer Kassenbestand am Ende des Tages.
  /// [cashRevenueCents] ist der Barumsatz laut Verkaufsdokumenten.
  int drawerCents(int cashRevenueCents) =>
      openingCents + cashRevenueCents + depositCents - withdrawalCents;

  /// True, wenn fuer den Tag ueberhaupt etwas eingetragen wurde.
  bool get hasEntries =>
      openingCents != 0 || depositCents != 0 || withdrawalCents != 0 || note.isNotEmpty;

  CashDay copyWith({
    int? openingCents,
    int? depositCents,
    int? withdrawalCents,
    String? note,
  }) =>
      CashDay(
        day: day,
        openingCents: openingCents ?? this.openingCents,
        depositCents: depositCents ?? this.depositCents,
        withdrawalCents: withdrawalCents ?? this.withdrawalCents,
        note: note ?? this.note,
        updatedAt: updatedAt,
        updatedBy: updatedBy,
      );
}

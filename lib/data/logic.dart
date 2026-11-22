import 'package:intl/intl.dart';

import 'models.dart';

final _money = NumberFormat.currency(locale: 'en_CA', symbol: r'$', decimalDigits: 2);
String money(num? v) => _money.format(v ?? 0);

const monthNames = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
const mon = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String plural(int n, String w) => '$n $w${n == 1 ? '' : 's'}';

DateTime today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

int daysBetween(DateTime a, DateTime b) =>
    DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

String isoDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime? parseIso(String s) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(s.trim());
  if (m == null) return null;
  final y = int.parse(m[1]!), mo = int.parse(m[2]!), d = int.parse(m[3]!);
  if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
  return DateTime(y, mo, d);
}

String fmtDate(String iso) {
  final d = parseIso(iso);
  return d == null ? '' : '${mon[d.month - 1]} ${d.day}, ${d.year}';
}

/// Easter Sunday (Gregorian calendar).
DateTime easterDate(int y) {
  final a = y % 19, b = y ~/ 100, c = y % 100, d = b ~/ 4, e = b % 4;
  final f = (b + 8) ~/ 25, g = (b - f + 1) ~/ 3, h = (19 * a + b - d - g + 15) % 30;
  final i = c ~/ 4, k = c % 4, l = (32 + 2 * e + 2 * i - h - k) % 7, m = (a + 11 * h + 22 * l) ~/ 451;
  final month = (h + l - 7 * m + 114) ~/ 31, day = ((h + l - 7 * m + 114) % 31) + 1;
  return DateTime(y, month, day);
}

DateTime? occasionDate(String occ, int y) => switch (occ) {
      'christmas' => DateTime(y, 12, 25),
      'valentines' => DateTime(y, 2, 14),
      'easter' => easterDate(y),
      _ => null,
    };

/// Christmas, Easter and Valentine's open on next year's once this year's has passed.
int defaultYear(String occ, [DateTime? now]) {
  final t = now ?? today();
  final d = occasionDate(occ, t.year);
  return d != null && d.isBefore(t) ? t.year + 1 : t.year;
}

class NextBirthday {
  NextBirthday(this.date, this.days, this.turns);
  final DateTime date;
  final int days;
  final int? turns;
}

NextBirthday? nextBirthday(Person p, [DateTime? now]) {
  final b = parseIso(p.birthday);
  if (b == null) return null;
  final t = now ?? today();
  var n = DateTime(t.year, b.month, b.day);
  if (n.isBefore(t)) n = DateTime(t.year + 1, b.month, b.day);
  return NextBirthday(n, daysBetween(t, n), b.year > 1900 ? n.year - b.year : null);
}

double total(Iterable<Gift> gs) => gs.fold(0.0, (a, g) => a + (g.price ?? 0));

class FairRow {
  FairRow(this.person, this.total, this.count);
  final Person person;
  final double total;
  final int count;
}

class FairGroup {
  FairGroup(this.name, this.rows);
  final String name;
  final List<FairRow> rows;

  double value(FairRow r, bool byCount) => byCount ? r.count.toDouble() : r.total;
  double max(bool byCount) => rows.fold(0.0, (a, r) => value(r, byCount) > a ? value(r, byCount) : a);
  double min(bool byCount) =>
      rows.isEmpty ? 0 : rows.map((r) => value(r, byCount)).reduce((a, b) => a < b ? a : b);

  /// One plain sentence about how even this group is.
  String note(bool byCount) {
    if (rows.length < 2) return '';
    final mx = max(byCount), mn = min(byCount);
    if (mx == 0) return 'Nothing bought yet for ${name.toLowerCase()}.';
    if (mx - mn < 0.005) {
      return byCount ? 'Even count. Everyone has ${plural(mx.round(), 'gift')}.' : 'Perfectly even. Everyone is at ${money(mx)}.';
    }
    final top = rows.firstWhere((r) => value(r, byCount) == mx);
    final behind = rows.where((r) => value(r, byCount) < mx).toList()
      ..sort((a, b) => value(a, byCount).compareTo(value(b, byCount)));
    final parts = behind
        .map((r) => byCount ? '${r.person.name} has ${plural(top.count - r.count, 'gift')} fewer' : '${r.person.name} is ${money(top.total - r.total)} behind')
        .join(', ');
    return byCount ? '$parts than ${top.person.name}.' : '$parts ${top.person.name}.';
  }
}

List<FairGroup> fairness(List<Person> people, List<Gift> gifts) {
  final out = <FairGroup>[];
  for (final g in groups) {
    final ps = people.where((p) => p.group == g).toList();
    if (ps.isEmpty) continue;
    out.add(FairGroup(g, [
      for (final p in ps)
        FairRow(p, total(gifts.where((x) => x.personId == p.id)), gifts.where((x) => x.personId == p.id).length)
    ]));
  }
  return out;
}

/// Short line for one person's window: money and gift count against the rest of their group.
String personNote(Person p, List<Person> people, List<Gift> gifts) {
  final peers = people.where((x) => x.group == p.group).toList();
  if (peers.length < 2) return '';
  final rows = [for (final x in peers) FairRow(x, total(gifts.where((g) => g.personId == x.id)), gifts.where((g) => g.personId == x.id).length)];
  final me = rows.firstWhere((r) => r.person.id == p.id);
  final mx = rows.map((r) => r.total).reduce((a, b) => a > b ? a : b);
  final mc = rows.map((r) => r.count).reduce((a, b) => a > b ? a : b);
  if (mx == 0 && mc == 0) return 'Nothing bought yet for anyone in ${p.group}.';
  final top = rows.firstWhere((r) => r.total == mx), topc = rows.firstWhere((r) => r.count == mc);
  String s;
  if (rows.every((r) => (r.total - mx).abs() < 0.005)) {
    s = 'Perfectly even with everyone in ${p.group}.';
  } else if (me.total >= mx - 0.005) {
    s = '${p.name} is the highest in ${p.group}.';
  } else {
    s = '${p.name} is ${money(mx - me.total)} behind ${top.person.name}.';
  }
  if (rows.every((r) => r.count == mc)) {
    s += ' Everyone has ${plural(mc, 'gift')}.';
  } else if (me.count >= mc) {
    s += ' ${p.name} has the most gifts ($mc).';
  } else {
    s += ' ${p.name} has ${plural(mc - me.count, 'gift')} fewer than ${topc.person.name}.';
  }
  return s;
}

String occasionDateLine(String occ, int y, List<Person> people, [DateTime? now]) {
  final t = now ?? today();
  if (occ == 'birthday') {
    final list = [
      for (final p in people)
        if (nextBirthday(p, t) != null) (p, nextBirthday(p, t)!)
    ]..sort((a, b) => a.$2.days.compareTo(b.$2.days));
    if (list.isEmpty) return "Add birthdays to see who's next";
    final (p, nb) = list.first;
    return nb.days == 0
        ? "${p.name}'s birthday is today"
        : '${p.name} · ${mon[nb.date.month - 1]} ${nb.date.day} · in ${plural(nb.days, 'day')}';
  }
  if (occ == 'special') return 'Graduations, showers, anniversaries';
  final d = occasionDate(occ, y)!;
  final days = daysBetween(t, d);
  final ds = '${mon[d.month - 1]} ${d.day}, ${d.year}';
  if (days > 0) return '$ds · ${plural(days, 'day')} to go';
  if (days == 0) return '$ds · Today';
  return '$ds · Celebrated';
}

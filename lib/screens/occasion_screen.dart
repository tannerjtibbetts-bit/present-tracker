import 'package:flutter/material.dart';

import '../data/logic.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../services/export.dart';
import '../ui/art.dart';
import '../ui/common.dart';
import '../ui/themes.dart';
import 'gift_sheet.dart';
import 'people_sheets.dart';
import 'person_screen.dart';

class OccasionScreen extends StatefulWidget {
  const OccasionScreen({super.key, required this.occ});
  final Occ occ;

  @override
  State<OccasionScreen> createState() => _OccasionScreenState();
}

class _OccasionScreenState extends State<OccasionScreen> {
  late int year = defaultYear(widget.occ.key);
  bool byCount = false;
  late DateTime calMonth = DateTime(DateTime.now().year, DateTime.now().month);

  Occ get occ => widget.occ;

  Future<void> export(BuildContext ctx) async {
    final ids = await showReportPicker(context, occ, year);
    if (ids == null || !ctx.mounted) return;
    await exportReport(ctx, occ, year, ids);
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: occTheme(occ),
      child: Scaffold(
        backgroundColor: occ.bg,
        body: Tiled(
          asset: occ.wall,
          tile: 300,
          color: occ.bg,
          child: SafeArea(
            child: ListenableBuilder(
              listenable: AppStore.instance,
              builder: (context, _) {
                final store = AppStore.instance;
                final list = store.giftsFor(occ.key, year);
                return ListView(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 40),
                  children: [
                    if (occ.key == 'christmas') const Garland(),
                    _topBar(context),
                    const SizedBox(height: 10),
                    _hero(context, list),
                    if (occ.key == 'birthday') ...[const SizedBox(height: 18), _calendar(context)],
                    const SizedBox(height: 18),
                    _fairness(list),
                    const SizedBox(height: 18),
                    _people(context, list),
                    const SizedBox(height: 18),
                    _garlandRow(),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context) => Row(children: [
        FilledButton.icon(
          style: altButton(occ),
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.chevron_left),
          label: const Text('All occasions'),
        ),
        const Spacer(),
        Container(
          decoration: BoxDecoration(color: occ.surface, borderRadius: BorderRadius.circular(99), border: Border.all(color: occ.accent2)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(onPressed: () => setState(() => year--), icon: const Icon(Icons.chevron_left), tooltip: 'Previous year'),
            Text('$year', style: TextStyle(fontWeight: FontWeight.w700, color: occ.ink)),
            IconButton(onPressed: () => setState(() => year++), icon: const Icon(Icons.chevron_right), tooltip: 'Next year'),
          ]),
        ),
      ]);

  Widget _hero(BuildContext context, List<Gift> list) => Panel(
        occ: occ,
        padding: EdgeInsets.zero,
        child: Column(children: [
          AspectRatio(aspectRatio: occ.sceneAspect, child: Art(occ.scene)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 22),
            child: Column(children: [
              Text(occ.eyebrow, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, letterSpacing: 2.4, color: occ.gold, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              FittedBox(child: Text(occ.label, style: display(54, occ.gold))),
              const SizedBox(height: 6),
              Text(occasionDateLine(occ.key, year, AppStore.instance.people), textAlign: TextAlign.center, style: TextStyle(color: occ.muted)),
              const SizedBox(height: 14),
              StatRow(occ: occ, items: [
                ('Spent', money(total(list))),
                ('Gifts', '${list.length}'),
                ('To arrive', '${list.where((g) => g.status == 'ordered').length}'),
              ]),
              const SizedBox(height: 16),
              Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 10, children: [
                FilledButton.icon(
                  onPressed: () => showGiftSheet(context, occ: occ, year: year),
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: const Text('Add a gift'),
                ),
                Builder(
                  builder: (ctx) => FilledButton.icon(
                    style: altButton(occ),
                    onPressed: () => export(ctx),
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('Export PDF'),
                  ),
                ),
                OutlinedButton.icon(onPressed: () => showPeopleSheet(context, occ), icon: const Icon(Icons.people_outline), label: const Text('People')),
              ]),
            ]),
          ),
        ]),
      );

  Widget _fairness(List<Gift> list) {
    final store = AppStore.instance;
    final groupsF = fairness(store.people, list);
    return Panel(
      occ: occ,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionTitle(
          'Fairness check',
          occ: occ,
          trailing: SegmentedButton<bool>(
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: occ.accent,
              selectedForegroundColor: occ.accentInk,
              backgroundColor: occ.surface,
              foregroundColor: occ.ink,
            ),
            segments: const [
              ButtonSegment(value: false, label: Text('By spending')),
              ButtonSegment(value: true, label: Text('By gifts')),
            ],
            selected: {byCount},
            onSelectionChanged: (s) => setState(() => byCount = s.first),
          ),
        ),
        if (store.people.isEmpty) Text('Add people to compare.', style: TextStyle(color: occ.muted)),
        for (final g in groupsF) ...[
          Text(g.name.toUpperCase(), style: TextStyle(fontSize: 11, letterSpacing: 2, color: occ.muted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          for (final r in g.rows) _fairRow(g, r),
          if (g.note(byCount).isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 4, bottom: 14),
              padding: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: occ.line))),
              child: Text(g.note(byCount), style: TextStyle(color: occ.muted, fontSize: 13.5)),
            )
          else
            const SizedBox(height: 14),
        ],
      ]),
    );
  }

  Widget _fairRow(FairGroup g, FairRow r) {
    final mx = g.max(byCount), v = g.value(r, byCount);
    final frac = mx == 0 ? 0.0 : (v / mx).clamp(0.02, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        SizedBox(width: 100, child: Text(r.person.name, overflow: TextOverflow.ellipsis, style: display(18, occ.ink, weight: FontWeight.w500))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: Container(
              height: 10,
              color: occ.surface2,
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: frac,
                child: Container(decoration: BoxDecoration(gradient: LinearGradient(colors: [occ.accent, occ.accent2]))),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 82,
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(byCount ? plural(r.count, 'gift') : money(r.total), style: TextStyle(fontWeight: FontWeight.w600, color: occ.ink)),
            Text(byCount ? money(r.total) : plural(r.count, 'gift'), style: TextStyle(fontSize: 11, color: occ.muted)),
          ]),
        ),
      ]),
    );
  }

  Widget _people(BuildContext context, List<Gift> list) {
    final store = AppStore.instance;
    return Panel(
      occ: occ,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionTitle("Who's getting what", occ: occ),
        if (store.people.isEmpty)
          TextButton(onPressed: () => showPeopleSheet(context, occ), child: const Text('Add someone to start their list')),
        for (var i = 0; i < store.people.length; i++) ...[
          _personCard(context, store.people[i], i, list.where((g) => g.personId == store.people[i].id).toList()),
          const SizedBox(height: 14),
        ],
      ]),
    );
  }

  Widget _personCard(BuildContext context, Person p, int i, List<Gift> gl) {
    gl.sort((a, b) => a.created.compareTo(b.created));
    final band = occ.band(i);
    final sub = [p.group, if (p.note.isNotEmpty) p.note];
    if (occ.key == 'birthday') {
      final nb = nextBirthday(p);
      sub.add(nb == null ? 'No birthday set' : '${mon[nb.date.month - 1]} ${nb.date.day}${nb.turns != null ? ' · turns ${nb.turns}' : ''}');
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(color: occ.surface, border: Border.all(color: occ.line), borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          InkWell(
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PersonScreen(occ: occ, year: year, personId: p.id))),
            child: BandBox(
              band: band,
              child: Row(children: [
                Motif(asset: occ.motif(i), ring: band.ink),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p.name, style: bandShadow(band, display(24, band.ink))),
                    Text(sub.join(' · '), style: bandShadow(band, TextStyle(fontSize: 12.5, color: band.ink.withValues(alpha: .88)))),
                  ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(money(total(gl)), style: bandShadow(band, display(22, band.ink, weight: FontWeight.w500))),
                  Text('${plural(gl.length, 'gift')} · OPEN ›', style: bandShadow(band, TextStyle(fontSize: 11, letterSpacing: .8, color: band.ink.withValues(alpha: .88)))),
                ]),
              ]),
            ),
          ),
          if (gl.isEmpty)
            Padding(padding: const EdgeInsets.all(16), child: Text('Nothing for ${p.name} yet.', style: TextStyle(color: occ.muted))),
          for (final g in gl) _giftRow(context, g),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () => showGiftSheet(context, occ: occ, year: year, personId: p.id),
                icon: const Icon(Icons.add, size: 18),
                label: Text('Add for ${p.name}'),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _giftRow(BuildContext context, Gift g) => InkWell(
        onTap: () => showGiftSheet(context, occ: occ, year: year, gift: g),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: occ.line))),
          child: Row(children: [
            Thumb(gift: g, occ: occ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(g.item.isEmpty ? 'Untitled gift' : g.item, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: occ.ink)),
                const SizedBox(height: 4),
                Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  if (g.event.isNotEmpty) Text(g.event.toUpperCase(), style: TextStyle(fontSize: 10.5, letterSpacing: 1.2, color: occ.gold)),
                  if (g.store.isNotEmpty) Text(g.store, style: TextStyle(fontSize: 12.5, color: occ.muted)),
                  StatusChip(gift: g, occ: occ),
                ]),
              ]),
            ),
            const SizedBox(width: 8),
            Text(g.price == null ? 'No price' : money(g.price), style: TextStyle(fontWeight: FontWeight.w600, color: g.price == null ? occ.muted : occ.ink)),
          ]),
        ),
      );

  Widget _calendar(BuildContext context) {
    final store = AppStore.instance;
    final y = calMonth.year, m = calMonth.month;
    final first = DateTime(y, m, 1), days = DateTime(y, m + 1, 0).day, lead = first.weekday % 7;
    final marks = <int, List<Person>>{};
    for (final p in store.people) {
      final b = parseIso(p.birthday);
      if (b != null && b.month == m) marks.putIfAbsent(b.day, () => []).add(p);
    }
    final t = today();
    final ups = [for (final p in store.people) (p, nextBirthday(p))];
    final set = ups.where((u) => u.$2 != null).toList()..sort((a, b) => a.$2!.days.compareTo(b.$2!.days));
    final unset = ups.where((u) => u.$2 == null);
    return Panel(
      occ: occ,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionTitle('Birthday calendar', occ: occ),
        Row(children: [
          IconButton.outlined(onPressed: () => setState(() => calMonth = DateTime(y, m - 1)), icon: const Icon(Icons.chevron_left), tooltip: 'Previous month'),
          Expanded(child: Text('${monthNames[m - 1]} $y', textAlign: TextAlign.center, style: display(24, occ.ink, weight: FontWeight.w500))),
          IconButton.outlined(onPressed: () => setState(() => calMonth = DateTime(y, m + 1)), icon: const Icon(Icons.chevron_right), tooltip: 'Next month'),
        ]),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          children: [
            for (final d in ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
              Center(child: Text(d, style: TextStyle(fontSize: 11, letterSpacing: 1.5, color: occ.muted))),
            for (var i = 0; i < lead; i++) const SizedBox.shrink(),
            for (var d = 1; d <= days; d++)
              GestureDetector(
                onTap: marks[d] == null ? null : () => showPersonForm(context, occ, marks[d]!.first),
                child: Container(
                  decoration: BoxDecoration(
                    color: marks[d] != null ? occ.gold.withValues(alpha: .16) : null,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: marks[d] != null ? occ.gold : (t.year == y && t.month == m && t.day == d ? occ.line : Colors.transparent),
                    ),
                  ),
                  padding: const EdgeInsets.only(top: 4),
                  child: Column(children: [
                    Text('$d', style: TextStyle(fontSize: 13, color: occ.ink)),
                    if (marks[d] != null)
                      Text(marks[d]!.first.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 9.5, color: occ.gold, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Text('Coming up', style: display(22, occ.ink, weight: FontWeight.w500)),
        for (final (p, nb) in set)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: SizedBox(
              width: 52,
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('${nb!.date.day}', style: display(24, occ.ink, weight: FontWeight.w500)),
                Text(mon[nb.date.month - 1].toUpperCase(), style: TextStyle(fontSize: 10, letterSpacing: 1.5, color: occ.gold)),
              ]),
            ),
            title: Text(p.name, style: display(20, occ.ink, weight: FontWeight.w500)),
            subtitle: Text(nb.turns != null ? 'Turns ${nb.turns}' : p.group),
            trailing: Text(nb.days == 0 ? 'Today' : 'in ${plural(nb.days, 'day')}', style: TextStyle(color: occ.muted)),
            onTap: () => showPersonForm(context, occ, p),
          ),
        for (final (p, _) in unset)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(p.name, style: display(20, occ.ink, weight: FontWeight.w500)),
            subtitle: const Text('No birthday set'),
            trailing: TextButton(onPressed: () => showPersonForm(context, occ, p), child: const Text('Set date')),
          ),
      ]),
    );
  }

  Widget _garlandRow() => Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(color: occ.panel, borderRadius: BorderRadius.circular(99), border: Border.all(color: occ.line)),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          for (var i = 0; i < 7; i++) SizedBox(width: 30, height: 30, child: Art(occ.motif(i), fit: BoxFit.contain)),
        ]),
      );
}

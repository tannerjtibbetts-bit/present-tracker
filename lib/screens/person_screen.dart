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

/// One person's own window for an occasion: only their gifts, in the occasion's theme.
class PersonScreen extends StatelessWidget {
  const PersonScreen({super.key, required this.occ, required this.year, required this.personId});
  final Occ occ;
  final int year;
  final String personId;

  @override
  Widget build(BuildContext context) => Theme(
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
                  final p = store.person(personId);
                  if (p == null) return Center(child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Back')));
                  final i = store.people.indexOf(p);
                  final all = store.giftsFor(occ.key, year);
                  final gl = all.where((g) => g.personId == p.id).toList()
                    ..sort((a, b) => a.purchased.compareTo(b.purchased) != 0 ? a.purchased.compareTo(b.purchased) : a.created.compareTo(b.created));
                  final band = occ.band(i);
                  final nb = nextBirthday(p);
                  final sub = [
                    p.group,
                    if (p.note.isNotEmpty) p.note,
                    if (nb != null) 'Birthday ${mon[nb.date.month - 1]} ${nb.date.day}${nb.turns != null ? ' · turns ${nb.turns}' : ''}',
                  ].join(' · ');
                  final note = personNote(p, store.people, all);
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(14, 6, 14, 40),
                    children: [
                      if (occ.key == 'christmas') const Garland(),
                      Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.spaceBetween, children: [
                        FilledButton.icon(
                          style: altButton(occ),
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.chevron_left),
                          label: Text('Back to ${occ.label}'),
                        ),
                        Wrap(spacing: 8, children: [
                          OutlinedButton(onPressed: () => showPersonForm(context, occ, p), child: const Text('Edit details')),
                          Builder(
                            builder: (ctx) => FilledButton.icon(
                              style: altButton(occ),
                              onPressed: () => exportReport(ctx, occ, year, [p.id]),
                              icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                              label: Text("${p.name}'s PDF"),
                            ),
                          ),
                        ]),
                      ]),
                      const SizedBox(height: 12),
                      Panel(
                        occ: occ,
                        padding: EdgeInsets.zero,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          AspectRatio(aspectRatio: occ.sceneAspect, child: Art(occ.scene)),
                          BandBox(
                            band: band,
                            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                            child: Wrap(spacing: 14, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
                              Motif(asset: occ.motif(i), size: 64, ring: band.ink),
                              ConstrainedBox(
                                constraints: const BoxConstraints(minWidth: 180, maxWidth: 520),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text('${occ.label} $year'.toUpperCase(), style: bandShadow(band, TextStyle(fontSize: 11, letterSpacing: 2, color: band.ink))),
                                  Text(p.name, style: bandShadow(band, display(44, band.ink))),
                                  Text(sub, style: bandShadow(band, TextStyle(fontSize: 13, color: band.ink.withValues(alpha: .9)))),
                                ]),
                              ),
                              FilledButton.icon(
                                onPressed: () => showGiftSheet(context, occ: occ, year: year, personId: p.id),
                                icon: const Icon(Icons.add),
                                label: const Text('Add a gift'),
                              ),
                            ]),
                          ),
                          StatRow(occ: occ, items: [
                            ('Spent', money(total(gl))),
                            ('Gifts', '${gl.length}'),
                            ('To arrive', '${gl.where((g) => g.status == 'ordered').length}'),
                            ('Wrapped', '${gl.where((g) => g.status == 'wrapped').length}'),
                          ]),
                          if (note.isNotEmpty) Padding(padding: const EdgeInsets.all(16), child: Text(note, style: TextStyle(color: occ.muted, fontSize: 14))),
                        ]),
                      ),
                      const SizedBox(height: 16),
                      Panel(
                        occ: occ,
                        child: gl.isEmpty
                            ? Column(children: [
                                Motif(asset: occ.motif(0), size: 64),
                                const SizedBox(height: 10),
                                Text("Nothing on ${p.name}'s ${occ.label} list yet.", style: TextStyle(color: occ.muted)),
                                const SizedBox(height: 10),
                                FilledButton(onPressed: () => showGiftSheet(context, occ: occ, year: year, personId: p.id), child: const Text('Add the first gift')),
                              ])
                            : LayoutBuilder(builder: (context, c) {
                                final cols = c.maxWidth > 640 ? 3 : (c.maxWidth > 420 ? 2 : 1);
                                final w = (c.maxWidth - (cols - 1) * 14) / cols;
                                return Wrap(spacing: 14, runSpacing: 14, children: [for (final g in gl) SizedBox(width: w, child: _GiftCard(occ: occ, gift: g))]);
                              }),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );
}

class _GiftCard extends StatelessWidget {
  const _GiftCard({required this.occ, required this.gift});
  final Occ occ;
  final Gift gift;

  @override
  Widget build(BuildContext context) {
    final g = gift;
    final f = AppStore.instance.photoFile(g.photo);
    final rows = <(String, String)>[
      if (g.store.isNotEmpty) ('Store', g.store),
      if (g.purchased.isNotEmpty) ('Purchased', fmtDate(g.purchased)),
      if (g.orderNo.isNotEmpty) ('Order #', g.orderNo),
      if (g.event.isNotEmpty) ('Occasion', g.event),
      if (g.details.isNotEmpty) ('Details', g.details),
      if (g.notes.isNotEmpty) ('Notes', g.notes),
    ];
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => showGiftSheet(context, occ: occ, year: g.year, gift: g),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: occ.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: occ.line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Container(
              color: occ.surface2,
              child: f != null ? Image.file(f, fit: BoxFit.cover, cacheWidth: 900) : Icon(Icons.card_giftcard, size: 56, color: occ.gold),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Text(g.item.isEmpty ? 'Untitled gift' : g.item, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: occ.ink))),
                const SizedBox(width: 8),
                Text(g.price == null ? '-' : money(g.price), style: display(22, occ.gold, weight: FontWeight.w500)),
              ]),
              const SizedBox(height: 8),
              StatusChip(gift: g, occ: occ),
              const SizedBox(height: 8),
              for (final (k, v) in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SizedBox(width: 82, child: Text(k, style: TextStyle(fontSize: 13, color: occ.muted))),
                    Expanded(child: Text(v, style: TextStyle(fontSize: 13, color: occ.ink))),
                  ]),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}

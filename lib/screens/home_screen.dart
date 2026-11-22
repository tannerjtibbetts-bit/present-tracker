import 'package:flutter/material.dart';

import '../data/logic.dart';
import '../data/store.dart';
import '../ui/art.dart';
import '../ui/common.dart';
import '../ui/themes.dart';
import 'occasion_screen.dart';
import 'people_sheets.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final home = occasions['special']!;
    return Scaffold(
      body: Tiled(
        asset: 'assets/art/wall_home.svg',
        tile: 360,
        color: HomeColors.bg,
        child: SafeArea(
          child: ListenableBuilder(
            listenable: AppStore.instance,
            builder: (context, _) => ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 30, 20, 26),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: .94), borderRadius: BorderRadius.circular(26), border: Border.all(color: HomeColors.line)),
                  child: Column(children: [
                    Text('THE FAMILY GIFT LEDGER', style: TextStyle(fontSize: 11, letterSpacing: 2.6, color: HomeColors.gold, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    FittedBox(
                      child: Text.rich(TextSpan(children: [
                        TextSpan(text: 'Present ', style: display(56, HomeColors.ink, weight: FontWeight.w500)),
                        TextSpan(text: 'Tracker', style: display(56, HomeColors.gold, weight: FontWeight.w500, style: FontStyle.italic)),
                      ])),
                    ),
                    const SizedBox(height: 10),
                    Text('Choose an occasion, photograph what you ordered, and keep every list beautifully even.',
                        textAlign: TextAlign.center, style: TextStyle(color: HomeColors.muted, fontSize: 15)),
                  ]),
                ),
                const SizedBox(height: 18),
                LayoutBuilder(builder: (context, c) {
                  final wide = c.maxWidth > 700;
                  final w = wide ? (c.maxWidth - 14) / 2 : c.maxWidth;
                  return Wrap(spacing: 14, runSpacing: 14, children: [
                    for (final k in occasionOrder) SizedBox(width: w, child: _OccTile(occ: occasions[k]!)),
                  ]);
                }),
                const SizedBox(height: 22),
                Panel(
                  occ: home,
                  color: Colors.white,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [
                      Expanded(child: Text('People', style: display(28, HomeColors.ink, weight: FontWeight.w500))),
                      OutlinedButton(onPressed: () => showPeopleSheet(context, home), child: const Text('Manage people')),
                    ]),
                    const SizedBox(height: 10),
                    if (AppStore.instance.people.isEmpty)
                      Text('No one here yet. Tap Manage people to add the first person you shop for.', style: TextStyle(color: HomeColors.muted)),
                    for (final p in AppStore.instance.people)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(p.name, style: display(21, HomeColors.ink, weight: FontWeight.w500)),
                        subtitle: Text(personLine(p)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => showPersonForm(context, home, p),
                      ),
                  ]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OccTile extends StatelessWidget {
  const _OccTile({required this.occ});
  final Occ occ;

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    final y = defaultYear(occ.key);
    final list = store.giftsFor(occ.key, y);
    final band = occ.band(0);
    final ink = band.ink;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => OccasionScreen(occ: occ))),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            AspectRatio(aspectRatio: occ.sceneAspect, child: Container(color: occ.panel, child: Art(occ.scene))),
            BandBox(
              band: band,
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(occ.eyebrow, style: bandShadow(band, TextStyle(fontSize: 10, letterSpacing: 2.2, color: ink.withValues(alpha: .85)))),
                const SizedBox(height: 4),
                Text(occ.label, style: bandShadow(band, display(28, ink))),
                const SizedBox(height: 4),
                Text(occasionDateLine(occ.key, y, store.people).toUpperCase(),
                    style: bandShadow(band, TextStyle(fontSize: 11.5, letterSpacing: 1.4, color: ink, fontWeight: FontWeight.w600))),
                const SizedBox(height: 2),
                Text(list.isEmpty ? 'No gifts yet' : '${plural(list.length, 'gift')} · ${money(total(list))}${occ.key == 'birthday' || occ.key == 'special' ? ' this year' : ''}',
                    style: bandShadow(band, TextStyle(fontSize: 13, color: ink.withValues(alpha: .9)))),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

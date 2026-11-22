import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/store.dart';
import 'art.dart';
import 'themes.dart';

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2)));
}

Future<bool> confirm(BuildContext context, String title, String body, String yes) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB42318), foregroundColor: Colors.white),
          onPressed: () => Navigator.pop(c, true),
          child: Text(yes),
        ),
      ],
    ),
  );
  return r ?? false;
}

/// A rounded panel in the occasion's tint.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.occ, required this.child, this.padding = const EdgeInsets.all(18), this.color});
  final Occ occ;
  final Widget child;
  final EdgeInsets padding;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: color ?? occ.panel,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: occ.line),
          boxShadow: const [BoxShadow(color: Color(0x333C1414), blurRadius: 24, offset: Offset(0, 12), spreadRadius: -14)],
        ),
        clipBehavior: Clip.antiAlias,
        padding: padding,
        child: child,
      );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, required this.occ, this.trailing});
  final String text;
  final Occ occ;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.only(bottom: 10),
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: occ.line))),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 8,
          children: [Text(text, style: display(26, occ.ink, weight: FontWeight.w500)), ?trailing],
        ),
      );
}

/// The coloured bar with a person's name (plaid at Christmas).
class BandBox extends StatelessWidget {
  const BandBox({super.key, required this.band, required this.child, this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 14)});
  final Band band;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final inner = Padding(padding: padding, child: child);
    if (band.plaid == null) return Container(color: band.bg, child: inner);
    return Tiled(asset: band.plaid!, tile: 28, color: band.bg, child: inner);
  }
}

/// Round white badge with one of the occasion's little drawings.
class Motif extends StatelessWidget {
  const Motif({super.key, required this.asset, this.size = 44, this.ring});
  final String asset;
  final double size;
  final Color? ring;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * .1),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: (ring ?? Colors.white).withValues(alpha: .6), width: 3),
        ),
        child: Art(asset, fit: BoxFit.contain),
      );
}

TextStyle bandShadow(Band b, TextStyle s) =>
    b.plaid == null ? s : s.copyWith(shadows: const [Shadow(color: Color(0x99000000), blurRadius: 3, offset: Offset(0, 1))]);

const _statusDot = {'ordered': Color(0xFFC9902F), 'arrived': Color(0xFF3F8A63), 'wrapped': Color(0xFFB3202E)};

/// Tap to move a gift from Ordered to Arrived to Wrapped.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.gift, required this.occ});
  final Gift gift;
  final Occ occ;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: () {
          final next = statuses[(statuses.indexOf(gift.status) + 1) % statuses.length];
          AppStore.instance.setStatus(gift, next);
          toast(context, 'Marked ${statusLabels[next]!.toLowerCase()}');
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(99), border: Border.all(color: occ.line), color: occ.surface),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 7, height: 7, decoration: BoxDecoration(color: _statusDot[gift.status], shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(statusLabels[gift.status]!, style: TextStyle(fontSize: 12, color: occ.ink)),
          ]),
        ),
      );
}

/// The gift's photo, or a small present drawing when there's none.
class GiftThumb extends StatelessWidget {
  const GiftThumb({super.key, required this.gift, required this.occ, this.size = 58, this.radius = 12});
  final Gift gift;
  final Occ occ;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final f = AppStore.instance.photoFile(gift.photo);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: size,
        height: size,
        color: occ.surface2,
        child: f != null
            ? Image.file(f, fit: BoxFit.cover, cacheWidth: (size * 3).round())
            : Padding(padding: EdgeInsets.all(size * .22), child: Icon(Icons.card_giftcard, color: occ.gold, size: size * .5)),
      ),
    );
  }
}

/// Big number with a small label above it.
class Stat extends StatelessWidget {
  const Stat(this.label, this.value, {super.key, required this.occ});
  final String label;
  final String value;
  final Occ occ;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        child: Column(children: [
          Text(label.toUpperCase(), style: TextStyle(fontSize: 10.5, letterSpacing: 1.8, color: occ.muted)),
          const SizedBox(height: 4),
          FittedBox(child: Text(value, style: display(28, occ.gold, weight: FontWeight.w500))),
        ]),
      );
}

class StatRow extends StatelessWidget {
  const StatRow({super.key, required this.occ, required this.items});
  final Occ occ;
  final List<(String, String)> items;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(border: Border.symmetric(horizontal: BorderSide(color: occ.line))),
        child: IntrinsicHeight(
          child: Row(children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) VerticalDivider(width: 1, color: occ.line),
              Expanded(child: Stat(items[i].$1, items[i].$2, occ: occ)),
            ],
          ]),
        ),
      );
}

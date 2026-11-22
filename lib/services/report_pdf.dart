import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/logic.dart';
import '../data/models.dart';

/// How each occasion's report is written and decorated.
class Letter {
  const Letter({
    required this.paper, required this.a, required this.b, required this.gold, required this.ink, required this.muted,
    required this.rule, required this.tint, required this.from, required this.greet, required this.intro, required this.list,
    required this.tally, required this.close, required this.seal, this.stripe = false,
  });
  final int paper, a, b, gold, ink, muted, rule, tint;
  final String from, greet, tally, close;
  final String Function(int year) intro;
  final String Function(String name) list;
  final List<String> seal;
  final bool stripe;
}

final letters = <String, Letter>{
  'christmas': Letter(
    paper: 0xFBF3E2, a: 0xC8102E, b: 0x1E7B4A, gold: 0xC9A13B, ink: 0x3A1A14, muted: 0x7E6253, rule: 0xEBCFC4, tint: 0xF6E7D8,
    from: 'SPECIAL DELIVERY TO THE NORTH POLE WORKSHOP', greet: 'Dear Santa,',
    intro: (y) => 'Here is our Christmas list for $y. Everyone has been very good this year, and we have kept every list fair and even. Thank you for all your hard work in the workshop!',
    list: (n) => "$n's Christmas List", tally: "Santa's Tally", close: 'With love and Christmas cheer,', seal: ['NICE LIST', 'APPROVED'], stripe: true,
  ),
  'easter': Letter(
    paper: 0xFFFBEA, a: 0xE0A21B, b: 0x6BA8D6, gold: 0xE59BB5, ink: 0x3B3355, muted: 0x7A7393, rule: 0xF1E2B0, tint: 0xFFF3C9,
    from: 'BY SPECIAL BUNNY POST TO THE EASTER MEADOW', greet: 'Dear Easter Bunny,',
    intro: (y) => 'Here is our Easter basket list for $y. Please hop by with these treats, and do not forget a few extra eggs for the hunt!',
    list: (n) => "$n's Easter Basket", tally: "The Bunny's Tally", close: 'Hoppy Easter, with love,', seal: ['BASKET', 'READY'],
  ),
  'valentines': Letter(
    paper: 0xFFF6F8, a: 0xD7263D, b: 0xF28AA8, gold: 0xE7B3C0, ink: 0x4A0F22, muted: 0x97596B, rule: 0xF6D0DA, tint: 0xFFE6EC,
    from: 'SEALED WITH A KISS AND SENT TO CUPID', greet: 'Dear Cupid,',
    intro: (y) => "Here are the gifts of love we have gathered for Valentine's Day $y. Please send a few of your arrows along with them.",
    list: (n) => 'For $n, With Love', tally: "Cupid's Tally", close: 'With all our love,', seal: ['SEALED', 'WITH LOVE'],
  ),
  'birthday': Letter(
    paper: 0xFFFFFF, a: 0xFF4F86, b: 0x2EC4B6, gold: 0xFFC145, ink: 0x1F2340, muted: 0x646A91, rule: 0xE2E8F7, tint: 0xF1F5FF,
    from: 'THE OFFICIAL BIRTHDAY PARTY PLANNER', greet: 'The Birthday Wish List',
    intro: (y) => 'Every present picked for the $y birthdays, so each celebration is as special as the next.',
    list: (n) => "$n's Birthday Wishes", tally: 'Party Tally', close: "Let's celebrate,", seal: ['PARTY', 'TIME'],
  ),
  'special': Letter(
    paper: 0xFDFCFF, a: 0x3B3486, b: 0xB8903A, gold: 0xD9C08A, ink: 0x1F1D3A, muted: 0x6B688C, rule: 0xE4E0F3, tint: 0xF2F0FA,
    from: "A RECORD OF LIFE'S BIG MOMENTS", greet: 'Gifts for Special Occasions',
    intro: (y) => 'A record of the gifts chosen for the milestones of $y: graduations, showers, anniversaries and every moment worth marking.',
    list: (n) => 'For $n', tally: 'The Tally', close: 'With warmest wishes,', seal: ['WITH', 'LOVE'],
  ),
};

PdfColor _c(int rgb) => PdfColor.fromInt(0xFF000000 | rgb);

/// The standard PDF fonts only cover Western European letters; anything else is swapped for a close match.
String clean(String s) {
  const map = {'’': "'", '‘': "'", '“': '"', '”': '"', '–': '-', '—': '-', '…': '...', '•': '·', ' ': ' '};
  final b = StringBuffer();
  for (final r in s.runes) {
    final ch = String.fromCharCode(r);
    if (map.containsKey(ch)) {
      b.write(map[ch]);
    } else if (r < 256) {
      b.write(ch);
    } else {
      b.write('?');
    }
  }
  return b.toString();
}

/// Builds the occasion's letter as a PDF. [photos] holds small JPEG/PNG thumbnails by gift id;
/// [ornament] and [corner] are SVG drawings for the letterhead and the page corners.
Future<Uint8List> buildReport({
  required String occasion,
  required String label,
  required int year,
  required List<Person> people,
  required List<Gift> gifts,
  Map<String, Uint8List> photos = const {},
  String? ornament,
  String? corner,
  DateTime? now,
}) async {
  final lt = letters[occasion]!;
  final ids = people.map((p) => p.id).toSet();
  final list = gifts.where((g) => g.occasion == occasion && g.year == year && ids.contains(g.personId)).toList();
  final date = now ?? DateTime.now();

  final times = pw.Font.times(), timesI = pw.Font.timesItalic(), timesB = pw.Font.timesBold(), timesBI = pw.Font.timesBoldItalic();
  final helv = pw.Font.helvetica(), helvB = pw.Font.helveticaBold();
  pw.TextStyle ts(pw.Font f, double size, int color, {double spacing = 0}) =>
      pw.TextStyle(font: f, fontSize: size, color: _c(color), letterSpacing: spacing);

  final doc = pw.Document(title: clean('$label $year - Present Tracker'), author: 'Present Tracker');

  pw.Widget background(pw.Context ctx) => pw.FullPage(
        ignoreMargins: true,
        child: pw.Stack(children: [
          pw.Positioned(
            left: 0,
            top: 0,
            right: 0,
            bottom: 0,
            child: pw.CustomPaint(painter: (canvas, size) {
              final w = size.x, h = size.y;
              canvas
                ..setFillColor(_c(lt.paper))
                ..drawRect(0, 0, w, h)
                ..fillPath();
              if (lt.stripe) {
                canvas
                  ..setStrokeColor(PdfColors.white)
                  ..setLineWidth(7)
                  ..drawRect(18, 18, w - 36, h - 36)
                  ..strokePath()
                  ..setLineDashPattern([9, 9])
                  ..setStrokeColor(_c(lt.a))
                  ..drawRect(18, 18, w - 36, h - 36)
                  ..strokePath()
                  ..setLineDashPattern();
              } else {
                canvas
                  ..setStrokeColor(_c(lt.a))
                  ..setLineWidth(5)
                  ..drawRect(18, 18, w - 36, h - 36)
                  ..strokePath();
              }
              canvas
                ..setStrokeColor(_c(lt.b))
                ..setLineWidth(1.4)
                ..drawRect(28, 28, w - 56, h - 56)
                ..strokePath()
                ..setStrokeColor(_c(lt.gold))
                ..setLineWidth(.6)
                ..drawRect(32, 32, w - 64, h - 64)
                ..strokePath();
            }),
          ),
          if (corner != null)
            for (final (l, t) in [(true, true), (false, true), (true, false), (false, false)])
              pw.Positioned(
                left: l ? 30 : null,
                right: l ? null : 30,
                top: t ? 30 : null,
                bottom: t ? null : 30,
                child: pw.SizedBox(width: 30, height: 30, child: pw.SvgImage(svg: corner)),
              ),
        ]),
      );

  pw.Widget checkbox(bool ticked) => pw.Container(
        width: 12,
        height: 12,
        decoration: pw.BoxDecoration(color: PdfColors.white, border: pw.Border.all(color: _c(lt.b), width: 1.1)),
        child: ticked
            ? pw.CustomPaint(painter: (canvas, size) {
                canvas
                  ..setStrokeColor(_c(lt.a))
                  ..setLineWidth(2)
                  ..moveTo(2.5, 6)
                  ..lineTo(5.5, 2.5)
                  ..lineTo(11, 11)
                  ..strokePath();
              })
            : null,
      );

  pw.Widget giftRow(Gift g) {
    final img = photos[g.id];
    final meta = [g.event, g.store, statusLabels[g.status] ?? '', if (g.purchased.isNotEmpty) 'Bought ${fmtDate(g.purchased)}', if (g.orderNo.isNotEmpty) 'Order ${g.orderNo}']
        .where((s) => s.isNotEmpty)
        .join('  ·  ');
    final extra = [g.details, g.notes].where((s) => s.isNotEmpty).join('  ·  ');
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 6),
      decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _c(lt.rule), width: .7))),
      child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
        checkbox(g.status == 'wrapped'),
        pw.SizedBox(width: 10),
        pw.Container(
          width: 38,
          height: 38,
          decoration: pw.BoxDecoration(color: _c(lt.tint), border: img == null ? null : pw.Border.all(color: _c(lt.gold), width: .8)),
          child: img == null
              ? pw.Center(child: pw.Text('No photo', style: ts(helv, 5.5, lt.muted)))
              : pw.Image(pw.MemoryImage(img), fit: pw.BoxFit.cover),
        ),
        pw.SizedBox(width: 12),
        pw.Expanded(
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(clean(g.item.isEmpty ? 'A surprise' : g.item), style: ts(times, 13.5, lt.ink), maxLines: 2),
            if (meta.isNotEmpty) pw.Text(clean(meta), style: ts(timesI, 10, lt.muted), maxLines: 2),
            if (extra.isNotEmpty) pw.Text(clean(extra), style: ts(timesI, 10, lt.muted), maxLines: 2),
          ]),
        ),
        pw.SizedBox(width: 10),
        pw.Text(g.price == null ? '-' : money(g.price), style: ts(times, 13.5, lt.ink)),
      ]),
    );
  }

  final content = <pw.Widget>[
    pw.Center(child: pw.Text(clean(lt.from), style: ts(helv, 7.5, lt.b, spacing: 2.2))),
    pw.SizedBox(height: 10),
    if (ornament != null) pw.Center(child: pw.SizedBox(width: 56, height: 56, child: pw.SvgImage(svg: ornament))),
    pw.SizedBox(height: 10),
    pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
      pw.Expanded(child: pw.Text(clean(lt.greet), style: ts(timesBI, 32, lt.a))),
      pw.Text('${mon[date.month - 1]} ${date.day}, ${date.year}', style: ts(timesI, 11, lt.muted)),
    ]),
    pw.SizedBox(height: 8),
    pw.Text(clean(lt.intro(year)), style: ts(timesI, 13, lt.ink).copyWith(lineSpacing: 4)),
    pw.SizedBox(height: 18),
  ];

  for (final p in people) {
    final gl = list.where((g) => g.personId == p.id).toList()
      ..sort((a, b) => a.purchased.compareTo(b.purchased) != 0 ? a.purchased.compareTo(b.purchased) : a.created.compareTo(b.created));
    content.add(pw.Container(
      margin: const pw.EdgeInsets.only(top: 14, bottom: 4),
      padding: const pw.EdgeInsets.only(bottom: 5),
      decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _c(lt.gold), width: 1.4))),
      child: pw.Row(children: [
        pw.Expanded(child: pw.Text(clean(lt.list(p.name)), style: ts(timesBI, 20, lt.b))),
        pw.Text(money(total(gl)), style: ts(timesB, 16, lt.a)),
      ]),
    ));
    if (gl.isEmpty) {
      content.add(pw.Padding(padding: const pw.EdgeInsets.fromLTRB(18, 10, 0, 14), child: pw.Text('Nothing on the list yet.', style: ts(timesI, 12, lt.muted))));
    } else {
      content.addAll(gl.map(giftRow));
    }
  }

  // Tally, sign-off and seal
  final rows = [for (final p in people) (p, list.where((g) => g.personId == p.id).length, total(list.where((g) => g.personId == p.id)))];
  final notes = <String>[];
  for (final grp in groups) {
    final rs = rows.where((r) => r.$1.group == grp).toList();
    if (rs.length < 2) continue;
    final mx = rs.map((r) => r.$3).reduce((a, b) => a > b ? a : b), mn = rs.map((r) => r.$3).reduce((a, b) => a < b ? a : b);
    notes.add(mx == 0 ? '$grp: nothing bought yet.' : mx - mn < .005 ? '$grp: perfectly even at ${money(mx)} each.' : '$grp: ${money(mx - mn)} between highest and lowest.');
    final nx = rs.map((r) => r.$2).reduce((a, b) => a > b ? a : b), nn = rs.map((r) => r.$2).reduce((a, b) => a < b ? a : b);
    if (nx > 0) notes.add(nx == nn ? '$grp: ${plural(nx, 'gift')} each.' : '$grp: ${plural(nx - nn, 'gift')} between most and fewest.');
  }
  content.add(pw.SizedBox(height: 26));
  content.add(pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
    pw.Container(
      width: 262,
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(color: _c(lt.tint), border: pw.Border.all(color: _c(lt.gold), width: .8)),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(clean(lt.tally), style: ts(timesBI, 16, lt.a)),
        pw.SizedBox(height: 10),
        for (final r in rows)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 6),
            child: pw.Row(children: [
              pw.Expanded(child: pw.Text(clean(r.$1.name), style: ts(times, 12, lt.ink))),
              pw.Text(plural(r.$2, 'gift'), style: ts(timesI, 10, lt.muted)),
              pw.SizedBox(width: 12),
              pw.Text(money(r.$3), style: ts(times, 12, lt.ink)),
            ]),
          ),
        pw.Divider(color: _c(lt.gold), thickness: .8),
        pw.Row(children: [
          pw.Expanded(child: pw.Text('Total', style: ts(timesBI, 13, lt.ink))),
          pw.Text(money(total(list)), style: ts(timesBI, 13, lt.a)),
        ]),
        if (notes.isNotEmpty) pw.SizedBox(height: 8),
        for (final n in notes) pw.Text(clean(n), style: ts(timesI, 9.5, lt.muted)),
      ]),
    ),
    pw.SizedBox(width: 36),
    pw.Expanded(
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.SizedBox(height: 10),
        pw.Text(clean(lt.close), style: ts(timesI, 14, lt.ink)),
        pw.SizedBox(height: 36),
        pw.Divider(color: _c(lt.ink), thickness: .6),
        pw.Text('SIGNED', style: ts(helv, 7, lt.muted, spacing: 1.5)),
        pw.SizedBox(height: 18),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Container(
            width: 74,
            height: 74,
            decoration: pw.BoxDecoration(color: _c(lt.a), shape: pw.BoxShape.circle, border: pw.Border.all(color: PdfColors.white, width: 1.2)),
            child: pw.Center(
              child: pw.Column(mainAxisSize: pw.MainAxisSize.min, children: [
                pw.Text('*', style: ts(helvB, 12, lt.gold)),
                pw.Text(lt.seal[0], style: ts(helvB, 7.5, 0xFFFFFF, spacing: 1.2)),
                pw.Text(lt.seal[1], style: ts(helvB, 7.5, 0xFFFFFF, spacing: 1.2)),
              ]),
            ),
          ),
        ),
      ]),
    ),
  ]));

  doc.addPage(pw.MultiPage(
    pageTheme: pw.PageTheme(
      pageFormat: PdfPageFormat.letter,
      margin: const pw.EdgeInsets.fromLTRB(64, 62, 64, 80),
      buildBackground: background,
    ),
    footer: (ctx) => pw.Center(
      child: pw.Text(clean('$label $year  ·  Page ${ctx.pageNumber} of ${ctx.pagesCount}  ·  Present Tracker'), style: ts(timesI, 9, lt.muted)),
    ),
    build: (ctx) => content,
  ));
  return doc.save();
}

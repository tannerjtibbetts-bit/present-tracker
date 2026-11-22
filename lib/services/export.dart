import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/store.dart';
import '../ui/common.dart';
import '../ui/themes.dart';
import 'report_pdf.dart';

/// A small copy of a photo for the PDF, so the file stays light.
Future<Uint8List?> _thumb(File f) async {
  try {
    final codec = await ui.instantiateImageCodec(await f.readAsBytes(), targetWidth: 180);
    final frame = await codec.getNextFrame();
    final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    frame.image.dispose();
    return data?.buffer.asUint8List();
  } catch (_) {
    return null;
  }
}

/// Makes the letter PDF for the chosen people and opens the share sheet (Save to Files, Mail, Print...).
Future<void> exportReport(BuildContext context, Occ occ, int year, List<String> personIds) async {
  final store = AppStore.instance;
  final people = store.people.where((x) => personIds.contains(x.id)).toList();
  final gifts = store.giftsFor(occ.key, year).where((g) => personIds.contains(g.personId)).toList();
  final box = context.findRenderObject() as RenderBox?;
  final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(const SnackBar(content: Text('Preparing PDF…'), behavior: SnackBarBehavior.floating));
  try {
    final photos = <String, Uint8List>{};
    for (final g in gifts) {
      final f = store.photoFile(g.photo);
      if (f == null) continue;
      final t = await _thumb(f);
      if (t != null) photos[g.id] = t;
    }
    String? ornament, corner;
    try {
      ornament = await rootBundle.loadString(occ.motif(0));
      corner = await rootBundle.loadString(occ.motif(1));
    } catch (_) {}
    final bytes = await buildReport(
      occasion: occ.key,
      label: occ.label,
      year: year,
      people: people,
      gifts: gifts,
      photos: photos,
      ornament: ornament,
      corner: corner,
    );
    final who = people.length == 1 ? '-${people.first.name}' : people.length < store.people.length ? '-Selected' : '';
    final name = '${occ.label}-$year$who-Gifts.pdf'.replaceAll(RegExp(r"[^A-Za-z0-9.-]+"), '-');
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, name));
    await file.writeAsBytes(bytes);
    messenger.hideCurrentSnackBar();
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: 'application/pdf', name: name)],
      subject: '${occ.label} $year gift list',
      title: name,
      sharePositionOrigin: origin,
    ));
  } catch (e) {
    messenger.hideCurrentSnackBar();
    if (context.mounted) toast(context, "Couldn't make the PDF. $e");
  }
}

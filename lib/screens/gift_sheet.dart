import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/logic.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../services/ocr.dart';
import '../services/photo_prep.dart';
import '../ui/common.dart';
import '../ui/themes.dart';
import 'people_sheets.dart';

/// Opens the add / edit gift form. [gift] null means a new gift.
Future<void> showGiftSheet(BuildContext context, {required Occ occ, required int year, Gift? gift, String? personId}) async {
  final store = AppStore.instance;
  if (store.people.isEmpty) {
    toast(context, 'Add a person first');
    await showPeopleSheet(context, occ);
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: occ.bg,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (_) => Theme(data: occTheme(occ), child: GiftForm(occ: occ, year: year, gift: gift, personId: personId)),
  );
}

class GiftForm extends StatefulWidget {
  const GiftForm({super.key, required this.occ, required this.year, this.gift, this.personId});
  final Occ occ;
  final int year;
  final Gift? gift;
  final String? personId;

  @override
  State<GiftForm> createState() => _GiftFormState();
}

class _GiftFormState extends State<GiftForm> {
  final store = AppStore.instance;
  late final Gift g;
  late final bool editing;
  final item = TextEditingController(), price = TextEditingController(), shop = TextEditingController();
  final orderNo = TextEditingController(), details = TextEditingController(), notes = TextEditingController(), event = TextEditingController();
  String? newPhotoPath;
  String readStatus = '';
  bool readOk = false, busy = false;
  String? error;

  Occ get occ => widget.occ;

  @override
  void initState() {
    super.initState();
    editing = widget.gift != null;
    g = widget.gift?.copy() ??
        Gift(
          id: store.newId(),
          occasion: occ.key,
          year: widget.year,
          personId: widget.personId ?? store.people.first.id,
          purchased: isoDate(DateTime.now()),
          created: DateTime.now().millisecondsSinceEpoch,
        );
    item.text = g.item;
    price.text = g.price == null ? '' : g.price!.toStringAsFixed(2);
    shop.text = g.store;
    orderNo.text = g.orderNo;
    details.text = g.details;
    notes.text = g.notes;
    event.text = g.event;
    readStatus = "Take or choose a photo. I'll read any price tag, box or order screen in it.";
  }

  @override
  void dispose() {
    for (final c in [item, price, shop, orderNo, details, notes, event]) {
      c.dispose();
    }
    super.dispose();
  }

  PhotoRead? lastRead;

  /// [scanOnly]: read a tag, receipt or order screen without replacing the gift's photo
  /// (unless the gift has no photo yet).
  Future<void> pick(ImageSource src, {bool scanOnly = false}) async {
    XFile? x;
    try {
      x = await ImagePicker().pickImage(source: src, requestFullMetadata: true);
    } catch (_) {
      if (mounted) {
        setState(() => readStatus = src == ImageSource.camera
            ? "Couldn't open the camera. Check Present Tracker is allowed to use it in Settings."
            : "Couldn't open your photos. Check Present Tracker is allowed to see them in Settings.");
      }
      return;
    }
    if (x == null || !mounted) return;
    setState(() {
      readStatus = 'Reading the photo…';
      readOk = false;
      lastRead = null;
    });
    final upright = await prepareFile(x.path);
    if (!mounted) return;
    if (!scanOnly || (newPhotoPath == null && g.photo.isEmpty)) setState(() => newPhotoPath = upright);
    try {
      final read = await readPhoto(upright, turned: (path, turn) => prepareFile(path, maxSide: 2400, turn: turn, suffix: 't$turn'));
      if (!mounted) return;
      final info = read.info;
      setState(() {
        lastRead = read;
        if (info.item != null && item.text.trim().isEmpty) item.text = info.item!;
        if (info.price != null && price.text.trim().isEmpty) price.text = info.price!.toStringAsFixed(2);
        if (info.store != null && shop.text.trim().isEmpty) shop.text = info.store!;
        if (info.orderDate != null) g.purchased = info.orderDate!;
        if (info.orderNumber != null && orderNo.text.trim().isEmpty) orderNo.text = info.orderNumber!;
        if (info.details != null && details.text.trim().isEmpty) details.text = info.details!;
        if (read.lines.isEmpty && read.prices.isEmpty) {
          readStatus = 'No writing found in this photo. To fill in the name and price, use Scan tag or receipt on the price tag, box, receipt or order screen.';
        } else if (info.price != null) {
          readOk = true;
          readStatus = 'Found ${money(info.price)}. Check the details below, or tap a line it read to use it instead.';
        } else {
          readStatus = "Couldn't spot a price. Tap one it read below, or type it in.";
        }
      });
    } catch (e) {
      if (mounted) setState(() => readStatus = "Couldn't read this photo. Type the details below. ($e)");
    }
  }

  Widget foundText() {
    final r = lastRead;
    if (r == null || (r.lines.isEmpty && r.prices.isEmpty)) return const SizedBox.shrink();
    Widget chip(String text, VoidCallback onTap, {bool strong = false}) => ActionChip(
          label: Text(text, overflow: TextOverflow.ellipsis),
          onPressed: onTap,
          backgroundColor: strong ? occ.accent2 : occ.surface,
          labelStyle: TextStyle(color: strong ? occ.accent2Ink : occ.ink, fontSize: 13),
          side: BorderSide(color: occ.line),
        );
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: occ.panel, borderRadius: BorderRadius.circular(14), border: Border.all(color: occ.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('TEXT FOUND IN THE PHOTO', style: TextStyle(fontSize: 11, letterSpacing: 1.6, color: occ.muted, fontWeight: FontWeight.w600)),
        if (r.prices.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Tap a price to use it:', style: TextStyle(fontSize: 12.5, color: occ.muted)),
          const SizedBox(height: 4),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final v in r.prices) chip(money(v), () => setState(() => price.text = v.toStringAsFixed(2)), strong: true),
          ]),
        ],
        if (r.lines.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('Tap a line to use it as the name:', style: TextStyle(fontSize: 12.5, color: occ.muted)),
          const SizedBox(height: 4),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final l in r.lines.take(24)) chip(l, () => setState(() => item.text = l)),
          ]),
        ],
      ]),
    );
  }

  Future<void> save() async {
    final raw = price.text.replaceAll(RegExp(r'[\$,\s]'), '');
    final p = raw.isEmpty ? null : double.tryParse(raw);
    if (item.text.trim().isEmpty && newPhotoPath == null && g.photo.isEmpty) {
      setState(() => error = 'Add an item name or a photo.');
      return;
    }
    if (raw.isNotEmpty && (p == null || p < 0)) {
      setState(() => error = 'Enter the price as a number, like 24.99.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (newPhotoPath != null) g.photo = await store.keepPhoto(newPhotoPath!);
      g
        ..item = item.text.trim()
        ..price = p == null ? null : (p * 100).round() / 100
        ..store = shop.text.trim()
        ..orderNo = orderNo.text.trim()
        ..details = details.text.trim()
        ..notes = notes.text.trim()
        ..event = event.text.trim();
      await store.saveGift(g);
      if (!mounted) return;
      final who = store.person(g.personId)?.name ?? '';
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(SnackBar(content: Text(editing ? 'Gift updated' : "Added to $who's list"), behavior: SnackBarBehavior.floating));
    } catch (e) {
      setState(() {
        busy = false;
        error = "Couldn't save the gift. $e";
      });
    }
  }

  Future<void> delete() async {
    final ok = await confirm(context, 'Delete this gift?', 'Delete "${g.item.isEmpty ? 'this gift' : g.item}" and its photo? This can\'t be undone.', 'Delete gift');
    if (!ok || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    await store.deleteGift(widget.gift!);
    if (!mounted) return;
    Navigator.pop(context);
    messenger.showSnackBar(const SnackBar(content: Text('Gift deleted'), behavior: SnackBarBehavior.floating));
  }

  Future<void> pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: parseIso(g.purchased) ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 2),
    );
    if (d != null) setState(() => g.purchased = isoDate(d));
  }

  Widget label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6, top: 14),
        child: Text(t.toUpperCase(), style: TextStyle(fontSize: 11, letterSpacing: 1.6, color: occ.muted, fontWeight: FontWeight.w600)),
      );

  @override
  Widget build(BuildContext context) {
    final existing = store.photoFile(g.photo);
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${occ.label} ${g.year}'.toUpperCase(), style: TextStyle(fontSize: 11, letterSpacing: 2, color: occ.gold, fontWeight: FontWeight.w700)),
                Text(editing ? 'Edit gift' : 'Add a gift', style: display(30, occ.ink)),
              ]),
            ),
            IconButton.outlined(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close), tooltip: 'Close'),
          ]),
          const SizedBox(height: 14),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 112,
                height: 112,
                color: occ.surface,
                child: newPhotoPath != null
                    ? Image.file(File(newPhotoPath!), fit: BoxFit.cover)
                    : existing != null
                        ? Image.file(existing, fit: BoxFit.cover)
                        : Icon(Icons.photo_camera_outlined, color: occ.gold, size: 40),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                FilledButton.icon(onPressed: () => pick(ImageSource.camera), icon: const Icon(Icons.photo_camera), label: const Text('Take photo')),
                const SizedBox(height: 8),
                OutlinedButton.icon(onPressed: () => pick(ImageSource.gallery), icon: const Icon(Icons.photo_library_outlined), label: const Text('Choose from library')),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => pick(ImageSource.camera, scanOnly: true),
                  icon: const Icon(Icons.document_scanner_outlined),
                  label: const Text('Scan tag or receipt'),
                ),
                const SizedBox(height: 6),
                Text(readStatus, style: TextStyle(fontSize: 12.5, color: readOk ? const Color(0xFF2F7A52) : occ.muted)),
              ]),
            ),
          ]),
          foundText(),
          label('For'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final p in store.people)
              ChoiceChip(
                label: Text(p.name),
                selected: g.personId == p.id,
                showCheckmark: false,
                labelStyle: TextStyle(color: g.personId == p.id ? occ.accentInk : occ.ink),
                onSelected: (_) => setState(() => g.personId = p.id),
              ),
          ]),
          label('Item'),
          TextField(controller: item, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(hintText: 'e.g. Wooden dollhouse')),
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                label('Price (CAD)'),
                TextField(controller: price, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(hintText: '0.00', prefixText: r'$ ')),
              ]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                label('Store'),
                TextField(controller: shop, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(hintText: 'e.g. Indigo')),
              ]),
            ),
          ]),
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                label('Date purchased'),
                OutlinedButton.icon(
                  onPressed: pickDate,
                  icon: const Icon(Icons.event_outlined, size: 18),
                  label: Text(g.purchased.isEmpty ? 'Pick a date' : fmtDate(g.purchased)),
                ),
              ]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                label('Order number'),
                TextField(controller: orderNo, decoration: const InputDecoration(hintText: 'Optional')),
              ]),
            ),
          ]),
          label('Details'),
          TextField(controller: details, decoration: const InputDecoration(hintText: 'Size, colour, delivery date…')),
          if (occ.key == 'special') ...[
            label('Occasion'),
            TextField(controller: event, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(hintText: 'e.g. Graduation, First Communion')),
          ],
          label('Status'),
          Wrap(spacing: 8, children: [
            for (final s in statuses)
              ChoiceChip(
                label: Text(statusLabels[s]!),
                selected: g.status == s,
                showCheckmark: false,
                labelStyle: TextStyle(color: g.status == s ? occ.accentInk : occ.ink),
                onSelected: (_) => setState(() => g.status = s),
              ),
          ]),
          label('Notes'),
          TextField(controller: notes, minLines: 2, maxLines: 4, decoration: const InputDecoration(hintText: "Where it's hidden, gift receipt…")),
          if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: const TextStyle(color: Color(0xFFB42318)))),
          const SizedBox(height: 18),
          Row(children: [
            if (editing) TextButton(onPressed: busy ? null : delete, child: const Text('Delete', style: TextStyle(color: Color(0xFFB42318)))),
            const Spacer(),
            OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            const SizedBox(width: 10),
            FilledButton(onPressed: busy ? null : save, child: Text(busy ? 'Saving…' : editing ? 'Save changes' : 'Save gift')),
          ]),
        ]),
      ),
    );
  }
}

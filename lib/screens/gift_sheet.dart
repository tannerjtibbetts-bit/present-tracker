import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/logic.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../services/ocr.dart';
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
    readStatus = "Take or choose a photo and I'll read the item and price.";
  }

  @override
  void dispose() {
    for (final c in [item, price, shop, orderNo, details, notes, event]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> pick(ImageSource src) async {
    XFile? x;
    try {
      x = await ImagePicker().pickImage(source: src, maxWidth: 1800, maxHeight: 1800, imageQuality: 85, requestFullMetadata: false);
    } catch (_) {
      if (mounted) setState(() => readStatus = src == ImageSource.camera ? "Couldn't open the camera. Check Present Tracker is allowed to use it in Settings." : "Couldn't open your photos.");
      return;
    }
    if (x == null || !mounted) return;
    final path = x.path;
    setState(() {
      newPhotoPath = path;
      readStatus = 'Reading the item and price…';
      readOk = false;
    });
    try {
      final info = await readPhoto(path);
      if (!mounted) return;
      setState(() {
        if (info.item != null && item.text.trim().isEmpty) item.text = info.item!;
        if (info.price != null && price.text.trim().isEmpty) price.text = info.price!.toStringAsFixed(2);
        if (info.store != null && shop.text.trim().isEmpty) shop.text = info.store!;
        if (info.orderDate != null) g.purchased = info.orderDate!;
        if (info.orderNumber != null && orderNo.text.trim().isEmpty) orderNo.text = info.orderNumber!;
        if (info.details != null && details.text.trim().isEmpty) details.text = info.details!;
        if (info.price != null) {
          readOk = true;
          readStatus = 'Found ${money(info.price)}. Check the details below.';
        } else {
          readStatus = info.isEmpty ? "Couldn't read this photo. Type the details below." : "Couldn't spot a price. Type it in below.";
        }
      });
    } catch (_) {
      if (mounted) setState(() => readStatus = "Couldn't read this photo. Type the details below.");
    }
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
                const SizedBox(height: 6),
                Text(readStatus, style: TextStyle(fontSize: 12.5, color: readOk ? const Color(0xFF2F7A52) : occ.muted)),
              ]),
            ),
          ]),
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

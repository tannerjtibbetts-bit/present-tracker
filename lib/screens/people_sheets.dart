import 'package:flutter/material.dart';

import '../data/logic.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../ui/common.dart';
import '../ui/themes.dart';

Future<T?> _sheet<T>(BuildContext context, Occ occ, Widget child) => showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: occ.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => Theme(data: occTheme(occ), child: child),
    );

Widget _head(BuildContext context, Occ occ, String eyebrow, String title) => Row(children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(eyebrow.toUpperCase(), style: TextStyle(fontSize: 11, letterSpacing: 2, color: occ.gold, fontWeight: FontWeight.w700)),
          Text(title, style: display(30, occ.ink)),
        ]),
      ),
      IconButton.outlined(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close), tooltip: 'Close'),
    ]);

String personLine(Person p) {
  final nb = nextBirthday(p);
  return [
    p.group,
    nb == null ? 'No birthday set' : 'Birthday ${mon[nb.date.month - 1]} ${nb.date.day}',
    if (p.note.isNotEmpty) p.note,
  ].join(' · ');
}

/// The list of everyone you buy for, with Add and Edit.
Future<void> showPeopleSheet(BuildContext context, Occ occ) => _sheet<void>(context, occ, _PeopleList(occ: occ));

class _PeopleList extends StatelessWidget {
  const _PeopleList({required this.occ});
  final Occ occ;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: AppStore.instance,
        builder: (context, _) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _head(context, occ, 'Your list', 'People'),
            const SizedBox(height: 8),
            Text('Everyone you buy for: your children, family, friends, teachers. Groups keep the fairness check comparing like with like.',
                style: TextStyle(color: occ.muted)),
            const SizedBox(height: 8),
            for (final p in AppStore.instance.people)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(border: Border(top: BorderSide(color: occ.line))),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p.name, style: display(22, occ.ink, weight: FontWeight.w500)),
                      Text(personLine(p), style: TextStyle(fontSize: 12.5, color: occ.muted)),
                    ]),
                  ),
                  OutlinedButton(onPressed: () => showPersonForm(context, occ, p), child: const Text('Edit')),
                ]),
              ),
            if (AppStore.instance.people.isEmpty) Padding(padding: const EdgeInsets.all(12), child: Text('No one yet.', style: TextStyle(color: occ.muted))),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(onPressed: () => showPersonForm(context, occ, null), icon: const Icon(Icons.person_add_alt_1), label: const Text('Add a person')),
            ),
          ]),
        ),
      );
}

/// Add or edit one person.
Future<void> showPersonForm(BuildContext context, Occ occ, Person? p) => _sheet<void>(context, occ, _PersonForm(occ: occ, person: p));

class _PersonForm extends StatefulWidget {
  const _PersonForm({required this.occ, this.person});
  final Occ occ;
  final Person? person;

  @override
  State<_PersonForm> createState() => _PersonFormState();
}

class _PersonFormState extends State<_PersonForm> {
  final name = TextEditingController(), note = TextEditingController();
  String group = 'Kids', birthday = '';
  String? error;

  Occ get occ => widget.occ;

  @override
  void initState() {
    super.initState();
    final p = widget.person;
    if (p != null) {
      name.text = p.name;
      note.text = p.note;
      group = p.group;
      birthday = p.birthday;
    }
  }

  @override
  void dispose() {
    name.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> pickBirthday() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: parseIso(birthday) ?? DateTime(now.year - 8, now.month, now.day),
      firstDate: DateTime(1920),
      lastDate: now,
      helpText: 'Birthday',
    );
    if (d != null) setState(() => birthday = isoDate(d));
  }

  Future<void> save() async {
    final n = name.text.trim();
    if (n.isEmpty) {
      setState(() => error = 'Enter a name.');
      return;
    }
    final store = AppStore.instance;
    final p = widget.person;
    await store.savePerson(Person(
      id: p?.id ?? store.newId(),
      name: n,
      group: group,
      birthday: birthday,
      note: note.text.trim(),
      created: p?.created ?? DateTime.now().millisecondsSinceEpoch,
    ));
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(SnackBar(content: Text(p == null ? '$n added' : 'Saved'), behavior: SnackBarBehavior.floating));
  }

  Future<void> remove() async {
    final p = widget.person!;
    final n = AppStore.instance.gifts.where((g) => g.personId == p.id).length;
    final ok = await confirm(context, 'Remove ${p.name}?',
        'Remove ${p.name}${n > 0 ? ' and ${plural(n, 'gift')} across all occasions' : ''}? This can\'t be undone.', 'Remove');
    if (!ok || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    await AppStore.instance.deletePerson(p.id);
    if (!mounted) return;
    Navigator.pop(context);
    messenger.showSnackBar(SnackBar(content: Text('${p.name} removed'), behavior: SnackBarBehavior.floating));
  }

  Widget label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6, top: 14),
        child: Text(t.toUpperCase(), style: TextStyle(fontSize: 11, letterSpacing: 1.6, color: occ.muted, fontWeight: FontWeight.w600)),
      );

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _head(context, occ, 'People', widget.person?.name ?? 'Add a person'),
            label('Name'),
            TextField(controller: name, autofocus: widget.person == null, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(hintText: 'e.g. Grandma Ruth')),
            label('Group'),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final g in groups)
                ChoiceChip(
                  label: Text(g),
                  selected: group == g,
                  showCheckmark: false,
                  labelStyle: TextStyle(color: group == g ? occ.accentInk : occ.ink),
                  onSelected: (_) => setState(() => group = g),
                ),
            ]),
            label('Birthday'),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: pickBirthday,
                  icon: const Icon(Icons.cake_outlined, size: 18),
                  label: Text(birthday.isEmpty ? 'Set birthday' : fmtDate(birthday)),
                ),
              ),
              if (birthday.isNotEmpty) TextButton(onPressed: () => setState(() => birthday = ''), child: const Text('Clear')),
            ]),
            label('Note'),
            TextField(controller: note, decoration: const InputDecoration(hintText: 'e.g. Daughter, size 6')),
            if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: const TextStyle(color: Color(0xFFB42318)))),
            const SizedBox(height: 18),
            Row(children: [
              if (widget.person != null) TextButton(onPressed: remove, child: const Text('Remove', style: TextStyle(color: Color(0xFFB42318)))),
              const Spacer(),
              OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              const SizedBox(width: 10),
              FilledButton(onPressed: save, child: Text(widget.person == null ? 'Add person' : 'Save')),
            ]),
          ]),
        ),
      );
}

/// "Who's on the report?" Returns the chosen people's ids, or null if cancelled.
Future<List<String>?> showReportPicker(BuildContext context, Occ occ, int year) =>
    _sheet<List<String>>(context, occ, _ReportPicker(occ: occ, year: year));

class _ReportPicker extends StatefulWidget {
  const _ReportPicker({required this.occ, required this.year});
  final Occ occ;
  final int year;

  @override
  State<_ReportPicker> createState() => _ReportPickerState();
}

class _ReportPickerState extends State<_ReportPicker> {
  late final Set<String> chosen = AppStore.instance.people.map((p) => p.id).toSet();
  bool error = false;

  @override
  Widget build(BuildContext context) {
    final occ = widget.occ, store = AppStore.instance, list = store.giftsFor(occ.key, widget.year);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _head(context, occ, '${occ.label} ${widget.year}', "Who's on the report?"),
        const SizedBox(height: 8),
        Text('Tick everyone you want in the PDF. The totals and fairness notes only count the people you pick.', style: TextStyle(color: occ.muted)),
        const SizedBox(height: 10),
        Row(children: [
          OutlinedButton(onPressed: () => setState(() => chosen.addAll(store.people.map((p) => p.id))), child: const Text('Select all')),
          const SizedBox(width: 8),
          TextButton(onPressed: () => setState(chosen.clear), child: const Text('Clear')),
        ]),
        for (final p in store.people)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: chosen.contains(p.id),
            onChanged: (v) => setState(() => v == true ? chosen.add(p.id) : chosen.remove(p.id)),
            title: Text(p.name, style: display(21, occ.ink, weight: FontWeight.w500)),
            subtitle: Builder(builder: (_) {
              final gl = list.where((g) => g.personId == p.id);
              return Text('${p.group} · ${plural(gl.length, 'gift')} · ${money(total(gl))}');
            }),
          ),
        if (error) const Padding(padding: EdgeInsets.only(top: 8), child: Text('Pick at least one person.', style: TextStyle(color: Color(0xFFB42318)))),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          const SizedBox(width: 10),
          FilledButton.icon(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Create PDF'),
            onPressed: () {
              if (chosen.isEmpty) {
                setState(() => error = true);
                return;
              }
              Navigator.pop(context, store.people.where((p) => chosen.contains(p.id)).map((p) => p.id).toList());
            },
          ),
        ]),
      ]),
    );
  }
}

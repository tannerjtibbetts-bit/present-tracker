import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'models.dart';

/// Everything is kept on this phone, in one JSON file plus a folder of photos.
class AppStore extends ChangeNotifier {
  AppStore._(this.dir);

  static late AppStore instance;
  static const _uuid = Uuid();

  final Directory dir;
  final List<Person> people = [];
  final List<Gift> gifts = [];

  File get _file => File(p.join(dir.path, 'present_tracker.json'));
  Directory get photoDir => Directory(p.join(dir.path, 'photos'));

  static Future<AppStore> open({Directory? at}) async {
    final d = at ?? await getApplicationDocumentsDirectory();
    final s = AppStore._(d);
    await s._load();
    instance = s;
    return s;
  }

  Future<void> _load() async {
    if (!photoDir.existsSync()) photoDir.createSync(recursive: true);
    if (_file.existsSync()) {
      try {
        final j = jsonDecode(await _file.readAsString()) as Map<String, Object?>;
        for (final x in (j['people'] as List? ?? [])) {
          people.add(Person.fromJson(Map<String, Object?>.from(x as Map)));
        }
        for (final x in (j['gifts'] as List? ?? [])) {
          gifts.add(Gift.fromJson(Map<String, Object?>.from(x as Map)));
        }
      } catch (_) {
        // A damaged file is kept aside so nothing is lost, and the app starts fresh.
        await _file.copy('${_file.path}.damaged');
      }
    } else {
      // First run: the three children are already set up.
      var t = 1;
      for (final n in ['Everleigh', 'Hudson', 'Nevaeh']) {
        people.add(Person(id: newId(), name: n, group: 'Kids', created: t++));
      }
      await _save();
    }
    _sortPeople();
  }

  String newId() => _uuid.v4();

  void _sortPeople() => people.sort((a, b) {
        final c = a.created.compareTo(b.created);
        return c != 0 ? c : a.name.compareTo(b.name);
      });

  Future<void> _save() async {
    final tmp = File('${_file.path}.tmp');
    await tmp.writeAsString(jsonEncode({
      'version': 1,
      'people': people.map((x) => x.toJson()).toList(),
      'gifts': gifts.map((x) => x.toJson()).toList(),
    }));
    await tmp.rename(_file.path);
  }

  Future<void> _changed() async {
    await _save();
    notifyListeners();
  }

  Person? person(String id) {
    for (final x in people) {
      if (x.id == id) return x;
    }
    return null;
  }

  Future<void> savePerson(Person x) async {
    final i = people.indexWhere((e) => e.id == x.id);
    if (i >= 0) {
      people[i] = x;
    } else {
      people.add(x);
    }
    _sortPeople();
    await _changed();
  }

  /// Removes the person and every gift they have, on every occasion.
  Future<void> deletePerson(String id) async {
    for (final g in gifts.where((g) => g.personId == id).toList()) {
      _deletePhoto(g.photo);
    }
    gifts.removeWhere((g) => g.personId == id);
    people.removeWhere((x) => x.id == id);
    await _changed();
  }

  List<Gift> giftsFor(String occasion, int year) =>
      gifts.where((g) => g.occasion == occasion && g.year == year).toList();

  Future<void> saveGift(Gift g) async {
    final i = gifts.indexWhere((e) => e.id == g.id);
    if (i >= 0) {
      if (gifts[i].photo != g.photo) _deletePhoto(gifts[i].photo);
      gifts[i] = g;
    } else {
      gifts.add(g);
    }
    await _changed();
  }

  Future<void> setStatus(Gift g, String status) async {
    g.status = status;
    await _changed();
  }

  Future<void> deleteGift(Gift g) async {
    _deletePhoto(g.photo);
    gifts.removeWhere((e) => e.id == g.id);
    await _changed();
  }

  /// Copies a picked photo into the app's own folder and returns its file name.
  Future<String> keepPhoto(String sourcePath) async {
    final ext = p.extension(sourcePath).isEmpty ? '.jpg' : p.extension(sourcePath);
    final name = '${newId()}$ext';
    await File(sourcePath).copy(p.join(photoDir.path, name));
    return name;
  }

  File? photoFile(String name) {
    if (name.isEmpty) return null;
    final f = File(p.join(photoDir.path, name));
    return f.existsSync() ? f : null;
  }

  void _deletePhoto(String name) {
    final f = photoFile(name);
    if (f != null) {
      try {
        f.deleteSync();
      } catch (_) {}
    }
  }
}

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

/// Turns a photo upright (phones often save it sideways with a note saying which way is up),
/// shrinks it to [maxSide] and saves it as a JPEG. Runs off the main thread.
Uint8List uprightJpeg(Uint8List bytes, {int maxSide = 1800, int turn = 0}) {
  var im = img.decodeImage(bytes);
  if (im == null) throw const FormatException('Not a photo');
  im = img.bakeOrientation(im);
  final longest = im.width > im.height ? im.width : im.height;
  if (longest > maxSide) {
    im = im.width >= im.height ? img.copyResize(im, width: maxSide) : img.copyResize(im, height: maxSide);
  }
  if (turn % 360 != 0) im = img.copyRotate(im, angle: turn);
  return img.encodeJpg(im, quality: 88);
}

Uint8List _work((Uint8List, int, int) a) => uprightJpeg(a.$1, maxSide: a.$2, turn: a.$3);

/// Writes an upright, smaller copy of [source] next to it and returns the new path.
/// If anything goes wrong, the original path is returned so the photo is never lost.
Future<String> prepareFile(String source, {int maxSide = 1800, int turn = 0, String suffix = 'upright'}) async {
  try {
    final bytes = await File(source).readAsBytes();
    final out = await compute(_work, (bytes, maxSide, turn));
    final dest = p.join(p.dirname(source), '${p.basenameWithoutExtension(source)}_$suffix.jpg');
    await File(dest).writeAsBytes(out, flush: true);
    return dest;
  } catch (_) {
    return source;
  }
}

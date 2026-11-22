import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:present_tracker/services/photo_prep.dart';

void main() {
  test('Photos are shrunk and can be turned', () {
    final wide = img.Image(width: 4000, height: 3000);
    final out = img.decodeJpg(uprightJpeg(Uint8List.fromList(img.encodeJpg(wide))))!;
    expect(out.width, 1800);
    expect(out.height, 1350);
    final turned = img.decodeJpg(uprightJpeg(Uint8List.fromList(img.encodeJpg(wide)), turn: 90))!;
    expect(turned.width, 1350);
    expect(turned.height, 1800);
  });
}

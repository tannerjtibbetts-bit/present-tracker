import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// One of the drawn illustrations, filling its box.
class Art extends StatelessWidget {
  const Art(this.asset, {super.key, this.fit = BoxFit.cover, this.size});
  final String asset;
  final BoxFit fit;
  final double? size;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(asset, fit: fit, width: size, height: size);
}

final Map<String, Future<ui.Image>> _tiles = {};

/// Draws an SVG tile once into a bitmap, so it can be repeated cheaply.
Future<ui.Image> _tile(String asset, double w, double h, double ratio) {
  final key = '$asset@$w@$h@$ratio';
  return _tiles[key] ??= () async {
    final info = await vg.loadPicture(SvgAssetLoader(asset), null);
    final pw = (w * ratio).round(), ph = (h * ratio).round();
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.scale(pw / info.size.width, ph / info.size.height);
    c.drawPicture(info.picture);
    final img = await rec.endRecording().toImage(pw, ph);
    info.picture.dispose();
    return img;
  }();
}

class _TilePainter extends CustomPainter {
  _TilePainter(this.image, this.w, this.h);
  final ui.Image image;
  final double w, h;

  @override
  void paint(Canvas canvas, Size size) {
    final src = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final paint = Paint()..filterQuality = FilterQuality.medium;
    for (var y = 0.0; y < size.height; y += h) {
      for (var x = 0.0; x < size.width; x += w) {
        canvas.drawImageRect(image, src, Rect.fromLTWH(x, y, w, h), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_TilePainter old) => old.image != image || old.w != w || old.h != h;
}

/// A repeating pattern (wallpaper, plaid or garland) behind [child].
class Tiled extends StatelessWidget {
  const Tiled({super.key, required this.asset, required this.tile, this.tileHeight, this.color, this.child, this.height});
  final String asset;
  final double tile;
  final double? tileHeight;
  final Color? color;
  final Widget? child;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final ratio = MediaQuery.of(context).devicePixelRatio;
    return Container(
      color: color,
      height: height,
      child: Stack(
        children: [
          Positioned.fill(
            child: FutureBuilder<ui.Image>(
              future: _tile(asset, tile, tileHeight ?? tile, ratio),
              builder: (context, snap) => snap.hasData
                  ? CustomPaint(painter: _TilePainter(snap.data!, tile, tileHeight ?? tile))
                  : const SizedBox.shrink(),
            ),
          ),
          ?child,
        ],
      ),
    );
  }
}

/// A row of lights strung along the top of the Christmas screens.
class Garland extends StatelessWidget {
  const Garland({super.key});

  @override
  Widget build(BuildContext context) => const IgnorePointer(
        child: SizedBox(height: 40, child: Tiled(asset: 'assets/art/garland.svg', tile: 139, tileHeight: 40)),
      );
}

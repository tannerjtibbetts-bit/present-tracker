import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// What could be read from a photo of a gift, price tag, receipt or order screenshot.
class PhotoInfo {
  PhotoInfo({this.item, this.price, this.store, this.orderDate, this.orderNumber, this.details});
  final String? item;
  final double? price;
  final String? store;

  /// YYYY-MM-DD
  final String? orderDate;
  final String? orderNumber;
  final String? details;

  bool get isEmpty => item == null && price == null && store == null && orderDate == null && orderNumber == null;
}

/// Everything read from one photo: the best guesses, plus every line and price found,
/// so the person can tap the right one when a guess is wrong.
class PhotoRead {
  PhotoRead(this.text, this.info) : lines = textLines(text), prices = priceCandidates(text);
  final String text;
  final PhotoInfo info;
  final List<String> lines;
  final List<double> prices;
}

List<String> textLines(String text) {
  final seen = <String>{};
  return [
    for (final l in text.split(RegExp(r'\r?\n')).map((l) => l.trim()))
      if (RegExp(r'[A-Za-z]{2}').hasMatch(l) && l.length <= 80 && seen.add(l.toLowerCase())) l
  ];
}

/// Every amount in the text that looks like a price, largest last, without repeats.
List<double> priceCandidates(String text) {
  final out = <double>{};
  for (final m in _priceRe.allMatches(text)) {
    final v = _toNum(m[1] ?? m[2]!);
    if (v != null) out.add(v);
  }
  return out.toList();
}

Future<String> _recognise(TextRecognizer rec, String path) async => (await rec.processImage(InputImage.fromFilePath(path))).text;

/// Reads the writing in a photo with the phone's own text recognition (nothing leaves the phone).
/// [path] should already be upright. If little is found, the photo is also tried turned
/// each way, in case the camera saved it sideways.
Future<PhotoRead> readPhoto(String path, {Future<String> Function(String path, int turn)? turned}) async {
  final rec = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    var best = await _recognise(rec, path);
    if (turned != null && textLines(best).length < 2) {
      for (final turn in [90, 270, 180]) {
        final p = await turned(path, turn);
        if (p == path) break;
        final t = await _recognise(rec, p);
        if (textLines(t).length > textLines(best).length) best = t;
        if (textLines(best).length >= 3) break;
      }
    }
    return PhotoRead(best, parsePhotoText(best));
  } finally {
    await rec.close();
  }
}

const _stores = {
  'amazon': 'Amazon', 'walmart': 'Walmart', 'indigo': 'Indigo', 'chapters': 'Indigo', 'canadian tire': 'Canadian Tire',
  'best buy': 'Best Buy', 'bestbuy': 'Best Buy', 'costco': 'Costco', 'target': 'Target', 'toys r us': 'Toys R Us',
  'toysrus': 'Toys R Us', 'mastermind': 'Mastermind Toys', "hudson's bay": "Hudson's Bay", 'the bay': "Hudson's Bay",
  'sport chek': 'Sport Chek', 'sportchek': 'Sport Chek', 'shoppers': 'Shoppers Drug Mart', 'etsy': 'Etsy', 'ebay': 'eBay',
  'apple': 'Apple', 'lego': 'LEGO', 'winners': 'Winners', 'marshalls': 'Marshalls', 'old navy': 'Old Navy', 'gap': 'Gap',
  'h&m': 'H&M', 'zara': 'Zara', 'sephora': 'Sephora', 'staples': 'Staples', 'dollarama': 'Dollarama', 'giant tiger': 'Giant Tiger',
  'the source': 'The Source', 'eb games': 'EB Games', 'gamestop': 'GameStop', 'temu': 'Temu', 'shein': 'SHEIN',
  'aliexpress': 'AliExpress', 'disney': 'Disney Store', 'build-a-bear': 'Build-A-Bear', 'claire': "Claire's", 'roots': 'Roots',
  'lululemon': 'Lululemon', 'nike': 'Nike', 'adidas': 'Adidas', 'home depot': 'Home Depot', 'loblaw': 'Loblaws',
  'superstore': 'Real Canadian Superstore', 'mec': 'MEC', 'michaels': 'Michaels', 'kmart': 'Kmart',
};

const _months = {
  'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6, 'jul': 7, 'aug': 8, 'sep': 9, 'sept': 9, 'oct': 10, 'nov': 11, 'dec': 12,
};

final _priceRe = RegExp(r'(?:CA?\$|\$|CAD\s?)\s?(\d{1,4}(?:[,\s]\d{3})*(?:[.,]\d{2})?)|\b(\d{1,4}[.,]\d{2})\b');
final _skipPrice = RegExp(r'ship|deliver|tax|hst|gst|pst|subtotal|total|save|saving|discount|was|reg\.?|regular|off\b|coupon|fee|tip|change|balance|points', caseSensitive: false);
final _goodPrice = RegExp(r'sale|now|price|our price|each|item', caseSensitive: false);

double? _toNum(String s) {
  var t = s.replaceAll(RegExp(r'\s'), '');
  if (RegExp(r',\d{2}$').hasMatch(t) && !t.contains('.')) t = t.replaceFirst(RegExp(r',(?=\d{2}$)'), '.');
  t = t.replaceAll(',', '');
  final v = double.tryParse(t);
  return v == null || v <= 0 || v > 20000 ? null : v;
}

/// Pulls out the item, price, store, date, order number and a few details from recognised text.
/// Kept free of the phone's text reader so it can be tested.
PhotoInfo parsePhotoText(String text) {
  final lines = text.split(RegExp(r'\r?\n')).map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
  final lower = text.toLowerCase();

  // Store
  String? store;
  var storeAt = 1 << 30;
  for (final e in _stores.entries) {
    final i = lower.indexOf(e.key);
    if (i >= 0 && i < storeAt) {
      final before = i == 0 ? ' ' : lower[i - 1];
      if (RegExp(r'[^a-z]').hasMatch(before)) {
        storeAt = i;
        store = e.value;
      }
    }
  }
  final storeLower = store?.toLowerCase();

  // Price: prefer a line marked sale/price, skip shipping, tax and totals; else the first item price.
  double? price;
  double? fallback;
  final totals = <double>[];
  for (final l in lines) {
    for (final m in _priceRe.allMatches(l)) {
      final v = _toNum(m[1] ?? m[2]!);
      if (v == null) continue;
      final skip = _skipPrice.hasMatch(l);
      if (RegExp(r'\btotal\b', caseSensitive: false).hasMatch(l) && !RegExp(r'sub', caseSensitive: false).hasMatch(l)) totals.add(v);
      if (_goodPrice.hasMatch(l) && !skip) {
        price ??= v;
      } else if (!skip) {
        fallback ??= v;
      }
    }
  }
  price ??= fallback ?? (totals.isNotEmpty ? totals.first : null);

  // Order number
  String? orderNo;
  final om = RegExp(r'(?:order|confirmation|invoice|receipt|transaction)\s*(?:number|no\.?|num\.?|#|id)?\s*[:#]?\s*([A-Z0-9][A-Z0-9-]{4,})', caseSensitive: false).firstMatch(text);
  if (om != null && RegExp(r'\d').hasMatch(om[1]!)) orderNo = om[1];

  // Date
  String? date;
  final iso = RegExp(r'\b(20\d{2})[-/.](\d{1,2})[-/.](\d{1,2})\b').firstMatch(text);
  final named = RegExp(r'\b(jan|feb|mar|apr|may|jun|jul|aug|sept?|oct|nov|dec)[a-z]*\.?\s+(\d{1,2}),?\s+(20\d{2})\b', caseSensitive: false).firstMatch(text);
  final dayFirst = RegExp(r'\b(\d{1,2})\s+(jan|feb|mar|apr|may|jun|jul|aug|sept?|oct|nov|dec)[a-z]*\.?,?\s+(20\d{2})\b', caseSensitive: false).firstMatch(text);
  final slash = RegExp(r'\b(\d{1,2})/(\d{1,2})/(20\d{2})\b').firstMatch(text);
  String pad(int n) => n.toString().padLeft(2, '0');
  bool ok(int y, int m, int d) => m >= 1 && m <= 12 && d >= 1 && d <= 31;
  if (iso != null && ok(int.parse(iso[1]!), int.parse(iso[2]!), int.parse(iso[3]!))) {
    date = '${iso[1]}-${pad(int.parse(iso[2]!))}-${pad(int.parse(iso[3]!))}';
  } else if (named != null) {
    final m = _months[named[1]!.toLowerCase().substring(0, 3)]!;
    date = '${named[3]}-${pad(m)}-${pad(int.parse(named[2]!))}';
  } else if (dayFirst != null) {
    final m = _months[dayFirst[2]!.toLowerCase().substring(0, 3)]!;
    date = '${dayFirst[3]}-${pad(m)}-${pad(int.parse(dayFirst[1]!))}';
  } else if (slash != null) {
    // Canada usually writes month/day on receipts; a first number over 12 must be the day.
    var a = int.parse(slash[1]!), b = int.parse(slash[2]!);
    if (a > 12) {
      final t = a;
      a = b;
      b = t;
    }
    if (ok(0, a, b)) date = '${slash[3]}-${pad(a)}-${pad(b)}';
  }

  // Item: the longest line that reads like a product name.
  String? item;
  var best = 0;
  for (final l in lines) {
    final lo = l.toLowerCase();
    if (_priceRe.hasMatch(l) && RegExp(r'^[\s$CAD0-9.,]+$').hasMatch(l)) continue;
    if (RegExp(r'order|ship|deliver|total|tax|qty|quantity|thank|receipt|invoice|www\.|http|@|visa|mastercard|payment|card|address|phone|tel|subtotal|cashier|store #', caseSensitive: false).hasMatch(lo)) continue;
    if (storeLower != null && lo.trim() == storeLower) continue;
    final letters = RegExp(r'[A-Za-z]').allMatches(l).length;
    if (letters < 4) continue;
    final score = letters + (RegExp(r'\d').hasMatch(l) ? 0 : 3);
    if (score > best) {
      best = score;
      item = l.replaceAll(_priceRe, '').replaceAll(RegExp(r'\s{2,}'), ' ').trim();
    }
  }
  final itemText = item == null || item.isEmpty ? null : (item.length > 60 ? '${item.substring(0, 57).trimRight()}…' : item);

  // Details: size, colour, quantity, delivery date.
  final bits = <String>[];
  final size = RegExp(r'\bsize\s*:?\s*([A-Z0-9./ -]{1,10})', caseSensitive: false).firstMatch(text);
  if (size != null) bits.add('Size ${size[1]!.trim()}');
  final colour = RegExp(r'\bcolou?r\s*:?\s*([A-Za-z ]{3,20})', caseSensitive: false).firstMatch(text);
  if (colour != null) bits.add(colour[1]!.trim().split(RegExp(r'\s+')).take(2).join(' '));
  final qty = RegExp(r'\b(?:qty|quantity)\s*:?\s*(\d{1,3})', caseSensitive: false).firstMatch(text);
  if (qty != null) bits.add('Qty ${qty[1]}');
  final arrive = RegExp(r'(?:arriv\w*|deliver\w*|get it)\s*(?:by|on)?\s*:?\s*((?:mon|tue|wed|thu|fri|sat|sun)[a-z]*,?\s+)?((?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.?\s+\d{1,2})', caseSensitive: false).firstMatch(text);
  if (arrive != null) bits.add('Arrives ${arrive[2]}');

  return PhotoInfo(
    item: itemText,
    price: price,
    store: store,
    orderDate: date,
    orderNumber: orderNo,
    details: bits.isEmpty ? null : bits.join(', '),
  );
}

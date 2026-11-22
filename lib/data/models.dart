/// The people you buy for, and the gifts you buy them.
library;

const groups = ['Kids', 'Family', 'Friends', 'Work', 'Other'];
const statuses = ['ordered', 'arrived', 'wrapped'];
const statusLabels = {'ordered': 'Ordered', 'arrived': 'Arrived', 'wrapped': 'Wrapped'};

String _s(Object? v) => v == null ? '' : v.toString();
int _i(Object? v, [int d = 0]) => v is num ? v.toInt() : int.tryParse(_s(v)) ?? d;
double? _d(Object? v) => v == null || v == '' ? null : (v is num ? v.toDouble() : double.tryParse(_s(v)));

class Person {
  Person({
    required this.id,
    required this.name,
    this.group = 'Kids',
    this.birthday = '',
    this.note = '',
    required this.created,
  });

  final String id;
  String name;
  String group;

  /// YYYY-MM-DD, or empty.
  String birthday;
  String note;
  final int created;

  Map<String, Object?> toJson() =>
      {'id': id, 'name': name, 'group': group, 'birthday': birthday, 'note': note, 'created': created};

  factory Person.fromJson(Map<String, Object?> j) => Person(
        id: _s(j['id']),
        name: _s(j['name']),
        group: groups.contains(j['group']) ? _s(j['group']) : 'Other',
        birthday: _s(j['birthday']),
        note: _s(j['note']),
        created: _i(j['created']),
      );
}

class Gift {
  Gift({
    required this.id,
    required this.occasion,
    required this.year,
    required this.personId,
    this.item = '',
    this.price,
    this.store = '',
    this.status = 'ordered',
    this.event = '',
    this.notes = '',
    this.photo = '',
    this.purchased = '',
    this.orderNo = '',
    this.details = '',
    required this.created,
  });

  final String id;
  String occasion;
  int year;
  String personId;
  String item;
  double? price;
  String store;
  String status;

  /// For Special Occasions: what the gift is for (Graduation, Shower...).
  String event;
  String notes;

  /// File name of the photo inside the app's photo folder, or empty.
  String photo;

  /// YYYY-MM-DD, or empty.
  String purchased;
  String orderNo;
  String details;
  final int created;

  Gift copy() => Gift.fromJson(toJson());

  Map<String, Object?> toJson() => {
        'id': id,
        'occasion': occasion,
        'year': year,
        'personId': personId,
        'item': item,
        'price': price,
        'store': store,
        'status': status,
        'event': event,
        'notes': notes,
        'photo': photo,
        'purchased': purchased,
        'orderNo': orderNo,
        'details': details,
        'created': created,
      };

  factory Gift.fromJson(Map<String, Object?> j) => Gift(
        id: _s(j['id']),
        occasion: _s(j['occasion']),
        year: _i(j['year'], DateTime.now().year),
        personId: _s(j['personId']),
        item: _s(j['item']),
        price: _d(j['price']),
        store: _s(j['store']),
        status: statuses.contains(j['status']) ? _s(j['status']) : 'ordered',
        event: _s(j['event']),
        notes: _s(j['notes']),
        photo: _s(j['photo']),
        purchased: _s(j['purchased']),
        orderNo: _s(j['orderNo']),
        details: _s(j['details']),
        created: _i(j['created']),
      );
}

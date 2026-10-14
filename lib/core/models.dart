import 'dart:convert';

class LatLng {
  final double lat;
  final double lng;
  const LatLng(this.lat, this.lng);

  /// Stable key used for dedupe/caching (~1 m precision).
  String get key => '${lat.toStringAsFixed(5)},${lng.toStringAsFixed(5)}';

  Map<String, dynamic> toWaypoint() => {
    'waypoint': {
      'location': {
        'latLng': {'latitude': lat, 'longitude': lng},
      },
    },
  };

  @override
  bool operator ==(Object other) => other is LatLng && other.key == key;
  @override
  int get hashCode => key.hashCode;
  @override
  String toString() => key;
}

class Place {
  final String label;
  final LatLng location;
  final String? placeId;
  final String? address;
  const Place({required this.label, required this.location, this.placeId, this.address});

  Map<String, dynamic> toJson() => {
    'label': label,
    'lat': location.lat,
    'lng': location.lng,
    'placeId': placeId,
    'address': address,
  };
  factory Place.fromJson(Map<String, dynamic> j) => Place(
    label: j['label'] as String,
    location: LatLng((j['lat'] as num).toDouble(), (j['lng'] as num).toDouble()),
    placeId: j['placeId'] as String?,
    address: j['address'] as String?,
  );
}

class CommutePair {
  final String id;
  final String name;
  final Place origin;
  final Place destination;
  const CommutePair({required this.id, required this.name, required this.origin, required this.destination});

  /// Changes whenever endpoints change, so edits invalidate cached results.
  String get routeKey => '${origin.location.key}>${destination.location.key}';

  String get title => name.trim().isNotEmpty ? name : '${origin.label} → ${destination.label}';

  CommutePair copyWith({String? name, Place? origin, Place? destination}) => CommutePair(
    id: id,
    name: name ?? this.name,
    origin: origin ?? this.origin,
    destination: destination ?? this.destination,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'origin': origin.toJson(),
    'destination': destination.toJson(),
  };
  factory CommutePair.fromJson(Map<String, dynamic> j) => CommutePair(
    id: j['id'] as String,
    name: (j['name'] as String?) ?? '',
    origin: Place.fromJson(j['origin'] as Map<String, dynamic>),
    destination: Place.fromJson(j['destination'] as Map<String, dynamic>),
  );

  static String encodeList(List<CommutePair> l) => jsonEncode(l.map((e) => e.toJson()).toList());
  static List<CommutePair> decodeList(String s) =>
      (jsonDecode(s) as List).map((e) => CommutePair.fromJson(e as Map<String, dynamic>)).toList();
}

enum TravelMode {
  walk('WALK', 'Walk'),
  drive('DRIVE', 'Car'),
  twoWheeler('TWO_WHEELER', 'Bike'),
  bicycle('BICYCLE', 'Cycle');

  final String api;
  final String label;
  const TravelMode(this.api, this.label);

  /// Traffic-aware only matters for motor vehicles (WALK/BICYCLE reject it).
  bool get trafficAware => this == drive || this == twoWheeler;

  static TravelMode? byName(String n) {
    for (final m in values) {
      if (m.name == n) return m;
    }
    return null;
  }
}

/// One cell: a pair × mode result (success or per-cell error).
class LegResult {
  final int? durationSec;
  final int? distanceMeters;
  final String? error;
  final DateTime fetchedAt;
  final String routeKey;

  const LegResult({
    this.durationSec,
    this.distanceMeters,
    this.error,
    required this.fetchedAt,
    required this.routeKey,
  });

  bool get ok => durationSec != null && error == null;

  Map<String, dynamic> toJson() => {
    'd': durationSec,
    'm': distanceMeters,
    'e': error,
    't': fetchedAt.millisecondsSinceEpoch,
    'k': routeKey,
  };
  factory LegResult.fromJson(Map<String, dynamic> j) => LegResult(
    durationSec: j['d'] as int?,
    distanceMeters: j['m'] as int?,
    error: j['e'] as String?,
    fetchedAt: DateTime.fromMillisecondsSinceEpoch(j['t'] as int),
    routeKey: j['k'] as String,
  );
}

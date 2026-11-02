import 'station.dart';

class BusService {
  final int id;
  final Station origin;
  final Station destination;
  final String departureTime;
  final int depMinutes;
  final String busType;
  final String viaStops;
  final String sourceDepot;
  final bool verified;

  const BusService({
    required this.id,
    required this.origin,
    required this.destination,
    required this.departureTime,
    required this.depMinutes,
    required this.busType,
    required this.viaStops,
    required this.sourceDepot,
    required this.verified,
  });

  factory BusService.fromMap(Map<String, dynamic> map, Station origin, Station destination) {
    return BusService(
      id: (map['id'] as int?) ?? 0,
      origin: origin,
      destination: destination,
      departureTime: (map['departure_time'] as String?) ?? '',
      depMinutes: (map['dep_minutes'] as int?) ?? 0,
      busType: (map['bus_type'] as String?) ?? 'Ordinary',
      viaStops: (map['via_stops'] as String?) ?? '',
      sourceDepot: (map['source_depot'] as String?) ?? 'MSRTC Depot Sheet',
      verified: (map['verified'] as int?) == 1,
    );
  }

  List<String> get viaList {
    if (viaStops.trim().isEmpty) return [];
    return viaStops.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  /// Returns a validated HH:MM departure time string.
  /// If the stored departureTime is malformed, falls back to computing it from
  /// depMinutes. If both are bad, returns '--:--' so the UI never shows
  /// impossible times like 84:24 or 83:84.
  String get validDepartureTime {
    // Try the stored string first: must match HH:MM with valid ranges.
    final timeRegex = RegExp(r'^(\d{1,2}):(\d{2})$');
    final match = timeRegex.firstMatch(departureTime);
    if (match != null) {
      final h = int.tryParse(match.group(1)!) ?? -1;
      final m = int.tryParse(match.group(2)!) ?? -1;
      if (h >= 0 && h <= 23 && m >= 0 && m <= 59) {
        return departureTime;
      }
    }
    // Fall back to depMinutes (0-1439 minutes since midnight).
    if (depMinutes >= 0 && depMinutes <= 1439) {
      final h = depMinutes ~/ 60;
      final m = depMinutes % 60;
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
    }
    return '--:--';
  }
}

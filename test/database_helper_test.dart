import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:st_saathi/core/database/database_helper.dart';

/// Baseline tests that lock in the behavior of the timetable queries before
/// the connecting-route refactor. Each test builds a fresh in-memory fixture
/// database with the real schema, injects it into DatabaseHelper, and asserts
/// on the exact results.
///
/// Fixture:
///   Stations: 1 Pune (depot), 2 Chandwad (town), 3 Malegaon (depot),
///             4 Nashik (depot), 5 Aurangabad (depot), 6 Nagpur (depot)
///   Services:
///     Pune -> Chandwad:      10 (06:00), 11 (07:00), 12 (08:00)
///     Chandwad -> Malegaon:  14 (09:00), 15 (10:00)
///     Pune -> Nashik:        16 (06:30), 17 (11:00)
///     Nashik -> Malegaon:    18 (12:00), 19 (13:00), 20 (14:00), 21 (15:00)
///     Pune -> Nagpur via 'Aurangabad, Malegaon': 30 (12:00)
///     Aurangabad -> Malegaon: 22 (16:00), 23 (17:00)
///     Aurangabad -> Nagpur:  24 (18:00)
void main() {
  late Database db;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await _createFixtureDb();
    DatabaseHelper.injectTestDatabase(db);
  });

  tearDown(() async {
    await db.close();
    DatabaseHelper.clearTestDatabase();
  });

  group('getServicesBetween', () {
    test('returns direct services ordered by departure', () async {
      final result = await DatabaseHelper.instance.getServicesBetween(1, 2);

      expect(result.length, 3);
      expect(result[0].id, 10);
      expect(result[0].departureTime, '06:00');
      expect(result[1].id, 11);
      expect(result[2].id, 12);
    });

    test('includes services that pass through the destination via stops', () async {
      // Service 30 runs Pune -> Nagpur but lists Malegaon in via_stops,
      // so it counts as a Pune -> Malegaon service.
      final result = await DatabaseHelper.instance.getServicesBetween(1, 3);

      expect(result.map((s) => s.id), contains(30));
    });

    test('returns empty for a pair with no services', () async {
      final result = await DatabaseHelper.instance.getServicesBetween(3, 1);
      expect(result, isEmpty);
    });
  });

  group('findConnectingRoutes', () {
    test('finds junction routes and sorts by total frequency', () async {
      final routes = await DatabaseHelper.instance.findConnectingRoutes(1, 3);

      // Junction candidates: Chandwad (3+2=5) and Nashik (2+4=6).
      expect(routes.length, 2);
      expect(routes[0].junction.id, 4); // Nashik, score 6
      expect(routes[1].junction.id, 2); // Chandwad, score 5

      final chandwad = routes[1];
      expect(chandwad.leg1Count, 3);
      expect(chandwad.leg2Count, 2);
      expect(chandwad.leg1Services.map((s) => s.id), [10, 11, 12]);
      expect(chandwad.leg2Services.map((s) => s.id), [14, 15]);
    });

    test('falls back to depot hubs when no junction pair exists', () async {
      // Pune -> Nagpur has no direct junction, but the Aurangabad depot
      // connects: Pune bus 30 passes through it, and bus 24 runs onward.
      final routes = await DatabaseHelper.instance.findConnectingRoutes(1, 6);

      expect(routes.length, 1);
      expect(routes[0].junction.id, 5); // Aurangabad
      expect(routes[0].leg1Services.map((s) => s.id), [30]); // via_stops match
      expect(routes[0].leg2Services.map((s) => s.id), [24]);
    });

    test('returns empty when no connection exists', () async {
      final routes = await DatabaseHelper.instance.findConnectingRoutes(3, 1);
      expect(routes, isEmpty);
    });

    test('excludes the origin and destination themselves as junctions', () async {
      final routes = await DatabaseHelper.instance.findConnectingRoutes(1, 3);
      final junctionIds = routes.map((r) => r.junction.id).toList();
      expect(junctionIds, isNot(contains(1)));
      expect(junctionIds, isNot(contains(3)));
    });
  });
}

/// Creates an in-memory database with the real app schema and the fixture
/// described at the top of this file.
Future<Database> _createFixtureDb() async {
  return databaseFactory.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE stations (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name_en TEXT NOT NULL,
            name_mr TEXT NOT NULL,
            is_depot INTEGER DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE services (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            origin_id INTEGER NOT NULL,
            destination_id INTEGER NOT NULL,
            departure_time TEXT NOT NULL,
            dep_minutes INTEGER NOT NULL,
            bus_type TEXT,
            via_stops TEXT,
            source_depot TEXT,
            verified INTEGER DEFAULT 1
          )
        ''');

        await db.insert('stations', {'id': 1, 'name_en': 'Pune', 'name_mr': 'पुणे', 'is_depot': 1});
        await db.insert('stations', {'id': 2, 'name_en': 'Chandwad', 'name_mr': 'चांदवड', 'is_depot': 0});
        await db.insert('stations', {'id': 3, 'name_en': 'Malegaon', 'name_mr': 'मालेगाव', 'is_depot': 1});
        await db.insert('stations', {'id': 4, 'name_en': 'Nashik', 'name_mr': 'नाशिक', 'is_depot': 1});
        await db.insert('stations', {'id': 5, 'name_en': 'Aurangabad', 'name_mr': 'औरंगाबाद', 'is_depot': 1});
        await db.insert('stations', {'id': 6, 'name_en': 'Nagpur', 'name_mr': 'नागपूर', 'is_depot': 1});

        // Pune -> Chandwad
        await db.insert('services', {'id': 10, 'origin_id': 1, 'destination_id': 2, 'departure_time': '06:00', 'dep_minutes': 360, 'bus_type': 'Ordinary', 'via_stops': '', 'source_depot': 'Pune', 'verified': 1});
        await db.insert('services', {'id': 11, 'origin_id': 1, 'destination_id': 2, 'departure_time': '07:00', 'dep_minutes': 420, 'bus_type': 'Ordinary', 'via_stops': '', 'source_depot': 'Pune', 'verified': 1});
        await db.insert('services', {'id': 12, 'origin_id': 1, 'destination_id': 2, 'departure_time': '08:00', 'dep_minutes': 480, 'bus_type': 'Ordinary', 'via_stops': '', 'source_depot': 'Pune', 'verified': 1});
        // Chandwad -> Malegaon
        await db.insert('services', {'id': 14, 'origin_id': 2, 'destination_id': 3, 'departure_time': '09:00', 'dep_minutes': 540, 'bus_type': 'Ordinary', 'via_stops': '', 'source_depot': 'Chandwad', 'verified': 1});
        await db.insert('services', {'id': 15, 'origin_id': 2, 'destination_id': 3, 'departure_time': '10:00', 'dep_minutes': 600, 'bus_type': 'Ordinary', 'via_stops': '', 'source_depot': 'Chandwad', 'verified': 1});
        // Pune -> Nashik
        await db.insert('services', {'id': 16, 'origin_id': 1, 'destination_id': 4, 'departure_time': '06:30', 'dep_minutes': 390, 'bus_type': 'Ordinary', 'via_stops': '', 'source_depot': 'Pune', 'verified': 1});
        await db.insert('services', {'id': 17, 'origin_id': 1, 'destination_id': 4, 'departure_time': '11:00', 'dep_minutes': 660, 'bus_type': 'Ordinary', 'via_stops': '', 'source_depot': 'Pune', 'verified': 1});
        // Nashik -> Malegaon
        await db.insert('services', {'id': 18, 'origin_id': 4, 'destination_id': 3, 'departure_time': '12:00', 'dep_minutes': 720, 'bus_type': 'Ordinary', 'via_stops': '', 'source_depot': 'Nashik', 'verified': 1});
        await db.insert('services', {'id': 19, 'origin_id': 4, 'destination_id': 3, 'departure_time': '13:00', 'dep_minutes': 780, 'bus_type': 'Ordinary', 'via_stops': '', 'source_depot': 'Nashik', 'verified': 1});
        await db.insert('services', {'id': 20, 'origin_id': 4, 'destination_id': 3, 'departure_time': '14:00', 'dep_minutes': 840, 'bus_type': 'Ordinary', 'via_stops': '', 'source_depot': 'Nashik', 'verified': 1});
        await db.insert('services', {'id': 21, 'origin_id': 4, 'destination_id': 3, 'departure_time': '15:00', 'dep_minutes': 900, 'bus_type': 'Ordinary', 'via_stops': '', 'source_depot': 'Nashik', 'verified': 1});
        // Pune -> Nagpur, passing through Aurangabad and Malegaon
        await db.insert('services', {'id': 30, 'origin_id': 1, 'destination_id': 6, 'departure_time': '12:00', 'dep_minutes': 720, 'bus_type': 'Ordinary', 'via_stops': 'Aurangabad, Malegaon', 'source_depot': 'Pune', 'verified': 1});
        // Aurangabad -> Malegaon
        await db.insert('services', {'id': 22, 'origin_id': 5, 'destination_id': 3, 'departure_time': '16:00', 'dep_minutes': 960, 'bus_type': 'Ordinary', 'via_stops': '', 'source_depot': 'Aurangabad', 'verified': 1});
        await db.insert('services', {'id': 23, 'origin_id': 5, 'destination_id': 3, 'departure_time': '17:00', 'dep_minutes': 1020, 'bus_type': 'Ordinary', 'via_stops': '', 'source_depot': 'Aurangabad', 'verified': 1});
        // Aurangabad -> Nagpur
        await db.insert('services', {'id': 24, 'origin_id': 5, 'destination_id': 6, 'departure_time': '18:00', 'dep_minutes': 1080, 'bus_type': 'Ordinary', 'via_stops': '', 'source_depot': 'Aurangabad', 'verified': 1});
      },
    ),
  );
}

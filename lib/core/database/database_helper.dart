import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../../models/station.dart';
import '../../models/bus_service.dart';
import '../../models/connecting_route.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  /// Held open while a timetable swap is in flight so concurrent searches
  /// wait for a clean database instead of opening a half-replaced file.
  Completer<void>? _swapGate;

  DatabaseHelper._init();

  /// Test-only: injects an already-open database (e.g. an in-memory fixture)
  /// so query logic can be exercised without the asset bundle.
  @visibleForTesting
  static void injectTestDatabase(Database db) {
    _database = db;
  }

  /// Test-only: clears the injected database reference.
  @visibleForTesting
  static void clearTestDatabase() {
    _database = null;
  }

  Future<Database> get database async {
    // If a timetable swap is in progress, wait for it to finish rather than
    // opening a file that is mid-replacement.
    final gate = _swapGate;
    if (gate != null) {
      await gate.future;
    }
    if (_database != null) return _database!;
    _database = await _initDB('st_timetable_v3.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);
    final backupPath = '$path.bak';

    final exists = await databaseExists(path);

    if (!exists) {
      // Crash recovery: an interrupted update renames the old DB to .bak
      // before copying the new one in. If we crashed in that window, restore
      // the backup (the working old database) instead of the bundled asset.
      final backupExists = await databaseExists(backupPath);
      if (backupExists) {
        try {
          await File(backupPath).rename(path);
        } catch (_) {}
      }
    }

    if (!await databaseExists(path)) {
      // Ensure the directory exists
      try {
        await Directory(dirname(path)).create(recursive: true);
      } catch (_) {}

      // Copy from asset
      final ByteData data = await rootBundle.load('assets/database/st_timetable.db');
      final List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await File(path).writeAsBytes(bytes, flush: true);
    }

    return await openDatabase(
      path,
      readOnly: true,
    );
  }

  Future<String> getDatabasePath() async {
    final dbPath = await getDatabasesPath();
    return join(dbPath, 'st_timetable_v3.db');
  }

  /// Atomically replaces the current SQLite database with a newly downloaded validated DB file.
  ///
  /// The downloaded file is validated before the live database is touched, a
  /// backup is kept until the new file is confirmed good, and concurrent
  /// searches wait on a swap gate so they never open a half-replaced file.
  Future<bool> replaceDatabase(File newDbFile) async {
    // 0. Validate the downloaded file first, before disturbing the live DB.
    if (!await _validateDbFile(newDbFile)) return false;

    final gate = Completer<void>();
    _swapGate = gate;
    try {
      final targetPath = await getDatabasePath();
      final backupPath = '$targetPath.bak';
      final targetFile = File(targetPath);
      final backupFile = File(backupPath);

      // 1. Close current connection
      if (_database != null && _database!.isOpen) {
        await _database!.close();
      }
      _database = null;

      // 2. Backup current working database if it exists
      if (await targetFile.exists()) {
        if (await backupFile.exists()) await backupFile.delete();
        await targetFile.rename(backupPath);
      }

      // 3. Move new database file into place
      await newDbFile.copy(targetPath);

      // 4. Reopen and confirm it still works
      _database = await openDatabase(targetPath, readOnly: true);

      // 5. Success: clean up backup
      if (await backupFile.exists()) {
        try {
          await backupFile.delete();
        } catch (_) {}
      }
      return true;
    } catch (e) {
      // Rollback to backup so the app is never left without a database.
      final targetPath = await getDatabasePath();
      final backupPath = '$targetPath.bak';
      final targetFile = File(targetPath);
      final backupFile = File(backupPath);
      if (await backupFile.exists()) {
        if (await targetFile.exists()) await targetFile.delete();
        await backupFile.rename(targetPath);
      }
      try {
        _database = await openDatabase(targetPath, readOnly: true);
      } catch (_) {}
      return false;
    } finally {
      gate.complete();
      _swapGate = null;
    }
  }

  /// Opens [file] read-only and confirms it looks like a real timetable.
  /// Returns false (instead of throwing) when the file is missing or corrupt.
  Future<bool> _validateDbFile(File file) async {
    Database? testDb;
    try {
      testDb = await openDatabase(file.path, readOnly: true);
      final countResult = await testDb.rawQuery('SELECT COUNT(*) as c FROM services');
      final count = Sqflite.firstIntValue(countResult) ?? 0;
      return count >= 100;
    } catch (_) {
      return false;
    } finally {
      await testDb?.close();
    }
  }

  Future<List<Station>> searchStations(String query, {int limit = 40}) async {
    final db = await database;
    final cleanQ = query.trim();
    if (cleanQ.isEmpty) {
      // Return top depots first, then major towns
      final result = await db.rawQuery(
        'SELECT * FROM stations ORDER BY is_depot DESC, name_en ASC LIMIT ?',
        [limit],
      );
      return result.map((e) => Station.fromMap(e)).toList();
    }

    final pattern = '%$cleanQ%';
    final result = await db.rawQuery(
      '''
      SELECT * FROM stations 
      WHERE name_en LIKE ? OR name_mr LIKE ?
      ORDER BY 
        CASE 
          WHEN name_en LIKE ? THEN 1
          WHEN name_mr LIKE ? THEN 2
          WHEN is_depot = 1 THEN 3
          ELSE 4 
        END,
        name_en ASC
      LIMIT ?
      ''',
      [pattern, pattern, '$cleanQ%', '$cleanQ%', limit],
    );

    return result.map((e) => Station.fromMap(e)).toList();
  }

  Future<Station?> getStationById(int id) async {
    final db = await database;
    final result = await db.query(
      'stations',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return Station.fromMap(result.first);
  }

  Future<List<BusService>> getUpcomingServicesFromOrigin(int originId, {int limit = 5}) async {
    final db = await database;
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;

    // Fetch next departures from current minute onwards
    final result = await db.rawQuery(
      '''
      SELECT 
        s.*,
        o.id as o_id, o.name_en as o_en, o.name_mr as o_mr, o.is_depot as o_depot,
        d.id as d_id, d.name_en as d_en, d.name_mr as d_mr, d.is_depot as d_depot
      FROM services s
      JOIN stations o ON s.origin_id = o.id
      JOIN stations d ON s.destination_id = d.id
      WHERE s.origin_id = ? AND s.dep_minutes >= ?
      ORDER BY s.dep_minutes ASC
      LIMIT ?
      ''',
      [originId, currentMinutes, limit],
    );

    List<BusService> list = result.map((row) {
      final origin = Station(
        id: row['o_id'] as int,
        nameEn: row['o_en'] as String,
        nameMr: row['o_mr'] as String,
        isDepot: (row['o_depot'] as int?) == 1,
      );
      final destination = Station(
        id: row['d_id'] as int,
        nameEn: row['d_en'] as String,
        nameMr: row['d_mr'] as String,
        isDepot: (row['d_depot'] as int?) == 1,
      );
      return BusService.fromMap(row, origin, destination);
    }).toList();

    // If late at night and few departures left, fetch tomorrow morning departures
    if (list.length < limit) {
      final morningResult = await db.rawQuery(
        '''
        SELECT 
          s.*,
          o.id as o_id, o.name_en as o_en, o.name_mr as o_mr, o.is_depot as o_depot,
          d.id as d_id, d.name_en as d_en, d.name_mr as d_mr, d.is_depot as d_depot
        FROM services s
        JOIN stations o ON s.origin_id = o.id
        JOIN stations d ON s.destination_id = d.id
        WHERE s.origin_id = ?
        ORDER BY s.dep_minutes ASC
        LIMIT ?
        ''',
        [originId, limit - list.length],
      );

      final morningList = morningResult.map((row) {
        final origin = Station(
          id: row['o_id'] as int,
          nameEn: row['o_en'] as String,
          nameMr: row['o_mr'] as String,
          isDepot: (row['o_depot'] as int?) == 1,
        );
        final destination = Station(
          id: row['d_id'] as int,
          nameEn: row['d_en'] as String,
          nameMr: row['d_mr'] as String,
          isDepot: (row['d_depot'] as int?) == 1,
        );
        return BusService.fromMap(row, origin, destination);
      }).toList();

      list.addAll(morningList);
    }

    return list;
  }

  Future<List<BusService>> getServicesBetween(int originId, int destinationId) async {
    final db = await database;
    
    // The search destination is joined directly (alias sd) so its name can be
    // matched against via_stops without a second lookup round trip.
    final result = await db.rawQuery(
      '''
      SELECT 
        s.*,
        o.id as o_id, o.name_en as o_en, o.name_mr as o_mr, o.is_depot as o_depot,
        d.id as d_id, d.name_en as d_en, d.name_mr as d_mr, d.is_depot as d_depot
      FROM services s
      JOIN stations o ON s.origin_id = o.id
      JOIN stations d ON s.destination_id = d.id
      LEFT JOIN stations sd ON sd.id = ?
      WHERE s.origin_id = ? AND (
        s.destination_id = ?
        OR (s.via_stops LIKE '%' || sd.name_en || '%' AND sd.name_en != '')
        OR (s.via_stops LIKE '%' || sd.name_mr || '%' AND sd.name_mr != '')
      )
      ORDER BY s.dep_minutes ASC
      ''',
      [destinationId, originId, destinationId],
    );

    return result.map((row) {
      final origin = Station(
        id: row['o_id'] as int,
        nameEn: row['o_en'] as String,
        nameMr: row['o_mr'] as String,
        isDepot: (row['o_depot'] as int?) == 1,
      );
      final destination = Station(
        id: row['d_id'] as int,
        nameEn: row['d_en'] as String,
        nameMr: row['d_mr'] as String,
        isDepot: (row['d_depot'] as int?) == 1,
      );
      return BusService.fromMap(row, origin, destination);
    }).toList();
  }

  Future<List<BusService>> getServicesByIds(List<int> ids) async {
    if (ids.isEmpty) return [];
    final db = await database;
    final placeholders = List.filled(ids.length, '?').join(',');
    final result = await db.rawQuery(
      '''
      SELECT 
        s.*,
        o.id as o_id, o.name_en as o_en, o.name_mr as o_mr, o.is_depot as o_depot,
        d.id as d_id, d.name_en as d_en, d.name_mr as d_mr, d.is_depot as d_depot
      FROM services s
      JOIN stations o ON s.origin_id = o.id
      JOIN stations d ON s.destination_id = d.id
      WHERE s.id IN ($placeholders)
      ORDER BY s.dep_minutes ASC
      ''',
      ids,
    );

    return result.map((row) {
      final origin = Station(
        id: row['o_id'] as int,
        nameEn: row['o_en'] as String,
        nameMr: row['o_mr'] as String,
        isDepot: (row['o_depot'] as int?) == 1,
      );
      final destination = Station(
        id: row['d_id'] as int,
        nameEn: row['d_en'] as String,
        nameMr: row['d_mr'] as String,
        isDepot: (row['d_depot'] as int?) == 1,
      );
      return BusService.fromMap(row, origin, destination);
    }).toList();
  }

  /// Calculates 1-stop connecting junction routes between origin and destination
  /// when no direct service is scheduled.
  ///
  /// Uses batched queries (2 per leg group) instead of one query pair per
  /// candidate junction, cutting a worst case of ~80 round trips down to ~6.
  Future<List<ConnectingRoute>> findConnectingRoutes(int originId, int destinationId) async {
    final db = await database;

    // 1. Direct pairwise intermediate junctions where Origin -> J and J -> Destination exist
    final junctionCandidates = await db.rawQuery(
      '''
      SELECT 
        j.id as j_id, j.name_en as j_en, j.name_mr as j_mr, j.is_depot as j_depot,
        COUNT(DISTINCT s1.id) as count1,
        COUNT(DISTINCT s2.id) as count2
      FROM stations j
      JOIN services s1 ON s1.destination_id = j.id
      JOIN services s2 ON s2.origin_id = j.id
      WHERE s1.origin_id = ? 
        AND s2.destination_id = ? 
        AND j.id != ? 
        AND j.id != ?
      GROUP BY j.id
      ORDER BY (COUNT(DISTINCT s1.id) + COUNT(DISTINCT s2.id)) DESC
      LIMIT 5
      ''',
      [originId, destinationId, originId, destinationId],
    );

    final junctions = junctionCandidates
        .map(
          (row) => Station(
            id: row['j_id'] as int,
            nameEn: row['j_en'] as String,
            nameMr: row['j_mr'] as String,
            isDepot: (row['j_depot'] as int?) == 1,
          ),
        )
        .toList();

    // 2. Batch-fetch both legs for every junction in 2 queries total.
    final destStation = await getStationById(destinationId);
    final leg1ByJunction = await _fetchLeg1Services(originId, junctions);
    final leg2ByJunction = await _fetchLeg2Services(junctions, destinationId, destStation);

    final List<ConnectingRoute> routes = [];
    final Set<int> seenJunctionIds = {};

    for (final junction in junctions) {
      seenJunctionIds.add(junction.id);
      final leg1 = leg1ByJunction[junction.id] ?? const <BusService>[];
      final leg2 = leg2ByJunction[junction.id] ?? const <BusService>[];

      if (leg1.isNotEmpty && leg2.isNotEmpty) {
        routes.add(
          ConnectingRoute(
            junction: junction,
            leg1Count: leg1.length,
            leg2Count: leg2.length,
            leg1Services: leg1,
            leg2Services: leg2,
          ),
        );
      }
    }

    // 3. If fewer than 2 routes found, evaluate major Maharashtra divisional hubs
    if (routes.length < 2) {
      final hubQuery = await db.rawQuery(
        '''
        SELECT * FROM stations 
        WHERE is_depot = 1 
          AND id != ? 
          AND id != ?
        ORDER BY id ASC 
        LIMIT 20
        ''',
        [originId, destinationId],
      );
      final hubs = hubQuery.map(Station.fromMap).toList();

      // Batch both legs for all hubs in 2 queries instead of 2 per hub.
      final hubLeg1 = await _fetchLeg1Services(originId, hubs);
      final hubLeg2 = await _fetchLeg2Services(hubs, destinationId, destStation);

      for (final hub in hubs) {
        if (seenJunctionIds.contains(hub.id)) continue;

        final leg1 = hubLeg1[hub.id] ?? const <BusService>[];
        if (leg1.isEmpty) continue;

        final leg2 = hubLeg2[hub.id] ?? const <BusService>[];
        if (leg2.isEmpty) continue;

        seenJunctionIds.add(hub.id);
        routes.add(
          ConnectingRoute(
            junction: hub,
            leg1Count: leg1.length,
            leg2Count: leg2.length,
            leg1Services: leg1,
            leg2Services: leg2,
          ),
        );

        if (routes.length >= 4) break;
      }
    }

    routes.sort((a, b) => b.totalFrequencyScore.compareTo(a.totalFrequencyScore));
    return routes;
  }

  /// One query that returns every service from [originId] which either
  /// terminates at or passes through any of [stations], grouped by station id.
  /// Replicates the per-junction `getServicesBetween(origin, station)` calls.
  Future<Map<int, List<BusService>>> _fetchLeg1Services(int originId, List<Station> stations) async {
    if (stations.isEmpty) return const {};
    final db = await database;

    final ids = stations.map((s) => s.id).toList();
    final idPlaceholders = List.filled(ids.length, '?').join(',');

    final viaPatterns = <String>[];
    final viaArgs = <Object>[];
    for (final s in stations) {
      if (s.nameEn.isNotEmpty) {
        viaPatterns.add('s.via_stops LIKE ?');
        viaArgs.add('%${s.nameEn}%');
      }
      if (s.nameMr.isNotEmpty) {
        viaPatterns.add('s.via_stops LIKE ?');
        viaArgs.add('%${s.nameMr}%');
      }
    }
    final viaClause = viaPatterns.isEmpty ? '' : ' OR (${viaPatterns.join(' OR ')})';

    final result = await db.rawQuery(
      '''
      SELECT 
        s.*,
        o.id as o_id, o.name_en as o_en, o.name_mr as o_mr, o.is_depot as o_depot,
        d.id as d_id, d.name_en as d_en, d.name_mr as d_mr, d.is_depot as d_depot
      FROM services s
      JOIN stations o ON s.origin_id = o.id
      JOIN stations d ON s.destination_id = d.id
      WHERE s.origin_id = ? AND (s.destination_id IN ($idPlaceholders)$viaClause)
      ORDER BY s.dep_minutes ASC
      ''',
      [originId, ...ids, ...viaArgs],
    );

    // Distribute each service to every station it terminates at or passes
    // through, mirroring the original per-junction LIKE matching.
    final grouped = <int, List<BusService>>{};
    for (final row in result) {
      final service = _rowToService(row);
      for (final station in stations) {
        if (service.destination.id == station.id || _viaMatches(service.viaStops, station)) {
          grouped.putIfAbsent(station.id, () => []).add(service);
        }
      }
    }
    return grouped;
  }

  /// One query that returns every service from any of [stations] which either
  /// terminates at or passes through [destinationId], grouped by station id.
  /// Replicates the per-junction `getServicesBetween(station, destination)` calls.
  Future<Map<int, List<BusService>>> _fetchLeg2Services(
    List<Station> stations,
    int destinationId,
    Station? destStation,
  ) async {
    if (stations.isEmpty) return const {};
    final db = await database;

    final ids = stations.map((s) => s.id).toList();
    final idPlaceholders = List.filled(ids.length, '?').join(',');

    final destNameEn = destStation?.nameEn ?? '';
    final destNameMr = destStation?.nameMr ?? '';

    final result = await db.rawQuery(
      '''
      SELECT 
        s.*,
        o.id as o_id, o.name_en as o_en, o.name_mr as o_mr, o.is_depot as o_depot,
        d.id as d_id, d.name_en as d_en, d.name_mr as d_mr, d.is_depot as d_depot
      FROM services s
      JOIN stations o ON s.origin_id = o.id
      JOIN stations d ON s.destination_id = d.id
      WHERE s.origin_id IN ($idPlaceholders) AND (
        s.destination_id = ?
        OR (s.via_stops LIKE ? AND ? != '')
        OR (s.via_stops LIKE ? AND ? != '')
      )
      ORDER BY s.dep_minutes ASC
      ''',
      [...ids, destinationId, '%$destNameEn%', destNameEn, '%$destNameMr%', destNameMr],
    );

    // Every returned service already satisfies the destination condition, so
    // its origin station is the only junction it can belong to.
    final grouped = <int, List<BusService>>{};
    for (final row in result) {
      final service = _rowToService(row);
      grouped.putIfAbsent(service.origin.id, () => []).add(service);
    }
    return grouped;
  }

  /// Case-insensitive check matching SQLite LIKE semantics for ASCII text.
  bool _viaMatches(String viaStops, Station station) {
    if (viaStops.isEmpty) return false;
    final via = viaStops.toLowerCase();
    if (station.nameEn.isNotEmpty && via.contains(station.nameEn.toLowerCase())) return true;
    if (station.nameMr.isNotEmpty && via.contains(station.nameMr.toLowerCase())) return true;
    return false;
  }

  BusService _rowToService(Map<String, dynamic> row) {
    final origin = Station(
      id: row['o_id'] as int,
      nameEn: row['o_en'] as String,
      nameMr: row['o_mr'] as String,
      isDepot: (row['o_depot'] as int?) == 1,
    );
    final destination = Station(
      id: row['d_id'] as int,
      nameEn: row['d_en'] as String,
      nameMr: row['d_mr'] as String,
      isDepot: (row['d_depot'] as int?) == 1,
    );
    return BusService.fromMap(row, origin, destination);
  }

  /// Returns the top destination stations with the highest departure counts from the given origin depot
  Future<List<Map<String, dynamic>>> getFrequentDestinationsFromOrigin(int originId, {int limit = 8}) async {
    final db = await database;
    final result = await db.rawQuery(
      '''
      SELECT 
        d.id as id, d.name_en as name_en, d.name_mr as name_mr, d.is_depot as is_depot,
        COUNT(s.id) as service_count
      FROM services s
      JOIN stations d ON s.destination_id = d.id
      WHERE s.origin_id = ?
      GROUP BY d.id
      ORDER BY service_count DESC
      LIMIT ?
      ''',
      [originId, limit],
    );
    return result;
  }
}

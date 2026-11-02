import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:st_saathi/models/station.dart';
import 'package:st_saathi/models/bus_service.dart';
import 'package:st_saathi/core/localization/app_strings.dart';
import 'package:st_saathi/presentation/widgets/enamel_bus_card.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Model & Logic Tests', () {
    test('Station bilingual resolution test', () {
      const station = Station(
        id: 1,
        nameEn: 'Amravati',
        nameMr: 'अमरावती',
        isDepot: true,
      );

      expect(station.displayName(false), 'Amravati');
      expect(station.displayName(true), 'अमरावती');
      expect(station.secondaryName(false), 'अमरावती');
      expect(station.secondaryName(true), 'Amravati');
    });

    test('Devanagari numeral conversion test', () {
      expect(AppStrings.toDevanagariDigits('06:30', true), '०६:३०');
      expect(AppStrings.toDevanagariDigits('06:30', false), '06:30');
      expect(AppStrings.toDevanagariDigits('11,109', true), '११,१०९');
    });

    test('Bus service via stops splitting', () {
      const origin = Station(id: 1, nameEn: 'Amravati', nameMr: 'अमरावती', isDepot: true);
      const dest = Station(id: 2, nameEn: 'Akot', nameMr: 'आकोट', isDepot: false);
      const service = BusService(
        id: 101,
        origin: origin,
        destination: dest,
        departureTime: '06:30',
        depMinutes: 390,
        busType: 'Ordinary',
        viaStops: 'Kurha, Tiwsa, Badnera',
        sourceDepot: 'Amravati Central',
        verified: true,
      );

      expect(service.viaList.length, 3);
      expect(service.viaList[0], 'Kurha');
      expect(service.viaList[1], 'Tiwsa');
      expect(service.viaList[2], 'Badnera');
    });
  });

  group('Widget Tests', () {
    testWidgets('EnamelBusCard renders authentic bus board destination and departure', (WidgetTester tester) async {
      const origin = Station(id: 1, nameEn: 'Amravati', nameMr: 'अमरावती', isDepot: true);
      const dest = Station(id: 2, nameEn: 'Akot', nameMr: 'आकोट', isDepot: false);
      const service = BusService(
        id: 101,
        origin: origin,
        destination: dest,
        departureTime: '06:30',
        depMinutes: 390,
        busType: 'Ordinary',
        viaStops: 'Paratwada',
        sourceDepot: 'Amravati Central',
        verified: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EnamelBusCard(
              service: service,
              isMarathi: false,
              is24Hour: true,
              isSaved: false,
              onToggleSave: () {},
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('AKOT'), findsOneWidget);
      expect(find.text('06:30'), findsOneWidget);
      expect(find.text('ORDINARY'), findsOneWidget);
    });
  });
}

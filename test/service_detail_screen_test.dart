import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:st_saathi/core/app_state.dart';
import 'package:st_saathi/models/bus_service.dart';
import 'package:st_saathi/models/station.dart';
import 'package:st_saathi/presentation/screens/service_detail_screen.dart';

/// Widget tests for the service detail screen. Focus on the parts touched by
/// the Phase 2 stop-list refactor (the Stack-based rail) and the bookmark
/// toggle.
///
/// The screen runs a 60-second periodic timer, so every test unmounts it at
/// the end or flutter_test reports a pending timer.
void main() {
  const origin = Station(id: 1, nameEn: 'Pune', nameMr: 'पुणे', isDepot: true);
  const destination = Station(id: 3, nameEn: 'Malegaon', nameMr: 'मालेगाव', isDepot: true);

  BusService makeService({String viaStops = ''}) {
    return BusService(
      id: 10,
      origin: origin,
      destination: destination,
      departureTime: '06:00',
      depMinutes: 360,
      busType: 'Shivneri',
      viaStops: viaStops,
      sourceDepot: 'Pune',
      verified: true,
    );
  }

  Widget wrap(BusService service, {bool isMarathi = false, bool isSaved = false, VoidCallback? onToggle}) {
    final appState = AppState()..setMarathi(isMarathi);
    return MaterialApp(
      home: ServiceDetailScreen(
        service: service,
        appState: appState,
        isSaved: isSaved,
        onToggleSave: onToggle ?? () {},
      ),
    );
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }

  testWidgets('shows origin, destination and departure time', (tester) async {
    await tester.pumpWidget(wrap(makeService()));
    await tester.pumpAndSettle();

    expect(find.textContaining('06:00'), findsWidgets);
    expect(find.text('SHIVNERI'), findsWidgets);
    await unmount(tester);
  });

  testWidgets('renders every via stop on the route', (tester) async {
    // 30+ stops is the case that used to stutter; the Stack refactor must
    // still lay all of them out.
    final stops = List.generate(32, (i) => 'Stop ${i + 1}');
    await tester.pumpWidget(wrap(makeService(viaStops: stops.join(', '))));
    await tester.pumpAndSettle();

    for (final stop in stops) {
      expect(find.text(stop), findsWidgets);
    }
    await unmount(tester);
  });

  testWidgets('bookmark button toggles and calls back', (tester) async {
    var toggles = 0;
    await tester.pumpWidget(wrap(makeService(), onToggle: () => toggles++));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bookmark Service'));
    await tester.pumpAndSettle();

    expect(toggles, 1);
    expect(find.text('Saved'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('shows Marathi labels when the language flag is on', (tester) async {
    await tester.pumpWidget(wrap(makeService(), isMarathi: true));
    await tester.pumpAndSettle();

    expect(find.text('आगार'), findsWidgets);
    await unmount(tester);
  });
}

import 'station.dart';
import 'bus_service.dart';

class ConnectingRoute {
  final Station junction;
  final int leg1Count;
  final int leg2Count;
  final List<BusService> leg1Services;
  final List<BusService> leg2Services;

  const ConnectingRoute({
    required this.junction,
    required this.leg1Count,
    required this.leg2Count,
    required this.leg1Services,
    required this.leg2Services,
  });

  int get totalFrequencyScore => leg1Count + leg2Count;
}

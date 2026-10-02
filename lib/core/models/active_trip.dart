import 'destination.dart';

enum TripStatus { idle, active, arrived }

class ActiveTrip {
  final Destination destination;
  final DateTime startTime;
  final TripStatus status;

  const ActiveTrip({
    required this.destination,
    required this.startTime,
    this.status = TripStatus.active,
  });

  ActiveTrip copyWith({TripStatus? status}) {
    return ActiveTrip(
      destination: destination,
      startTime: startTime,
      status: status ?? this.status,
    );
  }
}

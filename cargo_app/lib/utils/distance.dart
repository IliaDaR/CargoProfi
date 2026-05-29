import 'dart:math';

/// Вычисляет расстояние между двумя GPS-точками по формуле гаверсинусов.
/// Возвращает расстояние в километрах.
double haversineDistance(double lat1, double lon1, double lat2, double lon2) {
  const double earthRadiusKm = 6371.0;

  final double dLat = _toRadians(lat2 - lat1);
  final double dLon = _toRadians(lon2 - lon1);

  final double a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_toRadians(lat1)) *
          cos(_toRadians(lat2)) *
          sin(dLon / 2) *
          sin(dLon / 2);

  final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

  return earthRadiusKm * c;
}

/// Вычисляет суммарное расстояние по массиву координат в километрах.
double calculateTotalDistance(List<Map<String, double>> track) {
  if (track.length < 2) return 0.0;

  double total = 0.0;
  for (int i = 1; i < track.length; i++) {
    total += haversineDistance(
      track[i - 1]['latitude']!,
      track[i - 1]['longitude']!,
      track[i]['latitude']!,
      track[i]['longitude']!,
    );
  }

  return (total * 10).roundToDouble() / 10; // округляем до 0.1 км
}

double _toRadians(double degrees) => degrees * pi / 180.0;

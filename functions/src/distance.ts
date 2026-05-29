import {GeoPoint} from "./types";

const EARTH_RADIUS_KM = 6371;

function toRadians(degrees: number): number {
  return (degrees * Math.PI) / 180;
}

/**
 * Вычисляет расстояние между двумя точками (широта/долгота)
 * по формуле гаверсинусов. Возвращает километры.
 */
export function haversineDistance(
  lat1: number,
  lon1: number,
  lat2: number,
  lon2: number
): number {
  const dLat = toRadians(lat2 - lat1);
  const dLon = toRadians(lon2 - lon1);

  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRadians(lat1)) *
      Math.cos(toRadians(lat2)) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);

  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

  return EARTH_RADIUS_KM * c;
}

/**
 * Вычисляет суммарное расстояние по массиву GPS-точек.
 * Точки должны быть отсортированы по времени.
 * Возвращает километры, округлённые до 1 знака после запятой.
 */
export function calculateTotalDistance(track: GeoPoint[]): number {
  if (!track || track.length < 2) {
    return 0;
  }

  let totalDistance = 0;

  for (let i = 1; i < track.length; i++) {
    const prev = track[i - 1];
    const curr = track[i];

    totalDistance += haversineDistance(
      prev.latitude,
      prev.longitude,
      curr.latitude,
      curr.longitude
    );
  }

  return Math.round(totalDistance * 10) / 10;
}

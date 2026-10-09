import type { Coordinate } from "../../ExpoMapboxNavigation.types";

export interface RouteChunk {
  start: number;
  end: number;
  coordinates: Coordinate[];
}
export function createRouteChunks(coordinates: Coordinate[]): RouteChunk[] {
  const chunks: RouteChunk[] = [];
  for (let start = 0; start < coordinates.length - 1; start += 80) {
    const end = Math.min(start + 99, coordinates.length - 1);
    chunks.push({ start, end, coordinates: coordinates.slice(start, end + 1) });
    if (end === coordinates.length - 1) break;
  }
  return chunks;
}
export function isValidCoordinate(point: Coordinate): boolean {
  return (
    Number.isFinite(point.latitude) &&
    Number.isFinite(point.longitude) &&
    Math.abs(point.latitude) <= 90 &&
    Math.abs(point.longitude) <= 180
  );
}
export function routeIdentity(coordinates: Coordinate[]): string {
  let hash = 2166136261;
  for (const point of coordinates) {
    const value = point.latitude + "," + point.longitude + ";";
    for (let index = 0; index < value.length; index++)
      hash = Math.imul(hash ^ value.charCodeAt(index), 16777619);
  }
  return coordinates.length + "-" + (hash >>> 0).toString(16);
}
export function distanceBetween(first: Coordinate, second: Coordinate): number {
  const radians = Math.PI / 180;
  const latitude = (second.latitude - first.latitude) * radians;
  const longitude = (second.longitude - first.longitude) * radians;
  const a =
    Math.sin(latitude / 2) ** 2 +
    Math.cos(first.latitude * radians) *
      Math.cos(second.latitude * radians) *
      Math.sin(longitude / 2) ** 2;
  return (
    6371008.8 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(Math.max(0, 1 - a)))
  );
}
export function cumulativeDistances(coordinates: Coordinate[]): number[] {
  const distances = [0];
  for (let index = 1; index < coordinates.length; index++)
    distances.push(
      distances[index - 1] +
        distanceBetween(coordinates[index - 1], coordinates[index])
    );
  return distances;
}
export interface RouteProjection {
  index: number;
  distance: number;
  offset: number;
}
export function projectLocation(
  coordinates: Coordinate[],
  distances: number[],
  location: Coordinate,
  start = 0,
  end = coordinates.length - 1,
  previousDistance?: number
): RouteProjection {
  let result = {
    index: start,
    distance: distances[start] || 0,
    offset: Infinity,
  };
  const scaleX = Math.cos((location.latitude * Math.PI) / 180) * 111195.08;
  for (let index = start; index < end; index++) {
    const first = coordinates[index],
      second = coordinates[index + 1];
    const ax = (first.longitude - location.longitude) * scaleX;
    const ay = (first.latitude - location.latitude) * 111195.08;
    const bx = (second.longitude - first.longitude) * scaleX;
    const by = (second.latitude - first.latitude) * 111195.08;
    const length = bx * bx + by * by;
    const fraction = length
      ? Math.max(0, Math.min(1, -(ax * bx + ay * by) / length))
      : 0;
    const offset = Math.hypot(ax + bx * fraction, ay + by * fraction);
    const distance =
      distances[index] + (distances[index + 1] - distances[index]) * fraction;
    const tied = Math.abs(offset - result.offset) < 1;
    if (
      offset < result.offset - 1 ||
      (tied &&
        previousDistance !== undefined &&
        Math.abs(distance - previousDistance) <
          Math.abs(result.distance - previousDistance))
    )
      result = { index, distance, offset };
  }
  return result;
}
export function chunkForProjection(
  chunks: RouteChunk[],
  projection: RouteProjection
): number {
  let index = 0;
  while (
    index + 1 < chunks.length &&
    projection.index >= chunks[index + 1].start + 5
  )
    index++;
  return index;
}

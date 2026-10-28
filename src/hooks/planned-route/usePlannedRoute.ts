import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { AppState } from "react-native";
import { navigationStrings } from "../../utils/localization/navigationLocale";
import type {
  Coordinate,
  ExpoMapboxNavigationViewProps,
  GuidanceState,
  ProgressEvent,
} from "../../ExpoMapboxNavigation.types";
import {
  chunkForProjection,
  createRouteChunks,
  cumulativeDistances,
  isValidCoordinate,
  projectLocation,
  routeIdentity,
} from "../../utils/planned-route/routeGeometry";

const EMPTY_COORDINATES: Coordinate[] = [];

export function usePlannedRoute(
  props: ExpoMapboxNavigationViewProps
): ExpoMapboxNavigationViewProps {
  const planned = props.routeMode === "planned";
  const valid =
    props.coordinates.length >= 2 && props.coordinates.every(isValidCoordinate);
  const identity = useMemo(
    () => routeIdentity(props.coordinates),
    [props.coordinates]
  );
  const chunks = useMemo(
    () => createRouteChunks(props.coordinates),
    [props.coordinates]
  );
  const distances = useMemo(
    () => cumulativeDistances(props.coordinates),
    [props.coordinates]
  );
  const [chunkIndex, setChunkIndex] = useState(0);
  const [attempt, setAttempt] = useState(0);
  const [readyRevision, setReadyRevision] = useState("");
  const [onRoute, setOnRoute] = useState(false);
  const [hasRouteLocation, setHasRouteLocation] = useState(false);
  const progressRef = useRef<number | undefined>(undefined);
  const routeLocationRef = useRef<{ identity: string; inside?: boolean }>({ identity });
  const [progress, setProgress] = useState<ProgressEvent>({
    distanceRemaining: 0,
    distanceTraveled: 0,
    durationRemaining: 0,
    fractionTraveled: 0,
  });
  const [state, setState] = useState<GuidanceState>("preparing");
  const [guidanceError, setGuidanceError] = useState<string | undefined>(undefined);
  const active = Math.min(chunkIndex, Math.max(0, chunks.length - 1));
  const requestedTolerance = props.routeDeviationTolerance;
  const tolerance = requestedTolerance && Number.isFinite(requestedTolerance) && requestedTolerance > 0 && requestedTolerance <= 50 ? requestedTolerance : 25;
  const revision = identity + ":" + active + ":" + attempt + ":" + (props.locale || "default") + ":" + tolerance;
  const waypointIndices = useMemo(
    () => (chunks[active] ? [0, chunks[active].coordinates.length - 1] : []),
    [chunks, active]
  );
  const notify = useCallback(
    (next: GuidanceState, errorMessage?: string) => {
      setState(next);
      setGuidanceError(errorMessage);
    },
    []
  );
  // GPS classification alone does not mean the SDK has a guide to present.
  const presentedState: GuidanceState = !valid || (hasRouteLocation && !onRoute) || state === "unavailable"
    ? "unavailable"
    : hasRouteLocation && onRoute && readyRevision === revision ? "available" : "preparing";
  useEffect(() => {
    if (planned) props.onGuidanceStateChanged?.({ nativeEvent: { state: presentedState, errorMessage: guidanceError } });
  }, [planned, presentedState, guidanceError, props.onGuidanceStateChanged]);
  useEffect(() => {
    setChunkIndex(0);
    setAttempt(0);
    setReadyRevision("");
    setOnRoute(false);
    setHasRouteLocation(false);
    const total =
      props.plannedRouteDistance || distances[distances.length - 1] || 0;
    setProgress({
      distanceRemaining: total,
      distanceTraveled: 0,
      durationRemaining: props.plannedRouteDuration || 0,
      fractionTraveled: 0,
    });
    progressRef.current = undefined;
    routeLocationRef.current = { identity };
    notify(
      valid ? "preparing" : "unavailable",
      valid ? undefined : navigationStrings(props.locale).invalidRouteGeometry
    );
  }, [identity, valid]);
  useEffect(() => {
    if (!valid) notify("unavailable", navigationStrings(props.locale).invalidRouteGeometry);
    else if (planned) notify("preparing");
  }, [revision, planned, valid]);
  useEffect(() => {
    if (!planned || state !== "unavailable" || !valid) return;
    const retry = () => {
      setAttempt((value) => value + 1);
      notify("preparing");
    };
    const timer = setTimeout(retry, 15000);
    const subscription = AppState.addEventListener("change", (next) => {
      if (next === "active") retry();
    });
    return () => {
      clearTimeout(timer);
      subscription.remove();
    };
  }, [planned, state, valid, notify]);
  const onLocation = useCallback(
    (event: { nativeEvent: Coordinate }) => {
      if (!planned || !valid || !isValidCoordinate(event.nativeEvent)) return;
      if (routeLocationRef.current.identity !== identity) return;
      const projection = projectLocation(
        props.coordinates,
        distances,
        event.nativeEvent,
        0,
        props.coordinates.length - 1,
        progressRef.current
      );
      const inside = projection.offset <= tolerance;
      const previousInside = routeLocationRef.current.inside;
      routeLocationRef.current.inside = inside;
      setHasRouteLocation(true);
      setOnRoute(inside);
      if (!inside) {
        if (previousInside !== false) props.onUserOffRoute?.();
        return;
      }
      progressRef.current = projection.distance;
      setChunkIndex(chunkForProjection(chunks, projection));
      const total = distances[distances.length - 1] || 0;
      const fraction = total ? Math.min(1, projection.distance / total) : 0;
      const distance =
        props.plannedRouteDistance && props.plannedRouteDistance > 0
          ? props.plannedRouteDistance
          : total;
      const next = {
        distanceRemaining: distance * (1 - fraction),
        distanceTraveled: distance * fraction,
        durationRemaining: (props.plannedRouteDuration || 0) * (1 - fraction),
        fractionTraveled: fraction,
      };
      setProgress(next);
      props.onRouteProgressChanged?.({ nativeEvent: next });
    },
    [
      planned,
      valid,
      identity,
      props.coordinates,
      distances,
      tolerance,
      chunks,
      props.plannedRouteDistance,
      props.plannedRouteDuration,
      props.onRouteProgressChanged,
      props.onUserOffRoute,
    ]
  );
  const onLoaded: NonNullable<
    ExpoMapboxNavigationViewProps["onRoutesLoaded"]
  > = (event) => {
    if (!planned) {
      props.onRoutesLoaded?.(event);
      return;
    }
    if (
      (event.nativeEvent as { routeRevision?: string }).routeRevision !==
      revision
    )
      return;
    setReadyRevision(revision);
    notify("available");
    props.onRoutesLoaded?.(event);
  };
  const onFailed: NonNullable<
    ExpoMapboxNavigationViewProps["onRouteFailedToLoad"]
  > = (event) => {
    if (!planned) {
      props.onRouteFailedToLoad?.(event);
      return;
    }
    if (
      (event.nativeEvent as { routeRevision?: string }).routeRevision !==
      revision
    )
      return;
    setReadyRevision("");
    notify("unavailable", event.nativeEvent.errorMessage);
    props.onRouteFailedToLoad?.(event);
  };
  if (!planned) return props;
  return {
    ...props,
    coordinates: valid
      ? chunks[active]?.coordinates || EMPTY_COORDINATES
      : EMPTY_COORDINATES,
    plannedRouteCoordinates: valid ? props.coordinates : EMPTY_COORDINATES,
    prefetchCoordinates: chunks[active + 1]?.coordinates || EMPTY_COORDINATES,
    routeRevision: revision,
    guidanceEnabled: onRoute && readyRevision === revision,
    isOnPlannedRoute: hasRouteLocation ? onRoute : undefined,
    guidanceStatus:
      hasRouteLocation && !onRoute
        ? "off-route"
        : !valid || state === "unavailable"
        ? "unavailable"
        : readyRevision !== revision
          ? "preparing"
          : onRoute
            ? "available"
            : "off-route",
    isFinalRouteChunk: active === chunks.length - 1,
    plannedRouteProgress: progress,
    waypointIndices,
    useRouteMatchingApi: true,
    reroutingEnabled: false,
    disableAlternativeRoutes: true,
    onPlannedRouteLocation: onLocation,
    onRoutesLoaded: onLoaded,
    onRouteFailedToLoad: onFailed,
    onRouteProgressChanged: undefined,
    onWaypointArrival: undefined,
    onFinalDestinationArrival:
      active === chunks.length - 1
        ? props.onFinalDestinationArrival
        : undefined,
    onRouteChanged: undefined,
    // SDK deviations describe the matched window, not the original planned trace.
    onUserOffRoute: undefined,
  };
}

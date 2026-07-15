//@ts-ignore
import { ViewStyle, StyleProp } from "react-native/types";
import { Ref } from "react";

type ProgressEvent = {
  distanceRemaining: number;
  distanceTraveled: number;
  durationRemaining: number;
  fractionTraveled: number;
};

type Route = {
  distance: number;
  expectedTravelTime: number;
  legs: Array<{
    source?: { latitude: number; longitude: number };
    destination?: { latitude: number; longitude: number };
    steps: Array<{
      shape?: {
        coordinates: Array<{ latitude: number; longitude: number }>;
      };
    }>;
  }>;
};

type Routes = {
  mainRoute: Route;
  alternativeRoutes: Route[];
};

export type Marker = {
  id: string;
  latitude: number;
  longitude: number;
  title?: string;
  description?: string;
  iconName?: string;
  /**
   * Color of the marker in hex format (e.g., "#1FBF8F") or rgb format (e.g., "rgb(31, 191, 143)")
   * Default is red (#FF0000)
   */
  color?: string;
  /**
   * If true, allows navigating to this marker (shows "Navegar aquí" and uses navigation flow).
   * If false, the marker is informational only and navigation to it is not offered.
   * Default is false when omitted.
   */
  canNavigate?: boolean;
  /**
   * Letter shown on the marker icon (e.g. "P" for Parada, "S" for Stop).
   * Use based on app language for authorized stops.
   */
  markerLetter?: string;
};

export type ExpoMapboxNavigationViewRef = {
  recenterMap: () => void;
};

export type ExpoMapboxNavigationViewProps = {
  ref?: Ref<ExpoMapboxNavigationViewRef>;
  coordinates: Array<{ latitude: number; longitude: number }>;
  waypointIndices?: number[];
  useRouteMatchingApi?: boolean;
  locale?: string;
  routeProfile?: string;
  routeExcludeList?: string[];
  mapStyle?: string;
  mute?: boolean;
  vehicleMaxHeight?: number;
  vehicleMaxWidth?: number;
  initialLocation?: { latitude: number; longitude: number; zoom?: number };
  /**
   * The URL of the custom raster source to use for the map.
   * Should be a template string with {x}, {y}, {z} placeholders.
   * Example: "https://tile.openstreetmap.org/{z}/{x}/{y}.png"
   */
  customRasterSourceUrl?: string;
  placeCustomRasterLayerAbove?: string;
  disableAlternativeRoutes?: boolean;
  followingZoom?: number;
  /**
   * Determina si se muestra el botón de cancelar navegación.
   * Por defecto es true.
   */
  showCancelButton?: boolean;
  /**
   * Texto a mostrar en la parte inferior sobre o dentro del banner nativo
   */
  bottomLegend?: string;
  /**
   * Array of custom markers to display on the map during navigation.
   */
  markers?: Marker[];
  /**
   * Called when a marker is pressed.
   */
  onMarkerPress?: (event: { nativeEvent: Marker }) => void;
  onRouteProgressChanged?: (event: { nativeEvent: ProgressEvent }) => void;
  onCancelNavigation?: () => void;
  onWaypointArrival?: (event: {
    nativeEvent: ProgressEvent | undefined;
  }) => void;
  onFinalDestinationArrival?: () => void;
  onRouteChanged?: () => void;
  onUserOffRoute?: () => void;
  onRoutesLoaded?: (event: { nativeEvent: { routes: Routes } }) => void;
  onRouteFailedToLoad?: (event: {
    nativeEvent: { errorMessage: string };
  }) => void;
  style?: StyleProp<ViewStyle>;
};

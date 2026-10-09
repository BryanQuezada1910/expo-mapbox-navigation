import { requireNativeViewManager } from "expo-modules-core";
import * as React from "react";
import { usePlannedRoute } from "./hooks/planned-route/usePlannedRoute";

import {
  ExpoMapboxNavigationViewProps,
  ExpoMapboxNavigationViewRef,
} from "./ExpoMapboxNavigation.types";

const NativeView: React.ComponentType<ExpoMapboxNavigationViewProps> =
  requireNativeViewManager("ExpoMapboxNavigation");

export default React.forwardRef<
  ExpoMapboxNavigationViewRef,
  ExpoMapboxNavigationViewProps
>((props, ref) => {
  const navigationProps = usePlannedRoute(props);
  return <NativeView {...navigationProps} ref={ref} />;
});

import * as React from "react";

import { ExpoMapboxNavigationViewProps } from "./ExpoMapboxNavigation.types";
import { navigationStrings } from "./utils/localization/navigationLocale";

export default function ExpoMapboxNavigationView(
  props: ExpoMapboxNavigationViewProps
) {
  return (
    <div>
      <span>{navigationStrings(props.locale).webUnsupported}</span>
    </div>
  );
}

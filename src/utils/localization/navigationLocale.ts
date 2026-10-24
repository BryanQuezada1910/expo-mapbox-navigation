import catalog from "../../configs/localization/navigationStrings.json";

export function navigationLanguage(locale?: string): keyof typeof catalog {
  const requested = locale?.trim();
  const language = !requested || requested.toLowerCase() === "default"
    ? Intl.DateTimeFormat().resolvedOptions().locale
    : requested;
  return language.replace(/_/g, "-").split("-")[0].toLowerCase() === "en" ? "en" : "es";
}

export function navigationStrings(locale?: string) {
  return catalog[navigationLanguage(locale)];
}

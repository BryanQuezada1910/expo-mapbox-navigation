import { requireOptionalNativeModule } from 'expo-modules-core';

/** Plays a short sound bundled by the host app, independently of notification permission. */
export async function playAlertSound(soundName: string): Promise<void> {
  const native = requireOptionalNativeModule<{ playAlertSound?: (name: string) => Promise<void> }>('ExpoMapboxNavigation');
  if (!native?.playAlertSound) throw new Error('Rebuild the native app to enable alert sounds.');
  await native.playAlertSound(soundName);
}

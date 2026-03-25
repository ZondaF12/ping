import Constants from 'expo-constants';

/** Base URL of the Nest API (no trailing slash). */
export function getApiBaseUrl(): string {
  const fromEnv = process.env.EXPO_PUBLIC_API_URL;
  if (fromEnv && fromEnv.length > 0) return fromEnv.replace(/\/$/, '');
  const hostUri = Constants.expoConfig?.hostUri;
  if (__DEV__ && hostUri) {
    const host = hostUri.split(':')[0];
    if (host) return `http://${host}:3000`;
  }
  return 'http://127.0.0.1:3000';
}

import { useCallback, useEffect, useState } from 'react';
import {
  ActivityIndicator,
  Button,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { StatusBar } from 'expo-status-bar';
import * as Crypto from 'expo-crypto';
import * as Notifications from 'expo-notifications';
import * as SecureStore from 'expo-secure-store';
import { getApiBaseUrl } from './src/config';
import {
  openUrlFromNotificationResponse,
  registerForExpoPushTokenAsync,
  subscribeToNotificationResponses,
} from './src/notifications';

const SECRET_KEY = 'webhook_secret_v1';

async function getOrCreateSecret(): Promise<string> {
  const existing = await SecureStore.getItemAsync(SECRET_KEY);
  if (existing) return existing;
  const bytes = await Crypto.getRandomBytesAsync(24);
  const secret = `br_${Array.from(bytes, (b) => b.toString(16).padStart(2, '0')).join('')}`;
  await SecureStore.setItemAsync(SECRET_KEY, secret);
  return secret;
}

type Banner = { text: string; variant: 'info' | 'success' | 'error' };

export default function App() {
  const [secret, setSecret] = useState<string | null>(null);
  const [apiBase, setApiBase] = useState(getApiBaseUrl());
  const [banner, setBanner] = useState<Banner | null>(null);
  const [busy, setBusy] = useState(false);

  const webhookUrl =
    secret && apiBase ? `${apiBase}/v1/${encodeURIComponent(secret)}` : '';

  const registerWithApi = useCallback(
    async (s: string): Promise<{ ok: true; base: string } | { ok: false; banner: Banner }> => {
      const base = getApiBaseUrl();
      setApiBase(base);
      const expoPushToken = await registerForExpoPushTokenAsync();
      if (!expoPushToken) {
        return {
          ok: false,
          banner: {
            variant: 'error',
            text: 'No Expo push token (allow notifications in Settings, use a dev build or Expo Go, and ensure push is configured). The API was not contacted—webhook calls will return 404 until you register.',
          },
        };
      }
      const res = await fetch(`${base}/v1/register/${encodeURIComponent(s)}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ expoPushToken }),
      });
      if (!res.ok) {
        const body = await res.text();
        return {
          ok: false,
          banner: {
            variant: 'error',
            text: `Register failed: ${res.status} ${body}`,
          },
        };
      }
      return { ok: true, base };
    },
    [],
  );

  const registerDevice = useCallback(
    async (s: string) => {
      const result = await registerWithApi(s);
      if (!result.ok) {
        setBanner(result.banner);
        return;
      }
      setBanner({ variant: 'success', text: 'Registered with API.' });
    },
    [registerWithApi],
  );

  useEffect(() => {
    let sub: Notifications.Subscription | undefined;
    (async () => {
      try {
        const s = await getOrCreateSecret();
        setSecret(s);
        await registerDevice(s);

        const last = await Notifications.getLastNotificationResponseAsync();
        if (last) openUrlFromNotificationResponse(last);

        sub = subscribeToNotificationResponses((response) => {
          openUrlFromNotificationResponse(response);
        });
      } catch (e) {
        setBanner({
          variant: 'error',
          text: `Startup failed: ${e instanceof Error ? e.message : String(e)}`,
        });
      }
    })();
    return () => sub?.remove();
  }, [registerDevice]);

  const sendTest = async () => {
    if (!secret) return;
    setBusy(true);
    setBanner(null);
    try {
      const reg = await registerWithApi(secret);
      if (!reg.ok) {
        setBanner(reg.banner);
        return;
      }
      const { base } = reg;
      const res = await fetch(`${base}/v1/${encodeURIComponent(secret)}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          title: 'Ping test',
          subtitle: 'From the app',
          message: 'If you see this, the webhook works.',
          url: 'https://expo.dev',
        }),
      });
      const text = await res.text();
      if (!res.ok) {
        setBanner({
          variant: 'error',
          text: `Send failed: ${res.status} ${text}`,
        });
      } else {
        setBanner({
          variant: 'success',
          text: `Sent (${res.status}). ${text}`,
        });
      }
    } finally {
      setBusy(false);
    }
  };

  if (!secret) {
    return (
      <View style={styles.centered}>
        <ActivityIndicator size="large" />
        <Text style={styles.muted}>Preparing…</Text>
        <StatusBar style="auto" />
      </View>
    );
  }

  return (
    <ScrollView contentContainerStyle={styles.container}>
      <Text style={styles.title}>Ping</Text>
      <Text style={styles.label}>Webhook URL</Text>
      <Text selectable style={styles.mono}>
        {webhookUrl || '—'}
      </Text>
      <Text style={styles.hint}>
        Set EXPO_PUBLIC_API_URL to your API host if not using the default (
        {getApiBaseUrl()}).
      </Text>
      <View style={styles.actions}>
        <Button
          title="Re-register device"
          onPress={() => registerDevice(secret)}
          disabled={busy}
        />
        <View style={styles.gap} />
        <Button title="Send test notification" onPress={sendTest} disabled={busy} />
      </View>
      {busy ? <ActivityIndicator style={styles.spinner} /> : null}
      {banner ? (
        <Text
          style={[
            styles.banner,
            banner.variant === 'error' && styles.bannerError,
            banner.variant === 'success' && styles.bannerSuccess,
            banner.variant === 'info' && styles.bannerInfo,
          ]}
        >
          {banner.text}
        </Text>
      ) : null}
      <StatusBar style="auto" />
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    padding: 24,
    paddingTop: 56,
    backgroundColor: '#fff',
  },
  centered: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#fff',
  },
  title: {
    fontSize: 28,
    fontWeight: '700',
    marginBottom: 20,
  },
  label: {
    fontSize: 14,
    fontWeight: '600',
    marginBottom: 6,
    color: '#333',
  },
  mono: {
    fontFamily: 'monospace',
    fontSize: 12,
    color: '#111',
  },
  hint: {
    marginTop: 12,
    fontSize: 12,
    color: '#666',
  },
  actions: {
    marginTop: 24,
  },
  gap: { height: 12 },
  spinner: { marginTop: 16 },
  banner: {
    marginTop: 16,
    fontSize: 14,
  },
  bannerSuccess: { color: '#0a6b2f' },
  bannerError: { color: '#b00020' },
  bannerInfo: { color: '#333' },
  muted: { marginTop: 8, color: '#888' },
});

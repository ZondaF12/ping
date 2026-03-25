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

export default function App() {
  const [secret, setSecret] = useState<string | null>(null);
  const [apiBase, setApiBase] = useState(getApiBaseUrl());
  const [status, setStatus] = useState<string>('');
  const [busy, setBusy] = useState(false);

  const webhookUrl =
    secret && apiBase ? `${apiBase}/v1/${encodeURIComponent(secret)}` : '';

  const registerDevice = useCallback(async (s: string) => {
    const base = getApiBaseUrl();
    setApiBase(base);
    const expoPushToken = await registerForExpoPushTokenAsync();
    if (!expoPushToken) {
      setStatus('Push permission denied or token unavailable.');
      return;
    }
    const res = await fetch(`${base}/v1/register/${encodeURIComponent(s)}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ expoPushToken }),
    });
    if (!res.ok) {
      setStatus(`Register failed: ${res.status}`);
      return;
    }
    setStatus('Registered with API.');
  }, []);

  useEffect(() => {
    let sub: Notifications.Subscription | undefined;
    (async () => {
      const s = await getOrCreateSecret();
      setSecret(s);
      await registerDevice(s);

      const last = await Notifications.getLastNotificationResponseAsync();
      if (last) openUrlFromNotificationResponse(last);

      sub = subscribeToNotificationResponses((response) => {
        openUrlFromNotificationResponse(response);
      });
    })();
    return () => sub?.remove();
  }, [registerDevice]);

  const sendTest = async () => {
    if (!secret) return;
    setBusy(true);
    setStatus('');
    try {
      const base = getApiBaseUrl();
      setApiBase(base);
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
      if (!res.ok) setStatus(`Send failed: ${res.status} ${text}`);
      else setStatus(`Sent (${res.status}). ${text}`);
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
      {status ? <Text style={styles.status}>{status}</Text> : null}
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
  status: { marginTop: 16, fontSize: 14, color: '#0a0' },
  muted: { marginTop: 8, color: '#888' },
});

import * as Linking from 'expo-linking';
import * as Notifications from 'expo-notifications';
import Constants from 'expo-constants';
import { Platform } from 'react-native';

Notifications.setNotificationHandler({
  handleNotification: async () => ({
    shouldPlaySound: true,
    shouldSetBadge: false,
    shouldShowBanner: true,
    shouldShowList: true,
  }),
});

function readUrlFromData(data: Record<string, unknown> | undefined): string | undefined {
  const url = data?.url;
  return typeof url === 'string' && url.length > 0 ? url : undefined;
}

export function openUrlFromNotificationResponse(
  response: Notifications.NotificationResponse,
): void {
  const url = readUrlFromData(
    response.notification.request.content.data as Record<string, unknown> | undefined,
  );
  if (url) void Linking.openURL(url);
}

export async function registerForExpoPushTokenAsync(): Promise<string | null> {
  if (Platform.OS !== 'ios') return null;
  const { status: existing } = await Notifications.getPermissionsAsync();
  let finalStatus = existing;
  if (existing !== 'granted') {
    const { status } = await Notifications.requestPermissionsAsync();
    finalStatus = status;
  }
  if (finalStatus !== 'granted') return null;

  const projectId =
    Constants.expoConfig?.extra?.eas?.projectId ??
    Constants.easConfig?.projectId;
  const tokenData = await Notifications.getExpoPushTokenAsync(
    projectId ? { projectId } : undefined,
  );
  return tokenData.data;
}

export function subscribeToNotificationResponses(
  onResponse: (response: Notifications.NotificationResponse) => void,
): Notifications.Subscription {
  return Notifications.addNotificationResponseReceivedListener(onResponse);
}

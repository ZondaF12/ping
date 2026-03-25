import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import Expo, { ExpoPushMessage } from 'expo-server-sdk';

@Injectable()
export class ExpoPushService {
  private readonly log = new Logger(ExpoPushService.name);
  private readonly expo: Expo;

  constructor(private readonly config: ConfigService) {
    const accessToken = config.get<string>('EXPO_ACCESS_TOKEN');
    this.expo = new Expo(accessToken ? { accessToken } : undefined);
  }

  async sendToTokens(
    tokens: string[],
    message: Pick<ExpoPushMessage, 'title' | 'body' | 'subtitle' | 'data'>,
  ): Promise<{ invalidTokens: string[] }> {
    const invalidTokens: string[] = [];
    const valid = tokens.filter((t) => Expo.isExpoPushToken(t));
    for (const t of tokens) {
      if (!Expo.isExpoPushToken(t)) invalidTokens.push(t);
    }
    if (valid.length === 0) {
      return { invalidTokens };
    }
    const messages: ExpoPushMessage[] = valid.map((to) => ({
      to,
      sound: 'default',
      ...message,
    }));
    const chunks = this.expo.chunkPushNotifications(messages);
    for (const chunk of chunks) {
      try {
        const tickets = await this.expo.sendPushNotificationsAsync(chunk);
        tickets.forEach((ticket, i) => {
          if (ticket.status === 'error') {
            const token = chunk[i]?.to;
            if (
              typeof token === 'string' &&
              ticket.details?.error === 'DeviceNotRegistered'
            ) {
              invalidTokens.push(token);
            }
            this.log.warn(`Push ticket error: ${ticket.message}`);
          }
        });
      } catch (e) {
        this.log.error(`Expo send failed: ${e instanceof Error ? e.message : e}`);
        throw e;
      }
    }
    return { invalidTokens };
  }
}

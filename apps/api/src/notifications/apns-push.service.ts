import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createSign } from 'crypto';
import { connect } from 'http2';

export type ApnsTokenTarget = {
  token: string;
  apnsEnvironment?: 'sandbox' | 'production';
};

export type ApnsAlertMessage = {
  title?: string;
  body?: string;
  subtitle?: string;
  data?: Record<string, unknown>;
  imageUrl?: string;
  expirationDate?: Date;
  interruptionLevel?: 'passive' | 'active' | 'time-sensitive';
  filterCriteria?: string;
};

@Injectable()
export class ApnsPushService {
  private readonly log = new Logger(ApnsPushService.name);
  private readonly keyId: string;
  private readonly teamId: string;
  private readonly bundleId: string;
  private readonly privateKey: string;
  private readonly defaultHost: string;
  private readonly sandboxHost = 'https://api.sandbox.push.apple.com';
  private readonly productionHost = 'https://api.push.apple.com';
  private cachedToken: { value: string; expiresAtMs: number } | null = null;

  constructor(private readonly config: ConfigService) {
    this.keyId = this.require('APPLE_KEY_ID');
    this.teamId = this.require('APPLE_TEAM_ID');
    this.bundleId = this.require('APPLE_BUNDLE_ID');
    this.privateKey = this.loadPrivateKey();
    const useSandbox =
      this.config.get<string>('APPLE_APNS_USE_SANDBOX') !== 'false';
    this.defaultHost = useSandbox ? this.sandboxHost : this.productionHost;
  }

  private require(name: string): string {
    const value = this.config.get<string>(name)?.trim();
    if (!value) {
      throw new Error(`Missing required env var: ${name}`);
    }
    return value;
  }

  private loadPrivateKey(): string {
    const inline = this.config.get<string>('APPLE_APNS_KEY_P8')?.trim();
    if (inline) {
      return inline.replace(/\\n/g, '\n');
    }
    throw new Error('Missing required env var: APPLE_APNS_KEY_P8');
  }

  private base64url(input: string): string {
    return Buffer.from(input)
      .toString('base64')
      .replace(/=/g, '')
      .replace(/\+/g, '-')
      .replace(/\//g, '_');
  }

  private getAuthToken(): string {
    const nowMs = Date.now();
    if (this.cachedToken && nowMs < this.cachedToken.expiresAtMs) {
      return this.cachedToken.value;
    }
    const header = this.base64url(
      JSON.stringify({ alg: 'ES256', kid: this.keyId }),
    );
    const issuedAt = Math.floor(nowMs / 1000);
    const claims = this.base64url(
      JSON.stringify({ iss: this.teamId, iat: issuedAt }),
    );
    const body = `${header}.${claims}`;
    const signer = createSign('sha256');
    signer.update(body);
    signer.end();
    const signature = signer
      .sign(this.privateKey)
      .toString('base64')
      .replace(/=/g, '')
      .replace(/\+/g, '-')
      .replace(/\//g, '_');
    const token = `${body}.${signature}`;
    this.cachedToken = {
      value: token,
      expiresAtMs: nowMs + 50 * 60 * 1000,
    };
    return token;
  }

  private isLikelyApnsToken(token: string): boolean {
    return /^[a-f0-9]{64}$/i.test(token);
  }

  private errorMessage(error: unknown): string {
    if (error instanceof Error) {
      return error.message;
    }
    return String(error);
  }

  private resolveHost(target: ApnsTokenTarget): string {
    if (target.apnsEnvironment === 'sandbox') {
      return this.sandboxHost;
    }
    if (target.apnsEnvironment === 'production') {
      return this.productionHost;
    }
    return this.defaultHost;
  }

  /** @deprecated Prefer sendToTokenTargets for per-device environment */
  async sendToTokens(
    tokens: string[],
    message: ApnsAlertMessage,
  ): Promise<{ invalidTokens: string[]; acceptedTokens: string[] }> {
    return this.sendToTokenTargets(
      tokens.map((token) => ({ token })),
      message,
    );
  }

  private buildApnsPayload(message: ApnsAlertMessage): Record<string, unknown> {
    const alert: Record<string, string> = {};
    if (message.title) {
      alert.title = message.title;
    }
    if (message.subtitle) {
      alert.subtitle = message.subtitle;
    }
    if (message.body !== undefined && message.body !== '') {
      alert.body = message.body;
    }

    const aps: Record<string, unknown> = {
      alert:
        Object.keys(alert).length === 1 && alert.body !== undefined
          ? alert.body
          : alert,
      sound: 'default',
    };

    if (message.interruptionLevel) {
      aps['interruption-level'] = message.interruptionLevel;
    }
    if (message.filterCriteria) {
      aps['filter-criteria'] = message.filterCriteria;
    }
    if (message.imageUrl) {
      aps['mutable-content'] = 1;
    }

    const data: Record<string, unknown> = { ...(message.data ?? {}) };
    if (message.imageUrl) {
      data.image_url = message.imageUrl;
    }

    return { aps, ...data };
  }

  private buildApnsRequestHeaders(
    message: ApnsAlertMessage,
    authToken: string,
    deviceToken: string,
  ): Record<string, string> {
    const headers: Record<string, string> = {
      ':method': 'POST',
      ':path': `/3/device/${deviceToken}`,
      authorization: `bearer ${authToken}`,
      'apns-topic': this.bundleId,
      'apns-push-type': 'alert',
      'apns-priority': message.interruptionLevel === 'passive' ? '5' : '10',
    };
    if (
      message.expirationDate &&
      !Number.isNaN(message.expirationDate.getTime())
    ) {
      headers['apns-expiration'] = String(
        Math.floor(message.expirationDate.getTime() / 1000),
      );
    }
    return headers;
  }

  async sendToTokenTargets(
    targets: ApnsTokenTarget[],
    message: ApnsAlertMessage,
  ): Promise<{ invalidTokens: string[]; acceptedTokens: string[] }> {
    const invalidTokens: string[] = [];
    const acceptedTokens: string[] = [];
    const validTargets = targets.filter((t) => this.isLikelyApnsToken(t.token));
    for (const t of targets) {
      if (!this.isLikelyApnsToken(t.token)) invalidTokens.push(t.token);
    }
    if (validTargets.length === 0) {
      return { invalidTokens, acceptedTokens };
    }

    const byHost = new Map<string, ApnsTokenTarget[]>();
    for (const t of validTargets) {
      const host = this.resolveHost(t);
      const list = byHost.get(host) ?? [];
      list.push(t);
      byHost.set(host, list);
    }

    const authToken = this.getAuthToken();
    const payloadJson = JSON.stringify(this.buildApnsPayload(message));

    for (const [host, hostTargets] of byHost) {
      const client = connect(host);
      client.on('error', (error: unknown) => {
        this.log.error(`APNs client error: ${this.errorMessage(error)}`);
      });
      try {
        await Promise.all(
          hostTargets.map(
            (target) =>
              new Promise<void>((resolve) => {
                const token = target.token;
                const req = client.request(
                  this.buildApnsRequestHeaders(message, authToken, token),
                );
                let rawBody = '';
                req.setEncoding('utf8');
                req.on('response', (headers) => {
                  const status = Number(headers[':status'] ?? 0);
                  req.on('data', (chunk) => {
                    rawBody += chunk;
                  });
                  req.on('end', () => {
                    if (status === 200) {
                      acceptedTokens.push(token);
                      resolve();
                      return;
                    }
                    let reason = 'Unknown';
                    try {
                      const parsed = JSON.parse(rawBody) as {
                        reason?: string;
                      };
                      reason = parsed.reason ?? reason;
                    } catch {
                      // ignore malformed APNs error body
                    }
                    const permanentFailure =
                      status === 410 ||
                      reason === 'BadDeviceToken' ||
                      reason === 'Unregistered' ||
                      reason === 'DeviceTokenNotForTopic';
                    if (permanentFailure) {
                      invalidTokens.push(token);
                    } else {
                      this.log.warn(
                        `APNs rejected token (${status}): ${reason} [${token}]`,
                      );
                    }
                    resolve();
                  });
                });
                req.on('error', (error: unknown) => {
                  this.log.error(
                    `APNs request failed for token ${token}: ${this.errorMessage(error)}`,
                  );
                  resolve();
                });
                req.end(payloadJson);
              }),
          ),
        );
      } finally {
        client.close();
      }
    }

    return { invalidTokens, acceptedTokens };
  }
}

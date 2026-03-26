import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createSign } from 'crypto';
import { connect } from 'http2';

@Injectable()
export class ApnsPushService {
  private readonly log = new Logger(ApnsPushService.name);
  private readonly keyId: string;
  private readonly teamId: string;
  private readonly bundleId: string;
  private readonly privateKey: string;
  private readonly host: string;
  private cachedToken: { value: string; expiresAtMs: number } | null = null;

  constructor(private readonly config: ConfigService) {
    this.keyId = this.require('APPLE_KEY_ID');
    this.teamId = this.require('APPLE_TEAM_ID');
    this.bundleId = this.require('APPLE_BUNDLE_ID');
    this.privateKey = this.loadPrivateKey();
    const useSandbox =
      this.config.get<string>('APPLE_APNS_USE_SANDBOX') !== 'false';
    this.host = useSandbox
      ? 'https://api.sandbox.push.apple.com'
      : 'https://api.push.apple.com';
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

  async sendToTokens(
    tokens: string[],
    message: {
      title?: string;
      body?: string;
      subtitle?: string;
      data?: Record<string, unknown>;
    },
  ): Promise<{ invalidTokens: string[]; acceptedTokens: string[] }> {
    const invalidTokens: string[] = [];
    const acceptedTokens: string[] = [];
    const valid = tokens.filter((t) => this.isLikelyApnsToken(t));
    for (const token of tokens) {
      if (!this.isLikelyApnsToken(token)) invalidTokens.push(token);
    }
    if (valid.length === 0) {
      return { invalidTokens, acceptedTokens };
    }

    const authToken = this.getAuthToken();
    const client = connect(this.host);
    client.on('error', (error: unknown) => {
      this.log.error(`APNs client error: ${this.errorMessage(error)}`);
    });

    const payload = {
      aps: {
        alert: {
          title: message.title,
          subtitle: message.subtitle,
          body: message.body,
        },
        sound: 'default',
      },
      ...(message.data ?? {}),
    };

    try {
      await Promise.all(
        valid.map(
          (token) =>
            new Promise<void>((resolve) => {
              const req = client.request({
                ':method': 'POST',
                ':path': `/3/device/${token}`,
                authorization: `bearer ${authToken}`,
                'apns-topic': this.bundleId,
                'apns-push-type': 'alert',
                'apns-priority': '10',
              });
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
                  if (
                    reason === 'BadDeviceToken' ||
                    reason === 'Unregistered' ||
                    reason === 'DeviceTokenNotForTopic'
                  ) {
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
              req.end(JSON.stringify(payload));
            }),
        ),
      );
    } finally {
      client.close();
    }

    return { invalidTokens, acceptedTokens };
  }
}

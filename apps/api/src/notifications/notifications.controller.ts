import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Headers,
  HttpCode,
  HttpStatus,
  NotFoundException,
  Param,
  Post,
  UnauthorizedException,
} from '@nestjs/common';
import { Throttle, SkipThrottle } from '@nestjs/throttler';
import {
  brrNotifyPayloadSchema,
  brrRegisterEndpointSchema,
  notifyPayloadSchema,
} from '@ping/shared';
import { SecretDigestService } from '../crypto/secret-digest.service';
import { SubscribersService } from '../subscribers/subscribers.service';
import { ApnsPushService } from './apns-push.service';

@Controller('v1')
export class NotificationsController {
  constructor(
    private readonly digest: SecretDigestService,
    private readonly subscribers: SubscribersService,
    private readonly apnsPush: ApnsPushService,
  ) {}

  private requireCloudKitToken(token?: string): {
    token: string;
    tokenDigest: string;
  } {
    const t = token?.trim();
    if (!t) {
      throw new UnauthorizedException(
        'Missing X-CloudKit-Web-Auth-Token header',
      );
    }
    // Lightweight validation; upstream verifier can be swapped in later.
    if (t.length < 32) {
      throw new UnauthorizedException('Invalid X-CloudKit-Web-Auth-Token');
    }
    return { token: t, tokenDigest: this.digest.digest(`ckwt:${t}`) };
  }

  @Post('me/endpoints/register')
  @SkipThrottle()
  @HttpCode(HttpStatus.NO_CONTENT)
  async registerEndpoint(
    @Headers('x-cloudkit-web-auth-token') cloudKitToken: string | undefined,
    @Body() body: unknown,
  ): Promise<void> {
    const auth = this.requireCloudKitToken(cloudKitToken);

    const parsed = brrRegisterEndpointSchema.safeParse(body);
    if (!parsed.success) {
      throw new BadRequestException('Invalid body');
    }

    await this.subscribers.upsertEndpoint({
      keyDigest: parsed.data.key_digest,
      userKeyDigest: parsed.data.user_key_digest,
      userRecordName: parsed.data.record_name,
      cloudKitTokenDigest: auth.tokenDigest,
      pushToken: parsed.data.push_token,
      recordName: parsed.data.record_name,
    });
  }

  @Get('me/endpoints')
  @SkipThrottle()
  async getEndpoints(
    @Headers('x-cloudkit-web-auth-token') cloudKitToken: string | undefined,
  ): Promise<{
    user: { record_name: string; last_used_timestamp: string | null };
    devices: Array<{
      created_timestamp: string;
      last_seen_timestamp: string;
      last_used_timestamp: string | null;
      push_token: string;
      record_name: string;
    }>;
  }> {
    const auth = this.requireCloudKitToken(cloudKitToken);
    const sub = await this.subscribers.findByCloudKitTokenDigest(
      auth.tokenDigest,
    );
    if (!sub) {
      throw new NotFoundException('No endpoint found for key_digest');
    }
    return {
      user: {
        record_name: sub.userRecordName,
        last_used_timestamp:
          sub.devices
            .map((d) => d.lastUsedAt?.toISOString() ?? null)
            .filter((v): v is string => !!v)
            .sort()
            .at(-1) ?? null,
      },
      devices: sub.devices.map((d) => ({
        created_timestamp: d.createdAt.toISOString(),
        last_seen_timestamp: d.lastSeenAt.toISOString(),
        last_used_timestamp: d.lastUsedAt ? d.lastUsedAt.toISOString() : null,
        push_token: d.pushToken,
        record_name: d.recordName,
      })),
    };
  }

  @Post(':secret')
  @Throttle({ default: { limit: 60, ttl: 60_000 } })
  @HttpCode(HttpStatus.ACCEPTED)
  async notify(
    @Param('secret') secret: string,
    @Body() body: unknown,
  ): Promise<{ delivered: number }> {
    if (!secret || secret.length > 256) {
      throw new BadRequestException('Invalid secret');
    }
    const secretDigest = this.digest.digest(secret);
    const sub = await this.subscribers.findByKeyDigest(secretDigest);
    if (!sub || sub.devices.length === 0) {
      throw new NotFoundException(
        'No devices registered for this webhook secret.',
      );
    }
    const tokens = sub.devices
      .filter((d) => d.isEnabled)
      .map((d) => d.pushToken);
    const parsed = brrNotifyPayloadSchema.safeParse(body);
    if (!parsed.success) {
      throw new BadRequestException('Invalid body');
    }
    const payload =
      typeof parsed.data === 'string'
        ? {
            message: parsed.data,
            title: undefined,
            subtitle: undefined,
            url: undefined,
          }
        : notifyPayloadSchema.parse(parsed.data);
    const { invalidTokens, acceptedTokens } = await this.apnsPush.sendToTokens(
      tokens,
      {
        title: payload.title,
        body: payload.message,
        subtitle: payload.subtitle,
        data: payload.url ? { url: payload.url } : undefined,
      },
    );
    const invalid = new Set(invalidTokens);
    for (const t of invalid) {
      await this.subscribers.removeDeviceToken(secretDigest, t);
    }
    if (acceptedTokens.length > 0) {
      await this.subscribers.markDevicesUsed(secretDigest, acceptedTokens);
    }
    return { delivered: acceptedTokens.length };
  }
}

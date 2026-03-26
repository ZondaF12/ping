import {
  BadRequestException,
  Body,
  Controller,
  ForbiddenException,
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
  pingNotifyPayloadSchema,
  pingRegisterEndpointSchema,
  notifyPayloadSchema,
} from '@ping/shared';
import { SecretDigestService } from '../crypto/secret-digest.service';
import { SubscribersService } from '../subscribers/subscribers.service';
import { ApnsPushService } from './apns-push.service';
import { CloudKitAuthService } from '../cloudkit/cloudkit-auth.service';

@Controller('v1')
export class NotificationsController {
  constructor(
    private readonly digest: SecretDigestService,
    private readonly subscribers: SubscribersService,
    private readonly apnsPush: ApnsPushService,
    private readonly cloudKitAuth: CloudKitAuthService,
  ) {}

  private async requireCloudKitIdentity(token?: string): Promise<{
    userRecordName: string | null;
  }> {
    try {
      return await this.cloudKitAuth.verifyWebAuthToken(token);
    } catch (error) {
      if (
        error instanceof UnauthorizedException ||
        error instanceof ForbiddenException
      ) {
        throw error;
      }
      throw new UnauthorizedException('CloudKit token verification failed');
    }
  }

  @Post('me/endpoints/register')
  @SkipThrottle()
  @HttpCode(HttpStatus.NO_CONTENT)
  async registerEndpoint(
    @Headers('x-cloudkit-web-auth-token') cloudKitToken: string | undefined,
    @Body() body: unknown,
  ): Promise<void> {
    const parsed = pingRegisterEndpointSchema.safeParse(body);
    if (!parsed.success) {
      throw new BadRequestException('Invalid body');
    }
    const auth = await this.requireCloudKitIdentity(cloudKitToken);
    const resolvedUserRecordName =
      auth.userRecordName ?? parsed.data.user_record_name?.trim();
    if (
      !resolvedUserRecordName ||
      !/^[A-Za-z0-9_\-:.]{8,256}$/.test(resolvedUserRecordName)
    ) {
      throw new UnauthorizedException(
        'CloudKit auth response missing user identity',
      );
    }
    const resolvedIdentityDigest = this.cloudKitAuth.digestIdentity(
      resolvedUserRecordName,
    );

    await this.subscribers.upsertEndpoint({
      keyDigest: parsed.data.key_digest,
      userKeyDigest: parsed.data.user_key_digest,
      userRecordName: resolvedUserRecordName,
      cloudKitUserDigest: resolvedIdentityDigest,
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
    const auth = await this.requireCloudKitIdentity(cloudKitToken);
    if (!auth.userRecordName) {
      throw new UnauthorizedException(
        'CloudKit auth response missing user identity',
      );
    }
    const identityDigest = this.cloudKitAuth.digestIdentity(
      auth.userRecordName,
    );
    const sub = await this.subscribers.findByCloudKitUserDigest(identityDigest);
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
    const parsed = pingNotifyPayloadSchema.safeParse(body);
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

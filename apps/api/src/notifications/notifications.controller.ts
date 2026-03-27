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

    await this.subscribers.upsertEndpoint({
      keyDigest: parsed.data.key_digest,
      userRecordName: resolvedUserRecordName,
      pushToken: parsed.data.push_token,
      recordName: parsed.data.record_name,
      deviceKeyDigest: parsed.data.device_key_digest,
      label: parsed.data.device_label,
      deviceKind: parsed.data.device_kind,
      apnsEnvironment: parsed.data.apns_environment,
    });
  }

  @Get('me/endpoints')
  @SkipThrottle()
  async getEndpoints(
    @Headers('x-cloudkit-web-auth-token') cloudKitToken: string | undefined,
    @Headers('x-user-record-name') userRecordNameFallback: string | undefined,
  ): Promise<{
    user: { record_name: string; last_used_timestamp: string | null };
    devices: Array<{
      created_timestamp: string;
      last_seen_timestamp: string;
      last_used_timestamp: string | null;
      push_token: string;
      record_name: string;
      device_label: string | null;
      device_kind: string | null;
      apns_environment: string | null;
    }>;
  }> {
    const auth = await this.requireCloudKitIdentity(cloudKitToken);
    const resolvedUserRecordName =
      auth.userRecordName?.trim() || userRecordNameFallback?.trim();
    if (
      !resolvedUserRecordName ||
      !/^[A-Za-z0-9_\-:.]{8,256}$/.test(resolvedUserRecordName)
    ) {
      throw new UnauthorizedException(
        'CloudKit auth response missing user identity',
      );
    }
    const sub = await this.subscribers.findByUserRecordName(
      resolvedUserRecordName,
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
        device_label: d.label ?? null,
        device_kind: d.deviceKind ?? null,
        apns_environment: d.apnsEnvironment ?? null,
      })),
    };
  }

  @Post(':secret')
  @Throttle({ default: { limit: 60, ttl: 60_000 } })
  @HttpCode(HttpStatus.OK)
  async notify(
    @Param('secret') secret: string,
    @Body() body: unknown,
  ): Promise<{ success: boolean }> {
    try {
      if (!secret || secret.length > 256) {
        return { success: false };
      }
      const secretDigest = this.digest.digest(secret);
      let sub = await this.subscribers.findByKeyDigest(secretDigest);
      let singleDeviceOnly = false;
      if (!sub) {
        sub = await this.subscribers.findByDeviceKeyDigest(secretDigest);
        singleDeviceOnly = true;
      }
      if (!sub || sub.devices.length === 0) {
        return { success: false };
      }

      let devicesToNotify = sub.devices.filter((d) => d.isEnabled);
      if (singleDeviceOnly) {
        devicesToNotify = devicesToNotify.filter(
          (d) => d.keyDigest === secretDigest,
        );
      }
      if (devicesToNotify.length === 0) {
        return { success: false };
      }

      const parsed = pingNotifyPayloadSchema.safeParse(body);
      if (!parsed.success) {
        return { success: false };
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
      const { invalidTokens, acceptedTokens } =
        await this.apnsPush.sendToTokenTargets(
          devicesToNotify.map((d) => ({
            token: d.pushToken,
            apnsEnvironment: d.apnsEnvironment,
          })),
          {
            title: payload.title,
            body: payload.message,
            subtitle: payload.subtitle,
            data: payload.url ? { url: payload.url } : undefined,
          },
        );
      const invalid = new Set(invalidTokens);
      for (const t of invalid) {
        await this.subscribers.removeDeviceToken(sub.keyDigest, t);
      }
      if (acceptedTokens.length > 0) {
        await this.subscribers.markDevicesUsed(sub.keyDigest, acceptedTokens);
      }
      return { success: acceptedTokens.length > 0 };
    } catch {
      return { success: false };
    }
  }
}

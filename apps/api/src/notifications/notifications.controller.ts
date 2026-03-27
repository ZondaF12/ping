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
  Query,
  UnauthorizedException,
} from '@nestjs/common';
import { Throttle, SkipThrottle } from '@nestjs/throttler';
import {
  type NotifyPayload,
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

  private pickQueryString(
    query: Record<string, unknown>,
    key: string,
  ): string | undefined {
    const v = query[key];
    if (v === undefined || v === null) {
      return undefined;
    }
    if (Array.isArray(v)) {
      const first: unknown = v[0];
      return typeof first === 'string' ? first : undefined;
    }
    return typeof v === 'string' ? v : undefined;
  }

  /** Build a notify body object from GET query parameters (brrr-style). */
  private notifyPayloadFromQuery(
    query: Record<string, unknown>,
  ): Record<string, string> | null {
    const message = this.pickQueryString(query, 'message');
    if (!message) {
      return null;
    }
    const out: Record<string, string> = { message };
    const add = (qKey: string, objKey: string = qKey) => {
      const v = this.pickQueryString(query, qKey);
      if (v !== undefined && v !== '') {
        out[objKey] = v;
      }
    };
    add('title');
    add('subtitle');
    add('url');
    add('image_url');
    add('expiration_date');
    add('interruption-level');
    add('filter-criteria');
    return out;
  }

  private notifyPayloadFromStringBody(message: string): NotifyPayload {
    return {
      message,
      title: undefined,
      subtitle: undefined,
      url: undefined,
      image_url: undefined,
      expiration_date: undefined,
      'interruption-level': undefined,
      'filter-criteria': undefined,
    };
  }

  private buildNotifyData(
    payload: NotifyPayload,
  ): Record<string, unknown> | undefined {
    const data: Record<string, unknown> = {};
    if (payload.url) {
      data.url = payload.url;
    }
    if (payload.image_url) {
      data.image_url = payload.image_url;
    }
    return Object.keys(data).length > 0 ? data : undefined;
  }

  private expirationDateFromPayload(payload: NotifyPayload): Date | undefined {
    if (!payload.expiration_date) {
      return undefined;
    }
    const d = new Date(payload.expiration_date);
    return Number.isNaN(d.getTime()) ? undefined : d;
  }

  private async notifyWithPayload(
    secret: string,
    payload: NotifyPayload,
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
            data: this.buildNotifyData(payload),
            imageUrl: payload.image_url,
            expirationDate: this.expirationDateFromPayload(payload),
            interruptionLevel: payload['interruption-level'],
            filterCriteria: payload['filter-criteria'],
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

  @Get(':secret')
  @Throttle({ default: { limit: 60, ttl: 60_000 } })
  @HttpCode(HttpStatus.OK)
  async notifyGet(
    @Param('secret') secret: string,
    @Query() query: Record<string, unknown>,
  ): Promise<{ success: boolean }> {
    const raw = this.notifyPayloadFromQuery(query);
    if (!raw) {
      return { success: false };
    }
    const parsed = notifyPayloadSchema.safeParse(raw);
    if (!parsed.success) {
      return { success: false };
    }
    return this.notifyWithPayload(secret, parsed.data);
  }

  @Post(':secret')
  @Throttle({ default: { limit: 60, ttl: 60_000 } })
  @HttpCode(HttpStatus.OK)
  async notify(
    @Param('secret') secret: string,
    @Body() body: unknown,
  ): Promise<{ success: boolean }> {
    const parsed = pingNotifyPayloadSchema.safeParse(body);
    if (!parsed.success) {
      return { success: false };
    }
    const payload =
      typeof parsed.data === 'string'
        ? this.notifyPayloadFromStringBody(parsed.data)
        : notifyPayloadSchema.parse(parsed.data);
    return this.notifyWithPayload(secret, payload);
  }
}

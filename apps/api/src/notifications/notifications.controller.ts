import {
  BadRequestException,
  Body,
  Controller,
  HttpCode,
  HttpStatus,
  NotFoundException,
  Param,
  Post,
  Req,
} from '@nestjs/common';
import { Throttle, SkipThrottle } from '@nestjs/throttler';
import type { Request } from 'express';
import { notifyPayloadSchema, registerBodySchema } from '@ping/shared';
import { SecretDigestService } from '../crypto/secret-digest.service';
import { SubscribersService } from '../subscribers/subscribers.service';
import { ExpoPushService } from './expo-push.service';

@Controller('v1')
export class NotificationsController {
  constructor(
    private readonly digest: SecretDigestService,
    private readonly subscribers: SubscribersService,
    private readonly expoPush: ExpoPushService,
  ) {}

  /** Literal path must be registered before `:secret`. */
  @Post('register/:secret')
  @SkipThrottle()
  @HttpCode(HttpStatus.NO_CONTENT)
  async register(
    @Param('secret') secret: string,
    @Body() body: unknown,
  ): Promise<void> {
    const parsed = registerBodySchema.safeParse(body);
    if (!parsed.success) {
      throw new BadRequestException('Invalid body');
    }
    if (!secret || secret.length > 256) {
      throw new BadRequestException('Invalid secret');
    }
    const secretDigest = this.digest.digest(secret);
    await this.subscribers.upsertDevice(
      secretDigest,
      parsed.data.expoPushToken,
    );
  }

  @Post(':secret')
  @Throttle({ default: { limit: 60, ttl: 60_000 } })
  @HttpCode(HttpStatus.ACCEPTED)
  async notify(
    @Param('secret') secret: string,
    @Req() req: Request,
    @Body() body: unknown,
  ): Promise<{ delivered: number }> {
    if (!secret || secret.length > 256) {
      throw new BadRequestException('Invalid secret');
    }
    const ct = req.headers['content-type'] ?? '';
    if (!ct.includes('application/json')) {
      throw new BadRequestException('Content-Type must be application/json');
    }
    const parsed = notifyPayloadSchema.safeParse(body);
    if (!parsed.success) {
      throw new BadRequestException('Invalid body');
    }
    const secretDigest = this.digest.digest(secret);
    const sub = await this.subscribers.findByDigest(secretDigest);
    if (!sub || sub.devices.length === 0) {
      throw new NotFoundException(
        'No devices registered for this webhook secret. Open the Ping app, allow notifications, and tap Re-register device (Mongo must be running on the API).',
      );
    }
    const tokens = sub.devices.map((d) => d.expoPushToken);
    const payload = parsed.data;
    const { invalidTokens } = await this.expoPush.sendToTokens(tokens, {
      title: payload.title,
      body: payload.message,
      subtitle: payload.subtitle,
      data: payload.url ? { url: payload.url } : undefined,
    });
    const invalid = new Set(invalidTokens);
    for (const t of invalid) {
      await this.subscribers.removeDeviceToken(secretDigest, t);
    }
    return { delivered: tokens.filter((t) => !invalid.has(t)).length };
  }
}

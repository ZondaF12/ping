import { ForbiddenException, Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { Subscriber, SubscriberDocument } from './schemas/subscriber.schema';

@Injectable()
export class SubscribersService {
  constructor(
    @InjectModel(Subscriber.name)
    private readonly subscriberModel: Model<SubscriberDocument>,
  ) {}

  async upsertEndpoint(input: {
    keyDigest: string;
    userRecordName: string;
    pushToken: string;
    recordName: string;
    deviceKeyDigest: string;
    installationId?: string;
    platform?: string;
    label?: string;
    deviceKind?: string;
    apnsEnvironment?: 'sandbox' | 'production';
  }): Promise<SubscriberDocument> {
    const now = new Date();
    // Prefer CloudKit identity so user secret rotation (new key_digest, same user) updates one row.
    let existing = await this.subscriberModel
      .findOne({ userRecordName: input.userRecordName })
      .exec();
    if (!existing) {
      const byKey = await this.subscriberModel
        .findOne({ keyDigest: input.keyDigest })
        .exec();
      if (byKey && byKey.userRecordName !== input.userRecordName) {
        throw new ForbiddenException('Subscriber identity mismatch');
      }
      existing = byKey;
    }
    if (!existing) {
      return this.subscriberModel.create({
        keyDigest: input.keyDigest,
        userRecordName: input.userRecordName,
        devices: [
          {
            pushToken: input.pushToken,
            recordName: input.recordName,
            keyDigest: input.deviceKeyDigest,
            installationId: input.installationId,
            platform: input.platform,
            label: input.label,
            deviceKind: input.deviceKind,
            apnsEnvironment: input.apnsEnvironment,
            isEnabled: true,
            createdAt: now,
            lastSeenAt: now,
            lastUsedAt: null,
          },
        ],
      });
    }
    existing.keyDigest = input.keyDigest;
    existing.userRecordName = input.userRecordName;
    const idx = existing.devices.findIndex(
      (d) =>
        d.recordName === input.recordName ||
        d.pushToken === input.pushToken ||
        (input.deviceKeyDigest && d.keyDigest === input.deviceKeyDigest),
    );
    if (idx >= 0) {
      existing.devices[idx].pushToken = input.pushToken;
      existing.devices[idx].recordName = input.recordName;
      existing.devices[idx].keyDigest = input.deviceKeyDigest;
      existing.devices[idx].installationId = input.installationId;
      existing.devices[idx].platform = input.platform;
      if (input.label !== undefined) {
        existing.devices[idx].label = input.label;
      }
      if (input.deviceKind !== undefined) {
        existing.devices[idx].deviceKind = input.deviceKind;
      }
      if (input.apnsEnvironment !== undefined) {
        existing.devices[idx].apnsEnvironment = input.apnsEnvironment;
      }
      existing.devices[idx].isEnabled = true;
      existing.devices[idx].lastSeenAt = now;
    } else {
      existing.devices.push({
        pushToken: input.pushToken,
        recordName: input.recordName,
        keyDigest: input.deviceKeyDigest,
        installationId: input.installationId,
        platform: input.platform,
        label: input.label,
        deviceKind: input.deviceKind,
        apnsEnvironment: input.apnsEnvironment,
        isEnabled: true,
        createdAt: now,
        lastSeenAt: now,
        lastUsedAt: null,
      });
    }
    await existing.save();
    return existing;
  }

  async findByKeyDigest(keyDigest: string): Promise<SubscriberDocument | null> {
    return this.subscriberModel.findOne({ keyDigest }).exec();
  }

  async findByUserRecordName(
    userRecordName: string,
  ): Promise<SubscriberDocument | null> {
    return this.subscriberModel.findOne({ userRecordName }).exec();
  }

  async findByDeviceKeyDigest(
    deviceKeyDigest: string,
  ): Promise<SubscriberDocument | null> {
    return this.subscriberModel
      .findOne({ 'devices.keyDigest': deviceKeyDigest })
      .exec();
  }

  async markDevicesUsed(
    keyDigest: string,
    pushTokens: string[],
  ): Promise<void> {
    const now = new Date();
    await this.subscriberModel.updateOne(
      { keyDigest },
      {
        $set: {
          'devices.$[d].lastUsedAt': now,
          'devices.$[d].lastSeenAt': now,
        },
      },
      { arrayFilters: [{ 'd.pushToken': { $in: pushTokens } }] },
    );
  }

  async removeDeviceToken(keyDigest: string, pushToken: string): Promise<void> {
    await this.subscriberModel.updateOne(
      { keyDigest },
      { $pull: { devices: { pushToken } } },
    );
  }
}

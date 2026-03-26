import { Injectable } from '@nestjs/common';
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
    userKeyDigest: string;
    userRecordName: string;
    cloudKitTokenDigest: string;
    pushToken: string;
    recordName: string;
    installationId?: string;
    platform?: string;
  }): Promise<SubscriberDocument> {
    const now = new Date();
    const existing = await this.subscriberModel.findOne({
      keyDigest: input.keyDigest,
    });
    if (!existing) {
      return this.subscriberModel.create({
        keyDigest: input.keyDigest,
        userKeyDigest: input.userKeyDigest,
        userRecordName: input.userRecordName,
        cloudKitTokenDigest: input.cloudKitTokenDigest,
        devices: [
          {
            pushToken: input.pushToken,
            recordName: input.recordName,
            installationId: input.installationId,
            platform: input.platform,
            isEnabled: true,
            createdAt: now,
            lastSeenAt: now,
            lastUsedAt: null,
          },
        ],
      });
    }
    existing.userKeyDigest = input.userKeyDigest;
    existing.userRecordName = input.userRecordName;
    existing.cloudKitTokenDigest = input.cloudKitTokenDigest;
    const idx = existing.devices.findIndex(
      (d) =>
        d.recordName === input.recordName || d.pushToken === input.pushToken,
    );
    if (idx >= 0) {
      existing.devices[idx].pushToken = input.pushToken;
      existing.devices[idx].recordName = input.recordName;
      existing.devices[idx].installationId = input.installationId;
      existing.devices[idx].platform = input.platform;
      existing.devices[idx].isEnabled = true;
      existing.devices[idx].lastSeenAt = now;
    } else {
      existing.devices.push({
        pushToken: input.pushToken,
        recordName: input.recordName,
        installationId: input.installationId,
        platform: input.platform,
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

  async findByUserKeyDigest(
    userKeyDigest: string,
  ): Promise<SubscriberDocument | null> {
    return this.subscriberModel.findOne({ userKeyDigest }).exec();
  }

  async findByCloudKitTokenDigest(
    cloudKitTokenDigest: string,
  ): Promise<SubscriberDocument | null> {
    return this.subscriberModel.findOne({ cloudKitTokenDigest }).exec();
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

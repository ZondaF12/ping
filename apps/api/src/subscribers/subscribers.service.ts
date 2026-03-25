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

  async upsertDevice(
    secretDigest: string,
    expoPushToken: string,
  ): Promise<SubscriberDocument> {
    const now = new Date();
    const existing = await this.subscriberModel.findOne({ secretDigest });
    if (!existing) {
      return this.subscriberModel.create({
        secretDigest,
        devices: [{ expoPushToken, lastSeenAt: now }],
      });
    }
    const idx = existing.devices.findIndex(
      (d) => d.expoPushToken === expoPushToken,
    );
    if (idx >= 0) {
      existing.devices[idx].lastSeenAt = now;
    } else {
      existing.devices.push({ expoPushToken, lastSeenAt: now });
    }
    await existing.save();
    return existing;
  }

  async findByDigest(secretDigest: string): Promise<SubscriberDocument | null> {
    return this.subscriberModel.findOne({ secretDigest }).exec();
  }

  async removeDeviceToken(
    secretDigest: string,
    expoPushToken: string,
  ): Promise<void> {
    await this.subscriberModel.updateOne(
      { secretDigest },
      { $pull: { devices: { expoPushToken } } },
    );
  }
}

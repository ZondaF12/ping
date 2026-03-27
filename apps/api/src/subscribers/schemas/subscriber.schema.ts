import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument } from 'mongoose';

@Schema({ collection: 'subscribers', timestamps: true })
export class Subscriber {
  @Prop({ required: true, unique: true, index: true })
  keyDigest!: string;

  @Prop({ required: true, index: true })
  userRecordName!: string;

  @Prop({
    type: [
      {
        pushToken: { type: String, required: true },
        recordName: { type: String, required: true },
        keyDigest: { type: String, required: false },
        installationId: { type: String, required: false },
        platform: { type: String, required: false },
        label: { type: String, required: false },
        deviceKind: { type: String, required: false },
        apnsEnvironment: {
          type: String,
          required: false,
          enum: ['sandbox', 'production'],
        },
        isEnabled: { type: Boolean, required: true, default: true },
        createdAt: { type: Date, required: true },
        lastSeenAt: { type: Date, required: true },
        lastUsedAt: { type: Date, required: false, default: null },
      },
    ],
    default: [],
  })
  devices!: {
    pushToken: string;
    recordName: string;
    keyDigest?: string;
    installationId?: string;
    platform?: string;
    label?: string;
    deviceKind?: string;
    apnsEnvironment?: 'sandbox' | 'production';
    isEnabled: boolean;
    createdAt: Date;
    lastSeenAt: Date;
    lastUsedAt: Date | null;
  }[];
}

export type SubscriberDocument = HydratedDocument<Subscriber>;

export const SubscriberSchema = SchemaFactory.createForClass(Subscriber);

SubscriberSchema.index({ 'devices.keyDigest': 1 }, { sparse: true });

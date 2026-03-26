import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument } from 'mongoose';

export type SubscriberDocument = HydratedDocument<Subscriber>;

@Schema({ collection: 'subscribers', timestamps: true })
export class Subscriber {
  @Prop({ required: true, unique: true, index: true })
  keyDigest!: string;

  @Prop({ required: true, index: true })
  userKeyDigest!: string;

  @Prop({ required: true, index: true })
  userRecordName!: string;

  @Prop({ required: true, index: true })
  cloudKitUserDigest!: string;

  @Prop({
    type: [
      {
        pushToken: { type: String, required: true },
        recordName: { type: String, required: true },
        installationId: { type: String, required: false },
        platform: { type: String, required: false },
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
    installationId?: string;
    platform?: string;
    isEnabled: boolean;
    createdAt: Date;
    lastSeenAt: Date;
    lastUsedAt: Date | null;
  }[];
}

export const SubscriberSchema = SchemaFactory.createForClass(Subscriber);

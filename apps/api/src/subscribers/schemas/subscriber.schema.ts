import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { HydratedDocument } from 'mongoose';

export type SubscriberDocument = HydratedDocument<Subscriber>;

@Schema({ collection: 'subscribers', timestamps: true })
export class Subscriber {
  @Prop({ required: true, unique: true, index: true })
  secretDigest!: string;

  @Prop({
    type: [
      {
        expoPushToken: { type: String, required: true },
        lastSeenAt: { type: Date, required: true },
      },
    ],
    default: [],
  })
  devices!: { expoPushToken: string; lastSeenAt: Date }[];
}

export const SubscriberSchema = SchemaFactory.createForClass(Subscriber);

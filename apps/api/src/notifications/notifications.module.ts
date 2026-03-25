import { Module } from '@nestjs/common';
import { SubscribersModule } from '../subscribers/subscribers.module';
import { CryptoModule } from '../crypto/crypto.module';
import { NotificationsController } from './notifications.controller';
import { ExpoPushService } from './expo-push.service';

@Module({
  imports: [SubscribersModule, CryptoModule],
  controllers: [NotificationsController],
  providers: [ExpoPushService],
})
export class NotificationsModule {}

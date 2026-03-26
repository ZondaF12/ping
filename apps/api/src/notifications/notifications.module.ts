import { Module } from '@nestjs/common';
import { SubscribersModule } from '../subscribers/subscribers.module';
import { CryptoModule } from '../crypto/crypto.module';
import { NotificationsController } from './notifications.controller';
import { ApnsPushService } from './apns-push.service';

@Module({
  imports: [SubscribersModule, CryptoModule],
  controllers: [NotificationsController],
  providers: [ApnsPushService],
})
export class NotificationsModule {}

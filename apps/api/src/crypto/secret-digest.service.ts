import { createHmac } from 'crypto';
import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

@Injectable()
export class SecretDigestService {
  private readonly salt: string;

  constructor(private readonly config: ConfigService) {
    this.salt = this.config.get<string>(
      'SECRET_SALT',
      'dev-secret-salt-change-me',
    )!;
  }

  digest(secret: string): string {
    return createHmac('sha256', this.salt).update(secret, 'utf8').digest('hex');
  }
}

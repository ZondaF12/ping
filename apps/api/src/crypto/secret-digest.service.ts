import { createHash } from 'crypto';
import { Injectable } from '@nestjs/common';

@Injectable()
export class SecretDigestService {
  digest(secret: string): string {
    // ping-style digest shape: URL-safe base64 SHA-256, no padding.
    const hash = createHash('sha256')
      .update(secret, 'utf8')
      .digest('base64url');
    return hash;
  }
}

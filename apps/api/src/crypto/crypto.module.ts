import { Global, Module } from '@nestjs/common';
import { SecretDigestService } from './secret-digest.service';

@Global()
@Module({
  providers: [SecretDigestService],
  exports: [SecretDigestService],
})
export class CryptoModule {}

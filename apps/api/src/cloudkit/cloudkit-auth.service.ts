import {
  ForbiddenException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createHash } from 'crypto';

type CloudKitCallerResponse = {
  users?: Array<{
    userRecordName?: string;
    recordName?: string;
  }>;
};

@Injectable()
export class CloudKitAuthService {
  private readonly containerId: string;
  private readonly environment: string;
  private readonly apiToken: string;

  constructor(private readonly config: ConfigService) {
    this.containerId = this.require('CLOUDKIT_CONTAINER_ID');
    this.environment = this.require('CLOUDKIT_ENV');
    this.apiToken = this.require('CLOUDKIT_API_TOKEN');
  }

  private require(name: string): string {
    const value = this.config.get<string>(name)?.trim();
    if (!value) {
      throw new Error(`Missing required env var: ${name}`);
    }
    return value;
  }

  async verifyWebAuthToken(rawToken?: string): Promise<{
    userRecordName: string;
    identityDigest: string;
  }> {
    const token = rawToken?.trim();
    if (!token) {
      throw new UnauthorizedException('Missing X-CloudKit-Web-Auth-Token header');
    }

    const url = new URL(
      `https://api.apple-cloudkit.com/database/1/${this.containerId}/${this.environment}/public/users/caller`,
    );
    url.searchParams.set('ckAPIToken', this.apiToken);
    url.searchParams.set('ckWebAuthToken', token);

    const response = await fetch(url, {
      method: 'GET',
      headers: { Accept: 'application/json' },
    });

    if (response.status === 401) {
      throw new UnauthorizedException('Invalid X-CloudKit-Web-Auth-Token');
    }
    if (response.status === 403) {
      throw new ForbiddenException('CloudKit container/environment mismatch');
    }
    if (!response.ok) {
      throw new UnauthorizedException('CloudKit auth verification failed');
    }

    const payload = (await response.json()) as CloudKitCallerResponse;
    const userRecordName =
      payload.users?.[0]?.userRecordName ?? payload.users?.[0]?.recordName;
    if (!userRecordName) {
      throw new UnauthorizedException('CloudKit auth response missing user identity');
    }

    const identityDigest = createHash('sha256')
      .update(`ckuser:${userRecordName}`, 'utf8')
      .digest('base64url');

    return { userRecordName, identityDigest };
  }
}

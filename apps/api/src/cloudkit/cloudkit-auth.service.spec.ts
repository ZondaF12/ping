import { ConfigService } from '@nestjs/config';
import { ForbiddenException, UnauthorizedException } from '@nestjs/common';
import { CloudKitAuthService } from './cloudkit-auth.service';

describe('CloudKitAuthService', () => {
  const config = new ConfigService({
    CLOUDKIT_CONTAINER_ID: 'iCloud.com.example.ping',
    CLOUDKIT_ENV: 'development',
    CLOUDKIT_API_TOKEN: 'test-api-token',
  });

  const originalFetch = global.fetch;

  afterEach(() => {
    global.fetch = originalFetch;
    jest.restoreAllMocks();
  });

  it('returns verified identity digest from users/caller response', async () => {
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      status: 200,
      json: () =>
        Promise.resolve({
          users: [{ userRecordName: 'user_abc' }],
        }),
    } as Response);

    const service = new CloudKitAuthService(config);
    const result = await service.verifyWebAuthToken('token-123');

    expect(result.userRecordName).toBe('user_abc');
    expect(service.digestIdentity(result.userRecordName!)).toBeTruthy();
  });

  it('returns null identity when users/caller omits user fields', async () => {
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      status: 200,
      json: () =>
        Promise.resolve({
          users: [{}],
        }),
    } as Response);

    const service = new CloudKitAuthService(config);
    const result = await service.verifyWebAuthToken('token-123');

    expect(result.userRecordName).toBeNull();
  });

  it('throws unauthorized when Apple returns 401', async () => {
    global.fetch = jest.fn().mockResolvedValue({
      ok: false,
      status: 401,
      json: () => Promise.resolve({}),
    } as Response);

    const service = new CloudKitAuthService(config);
    await expect(
      service.verifyWebAuthToken('bad-token'),
    ).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it('throws forbidden when Apple returns 403', async () => {
    global.fetch = jest.fn().mockResolvedValue({
      ok: false,
      status: 403,
      json: () => Promise.resolve({}),
    } as Response);

    const service = new CloudKitAuthService(config);
    await expect(
      service.verifyWebAuthToken('bad-token'),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });
});

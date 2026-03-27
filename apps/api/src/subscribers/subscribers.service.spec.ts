import { ForbiddenException } from '@nestjs/common';
import { getModelToken } from '@nestjs/mongoose';
import { Test, TestingModule } from '@nestjs/testing';
import { Model } from 'mongoose';
import { Subscriber } from './schemas/subscriber.schema';
import { SubscribersService } from './subscribers.service';

function execQuery<T>(value: T | null) {
  return { exec: () => Promise.resolve(value) };
}

describe('SubscribersService', () => {
  let service: SubscribersService;
  let findOne: jest.Mock;
  let create: jest.Mock;

  beforeEach(async () => {
    findOne = jest.fn();
    create = jest.fn();
    const mockModel: Pick<Model<unknown>, 'findOne' | 'create'> = {
      findOne,
      create,
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        SubscribersService,
        {
          provide: getModelToken(Subscriber.name),
          useValue: mockModel,
        },
      ],
    }).compile();

    service = module.get(SubscribersService);
  });

  it('creates a subscriber when none exists', async () => {
    findOne.mockReturnValueOnce(execQuery(null));
    findOne.mockReturnValueOnce(execQuery(null));
    const created = { keyDigest: 'kd', userRecordName: 'u1', devices: [] };
    create.mockResolvedValue(created);

    const result = await service.upsertEndpoint({
      keyDigest: 'kd',
      userRecordName: 'u1',
      pushToken: 'pt',
      recordName: 'rn',
      deviceKeyDigest: 'dkd',
    });

    expect(findOne).toHaveBeenNthCalledWith(1, { userRecordName: 'u1' });
    expect(findOne).toHaveBeenNthCalledWith(2, { keyDigest: 'kd' });
    expect(create).toHaveBeenCalled();
    const calls = create.mock.calls as Array<
      [
        {
          keyDigest: string;
          userRecordName: string;
          devices: Array<{
            pushToken: string;
            recordName: string;
            keyDigest: string;
          }>;
        },
      ]
    >;
    const createdArg = calls[0]?.[0];
    expect(createdArg.keyDigest).toBe('kd');
    expect(createdArg.userRecordName).toBe('u1');
    expect(createdArg.devices[0]?.pushToken).toBe('pt');
    expect(createdArg.devices[0]?.recordName).toBe('rn');
    expect(createdArg.devices[0]?.keyDigest).toBe('dkd');
    expect(result).toBe(created);
  });

  it('updates keyDigest when matched by userRecordName (user secret rotation)', async () => {
    const save = jest.fn().mockResolvedValue(undefined);
    const existing = {
      keyDigest: 'old_kd',
      userRecordName: 'u1',
      devices: [
        {
          pushToken: 'pt1',
          recordName: 'rn1',
          keyDigest: 'dk1',
          isEnabled: true,
          createdAt: new Date(),
          lastSeenAt: new Date(),
          lastUsedAt: null,
        },
        {
          pushToken: 'pt2',
          recordName: 'rn2',
          keyDigest: 'dk2',
          isEnabled: true,
          createdAt: new Date(),
          lastSeenAt: new Date(),
          lastUsedAt: null,
        },
      ],
      save,
    };
    findOne.mockReturnValueOnce(execQuery(existing));

    await service.upsertEndpoint({
      keyDigest: 'new_kd',
      userRecordName: 'u1',
      pushToken: 'pt1',
      recordName: 'rn1',
      deviceKeyDigest: 'dk1',
    });

    expect(existing.keyDigest).toBe('new_kd');
    expect(save).toHaveBeenCalled();
    expect(existing.devices).toHaveLength(2);
  });

  it('matches by keyDigest when userRecordName row not found (first path miss)', async () => {
    const save = jest.fn().mockResolvedValue(undefined);
    const existing = {
      keyDigest: 'kd',
      userRecordName: 'u1',
      devices: [
        {
          pushToken: 'pt',
          recordName: 'rn',
          keyDigest: 'dkd',
          isEnabled: true,
          createdAt: new Date(),
          lastSeenAt: new Date(),
          lastUsedAt: null,
        },
      ],
      save,
    };
    findOne.mockReturnValueOnce(execQuery(null));
    findOne.mockReturnValueOnce(execQuery(existing));

    await service.upsertEndpoint({
      keyDigest: 'kd',
      userRecordName: 'u1',
      pushToken: 'pt',
      recordName: 'rn',
      deviceKeyDigest: 'dkd',
    });

    expect(existing.keyDigest).toBe('kd');
    expect(save).toHaveBeenCalled();
  });

  it('throws when keyDigest matches another user than CloudKit identity', async () => {
    findOne.mockReturnValueOnce(execQuery(null));
    findOne.mockReturnValueOnce(
      execQuery({
        keyDigest: 'stolen',
        userRecordName: 'victim',
        devices: [],
      }),
    );

    await expect(
      service.upsertEndpoint({
        keyDigest: 'stolen',
        userRecordName: 'attacker',
        pushToken: 'pt',
        recordName: 'rn',
        deviceKeyDigest: 'dkd',
      }),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });
});

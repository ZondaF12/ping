import { notifyPayloadSchema } from '@ping/shared';

describe('notifyPayloadSchema', () => {
  it('accepts minimal message-only payload', () => {
    const r = notifyPayloadSchema.safeParse({ message: 'Hello' });
    expect(r.success).toBe(true);
  });

  it('accepts optional fields including hyphenated keys', () => {
    const r = notifyPayloadSchema.safeParse({
      message: 'Coffee offline',
      title: 'Coffee Machine Offline',
      subtitle: 'Kitchen',
      url: 'https://example.com/status',
      image_url: 'https://example.com/img.png',
      expiration_date: '2026-04-23T09:00:00.000Z',
      'interruption-level': 'time-sensitive',
      'filter-criteria': 'work',
    });
    expect(r.success).toBe(true);
    if (r.success) {
      expect(r.data['interruption-level']).toBe('time-sensitive');
      expect(r.data['filter-criteria']).toBe('work');
    }
  });

  it('rejects invalid interruption-level', () => {
    const r = notifyPayloadSchema.safeParse({
      message: 'x',
      'interruption-level': 'loud',
    });
    expect(r.success).toBe(false);
  });

  it('rejects invalid expiration_date', () => {
    const r = notifyPayloadSchema.safeParse({
      message: 'x',
      expiration_date: 'not-a-date',
    });
    expect(r.success).toBe(false);
  });
});

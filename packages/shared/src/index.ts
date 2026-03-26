import { z } from "zod";

export const notifyPayloadSchema = z.object({
    title: z.string().min(1).max(200).optional(),
    subtitle: z.string().max(300).optional(),
    message: z.string().min(1).max(4000),
    url: z.string().url().optional(),
});

export type NotifyPayload = z.infer<typeof notifyPayloadSchema>;

export const registerBodySchema = z.object({
    expoPushToken: z.string().min(1).max(512),
});

export type RegisterBody = z.infer<typeof registerBodySchema>;

export const brrRegisterEndpointSchema = z.object({
    push_token: z.string().min(1).max(512),
    user_key_digest: z.string().min(8).max(256),
    key_digest: z.string().min(8).max(256),
    record_name: z.string().min(1).max(256),
});

export type BrrRegisterEndpointBody = z.infer<typeof brrRegisterEndpointSchema>;

export const brrNotifyPayloadSchema = z.union([
    notifyPayloadSchema,
    z.string().min(1).max(10_000),
]);

export type BrrNotifyPayload = z.infer<typeof brrNotifyPayloadSchema>;

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

export const deviceKindSchema = z.enum([
    "iphone",
    "ipad",
    "mac",
    "tv",
    "watch",
    "vision",
    "catalyst",
    "unspecified",
]);

export const pingRegisterEndpointSchema = z.object({
    push_token: z.string().min(1).max(512),
    key_digest: z.string().min(8).max(256),
    device_key_digest: z.string().min(8).max(256),
    record_name: z.string().min(1).max(256),
    user_record_name: z.string().min(8).max(256),
    device_label: z.string().min(1).max(256).optional(),
    device_kind: deviceKindSchema.optional(),
    apns_environment: z.enum(["sandbox", "production"]),
});

export type pingRegisterEndpointBody = z.infer<
    typeof pingRegisterEndpointSchema
>;

export const pingNotifyPayloadSchema = z.union([
    notifyPayloadSchema,
    z.string().min(1).max(10_000),
]);

export type pingNotifyPayload = z.infer<typeof pingNotifyPayloadSchema>;

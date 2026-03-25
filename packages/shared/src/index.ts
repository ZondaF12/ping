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

import admin from "firebase-admin";
import { prisma } from "./prisma.js";

export interface PushMessage {
  title: string;
  body: string;
  data: Record<string, string>;
}

let enabled = false;
try {
  const raw = process.env.FIREBASE_SERVICE_ACCOUNT ?? "";
  if (raw.trim() !== "") {
    admin.initializeApp({ credential: admin.credential.cert(JSON.parse(raw)) });
    enabled = true;
  } else {
    console.warn("[push] FIREBASE_SERVICE_ACCOUNT missing — push disabled");
  }
} catch (e) {
  console.warn("[push] init failed, push disabled:", (e as Error).message);
}

export function isPushEnabled(): boolean {
  return enabled;
}

async function safe<T>(fn: () => Promise<T>): Promise<T | null> {
  if (!enabled) return null;
  try {
    return await fn();
  } catch (e) {
    console.warn("[push] send failed:", (e as Error).message);
    return null;
  }
}

export function sendToTopic(topic: string, msg: PushMessage): Promise<string | null> {
  return safe(() =>
    admin.messaging().send({
      topic,
      notification: { title: msg.title, body: msg.body },
      data: msg.data,
    }),
  );
}

export function sendToUser(userId: number, msg: PushMessage): Promise<unknown | null> {
  return safe(async () => {
    const rows = await prisma.deviceToken.findMany({ where: { userId } });
    if (rows.length === 0) return null;
    const tokens = rows.map((r) => r.token);
    const res = await admin.messaging().sendEachForMulticast({
      tokens,
      notification: { title: msg.title, body: msg.body },
      data: msg.data,
    });
    const stale: string[] = [];
    res.responses.forEach((r, i) => {
      if (!r.success && r.error?.code === "messaging/registration-token-not-registered") {
        stale.push(tokens[i]);
      }
    });
    if (stale.length > 0) {
      await prisma.deviceToken.deleteMany({ where: { userId, token: { in: stale } } });
    }
    return res;
  });
}

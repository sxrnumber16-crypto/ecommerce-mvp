import { randomUUID } from "node:crypto";
import jwt from "jsonwebtoken";
import { config } from "../config.js";

export interface AccessPayload {
  sub: number;
  role: string;
}

export interface RefreshPayload {
  sub: number;
  jti: string;
}

export function signAccessToken(userId: number, role: string): string {
  return jwt.sign({ sub: userId, role }, config.jwtAccessSecret, { expiresIn: "15m" });
}

export function signRefreshToken(userId: number): string {
  // jti guarantees uniqueness: without it two tokens issued in the same
  // second for the same user are byte-identical and collide on tokenHash.
  return jwt.sign({ sub: userId, jti: randomUUID() }, config.jwtRefreshSecret, { expiresIn: "30d" });
}

export function verifyAccessToken(token: string): AccessPayload {
  return jwt.verify(token, config.jwtAccessSecret) as unknown as AccessPayload;
}

export function verifyRefreshToken(token: string): RefreshPayload {
  return jwt.verify(token, config.jwtRefreshSecret) as unknown as RefreshPayload;
}

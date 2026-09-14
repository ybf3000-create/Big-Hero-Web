import { hashSecret } from "./security.js";

interface AttemptBucket {
  failures: number[];
  blockedUntil: number;
}

export interface LoginLimitResult {
  allowed: boolean;
  retryAfterSeconds: number;
  delayMs: number;
}

export class LoginLimiter {
  private readonly ipBuckets = new Map<string, AttemptBucket>();
  private readonly accountBuckets = new Map<string, AttemptBucket>();

  constructor(private readonly now: () => number = Date.now) {}

  check(ip: string, username: string): LoginLimitResult {
    const current = this.now();
    const ipBucket = this.bucket(this.ipBuckets, hashSecret(ip), current);
    const accountBucket = this.bucket(this.accountBuckets, hashSecret(username), current);
    const blockedUntil = Math.max(ipBucket.blockedUntil, accountBucket.blockedUntil);
    const failures = Math.max(ipBucket.failures.length, accountBucket.failures.length);
    return {
      allowed: blockedUntil <= current,
      retryAfterSeconds: Math.max(0, Math.ceil((blockedUntil - current) / 1000)),
      delayMs: failures >= 5 ? Math.min(2000, (failures - 4) * 250) : 0,
    };
  }

  recordFailure(ip: string, username: string): void {
    const current = this.now();
    const ipBucket = this.bucket(this.ipBuckets, hashSecret(ip), current);
    const accountBucket = this.bucket(this.accountBuckets, hashSecret(username), current);
    ipBucket.failures.push(current);
    accountBucket.failures.push(current);
    if (ipBucket.failures.length >= 10) {
      ipBucket.blockedUntil = current + 15 * 60_000;
    }
    if (accountBucket.failures.length >= 5) {
      accountBucket.blockedUntil = current + 15 * 60_000;
    }
  }

  recordSuccess(ip: string, username: string): void {
    this.ipBuckets.delete(hashSecret(ip));
    this.accountBuckets.delete(hashSecret(username));
  }

  private bucket(map: Map<string, AttemptBucket>, key: string, current: number): AttemptBucket {
    let bucket = map.get(key);
    if (!bucket) {
      bucket = { failures: [], blockedUntil: 0 };
      map.set(key, bucket);
    }
    bucket.failures = bucket.failures.filter((time) => current - time < 10 * 60_000);
    if (bucket.blockedUntil <= current && bucket.failures.length === 0) {
      bucket.blockedUntil = 0;
    }
    return bucket;
  }
}

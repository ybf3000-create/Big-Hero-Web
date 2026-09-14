import { AppError } from "./errors.js";

export class WorkLimiter {
  private running = 0;
  private readonly queue: Array<() => void> = [];

  constructor(
    private readonly concurrency: number,
    private readonly maxQueued: number,
  ) {
    if (concurrency < 1 || maxQueued < 0) {
      throw new RangeError("invalid work limiter capacity");
    }
  }

  async run<T>(operation: () => Promise<T>): Promise<T> {
    if (this.running >= this.concurrency) {
      if (this.queue.length >= this.maxQueued) {
        throw new AppError("RATE_LIMITED", 429, "尝试过于频繁，请稍后再试");
      }
      await new Promise<void>((resolve) => this.queue.push(resolve));
    }

    this.running += 1;
    try {
      return await operation();
    } finally {
      this.running -= 1;
      this.queue.shift()?.();
    }
  }
}

export function auctionTransactionFee(price: bigint): bigint {
  if (price < 1n || price > 9_000_000_000_000_000n) {
    throw new RangeError("auction price is outside the supported range");
  }
  return (price * 5n) / 100n;
}

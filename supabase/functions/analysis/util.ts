import stats from "@stdlib/stats-base-dists-normal";
import stdev from "@stdlib/stats-base-stdev";

export type Normal = { mean: number; stdev: number, quantile( p: number ): number; }; // no idea why we need this but we do
// TODO switch to skewed normal distribution

export function std(x: number[]) {
  return stdev(x.length, 1, x, 1) || Number.EPSILON; // std cannot be 0, or things get unhappy.
}
export function avg(x: number[]) {
  return x.length === 0 ? 0 : x.reduce((a, b) => a + b, 0) / x.length;
}

export function normalSum(...terms: Normal[]) {
  return new stats.Normal(
    terms.reduce((t, a) => t + a.mean, 0),
    Math.sqrt(terms.reduce((t, a) => t + a.stdev * a.stdev, 0)),
  );
}

export function normalDifference(
  minuend: Normal,
  subtrahend: Normal,
) {
  return new stats.Normal(
    minuend.mean - subtrahend.mean,
    Math.sqrt(minuend.stdev * minuend.stdev + subtrahend.stdev * subtrahend.stdev),
  );
}

/**
 * Sigmoid/Logistic Interpolation
 * @param x The variable to scale (-∞, ∞) centered at 0.5
 * @param a The "compression factor". Higher = sharper slope
 * @returns The scaled variable (0, 1)
 */
export function sigmoid(x: number, a: number = 5): number {
  return 1 / (1 + Math.exp(a * (0.5 - x)));
}
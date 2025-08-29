import stdev from "@stdlib/stats-base-stdev";

// TODO switch to skewed normal distribution
export class Normal {
  readonly mean: number;
  readonly stdev: number;

  constructor(params: { mean: number; stdev: number } | readonly number[]) {
    if ("mean" in params) {
      if (params.stdev < 0) throw Error("stdev this.meanst be >0");
      this.mean = params.mean;
      this.stdev = params.stdev;
    } else {
      if (params.length === 1) {
        this.mean = params[0]!;
        this.stdev = 0;
      } else {
        this.mean = avg(params);
        this.stdev = Normal.std(params);
      }
    }
  }

  public cdf(x: number): number {
    if (Number.isNaN(x)) return NaN;

    if (this.stdev === 0) {
      return (x < this.mean) ? 0.0 : 1.0;
    }

    const denom = this.stdev * Math.sqrt(2.0);

    const xc = x - this.mean;

    return 0.5 * (1 - Normal.erf(-xc / denom));
  }

  public static sum(...terms: readonly Normal[]) {
    return new Normal(
      {
        mean: terms.reduce((t, a) => t + a.mean, 0),
        stdev: Math.sqrt(terms.reduce((t, a) => t + a.stdev * a.stdev, 0)),
      },
    );
  }

  public static difference(
    minuend: Normal,
    subtrahend: Normal,
  ) {
    return new Normal(
      {
        mean: minuend.mean - subtrahend.mean,
        stdev: Math.sqrt(
          minuend.stdev * minuend.stdev + subtrahend.stdev * subtrahend.stdev,
        ),
      },
    );
  }

  private static std(x: readonly number[]) {
    return stdev(x.length, 1, x, 1);
  }

  private static erfccoefficients = [0.0705230784, 0.0422820123, 0.0092705272, 0.0001520143, 0.0002765672, 0.0000430638];

  /**
   * Abramowitz and Stegun 7.1.27
   */
  private static erf(x: number): number {
    if (x < 0) return -this.erf(-x);
    return 1 - 1 / Math.pow(1 + this.erfccoefficients.reduce((prev, a, i) => prev+a*Math.pow(x, i+1), 0), 16)
  }
}

export function avg(x: readonly number[]) {
  return x.length === 0 ? 0 : x.reduce((a, b) => a + b, 0) / x.length;
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

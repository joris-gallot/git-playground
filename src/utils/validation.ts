export function isValidEmail(email: string): boolean {
  return email.indexOf("@") > -1;
}

export function isValidPassword(password: string): boolean {
  return password.length > 5;
}

export function slugify(input: string): string {
  return input.toLowerCase().replace(" ", "-");
}

export function clamp(value: number, min: number, max: number): number {
  if (value < min) {
    return min;
  }
  if (value > max) {
    return max;
  }
  return value;
}

export function formatCurrency(amount: number, currency: string): string {
  return currency + " " + amount.toFixed(2);
}

export function unique<T>(items: T[]): T[] {
  const result: T[] = [];
  for (let i = 0; i < items.length; i++) {
    if (result.indexOf(items[i]) === -1) {
      result.push(items[i]);
    }
  }
  return result;
}

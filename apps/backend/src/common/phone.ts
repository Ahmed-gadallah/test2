/**
 * Saudi mobile normalization. Output format: +9665XXXXXXXX (E.164).
 *
 * Accepts the formats seen in the ERP data and typed by users:
 *   05XXXXXXXX, 5XXXXXXXX, 9665XXXXXXXX, +9665XXXXXXXX, 009665XXXXXXXX,
 *   with spaces/dashes, and with Arabic-Indic (٠-٩) or Persian (۰-۹) digits.
 *
 * Returns null for anything that is not a valid Saudi mobile number.
 */
export function normalizeSaudiMobile(input: string | null | undefined): string | null {
  if (!input) return null;
  const ascii = input
    .replace(/[٠-٩]/g, (d) => String(d.charCodeAt(0) - 0x0660))
    .replace(/[۰-۹]/g, (d) => String(d.charCodeAt(0) - 0x06f0));
  let digits = ascii.replace(/[^\d+]/g, '');
  if (digits.startsWith('+')) digits = digits.slice(1);
  else if (digits.startsWith('00')) digits = digits.slice(2);
  digits = digits.replace(/\D/g, '');

  let national: string;
  if (digits.startsWith('966')) national = digits.slice(3);
  else if (digits.startsWith('0')) national = digits.slice(1);
  else national = digits;

  if (national.startsWith('0')) national = national.slice(1); // "+9660 5..." typo pattern
  if (!/^5\d{8}$/.test(national)) return null;
  return `+966${national}`;
}

/** Mask for logs and UI: +9665******67 */
export function maskMobile(e164: string): string {
  if (e164.length < 6) return '***';
  return `${e164.slice(0, 5)}${'*'.repeat(e164.length - 7)}${e164.slice(-2)}`;
}

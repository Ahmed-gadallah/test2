import { maskMobile, normalizeSaudiMobile } from './phone';

describe('normalizeSaudiMobile', () => {
  it.each([
    ['0500000001', '+966500000001'],
    ['500000001', '+966500000001'],
    ['966500000001', '+966500000001'],
    ['+966500000001', '+966500000001'],
    ['00966500000001', '+966500000001'],
    ['+966 50 000 0001', '+966500000001'],
    ['050-000-0001', '+966500000001'],
    ['٠٥٠٠٠٠٠٠٠١', '+966500000001'],
    ['۰۵۰۰۰۰۰۰۰۱', '+966500000001'],
    ['+9660500000001', '+966500000001'], // typo pattern seen in ERP data (13 digits)
  ])('%s → %s', (input, expected) => expect(normalizeSaudiMobile(input)).toBe(expected));

  it.each(['', '0112345678', '05000', '+201000000000', '05000000012', 'abc'])('rejects %s', (input) => {
    expect(normalizeSaudiMobile(input)).toBeNull();
  });

  it('masks numbers for logs', () => expect(maskMobile('+966500000001')).toBe('+9665******01'));
});

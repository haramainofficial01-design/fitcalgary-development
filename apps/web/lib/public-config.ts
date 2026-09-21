export const publicSupportEmail =
  process.env.NEXT_PUBLIC_SUPPORT_EMAIL?.trim() || 'ramy@fitxplor.com';

export const publicSupportMailto = `mailto:${publicSupportEmail}`;

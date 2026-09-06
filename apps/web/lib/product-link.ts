// Only known internal product destinations may be opened from notification data.
export function productLink(value: unknown): string | undefined {
  if (typeof value !== 'string') return undefined;
  const match = /^fitcalgary:\/\/(submissions|leaderboards|events)\/([a-zA-Z0-9-]+)$/.exec(value);
  return match ? `/${match[1]}/${match[2]}` : undefined;
}

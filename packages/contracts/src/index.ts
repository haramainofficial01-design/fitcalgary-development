export type Role = 'USER' | 'MODERATOR' | 'ADMIN' | 'PERSONAL_TRAINER' | 'JUDGE';
export type BoardType = 'OFFICIAL' | 'COMMUNITY';
export type RankingDirection = 'LOWER_IS_BETTER' | 'HIGHER_IS_BETTER';
export type MetricType = 'TIME' | 'REPETITIONS' | 'WEIGHT' | 'DISTANCE' | 'POINTS' | 'CUSTOM_NUMERIC';
export type SubmissionStatus = 'DRAFT' | 'UPLOADING' | 'PENDING_REVIEW' | 'APPROVED' | 'REJECTED' | 'CANCELLED';
export type PublishStatus = 'DRAFT' | 'PUBLISHED' | 'ARCHIVED';

export interface Page<T> { data: T[]; page: number; pageSize: number; total: number; }
export interface ApiError { error: { code: string; message: string; requestId: string; details?: Record<string, unknown> }; }
export interface GymSummary { id: string; slug: string; name: string; operator: string | null; area: string | null; city: string; categories: string[]; lowestOngoingMonthlyCents: number | null; pricingComplete: boolean; updatedAt: string; }
export interface EventSummary { id: string; slug: string; name: string; startAt: string; endAt: string | null; city: string; registrationOpen: boolean; category: string; status: 'ACTIVE' | 'CANCELLED' | 'POSTPONED'; }
export interface LeaderboardEntry { resultId: string; rank: number; previousRank: number | null; displayName: string; gymName: string | null; normalizedMetric: string; displayMetric: string; verifiedAt: string; verificationType: 'IN_PERSON' | 'COMMUNITY_REVIEWED'; }
export interface LeaderboardView { id: string; discipline: { id: string; slug: string; name: string; metricType: MetricType; unit: string; rankingDirection: RankingDirection }; division: { id: string; label: string }; boardType: BoardType; region: { id: string; name: string }; entries: LeaderboardEntry[]; }
export interface NotificationPayload { id: string; type: string; title: string; body: string; deepLink: string; createdAt: string; readAt: string | null; }
export interface AuthContext { subject: string; roles: Role[]; profileId: string | null; emailVerified: boolean; }

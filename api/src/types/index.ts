export interface JWTPayload {
  userId: string;
  householdId: string | null;
}

export interface AuthUser {
  id: string;
  email: string;
  name: string;
  householdId: string | null;
}

export type Frequency = 'daily' | 'weekly' | 'monthly' | 'as-needed';
export type EffortLevel = 'light' | 'medium' | 'heavy';

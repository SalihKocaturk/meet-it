export type PersonalityType = 'explorer' | 'social' | 'creative' | 'cozy';

export type ActivityType =
  | 'yeme-icme'
  | 'kultur-sanat'
  | 'spor-dogal'
  | 'eglence'
  | 'kafe-kahve';

export interface User {
  id: string;
  name: string;
  email: string;
  password: string;
  avatar: string;
  personalityType?: PersonalityType;
  quizCompleted: boolean;
  inviteCode: string;
  bio?: string;
  age?: number;
}

export interface Venue {
  id: string;
  name: string;
  description: string;
  activityTypes: ActivityType[];
  personalityMatch: PersonalityType[];
  location: string;
  district: string;
  rating: number;
  priceRange: '₺' | '₺₺' | '₺₺₺';
  emoji: string;
  tags: string[];
}

export interface QuizQuestion {
  id: number;
  text: string;
  options: {
    text: string;
    personality: PersonalityType;
  }[];
}

export interface MeetingSuggestion {
  venue: Venue;
  compatibilityScore: number;
  reason: string;
}

export interface AppState {
  users: User[];
  currentUser: User | null;
  friends: Record<string, string[]>; // userId -> friendIds
  pendingInvites: Record<string, string>; // inviteCode -> userId

  // Actions
  login: (email: string, password: string) => User | null;
  logout: () => void;
  completeQuiz: (userId: string, personality: PersonalityType) => void;
  updateProfile: (userId: string, updates: Partial<User>) => void;
  addFriendByCode: (inviterCode: string) => boolean;
  getSuggestedVenues: (
    activityTypes: ActivityType[],
    userId1: string,
    userId2: string
  ) => MeetingSuggestion[];
  getFriends: (userId: string) => User[];
  generateInviteLink: (userId: string) => string;
}

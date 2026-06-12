import React, { createContext, useContext, useState, useCallback } from 'react';
import { User, PersonalityType, ActivityType, MeetingSuggestion, AppState } from '../types';
import { STATIC_USERS, INITIAL_FRIENDS } from '../data/users';
import { VENUES } from '../data/venues';

const AppContext = createContext<AppState | null>(null);

export function AppProvider({ children }: { children: React.ReactNode }) {
  const [users, setUsers] = useState<User[]>(STATIC_USERS);
  const [currentUser, setCurrentUser] = useState<User | null>(null);
  const [friends, setFriends] = useState<Record<string, string[]>>(INITIAL_FRIENDS);

  // Build a map of inviteCode -> userId for quick lookup
  const pendingInvites = Object.fromEntries(
    users.map((u) => [u.inviteCode, u.id])
  );

  const login = useCallback(
    (email: string, password: string): User | null => {
      const found = users.find(
        (u) => u.email.toLowerCase() === email.toLowerCase() && u.password === password
      );
      if (found) {
        setCurrentUser(found);
        return found;
      }
      return null;
    },
    [users]
  );

  const logout = useCallback(() => {
    setCurrentUser(null);
  }, []);

  const completeQuiz = useCallback(
    (userId: string, personality: PersonalityType) => {
      setUsers((prev) =>
        prev.map((u) =>
          u.id === userId ? { ...u, personalityType: personality, quizCompleted: true } : u
        )
      );
      setCurrentUser((prev) =>
        prev && prev.id === userId
          ? { ...prev, personalityType: personality, quizCompleted: true }
          : prev
      );
    },
    []
  );

  const updateProfile = useCallback(
    (userId: string, updates: Partial<User>) => {
      setUsers((prev) =>
        prev.map((u) => (u.id === userId ? { ...u, ...updates } : u))
      );
      setCurrentUser((prev) =>
        prev && prev.id === userId ? { ...prev, ...updates } : prev
      );
    },
    []
  );

  const addFriendByCode = useCallback(
    (inviterCode: string): boolean => {
      if (!currentUser) return false;
      const inviterCode_trimmed = inviterCode.trim().toUpperCase();
      const targetUserId = pendingInvites[inviterCode_trimmed];
      if (!targetUserId) return false;
      if (targetUserId === currentUser.id) return false;

      const alreadyFriends = friends[currentUser.id]?.includes(targetUserId);
      if (alreadyFriends) return false;

      setFriends((prev) => ({
        ...prev,
        [currentUser.id]: [...(prev[currentUser.id] || []), targetUserId],
        [targetUserId]: [...(prev[targetUserId] || []), currentUser.id],
      }));
      return true;
    },
    [currentUser, pendingInvites, friends]
  );

  const getFriends = useCallback(
    (userId: string): User[] => {
      const friendIds = friends[userId] || [];
      return users.filter((u) => friendIds.includes(u.id));
    },
    [friends, users]
  );

  const getSuggestedVenues = useCallback(
    (activityTypes: ActivityType[], userId1: string, userId2: string): MeetingSuggestion[] => {
      const user1 = users.find((u) => u.id === userId1);
      const user2 = users.find((u) => u.id === userId2);

      const p1 = user1?.personalityType;
      const p2 = user2?.personalityType;

      // Score venues
      const scored = VENUES.filter((v) => {
        // Must match at least one selected activity type
        if (activityTypes.length === 0) return true;
        return v.activityTypes.some((at) => activityTypes.includes(at));
      }).map((venue) => {
        let score = 0;
        const reasons: string[] = [];

        // Personality match scoring
        if (p1 && venue.personalityMatch.includes(p1)) {
          score += 40;
          reasons.push(`${user1?.name ?? 'Kullanıcı 1'} kişiliğiyle uyumlu`);
        }
        if (p2 && venue.personalityMatch.includes(p2)) {
          score += 40;
          reasons.push(`${user2?.name ?? 'Kullanıcı 2'} kişiliğiyle uyumlu`);
        }

        // Activity type overlap bonus
        const matchedActivities = venue.activityTypes.filter((at) =>
          activityTypes.includes(at)
        ).length;
        score += matchedActivities * 10;
        if (matchedActivities > 1) {
          reasons.push('Birden fazla aktivite türünü kapsıyor');
        }

        // Rating bonus
        score += (venue.rating - 4) * 10;

        // Both personalities match = perfect fit
        if (
          p1 && p2 &&
          venue.personalityMatch.includes(p1) &&
          venue.personalityMatch.includes(p2)
        ) {
          score += 20;
          reasons.push('İki kişiye de mükemmel uyum');
        }

        // Default reason
        if (reasons.length === 0) {
          reasons.push('Seçtiğiniz aktivite türüne uygun');
        }

        return {
          venue,
          compatibilityScore: Math.min(100, Math.round(score)),
          reason: reasons.join(' · '),
        } as MeetingSuggestion;
      });

      // Sort by score descending, return top results
      return scored.sort((a, b) => b.compatibilityScore - a.compatibilityScore).slice(0, 6);
    },
    [users]
  );

  const generateInviteLink = useCallback(
    (userId: string): string => {
      const user = users.find((u) => u.id === userId);
      if (!user) return '';
      return `meetit://invite?code=${user.inviteCode}`;
    },
    [users]
  );

  const value: AppState = {
    users,
    currentUser,
    friends,
    pendingInvites,
    login,
    logout,
    completeQuiz,
    updateProfile,
    addFriendByCode,
    getFriends,
    getSuggestedVenues,
    generateInviteLink,
  };

  return <AppContext.Provider value={value}>{children}</AppContext.Provider>;
}

export function useApp(): AppState {
  const ctx = useContext(AppContext);
  if (!ctx) throw new Error('useApp must be used within AppProvider');
  return ctx;
}

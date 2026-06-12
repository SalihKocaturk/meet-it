import { User } from '../types';

export const STATIC_USERS: User[] = [
  {
    id: 'user-1',
    name: 'Ayşe Kaya',
    email: 'ayse@example.com',
    password: '123456',
    avatar: 'AK',
    personalityType: undefined,
    quizCompleted: false,
    inviteCode: 'AYSE-XK92',
    bio: 'Müzik ve kahve tutkunu ☕',
    age: 26,
  },
  {
    id: 'user-2',
    name: 'Mehmet Demir',
    email: 'mehmet@example.com',
    password: '123456',
    avatar: 'MD',
    personalityType: undefined,
    quizCompleted: false,
    inviteCode: 'MHMT-PL47',
    bio: 'Fotoğraf çekmeyi seven biri 📷',
    age: 28,
  },
  {
    id: 'user-3',
    name: 'Zeynep Arslan',
    email: 'zeynep@example.com',
    password: '123456',
    avatar: 'ZA',
    personalityType: 'social',
    quizCompleted: true,
    inviteCode: 'ZEYN-RT83',
    bio: 'Yeni yerler keşfetmeyi seviyorum 🗺️',
    age: 24,
  },
];

export const INITIAL_FRIENDS: Record<string, string[]> = {
  'user-1': ['user-3'],
  'user-2': [],
  'user-3': ['user-1'],
};

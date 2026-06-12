import { QuizQuestion } from '../types';

export const QUIZ_QUESTIONS: QuizQuestion[] = [
  {
    id: 1,
    text: 'Hafta sonu boş bir gün, ne yapmak istersin?',
    options: [
      { text: '🌲 Doğaya çıkar, yürüyüş veya bisiklet sürüşü yaparım', personality: 'explorer' },
      { text: '☕ Sevdiklerimle buluşur, kafede sohbet ederim', personality: 'social' },
      { text: '🎨 Müze, galeri ya da konser ziyaret ederim', personality: 'creative' },
      { text: '📚 Evde kitap okur, film izler, dinlenirim', personality: 'cozy' },
    ],
  },
  {
    id: 2,
    text: 'Tatil planın nasıl olurdu?',
    options: [
      { text: '🧗 Trekking, kamp ya da macera dolu bir rota', personality: 'explorer' },
      { text: '🏖️ Arkadaşlarla gidilen canlı bir tatil beldesi', personality: 'social' },
      { text: '🏛️ Tarihi şehirler, müzeler ve yerel kültür turu', personality: 'creative' },
      { text: '🏡 Sakin bir köy ya da sessiz bir otel, tam dinlenme', personality: 'cozy' },
    ],
  },
  {
    id: 3,
    text: 'Bir arkadaşınla buluşuyorsun. Nereye gitmek istersin?',
    options: [
      { text: '🚴 Yeni bir parkur keşfetmek ya da doğa yürüyüşü', personality: 'explorer' },
      { text: '🍻 Kalabalık ve enerjik bir mekân', personality: 'social' },
      { text: '🖼️ Sanat galerisi veya performans etkinliği', personality: 'creative' },
      { text: '☕ Sessiz ve sıcacık bir kafe', personality: 'cozy' },
    ],
  },
  {
    id: 4,
    text: 'Hangi tür film en çok seni çekiyor?',
    options: [
      { text: '🌍 Macera ve keşif filmleri', personality: 'explorer' },
      { text: '😂 Komedi ve romantik filmler, çok güldüm çok ağladım', personality: 'social' },
      { text: '🎬 Sanat filmleri ve bağımsız yapımlar', personality: 'creative' },
      { text: '🕵️ Gerilim veya drama, derin hikayeler', personality: 'cozy' },
    ],
  },
  {
    id: 5,
    text: 'Yeni biriyle tanıştığında nasıl davranırsın?',
    options: [
      { text: '🤝 Hemen ilgimi çeken şeyleri sorgulamaya başlarım', personality: 'explorer' },
      { text: '😄 Çok konuşur, çabuk ısınırım', personality: 'social' },
      { text: '🎵 Ortak ilgi alanlarımızı bulmaya çalışırım', personality: 'creative' },
      { text: '🤫 Biraz zaman tanır, sessizce gözlemlerim', personality: 'cozy' },
    ],
  },
  {
    id: 6,
    text: 'Günün en sevdiğin saati hangisi?',
    options: [
      { text: '🌅 Sabah erken, güneş doğarken', personality: 'explorer' },
      { text: '🌆 Akşam, hareketli şehir hayatı başlıyor', personality: 'social' },
      { text: '🌇 Öğleden sonra, en yaratıcı saatlerim', personality: 'creative' },
      { text: '🌙 Gece, herkes uyuduğunda kendim olurum', personality: 'cozy' },
    ],
  },
  {
    id: 7,
    text: 'Bir şehri gezmek için tercih ettiğin yöntem?',
    options: [
      { text: '🗺️ Haritasız gez, kaybol ve keşfet', personality: 'explorer' },
      { text: '👥 Rehberli grup turu, hem öğrenirsin hem sosyalleşirsin', personality: 'social' },
      { text: '📸 Fotoğraf çekerek, anları yakalayarak', personality: 'creative' },
      { text: '☕ Belli başlı yerleri seç, acele etme, derin dalmak istiyorum', personality: 'cozy' },
    ],
  },
  {
    id: 8,
    text: 'Stres attığında ne yaparsın?',
    options: [
      { text: '🏃 Spor yaparım, koşarım ya da bisiklete binerim', personality: 'explorer' },
      { text: '📱 Arkadaşlarımı arar ya da buluşmayı planlarım', personality: 'social' },
      { text: '🎸 Müzik dinler, çizerim ya da yazarım', personality: 'creative' },
      { text: '🛋️ Yalnız kalır, sessizlikte dinlenirim', personality: 'cozy' },
    ],
  },
];

export const PERSONALITY_LABELS: Record<string, string> = {
  explorer: 'Kaşif',
  social: 'Sosyal Kelebek',
  creative: 'Yaratıcı Ruh',
  cozy: 'Huzur Arayan',
};

export const PERSONALITY_DESCRIPTIONS: Record<string, string> = {
  explorer: 'Yeni deneyimler ve maceralar için can atıyorsun! Doğa, keşif ve aktif aktiviteler seni besliyor. Risk almaktan çekinmiyorsun ve her yeni yeri merakla karşılıyorsun.',
  social: 'İnsanlarla birlikte olmak sana enerji veriyor! Sosyal ortamlar, kalabalıklar ve canlı mekanlar tam sana göre. Yeni arkadaşlıklar kurmak ve ilişkileri beslemek en büyük tutkunun.',
  creative: 'Sanat, kültür ve yaratıcılık senin dünyan! Müzeler, galeriler, konserler ve özgün deneyimler seni besliyor. Her şeyde estetik ve derinlik arıyorsun.',
  cozy: 'Huzur ve derinlik senin için çok önemli. Sessiz kafeler, iyi sohbetler ve kaliteli vakit geçirme şeklin. Az ama öz, derinlikli ve anlamlı deneyimler arıyorsun.',
};

export const PERSONALITY_EMOJIS: Record<string, string> = {
  explorer: '🧭',
  social: '🦋',
  creative: '🎨',
  cozy: '🍵',
};

export const PERSONALITY_COLORS: Record<string, string> = {
  explorer: '#22c55e',
  social: '#f59e0b',
  creative: '#8b5cf6',
  cozy: '#3b82f6',
};

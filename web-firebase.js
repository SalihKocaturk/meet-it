// MeetIt web sayfaları için ortak Firebase başlatma (ES module).
// Hesapsız ziyaretçi anonim oturumla girer; Firestore kuralları yalnızca
// gerekli alanlara yazmasına izin verir (bkz. firestore.rules).
import { initializeApp } from "https://www.gstatic.com/firebasejs/10.12.2/firebase-app.js";
import { getAuth, signInAnonymously, onAuthStateChanged } from "https://www.gstatic.com/firebasejs/10.12.2/firebase-auth.js";
import { getFirestore } from "https://www.gstatic.com/firebasejs/10.12.2/firebase-firestore.js";
import { initializeAppCheck, ReCaptchaV3Provider } from "https://www.gstatic.com/firebasejs/10.12.2/firebase-app-check.js";

export function configReady() {
  const c = window.MEETIT_FIREBASE_CONFIG || {};
  return !!c.apiKey && !c.apiKey.includes("BURAYA") && !!c.appId && !c.appId.includes("BURAYA");
}

/** Firebase'i başlatır, anonim oturum açar. { db, uid } döner. */
export async function boot() {
  const app = initializeApp(window.MEETIT_FIREBASE_CONFIG);
  const siteKey = window.MEETIT_RECAPTCHA_SITE_KEY;
  if (siteKey) {
    initializeAppCheck(app, {
      provider: new ReCaptchaV3Provider(siteKey),
      isTokenAutoRefreshEnabled: true,
    });
  }
  const auth = getAuth(app);
  const user = await new Promise((resolve, reject) => {
    const off = onAuthStateChanged(auth, (u) => {
      if (u) { off(); resolve(u); }
    });
    signInAnonymously(auth).catch((e) => { off(); reject(e); });
  });
  return { db: getFirestore(app), uid: user.uid };
}

export const STORE = {
  ios: "https://apps.apple.com/tr/app/meetit/id6800778351",
  android: "https://play.google.com/store/apps/details?id=com.kocaturksalih.meetit",
};

/** Kullanıcının cihazına göre mağaza linki. */
export function storeLink() {
  const ua = navigator.userAgent || "";
  if (/Android/i.test(ua)) return STORE.android;
  return STORE.ios;
}

export function esc(s) {
  const d = document.createElement("div");
  d.textContent = s == null ? "" : String(s);
  return d.innerHTML;
}

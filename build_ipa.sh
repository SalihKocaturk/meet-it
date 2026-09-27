#!/usr/bin/env bash
# MeetIt — iOS IPA build
# Kullanım:
#   ./build_ipa.sh                 -> TestFlight / App Store Connect için
#   ./build_ipa.sh release-testing -> Ad-hoc (cihaz UDID'si kayıtlı olmalı)
#   ./build_ipa.sh --fast          -> clean atlanır (hızlı tekrar build)
#   ./build_ipa.sh --repair        -> bozuk pub cache / Pods / DerivedData temizliği
set -euo pipefail
cd "$(dirname "$0")"

METHOD="app-store-connect"
FAST=0
REPAIR=0
for arg in "$@"; do
  case "$arg" in
    --fast)   FAST=1 ;;
    --repair) REPAIR=1 ;;
    *)      METHOD="$arg" ;;
  esac
done

if [ "$REPAIR" -eq 1 ]; then
  echo "▶ bozuk pub cache paketleri siliniyor"
  rm -rf "$HOME"/.pub-cache/hosted/pub.dev/sign_in_with_apple-*
  rm -rf "$HOME"/.pub-cache/hosted/pub.dev/google_mobile_ads-*
  echo "▶ Pods / symlinks / DerivedData siliniyor"
  rm -rf ios/Pods ios/Podfile.lock ios/.symlinks build
  rm -rf "$HOME/Library/Developer/Xcode/DerivedData"
fi

if [ "$FAST" -eq 0 ]; then
  echo "▶ flutter clean"
  flutter clean
fi

# TestFlight aynı build numarasını iki kez kabul etmiyor -> otomatik artır
if [ "$METHOD" = "app-store-connect" ] || [ "$METHOD" = "app-store" ]; then
  OLD="$(grep -m1 '^version:' pubspec.yaml)"
  NEW="$(python3 -c "
import re,sys
l=sys.argv[1]
m=re.match(r'version:\\s*([0-9.]+)\\+([0-9]+)', l)
print('version: %s+%d' % (m.group(1), int(m.group(2))+1) if m else l)
" "$OLD")"
  if [ "$OLD" != "$NEW" ]; then
    python3 - "$OLD" "$NEW" <<'PYEOF'
import io,sys
p='pubspec.yaml'
s=io.open(p,encoding='utf-8').read().replace(sys.argv[1], sys.argv[2], 1)
io.open(p,'w',encoding='utf-8').write(s)
PYEOF
    echo "▶ build no artırıldı: $OLD -> $NEW"
  fi
fi

echo "▶ flutter pub get"
flutter pub get

echo "▶ pod install"
if [ "$REPAIR" -eq 1 ]; then
  ( cd ios && pod install --repo-update )
else
  ( cd ios && pod install )
fi

echo "▶ flutter build ipa  (export-method: $METHOD)"
if ! flutter build ipa \
      --release \
      --dart-define-from-file=dart_defines.json \
      --export-method="$METHOD"; then
  # Eski Flutter sürümleri farklı isimlendirme kullanıyor
  case "$METHOD" in
    app-store-connect) FALLBACK="app-store" ;;
    release-testing)   FALLBACK="ad-hoc" ;;
    debugging)         FALLBACK="development" ;;
    *)                 FALLBACK="$METHOD" ;;
  esac
  echo "▶ '$METHOD' kabul edilmedi, '$FALLBACK' deneniyor"
  if ! flutter build ipa \
        --release \
        --dart-define-from-file=dart_defines.json \
        --export-method="$FALLBACK"; then
    # Son çare: export-method bayrağı olmadan, düz komut
    echo "▶ export-method olmadan deneniyor"
    flutter build ipa --release --dart-define-from-file=dart_defines.json
  fi
fi

IPA="$(ls -1t build/ios/ipa/*.ipa 2>/dev/null | head -1 || true)"
echo
if [ -n "$IPA" ]; then
  echo "✅ IPA hazır: $IPA"
  echo "   TestFlight'a yükle: Transporter.app'e sürükle (App Store'dan ücretsiz)"
else
  echo "⚠️  IPA üretilmedi. Arşiv: build/ios/archive/Runner.xcarchive"
  echo "   Xcode > Window > Organizer üzerinden dağıtabilirsin."
fi

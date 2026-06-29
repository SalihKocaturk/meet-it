import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meetit/core/constants/app_colors.dart';
import 'package:meetit/core/utils/important_action_guard.dart';
import 'package:meetit/features/auth/providers/auth_provider.dart';
import 'package:meetit/features/match/providers/match_provider.dart';
import 'package:meetit/features/match/providers/venue_search_provider.dart';
import 'package:meetit/features/personality/models/personality_model.dart';

// ── "Mekan Bul" Sabit (Asılı) Alt Bar ────────────────────────────────────────
//
// Kullanıcı talebi: buton liste içinde EN ALTTA bir sliver olduğu için tüm
// filtreler eklenince ekranın çok aşağısına gidiyordu, kullanıcı görmek
// için tamamen sona kadar kaydırmak zorunda kalıyordu. Artık MatchPage'in
// build()'inde bir Stack ile ekranın en altına SABİTLENDİ (diğer
// filtreler bunun ÜZERİNDEN/ALTINDAN kayar) — eski mantık (guard'lar,
// arama çağrısı, navigasyon, hata mesajı) burada AYNEN korunuyor, sadece
// bir SliverToBoxAdapter içinden bağımsız bir widget'a taşındı. Mesafe
// filtresi (maxVenueDistanceKm) artık searchVenues() çağrısına da
// iletiliyor (bkz. venue_search_notifier.dart).
//
// Kullanıcı talebi (#160): buton arkasındaki arka plan/gölge panel VE
// butonun altındaki "solo_hint" metni tamamen kaldırıldı — artık SADECE
// buton kendisi ekranda yüzüyor, altında hiçbir panel/yazı yok.
/// 🎬 Yükleniyor border'ı: buton etrafındaki yuvarlatılmış dikdörtgenin
/// kenarını bir `Path` olarak alıp, sadece `progress` (0..1) kadarlık bir
/// kısmını çizer. Dışta hafif bulanık (glow) bir kopya + üstte net bir
/// çizgi ile "parlayan" bir görünüm elde edilir. Gerçek bir ilerleme
/// yüzdesi bilinmediğinden (ağ gecikmesi değişken), `progress` sürekli
/// 0→1 arası döngüye giren bir animasyondan besleniyor — kullanıcı arama
/// sürerken "hâlâ çalışıyor" hissini görsel olarak takip edebiliyor.
class _LoadingBorderPainter extends CustomPainter {
  final double progress;
  final double radius;
  final Color color;

  _LoadingBorderPainter({
    required this.progress,
    required this.radius,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(1.5, 1.5, size.width - 3, size.height - 3),
      Radius.circular(radius),
    );
    final fullPath = Path()..addRRect(rrect);
    final metrics = fullPath.computeMetrics().toList();
    if (metrics.isEmpty) return;
    final metric = metrics.first;
    final total = metric.length;

    // 📍 SİLME YÖNÜ DÜZELTMESİ (2026-06-28): Kullanıcı talebi — eskiden
    // (reverse:true ile) segment HER ZAMAN sabit `0` noktasından başlayıp
    // (`extractPath(0, visibleLength)`) sadece UCU büyüyüp küçülüyordu;
    // yani "boşalma" sırasında uç geri çekiliyordu — kullanıcı bunu
    // "alttan silinme" olarak tarif etti ve bunun TERSİNİ istedi: boşalma
    // sırasında BAŞLANGIÇ noktası (kuyruk) İLERİ doğru hareket etsin, uç
    // (baş) ise YERİNDE sabit kalsın — çizgi sanki "devam ediyormuş gibi
    // görünüp arkadan silinsin" ("üstten silinme"). Bunu `progress`
    // (0→1, controller artık DÜZ döngü — `..repeat()`, reverse YOK) tek bir
    // periyodu iki faza bölerek elde ediyoruz:
    //   • Faz 1 (0.0-0.5, "dolma"): kuyruk sabit 0'da, baş 0→total büyür.
    //   • Faz 2 (0.5-1.0, "boşalma"): baş sabit total'de, kuyruk 0→total
    //     ilerleyerek başa yetişir — görünen kısım hep İLERİ doğru "kayar",
    //     asla geriye doğru küçülmez.
    double startLength;
    double endLength;
    if (progress < 0.5) {
      final p = progress / 0.5;
      startLength = 0;
      endLength = total * p;
    } else {
      final p = (progress - 0.5) / 0.5;
      startLength = total * p;
      endLength = total;
    }
    if (endLength - startLength <= 0) return;
    final segment = metric.extractPath(startLength, endLength);

    final glowPaint = Paint()
      ..color = color.withOpacity(0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawPath(segment, glowPaint);

    final corePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(segment, corePaint);
  }

  @override
  bool shouldRepaint(covariant _LoadingBorderPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

class FindVenueButtonBar extends ConsumerStatefulWidget {
  const FindVenueButtonBar({super.key});

  @override
  ConsumerState<FindVenueButtonBar> createState() => _FindVenueButtonBarState();
}

class _FindVenueButtonBarState extends ConsumerState<FindVenueButtonBar>
    with SingleTickerProviderStateMixin {
  // Animasyon kontrolcüsü SADECE bu widget'ın görsel (UI-local) loading
  // efekti için — arama/iş mantığı state'i hâlâ tamamen Riverpod
  // (venueSearchProvider) üzerinden yönetiliyor, burada değişen bir şey
  // yok. AnimationController'ın bir TickerProvider'a (vsync) bağlı olması
  // gerektiğinden bu tek istisna StatefulWidget olarak kalıyor.
  late final AnimationController _borderController;

  @override
  void initState() {
    super.initState();
    _borderController = AnimationController(
      vsync: this,
      // Bir periyot = dolma + boşalma (her biri yaklaşık yarı süre) —
      // bkz. _LoadingBorderPainter.paint() içindeki faz mantığı. Kullanıcı
      // talebi (2026-06-28): efekt çok hızlı hissettiriliyordu — `duration`
      // büyütüldükçe animasyon DAHA YAVAŞ oynar (1600ms → 7000ms), çünkü
      // bu süre periyodun TAMAMINI (dolma+boşalma) kapsıyor; her faz bu
      // sürenin yarısını kullanıyor.
      duration: const Duration(milliseconds: 7000),
      // 📍 SİLME YÖNÜ DÜZELTMESİ (2026-06-28): Kullanıcı talebi — `reverse:
      // true` border'ı YUMUŞAK dolup-boşaltıyordu ama boşalma sırasında uç
      // GERİ çekiliyordu ("alttan silinme"). Artık bu animasyon DÜZ bir
      // döngü (`..repeat()`, reverse YOK) — dolma/boşalma fazlarının
      // YÖNÜNÜ artık `_LoadingBorderPainter` kendi içinde `progress`
      // değerine göre hesaplıyor (0.0-0.5 dolma, 0.5-1.0 boşalma), böylece
      // boşalma sırasında kuyruk İLERİ kayıyor, uç sabit kalıyor
      // ("üstten silinme").
    );
    // 📍 RESET DÜZELTMESİ (2026-06-29): Kullanıcı talebi — önceden
    // `..repeat()` burada (initState'te) SÜREKLİ çalışıyordu; widget hiç
    // kaybolmasa bile arka planda dönmeye devam ediyordu. Bu yüzden bir
    // arama bitip yeni arama başladığında animasyon HER ZAMAN bir önceki
    // aramanın bittiği `progress` değerinden devam ediyordu, asla 0'dan
    // başlamıyordu. Artık controller'ı BURADA başlatmıyoruz — sadece
    // build()'teki `ref.listen` (aşağıda) her arama başladığında
    // `reset()+repeat()`, her arama bittiğinde `stop()+reset()` çağırıyor.
  }

  @override
  void dispose() {
    _borderController.dispose();
    super.dispose();
  }

  // NOT: ConsumerState'te build SADECE (BuildContext context) alır — eski
  // ConsumerWidget'taki gibi 'WidgetRef ref' ikinci parametre OLARAK
  // gelmiyor. 'ref', ConsumerState'in miras alınan bir ÜYESİ (property) —
  // doğrudan 'ref.watch(...)' / 'ref.read(...)' şeklinde erişiliyor.
  @override
  Widget build(BuildContext context) {
    final selectedFriend = ref.watch(selectedFriendProvider);
    final isSearchLoading = ref.watch(
      venueSearchProvider.select((s) => s.isLoading),
    );

    // 📍 RESET DÜZELTMESİ (2026-06-29): `isSearchLoading` false→true
    // (yeni arama başladı) olduğunda border animasyonu SIFIRDAN başlasın
    // (`reset()` + `repeat()`); true→false (mekan(lar) bulundu/arama
    // bitti) olduğunda da DURUP sıfırlansın (`stop()` + `reset()`) — bir
    // sonraki arama asla önceki aramanın bıraktığı `progress` değerinden
    // devam etmesin.
    ref.listen(venueSearchProvider.select((s) => s.isLoading), (
      previous,
      next,
    ) {
      if (next) {
        _borderController
          ..reset()
          ..repeat();
      } else {
        _borderController
          ..stop()
          ..reset();
      }
    });

    // Arkadaş seçilmese de tek başına mekan arama yapılabilsin — buton
    // her zaman aktif.
    const isEnabled = true;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          child: Stack(
            children: [
              // ⚠️ Stack varsayılan olarak (StackFit.loose) non-positioned
              // çocuklarına GEVŞEK (loose) genişlik kısıtı verir — yani
              // ElevatedButton, SizedBox(width: double.infinity) içinde
              // olsa bile artık tam genişliğe ZORLANMIYOR, sadece kendi
              // içeriğine (ikon+yazı) göre dar bir genişlik alıyor. Bu da
              // butonun "yarısı görünüyor" hissini ve etrafındaki
              // Positioned.fill border'ın (tam Stack genişliğinde) butona
              // OTURMAMASINI açıklıyor. Çözüm: butonu burada AYRICA bir
              // SizedBox(width: double.infinity) ile sarıp tam genişliğe
              // ZORLUYORUZ.
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isEnabled && !isSearchLoading
                      ? () async {
                          // Önemli işlem koruması: e-posta doğrulanmamışsa
                          // veya kişilik testi tamamlanmamışsa burada
                          // engellenir (bkz. important_action_guard.dart).
                          final canProceed =
                              await ensureEmailVerified(context, ref) &&
                              await ensurePersonalityReady(context, ref);
                          if (!canProceed) return;

                          final currentUser = ref.read(currentUserProvider);
                          final activities = ref.read(
                            selectedActivitiesProvider,
                          );
                          final userProfile =
                              currentUser?.personalityProfile ??
                              PersonalityProfile.mock(
                                PersonalityType.sosyalKelebek,
                              );
                          // Arkadaş seçilmediyse kendi profili kullanılır
                          // (tek başına buluşma modu).
                          final friendProfile =
                              selectedFriend?.personalityProfile ?? userProfile;
                          final priceLevel = ref.read(
                            selectedPriceLevelProvider,
                          );
                          final userLoc = ref.read(userLocationProvider);
                          final maxDistanceKm = ref.read(
                            selectedMaxDistanceKmProvider,
                          );

                          await ref
                              .read(venueSearchProvider.notifier)
                              .searchVenues(
                                userProfile: userProfile,
                                friendProfile: friendProfile,
                                selectedActivities: activities.toList(),
                                friendUid: selectedFriend?.uid,
                                priceLevel: priceLevel,
                                userLat: userLoc?.lat,
                                userLng: userLoc?.lng,
                                maxVenueDistanceKm: maxDistanceKm,
                              );

                          if (!context.mounted) return;

                          // ── Artık varsayılan görünüm HARİTA: tek buton
                          // hem aramayı yapıyor hem de sonuçları haritada
                          // gösteriyor. Liste/harita geçişi ARTIK
                          // Navigator.push/pop İLE YAPILMIYOR — sadece iki
                          // state (showVenuesProvider + showMapViewProvider)
                          // değişiyor ve MatchPage'in gövdesi buna göre
                          // yeniden çiziliyor. Bu sayede "geri" tuşu her
                          // zaman tek basışta doğrudan forma döner — eskiden
                          // (push/pop kullanılırken) bir ara ekrana (önceki
                          // görünüme) gidip ikinci bir geri basışı
                          // gerektiriyordu.
                          final result = ref.read(venueSearchProvider);
                          if (!result.hasResults) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  result.errorMessage ??
                                      'match.no_venues_found'.tr(),
                                ),
                              ),
                            );
                            return;
                          }

                          ref.read(showMapViewProvider.notifier).state = true;
                          ref.read(showVenuesProvider.notifier).state = true;
                        }
                      : null,
                  icon: isSearchLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.search, color: Colors.white),
                  label: Text(
                    'match.see_venues'.tr(),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colors.primary,
                    disabledBackgroundColor: context.colors.primary.withOpacity(
                      0.35,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 4,
                    shadowColor: Colors.black.withOpacity(0.25),
                  ),
                ),
              ),

              // ── Aranıyorken: butonun kenarını yavaş yavaş kaplayan
              // parlak yeşil border animasyonu ────────────────────────
              if (isSearchLoading)
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _borderController,
                      builder: (context, _) {
                        return CustomPaint(
                          painter: _LoadingBorderPainter(
                            progress: _borderController.value,
                            radius: 14,
                            color: const Color(0xFF00E676),
                          ),
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

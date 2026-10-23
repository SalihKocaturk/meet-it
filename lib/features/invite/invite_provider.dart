import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Davet eden kişi (uid + varsa linkteki ilk ad).
class InviteRef {
  final String uid;
  final String? name;

  const InviteRef(this.uid, [this.name]);

  Map<String, dynamic> toJson() => {'uid': uid, if (name != null) 'name': name};

  static InviteRef? fromJson(String? raw) {
    if (raw == null) return null;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final uid = m['uid'] as String?;
      if (uid == null || uid.isEmpty) return null;
      return InviteRef(uid, m['name'] as String?);
    } catch (_) {
      return null;
    }
  }
}

/// Davet akışının kalıcı durumu (uygulama kapanıp açılsa da korunur):
///  • [pending] — linkten/panodan gelen, henüz işlenmemiş davet. Kullanıcı
///    giriş yapıp profilini tamamlayınca otomatik arkadaşlık kurulur.
///  • [reveal]  — arkadaşlık kuruldu; kullanıcı kişilik testini bitirince
///    davet edenle uyum ekranı gösterilecek.
class InviteState {
  final InviteRef? pending;
  final InviteRef? reveal;
  final bool loaded;

  const InviteState({this.pending, this.reveal, this.loaded = false});
}

class InviteNotifier extends Notifier<InviteState> {
  static const _kPending = 'invite_pending';
  static const _kReveal = 'invite_reveal';

  @override
  InviteState build() {
    _load();
    return const InviteState();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final loadedPending = InviteRef.fromJson(prefs.getString(_kPending));
      final loadedReveal = InviteRef.fromJson(prefs.getString(_kReveal));
      // Yükleme sürerken linkten gelmiş bir davet varsa onu ezme.
      state = InviteState(
        pending: state.pending ?? loadedPending,
        reveal: state.reveal ?? loadedReveal,
        loaded: true,
      );
    } catch (_) {
      state = InviteState(
        pending: state.pending,
        reveal: state.reveal,
        loaded: true,
      );
    }
  }

  Future<void> _save(String key, InviteRef? value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value == null) {
        await prefs.remove(key);
      } else {
        await prefs.setString(key, jsonEncode(value.toJson()));
      }
    } catch (_) {}
  }

  Future<void> setPending(InviteRef invite) async {
    state = InviteState(pending: invite, reveal: state.reveal, loaded: state.loaded);
    await _save(_kPending, invite);
  }

  Future<void> clearPending() async {
    state = InviteState(reveal: state.reveal, loaded: state.loaded);
    await _save(_kPending, null);
  }

  Future<void> setReveal(InviteRef invite) async {
    state = InviteState(pending: state.pending, reveal: invite, loaded: state.loaded);
    await _save(_kReveal, invite);
  }

  Future<void> clearReveal() async {
    state = InviteState(pending: state.pending, loaded: state.loaded);
    await _save(_kReveal, null);
  }
}

final inviteProvider =
    NotifierProvider<InviteNotifier, InviteState>(InviteNotifier.new);

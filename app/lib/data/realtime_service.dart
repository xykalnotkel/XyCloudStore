import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../core/config.dart';
import 'api_client.dart';

enum RealtimeState { connecting, online, offline }

/// Channel realtime ke Cloudflare Durable Object.
///
/// Server mengirim event JSON:
///   {"type":"order.update","payload":{...}}
///   {"type":"chat.message","payload":{...}}
///   {"type":"stock.update","payload":{"id":"pc-1","unitTersedia":3}}
///   {"type":"cs.typing","payload":{"typing":true}}
class RealtimeService {
  RealtimeService(this._api);

  final ApiClient _api;
  WebSocketChannel? _ch;
  StreamSubscription? _sub;
  Timer? _ping;
  Timer? _retry;
  int _attempt = 0;
  bool _sengajaTutup = false;
  String? _room;

  final _events = StreamController<RealtimeEvent>.broadcast();
  final _state = StreamController<RealtimeState>.broadcast();

  Stream<RealtimeEvent> get events => _events.stream;
  Stream<RealtimeState> get state => _state.stream;
  RealtimeState current = RealtimeState.offline;

  void _setState(RealtimeState s) {
    current = s;
    if (!_state.isClosed) _state.add(s);
  }

  Future<void> connect({required String room}) async {
    _room = room;
    _sengajaTutup = false;
    await _open();
  }

  Future<void> _open() async {
    final room = _room;
    if (room == null || _sengajaTutup) return;
    _setState(RealtimeState.connecting);
    try {
      String? ticket;
      if (room.startsWith('user:')) {
        final hasil = await _api.post('/ws/ticket', {'room': room});
        ticket = hasil is Map ? hasil['ticket'] as String? : null;
        if (ticket == null || ticket.isEmpty) {
          throw const FormatException('Ticket realtime tidak tersedia.');
        }
      }
      if (_sengajaTutup || room != _room) return;
      final channel = WebSocketChannel.connect(Uri.parse(XyConfig.wsUrl(room, ticket: ticket)));
      _ch = channel;
      await channel.ready.timeout(const Duration(seconds: 10));
      if (_sengajaTutup || room != _room || !identical(_ch, channel)) {
        await channel.sink.close();
        return;
      }
      _attempt = 0;
      _retry?.cancel();
      _setState(RealtimeState.online);
      _sub = channel.stream.listen(
        (data) {
          try {
            final m = jsonDecode(data as String) as Map<String, dynamic>;
            if (m['type'] == 'pong') return;
            if (!_events.isClosed) {
              _events.add(RealtimeEvent(m['type'] ?? '', (m['payload'] ?? {}) as Map<String, dynamic>));
            }
          } catch (_) {/* abaikan frame non-JSON */}
        },
        onDone: () { if (identical(_ch, channel)) _handleDrop(); },
        onError: (_) { if (identical(_ch, channel)) _handleDrop(); },
        cancelOnError: true,
      );
      _ping?.cancel();
      _ping = Timer.periodic(const Duration(seconds: 25), (_) => send('ping', {}));
    } catch (_) {
      _handleDrop();
    }
  }

  Future<void> _tutupChannel(WebSocketChannel? channel) async {
    try { await channel?.sink.close(); } catch (_) {}
  }

  void _handleDrop() {
    _ping?.cancel();
    _sub?.cancel();
    final channel = _ch;
    _ch = null;
    unawaited(_tutupChannel(channel));
    _setState(RealtimeState.offline);
    if (_sengajaTutup || (_retry?.isActive ?? false)) return;
    // exponential backoff + jitter, maks 20 detik. Reconnect mengambil ticket
    // baru; capability lama tidak pernah dipakai ulang setelah kedaluwarsa.
    final delay = min(20, pow(2, _attempt++).toInt()) * 1000 + Random().nextInt(600);
    _retry = Timer(Duration(milliseconds: delay), () {
      _retry = null;
      unawaited(_open());
    });
  }

  void send(String type, Map<String, dynamic> payload) {
    try {
      _ch?.sink.add(jsonEncode({'type': type, 'payload': payload}));
    } catch (_) {}
  }

  Future<void> dispose() async {
    _sengajaTutup = true;
    _ping?.cancel();
    _retry?.cancel();
    await _sub?.cancel();
    await _ch?.sink.close();
    await _events.close();
    await _state.close();
  }
}

class RealtimeEvent {
  final String type;
  final Map<String, dynamic> payload;
  RealtimeEvent(this.type, this.payload);
}

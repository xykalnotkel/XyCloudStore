/// Model XyCloud Live dipisah agar models.dart tetap kompatibel dengan data lama.
class LivestreamItem {
  const LivestreamItem({
    required this.id,
    required this.creatorName,
    required this.title,
    required this.game,
    required this.status,
    this.creatorId,
    this.creatorPhoto,
    this.startedAt,
    this.scheduledEnd,
    this.viewers = 0,
    this.viewerPeak = 0,
    this.grossTip = 0,
    this.shareUrl = '',
    this.canWatch = false,
  });

  final String id;
  final String? creatorId;
  final String creatorName;
  final String? creatorPhoto;
  final String title;
  final String game;
  final String status;
  final DateTime? startedAt;
  final DateTime? scheduledEnd;
  final int viewers;
  final int viewerPeak;
  final int grossTip;
  final String shareUrl;
  final bool canWatch;

  factory LivestreamItem.fromJson(Map<String, dynamic> j) => LivestreamItem(
        id: '${j['id'] ?? ''}',
        creatorId: j['creator_id'] as String?,
        creatorName: '${j['creator_name'] ?? 'Kreator XyCloud'}',
        creatorPhoto: j['creator_photo'] as String?,
        title: '${j['title'] ?? 'Livestream gamer'}',
        game: '${j['game'] ?? 'Game'}',
        status: '${j['status'] ?? 'ended'}',
        startedAt: DateTime.tryParse('${j['started_at'] ?? ''}'),
        scheduledEnd: DateTime.tryParse('${j['scheduled_end'] ?? ''}'),
        viewers: (j['viewers'] as num?)?.toInt() ?? 0,
        viewerPeak: (j['viewer_peak'] as num?)?.toInt() ?? 0,
        grossTip: (j['gross_tip'] as num?)?.toInt() ?? 0,
        shareUrl: '${j['share_url'] ?? ''}',
        canWatch: j['can_watch'] == true,
      );

  LivestreamItem copyWith({String? status, int? viewers, int? grossTip}) =>
      LivestreamItem(
        id: id,
        creatorId: creatorId,
        creatorName: creatorName,
        creatorPhoto: creatorPhoto,
        title: title,
        game: game,
        status: status ?? this.status,
        startedAt: startedAt,
        scheduledEnd: scheduledEnd,
        viewers: viewers ?? this.viewers,
        viewerPeak: viewerPeak,
        grossTip: grossTip ?? this.grossTip,
        shareUrl: shareUrl,
        canWatch: ['starting', 'live'].contains(status ?? this.status),
      );
}

class LiveCatalog {
  const LiveCatalog({
    this.enabled = false,
    this.minTip = 5000,
    this.maxTip = 500000,
    this.platformFeeBps = 2000,
    this.streams = const [],
  });

  final bool enabled;
  final int minTip;
  final int maxTip;
  final int platformFeeBps;
  final List<LivestreamItem> streams;

  factory LiveCatalog.fromJson(Map<String, dynamic> j) => LiveCatalog(
        enabled: j['enabled'] == true,
        minTip: (j['min_tip'] as num?)?.toInt() ?? 5000,
        maxTip: (j['max_tip'] as num?)?.toInt() ?? 500000,
        platformFeeBps: (j['platform_fee_bps'] as num?)?.toInt() ?? 2000,
        streams: (j['streams'] as List? ?? const [])
            .whereType<Map>()
            .map((x) => LivestreamItem.fromJson(Map<String, dynamic>.from(x)))
            .toList(),
      );
}

class LiveDiagnostics {
  const LiveDiagnostics({
    this.quality = 'offline',
    this.healthCode = 'UNKNOWN',
    this.checkedAt,
    this.reconnecting = false,
    this.cleanupPending = false,
    this.congestion,
    this.bytesSent = 0,
    this.durationMs = 0,
    this.skippedFrames = 0,
    this.totalFrames = 0,
    this.failureCode,
    this.endReason,
  });

  final String quality;
  final String healthCode;
  final DateTime? checkedAt;
  final bool reconnecting;
  final bool cleanupPending;
  final double? congestion;
  final int bytesSent;
  final int durationMs;
  final int skippedFrames;
  final int totalFrames;
  final String? failureCode;
  final String? endReason;

  double get skippedRatio => totalFrames <= 0 ? 0 : skippedFrames / totalFrames;

  factory LiveDiagnostics.fromJson(Map<String, dynamic> j) => LiveDiagnostics(
        quality: '${j['quality'] ?? 'offline'}',
        healthCode: '${j['health_code'] ?? 'UNKNOWN'}',
        checkedAt: DateTime.tryParse('${j['checked_at'] ?? ''}'),
        reconnecting: j['reconnecting'] == true,
        cleanupPending: j['cleanup_pending'] == true,
        congestion: (j['congestion'] as num?)?.toDouble(),
        bytesSent: (j['bytes_sent'] as num?)?.toInt() ?? 0,
        durationMs: (j['duration_ms'] as num?)?.toInt() ?? 0,
        skippedFrames: (j['skipped_frames'] as num?)?.toInt() ?? 0,
        totalFrames: (j['total_frames'] as num?)?.toInt() ?? 0,
        failureCode: j['failure_code'] as String?,
        endReason: j['end_reason'] as String?,
      );
}

class CreatorLiveData {
  const CreatorLiveData({
    this.featureEnabled = false,
    this.profile,
    this.active,
    this.activeDiagnostics,
    this.lastBroadcast,
    this.lastDiagnostics,
    this.earning = const {},
    this.payouts = const [],
    this.minPayout = 100000,
    this.holdDays = 7,
  });

  final bool featureEnabled;
  final Map<String, dynamic>? profile;
  final LivestreamItem? active;
  final LiveDiagnostics? activeDiagnostics;
  final LivestreamItem? lastBroadcast;
  final LiveDiagnostics? lastDiagnostics;
  final Map<String, dynamic> earning;
  final List<Map<String, dynamic>> payouts;
  final int minPayout;
  final int holdDays;

  String get status => '${profile?['status'] ?? 'none'}';
  bool get approved => status == 'approved';
  bool get payoutVerified => profile?['payout_verified'] == 1 || profile?['payout_verified'] == true;
  int earningValue(String key) => (earning[key] as num?)?.toInt() ?? 0;

  factory CreatorLiveData.fromJson(Map<String, dynamic> j) => CreatorLiveData(
        featureEnabled: j['feature_enabled'] == true,
        profile: j['profile'] is Map
            ? Map<String, dynamic>.from(j['profile'] as Map)
            : null,
        active: j['active'] is Map
            ? LivestreamItem.fromJson(Map<String, dynamic>.from(j['active'] as Map))
            : null,
        activeDiagnostics: j['active_diagnostics'] is Map
            ? LiveDiagnostics.fromJson(Map<String, dynamic>.from(j['active_diagnostics'] as Map))
            : null,
        lastBroadcast: j['last_broadcast'] is Map
            ? LivestreamItem.fromJson(Map<String, dynamic>.from(j['last_broadcast'] as Map))
            : null,
        lastDiagnostics: j['last_diagnostics'] is Map
            ? LiveDiagnostics.fromJson(Map<String, dynamic>.from(j['last_diagnostics'] as Map))
            : null,
        earning: j['earning'] is Map
            ? Map<String, dynamic>.from(j['earning'] as Map)
            : const {},
        payouts: (j['payouts'] as List? ?? const [])
            .whereType<Map>()
            .map((x) => Map<String, dynamic>.from(x))
            .toList(),
        minPayout: (j['min_payout'] as num?)?.toInt() ?? 100000,
        holdDays: (j['hold_days'] as num?)?.toInt() ?? 7,
      );
}

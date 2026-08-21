// ignore_for_file: require_trailing_commas, curly_braces_in_flow_control_structures

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/services.dart';
import 'package:snakecare_mobile/src/core/localization/app_localizations.dart';
import 'package:snakecare_mobile/src/features/offline_resilience/data/emergency_platform_service.dart';
import 'package:snakecare_mobile/src/features/offline_resilience/data/offline_resilience_store.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

class OfflineResilienceScreen extends StatefulWidget {
  const OfflineResilienceScreen({super.key});

  @override
  State<OfflineResilienceScreen> createState() =>
      _OfflineResilienceScreenState();
}

class _OfflineResilienceScreenState extends State<OfflineResilienceScreen> {
  static const _firstAidVideoId = 'fd42XW9RJeE';
  static const _symptomWeights = <String, int>{
    'Difficulty breathing': 5,
    'Drooping eyelids': 4,
    'Unconsciousness': 5,
    'Severe bleeding': 4,
    'Vomiting': 2,
    'Spreading swelling': 3,
    'Pain at bite': 1,
    'Unknown snake': 1,
  };
  final selected = <String>{};
  final gatewayNumber = TextEditingController();
  final platformService = const EmergencyPlatformService();
  StreamSubscription<List<ConnectivityResult>>? connectivitySubscription;
  bool online = true;
  bool responderMode = false;
  bool bleBroadcast = false;
  int? riskScore;
  String? riskLabel;
  double latitude = 18.5204;
  double longitude = 73.8567;
  late final YoutubePlayerController videoController;
  EmergencyCapabilities? emergencyCapabilities;
  String transportStatus = 'No SOS transport attempted yet.';
  String signalStatus = 'Signal reading not checked.';

  @override
  void initState() {
    super.initState();
    videoController = YoutubePlayerController.fromVideoId(
      videoId: _firstAidVideoId,
      autoPlay: false,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
        enableCaption: true,
      ),
    );
    responderMode = OfflineResilienceStore.box.get(
      'community_responder',
      defaultValue: false,
    ) as bool;
    gatewayNumber.text = OfflineResilienceStore.box.get(
      'sos_gateway_number',
      defaultValue: '',
    ) as String;
    platformService.capabilities().then((value) {
      if (mounted) setState(() => emergencyCapabilities = value);
    });
    Connectivity().checkConnectivity().then(_setConnectivity);
    connectivitySubscription = Connectivity().onConnectivityChanged.listen(
          _setConnectivity,
        );
  }

  @override
  void dispose() {
    connectivitySubscription?.cancel();
    gatewayNumber.dispose();
    videoController.close();
    super.dispose();
  }

  void _setConnectivity(List<ConnectivityResult> result) {
    if (!mounted) return;
    setState(
        () => online = result.any((item) => item != ConnectivityResult.none));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(context.tr('offline_center')),
          backgroundColor: const Color(0xFF1E88E5),
          foregroundColor: Colors.white,
          actions: const [LanguageMenu()],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _statusBanner(),
            const SizedBox(height: 14),
            _callAndSosCard(),
            const SizedBox(height: 12),
            _transportStatusCard(),
            const SizedBox(height: 16),
            _triageCard(),
            const SizedBox(height: 16),
            _firstAidCard(),
            const SizedBox(height: 16),
            _videoCard(),
            const SizedBox(height: 16),
            _hospitalCard(),
            const SizedBox(height: 16),
            _lowSignalCard(),
            const SizedBox(height: 16),
            _tripCard(),
            const SizedBox(height: 16),
            const Card(
              color: Color(0xFFFFF3E0),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Honest limitation: if there is no tower, satellite link, or nearby relay phone, a phone-only SOS cannot leave the area. Satellite or LoRa hardware is required for that case.',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      );

  Widget _statusBanner() => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: (online ? Colors.green : Colors.orange).withValues(alpha: .12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          Icon(online ? Icons.cloud_done : Icons.cloud_off,
              color: online ? Colors.green : Colors.orange),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              online
                  ? 'Connected • offline cache and outbox ready'
                  : 'No data • local triage, 112, SMS/BLE staging available',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Text('${OfflineResilienceStore.pendingCount} pending'),
        ]),
      );

  Widget _callAndSosCard() => Card(
        color: const Color(0xFFE53935),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            const Icon(Icons.sos, color: Colors.white, size: 54),
            Text(context.tr('emergency'),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(context.tr('call_first'),
                style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => launchUrl(Uri(scheme: 'tel', path: '112')),
                  style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFFE53935)),
                  icon: const Icon(Icons.call),
                  label: Text(context.tr('call_112')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _queueSos,
                  style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white)),
                  icon: const Icon(Icons.outbox),
                  label: Text(context.tr('queue_sos')),
                ),
              ),
            ]),
          ]),
        ),
      );

  Widget _transportStatusCard() => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Emergency transport status',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(transportStatus),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _capabilityChip(
                    'SMS composer',
                    emergencyCapabilities?.smsComposer == true,
                  ),
                  _capabilityChip(
                    'Dialer',
                    emergencyCapabilities?.dialer == true,
                  ),
                  _capabilityChip(
                    'BLE advertiser',
                    emergencyCapabilities?.bleAdvertiser == true,
                  ),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _capabilityChip(String label, bool available) => Chip(
        avatar: Icon(
          available ? Icons.check_circle : Icons.info_outline,
          size: 18,
          color: available ? Colors.green : Colors.orange,
        ),
        label: Text('$label: ${available ? 'ready' : 'unavailable'}'),
      );

  Widget _triageCard() => _section(
        'On-device triage • rules 2026.08-r1',
        Icons.health_and_safety,
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text(
              'Select everything you can observe. No server call is used.'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _symptomWeights.keys
                .map((item) => FilterChip(
                      label: Text(item),
                      selected: selected.contains(item),
                      onSelected: (value) => setState(() =>
                          value ? selected.add(item) : selected.remove(item)),
                    ))
                .toList(),
          ),
          const SizedBox(height: 10),
          FilledButton(
              onPressed: _assess, child: const Text('Calculate local risk')),
          if (riskScore != null) ...[
            const SizedBox(height: 10),
            Text('$riskLabel RISK • score $riskScore',
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          ],
        ]),
      );

  Widget _firstAidCard() => _section(
        'First aid and prohibited actions',
        Icons.medical_services_outlined,
        const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('1. Keep the person calm and completely still.'),
          Text('2. Move away from the snake; do not catch it.'),
          Text('3. Immobilize the limb below heart level.'),
          Text('4. Remove rings, watches, shoes, and tight clothing.'),
          Text('5. Note the time and reach suitable care urgently.'),
          Divider(height: 22),
          Text(
              'DO NOT cut, suck, wash, ice, massage, shock, or tightly tourniquet the wound.',
              style: TextStyle(
                  color: Color(0xFFE53935), fontWeight: FontWeight.w800)),
        ]),
      );

  Widget _videoCard() => _section(
        context.tr('video_title'),
        Icons.ondemand_video_outlined,
        Column(children: [
          if (online)
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: YoutubePlayer(controller: videoController),
              ),
            )
          else
            Container(
              height: 170,
              decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(14)),
              alignment: Alignment.center,
              padding: const EdgeInsets.all(20),
              child: Text(
                context.tr('video_needs_data'),
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white),
              ),
            ),
          const SizedBox(height: 10),
          const Text(
            'Online snakebite first-aid education based on WHO emergency-care standards. The cached written steps above remain available without data.',
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: online
                ? () => launchUrl(
                      Uri.parse(
                        'https://www.youtube.com/watch?v=$_firstAidVideoId',
                      ),
                      mode: LaunchMode.externalApplication,
                    )
                : null,
            icon: const Icon(Icons.open_in_new),
            label: Text(
              online ? 'Open video in YouTube' : 'Video needs mobile data',
            ),
          ),
        ]),
      );

  Widget _hospitalCard() => _section(
        'Cached hospitals',
        Icons.local_hospital_outlined,
        Column(children: [
          const Text(
              'Approximate straight-line distance • not road distance or ETA.'),
          const SizedBox(height: 8),
          ...OfflineResilienceStore.hospitals.map(
            (item) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(child: Icon(Icons.local_hospital)),
              title: Text(item['name'] as String),
              subtitle: Text(item['status'] as String),
              trailing: Text('≈ ${item['distance_km']} km'),
            ),
          ),
        ]),
      );

  Widget _lowSignalCard() => _section(
        'Weak/zero-signal fallbacks',
        Icons.signal_cellular_connected_no_internet_4_bar,
        Column(children: [
          TextField(
            controller: gatewayNumber,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Verified SMS / missed-call gateway number',
              helperText: 'Provided by your hospital or telephony gateway',
              prefixIcon: Icon(Icons.phone_forwarded_outlined),
            ),
            onChanged: (value) => OfflineResilienceStore.box.put(
              'sos_gateway_number',
              value.trim(),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _prepareSms,
                icon: const Icon(Icons.sms_outlined),
                label: const Text('Prepare SOS SMS'),
              ),
              OutlinedButton.icon(
                onPressed: _prepareMissedCall,
                icon: const Icon(Icons.phone_callback_outlined),
                label: const Text('Open gateway dialer'),
              ),
            ],
          ),
          const Divider(height: 24),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('BLE SOS broadcast'),
            subtitle: const Text(
                'Activates immediately from this emergency screen; Android hardware required'),
            value: bleBroadcast,
            onChanged: _toggleBle,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Community responder mode'),
            subtitle:
                const Text('Opt in to low-power scanning and relay storage'),
            value: responderMode,
            onChanged: (value) async {
              await OfflineResilienceStore.box
                  .put('community_responder', value);
              setState(() => responderMode = value);
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.my_location),
            title: const Text('Current / nearest known signal point'),
            subtitle: Text(
                '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)} • cached locally'),
            trailing: IconButton(
                icon: const Icon(Icons.refresh), onPressed: _refreshLocation),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.signal_cellular_alt),
            title: const Text('Android cellular signal'),
            subtitle: Text(signalStatus),
            trailing: IconButton(
              tooltip: 'Read signal strength',
              icon: const Icon(Icons.refresh),
              onPressed: _refreshSignal,
            ),
          ),
          const Text(
              'Weak signal: SMS + user-initiated missed-call gateway. Zero signal: BLE relay. Android decides cross-carrier 112 routing.'),
        ]),
      );

  Widget _tripCard() => _section(
        'Pre-departure check-in',
        Icons.route_outlined,
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text(
              'Register a trusted contact and expected return time before entering a known dead zone.'),
          const SizedBox(height: 10),
          OutlinedButton.icon(
              onPressed: _registerTrip,
              icon: const Icon(Icons.schedule_send),
              label: const Text('Register trip')),
        ]),
      );

  Widget _section(String title, IconData icon, Widget child) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Icon(icon),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800)))
            ]),
            const SizedBox(height: 12),
            child,
          ]),
        ),
      );

  void _assess() {
    final score = selected.fold<int>(
        0, (sum, item) => sum + (_symptomWeights[item] ?? 0));
    setState(() {
      riskScore = score;
      riskLabel = score >= 8
          ? 'CRITICAL'
          : score >= 5
              ? 'HIGH'
              : score >= 2
                  ? 'MODERATE'
                  : 'LOW';
    });
  }

  Future<void> _queueSos() async {
    _assess();
    await _refreshLocation();
    final payload = _sosPayload();
    await OfflineResilienceStore.queueSos(payload);
    var status = 'SOS saved in the encrypted outbox.';
    if (bleBroadcast && emergencyCapabilities?.bleAdvertiser == true) {
      try {
        await platformService.startBleBroadcast(_blePayload(payload));
        status = '$status BLE relay beacon is active.';
      } on PlatformException catch (error) {
        status = '$status BLE could not start: ${error.message ?? error.code}';
      }
    }
    transportStatus = status;
    if (mounted) setState(() {});
    if (mounted)
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(status)));
  }

  Map<String, dynamic> _sosPayload() => {
        'risk': riskLabel,
        'score': riskScore,
        'symptoms': selected.toList(),
        'lat': latitude,
        'lon': longitude,
        'transport_preference': online ? 'api' : 'sms_then_ble',
      };

  String _blePayload(Map<String, dynamic> payload) {
    final score = payload['score'] ?? 0;
    final lat = ((payload['lat'] as num) * 100).round();
    final lon = ((payload['lon'] as num) * 100).round();
    return 'SC1|$score|$lat|$lon';
  }

  String _sosMessage() => 'SnakeCare SOS • Risk: ${riskLabel ?? 'UNASSESSED'} '
      '(score ${riskScore ?? 0}) • GPS: '
      '${latitude.toStringAsFixed(5)},${longitude.toStringAsFixed(5)} • '
      'Symptoms: ${selected.isEmpty ? 'not entered' : selected.join(', ')} • '
      'Call the patient and dispatch help. This is user-reported information.';

  Future<void> _prepareSms() async {
    _assess();
    await _refreshLocation();
    try {
      await platformService.prepareSms(
        number: gatewayNumber.text,
        message: _sosMessage(),
      );
      _setTransportStatus(
        'SOS SMS prepared. Confirm and press Send in the messaging app.',
      );
    } on PlatformException catch (error) {
      _setTransportStatus(error.message ?? 'SMS preparation failed.');
    }
  }

  Future<void> _prepareMissedCall() async {
    try {
      await platformService.prepareMissedCall(gatewayNumber.text);
      _setTransportStatus(
        'Gateway number opened in the dialer. Place and end the call manually.',
      );
    } on PlatformException catch (error) {
      _setTransportStatus(error.message ?? 'Gateway dialer failed.');
    }
  }

  Future<void> _toggleBle(bool value) async {
    if (!value) {
      try {
        await platformService.stopBleBroadcast();
      } on MissingPluginException {
        // Web and unsupported platforms have no active native broadcast.
      }
      if (mounted) {
        setState(() {
          bleBroadcast = false;
          transportStatus = 'BLE SOS broadcast stopped.';
        });
      }
      return;
    }
    if (emergencyCapabilities?.bleAdvertiser != true) {
      _setTransportStatus(
        'This device/browser cannot advertise BLE. Use a supported Android phone.',
      );
      return;
    }
    setState(() {
      bleBroadcast = true;
      transportStatus = 'BLE armed. Queue SOS to begin the emergency beacon.';
    });
  }

  void _setTransportStatus(String value) {
    if (!mounted) return;
    setState(() => transportStatus = value);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  Future<void> _refreshSignal() async {
    try {
      final info = await platformService.signalInfo();
      final available = info['available'] == true;
      final value = available
          ? 'Level ${info['level']} of 4 • ${info['isGsm'] == true ? 'GSM registered' : 'cellular radio'}'
          : (info['reason'] as String? ?? 'Signal reading unavailable.');
      if (mounted) setState(() => signalStatus = value);
    } on PlatformException catch (error) {
      if (mounted) {
        setState(
          () => signalStatus = error.message ?? 'Signal reading unavailable.',
        );
      }
    }
  }

  Future<void> _refreshLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied)
        permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) return;
      final position = await Geolocator.getCurrentPosition();
      if (mounted)
        setState(() {
          latitude = position.latitude;
          longitude = position.longitude;
        });
      await OfflineResilienceStore.box.put('last_signal_point', {
        'lat': latitude,
        'lon': longitude,
        'at': DateTime.now().toIso8601String()
      });
    } catch (_) {
      // Keep the last cached coordinates when hardware/browser location is unavailable.
    }
  }

  Future<void> _registerTrip() async {
    final contact = TextEditingController();
    var expected = DateTime.now().add(const Duration(hours: 4));
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Register low-signal trip'),
        content: StatefulBuilder(
            builder: (context, setDialogState) =>
                Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(
                      controller: contact,
                      decoration:
                          const InputDecoration(labelText: 'Trusted contact')),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Expected return'),
                    subtitle: Text(expected.toLocal().toString()),
                    onTap: () => setDialogState(() =>
                        expected = expected.add(const Duration(hours: 1))),
                  ),
                ])),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save check-in')),
        ],
      ),
    );
    if (save == true && contact.text.trim().isNotEmpty) {
      await OfflineResilienceStore.saveTrip(
          contact: contact.text.trim(), expectedReturn: expected);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Trip saved locally and queued for sync.')));
    }
    contact.dispose();
  }
}

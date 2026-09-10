import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:snakecare_mobile/src/core/network/api_client.dart';

/// Foreground-only sharing: no background location or silent tracking.
enum TrackingPortal { patient, driver, hospital }

class TrackingScreen extends ConsumerStatefulWidget {
  const TrackingScreen(
      {required this.accessToken,
      this.portal = TrackingPortal.patient,
      super.key,});
  final String accessToken;
  final TrackingPortal portal;
  @override
  ConsumerState<TrackingScreen> createState() => _TrackingState();
}

class _TrackingState extends ConsumerState<TrackingScreen>
    with WidgetsBindingObserver {
  static const base = '/api/v1/ambulance-tracking';
  final name = TextEditingController();
  final vehicle = TextEditingController();
  final reference = TextEditingController();
  final search = TextEditingController();
  Map<String, dynamic> workspace = {};
  List<Map<String, dynamic>> hospitals = [];
  String? hospitalId, error, sharing;
  bool busy = false, loading = false, sending = false, consent = false;
  Timer? refreshTimer, gpsTimer;
  String? gpsStatus;
  Options get options =>
      Options(headers: {'Authorization': 'Bearer ${widget.accessToken}'});
  List<Map<String, dynamic>> rows(String key) =>
      (workspace[key] as List? ?? []).cast<Map<String, dynamic>>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    load();
    findHospitals();
    refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) => load());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      stopSharing();
      refreshTimer?.cancel();
    } else {
      load();
      refreshTimer?.cancel();
      refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) => load());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    refreshTimer?.cancel();
    gpsTimer?.cancel();
    for (final c in [name, vehicle, reference, search]) {
      c.dispose();
    }
    super.dispose();
  }

  String failure(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['detail'] is String) {
        return data['detail'] as String;
      }
    }
    return 'Could not complete the request. Check your connection, permissions and details.';
  }

  Future<void> load() async {
    if (loading) return;
    loading = true;
    try {
      final response = await ref
          .read(dioProvider)
          .get<Map<String, dynamic>>('$base/workspace', options: options);
      if (!mounted) return;
      setState(() {
        workspace = response.data ?? {};
        error = null;
      });
      if (sharing != null &&
          !rows('trips').any(
            (t) =>
                t['id'] == sharing &&
                t['is_driver'] == true &&
                ['en_route', 'onboard'].contains(t['status']),
          )) {
        stopSharing();
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error =
              'Connection lost: displayed positions are last known, not live. ${failure(e)}',
        );
      }
    } finally {
      loading = false;
    }
  }

  Future<void> findHospitals() async {
    try {
      final response = await ref.read(dioProvider).get<List<dynamic>>(
            '$base/hospitals',
            queryParameters: {'search': search.text.trim()},
            options: options,
          );
      if (mounted) {
        setState(() {
          hospitals = (response.data ?? []).cast<Map<String, dynamic>>();
          hospitalId = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = failure(e));
    }
  }

  Future<void> action(String path, Map<String, dynamic> data) async {
    if (busy) return;
    if (path == '/drivers' &&
        (name.text.trim().length < 2 ||
            vehicle.text.trim().length < 3 ||
            reference.text.trim().length < 3)) {
      setState(() => error =
          'Enter your full name, vehicle number (at least 3 characters), '
              'and hospital reference (at least 3 characters). Use genuine details; contact your hospital if the reference is shorter.',);
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref
          .read(dioProvider)
          .post<dynamic>('$base$path', data: data, options: options);
      await load();
    } catch (e) {
      if (mounted) setState(() => error = failure(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<Position> locate() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw StateError('Enable location services.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw StateError('Location permission is required.');
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
  }

  Future<void> requestTrip() async {
    if (!consent || hospitalId == null || busy) return;
    setState(() => busy = true);
    try {
      final p = await locate();
      if (!mounted) return;
      await ref.read(dioProvider).post<dynamic>(
            '$base/trips',
            data: {
              'hospital_id': hospitalId,
              'latitude': p.latitude,
              'longitude': p.longitude,
              'share_pickup_consent': true,
            },
            options: options,
          );
      await load();
    } catch (e) {
      if (mounted) setState(() => error = failure(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void stopSharing() {
    gpsTimer?.cancel();
    if (mounted) {
      setState(() {
        sharing = null;
        gpsStatus = 'GPS sharing stopped.';
      });
    }
  }

  Future<void> publish(String id) async {
    if (sending || sharing != id) return;
    sending = true;
    try {
      final p = await locate();
      if (!mounted || sharing != id) return;
      await ref.read(dioProvider).post<dynamic>(
            '$base/trips/$id/location',
            data: {
              'latitude': p.latitude,
              'longitude': p.longitude,
              'accuracy_m': p.accuracy,
              'captured_at': p.timestamp.toUtc().toIso8601String(),
            },
            options: options,
          );
      if (mounted) {
        setState(
          () => gpsStatus =
              'GPS delivered at ${DateTime.now().toLocal().toString().substring(11, 19)}',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => gpsStatus = 'GPS not delivered. ${failure(e)}');
      }
      if (e is DioException &&
          [401, 403, 409].contains(e.response?.statusCode)) {
        stopSharing();
      }
    } finally {
      sending = false;
    }
  }

  Future<void> startSharing(String id) async {
    final agree = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Share ambulance location?'),
        content: const Text(
            'The assigned patient and hospital can see your GPS during this trip. '
            'Keep this screen open. Sharing stops when you leave or background the app. '
            'Do not operate this screen while driving; ask a crew member.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Share GPS'),
          ),
        ],
      ),
    );
    if (!mounted || agree != true) return;
    gpsTimer?.cancel();
    setState(() => sharing = id);
    await publish(id);
    if (mounted && sharing == id) {
      gpsTimer = Timer.periodic(const Duration(seconds: 8), (_) => publish(id));
    }
  }

  Widget panel(String title, List<Widget> children) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...children,
            ],
          ),
        ),
      );

  Widget hospitalPicker() => Column(
        children: [
          TextField(
            controller: search,
            decoration: InputDecoration(
              labelText: 'Search registered hospital',
              suffixIcon: IconButton(
                onPressed: findHospitals,
                icon: const Icon(Icons.search),
              ),
            ),
            onSubmitted: (_) => findHospitals(),
          ),
          DropdownButtonFormField<String>(
            key: ValueKey(hospitalId),
            initialValue: hospitalId,
            isExpanded: true,
            decoration:
                const InputDecoration(labelText: 'Select your hospital'),
            items: hospitals
                .map(
                  (h) => DropdownMenuItem(
                    value: h['id'] as String,
                    child: Text(
                      h['name'] as String,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => hospitalId = v),
          ),
          if (hospitals.isEmpty)
            const Text(
              'No matching managed hospital. The hospital must first complete its authority claim.',
            ),
        ],
      );

  Widget tripCard(Map<String, dynamic> t) {
    final id = t['id'] as String;
    final status = t['status'] as String;
    final active = !['completed', 'cancelled'].contains(status);
    final manager = widget.portal == TrackingPortal.hospital &&
        rows('managed_hospitals').any((h) => h['id'] == t['hospital_id']);
    final captured = DateTime.tryParse(t['captured_at']?.toString() ?? '');
    final stale = error != null ||
        captured == null ||
        DateTime.now().difference(captured).inSeconds > 60;
    return panel('Trip • ${status.replaceAll('_', ' ')}', [
      SelectableText('Reference: $id'),
      if (status == 'requested')
        const Text(
          'Waiting for hospital assignment. This is NOT a confirmed ambulance booking. Call emergency services if urgent.',
        ),
      if (t['driver_name'] != null)
        Text('Driver: ${t['driver_name']} • Vehicle: ${t['vehicle_number']}'),
      if (active)
        Text(
          captured == null
              ? 'Awaiting driver GPS; no live position yet.'
              : '${stale ? 'OUTDATED / last known' : 'Recent GPS'} • ${captured.toLocal()} • accuracy ±${t['accuracy_m']} m',
        ),
      if (active && t['latitude'] != null)
        SizedBox(
          height: 290,
          child: FlutterMap(
            key: ValueKey(id),
            options: MapOptions(
              initialCenter: LatLng(
                (t['latitude'] as num).toDouble(),
                (t['longitude'] as num).toDouble(),
              ),
              initialZoom: 14,
            ),
            children: [
              TileLayer(
                urlTemplate: const String.fromEnvironment(
                  'MAP_TILE_URL',
                  defaultValue:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                ),
                userAgentPackageName: 'com.snakecare.mobile',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(
                      (t['latitude'] as num).toDouble(),
                      (t['longitude'] as num).toDouble(),
                    ),
                    child: Icon(
                      Icons.emergency,
                      color: stale ? Colors.grey : Colors.red,
                      size: 38,
                    ),
                  ),
                  if (t['pickup_latitude'] != null)
                    Marker(
                      point: LatLng(
                        (t['pickup_latitude'] as num).toDouble(),
                        (t['pickup_longitude'] as num).toDouble(),
                      ),
                      child: const Icon(
                        Icons.person_pin_circle,
                        color: Colors.blue,
                        size: 38,
                      ),
                    ),
                ],
              ),
              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution(
                    'OpenStreetMap contributors',
                    onTap: () => launchUrl(
                      Uri.parse('https://www.openstreetmap.org/copyright'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      if (active && t['latitude'] != null)
        Text(
          'Ambulance: ${t['latitude']}, ${t['longitude']} • red/grey marker; pickup: blue marker. Map requires internet. No ETA is estimated.',
        ),
      if (manager && status == 'requested') ...[
        const Text('Assign an approved driver:'),
        ...rows('registrations')
            .where(
              (d) =>
                  d['status'] == 'approved' &&
                  d['hospital_id'] == t['hospital_id'],
            )
            .map(
              (d) => OutlinedButton(
                onPressed: busy
                    ? null
                    : () => action('/trips/$id/assign', {'driver_id': d['id']}),
                child: Text('${d['driver_name']} • ${d['vehicle_number']}'),
              ),
            ),
      ],
      if (widget.portal == TrackingPortal.driver &&
          t['is_driver'] == true &&
          active) ...[
        if (['en_route', 'onboard'].contains(status))
          FilledButton.icon(
            onPressed: sharing == id ? stopSharing : () => startSharing(id),
            icon: const Icon(Icons.my_location),
            label: Text(
              sharing == id
                  ? 'Stop sharing GPS'
                  : 'Share GPS (keep screen open)',
            ),
          ),
        if (gpsStatus != null) Text(gpsStatus!),
        if ({
          'assigned': 'en_route',
          'en_route': 'onboard',
          'onboard': 'completed',
        }.containsKey(status))
          OutlinedButton(
            onPressed: busy
                ? null
                : () => action('/trips/$id/status', {
                      'status': {
                        'assigned': 'en_route',
                        'en_route': 'onboard',
                        'onboard': 'completed',
                      }[status],
                    }),
            child: Text(
              {
                'assigned': 'Accept and start trip',
                'en_route': 'Patient onboard',
                'onboard': 'Complete trip',
              }[status]!,
            ),
          ),
      ],
      if (active && (manager || t['is_patient'] == true))
        TextButton(
          onPressed: busy
              ? null
              : () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('Cancel this trip?'),
                      content: const Text(
                        'This stops tracking. Contact the hospital directly if transport is still needed.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(c, false),
                          child: const Text('Keep trip'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(c, true),
                          child: const Text('Cancel trip'),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) {
                    await action(
                      '/trips/$id/status',
                      {'status': 'cancelled'},
                    );
                  }
                },
          child: const Text('Cancel trip'),
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final registration = workspace['registration'] as Map<String, dynamic>?;
    final driverPortal = widget.portal == TrackingPortal.driver;
    final patientPortal = widget.portal == TrackingPortal.patient;
    final displayedTrips = rows('trips')
        .where((t) => patientPortal
            ? t['is_patient'] == true
            : driverPortal
                ? t['is_driver'] == true
                : rows('managed_hospitals')
                    .any((h) => h['id'] == t['hospital_id']),)
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(patientPortal
            ? 'Track my ambulance'
            : driverPortal
                ? 'Driver • My trips'
                : 'Hospital • Ambulance operations',),
        actions: [
          IconButton(onPressed: load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 950),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              panel(
                  patientPortal
                      ? 'Your transport, in one place'
                      : driverPortal
                          ? 'Driver workspace'
                          : 'Hospital dispatch desk',
                  [
                    Text(patientPortal
                        ? 'Request transport here and follow your assigned ambulance. You do not need to register as a driver.'
                        : driverPortal
                            ? 'Register with your hospital. After approval, assigned trips and GPS controls appear here.'
                            : 'Review driver registrations and assign waiting patient requests. Patients must request transport from their own accounts.',),
                  ]),
              const Text(
                  'SnakeCare registered hospital fleet only — not connected to 108/112 dispatch. '
                  'Hospital staff must keep this workspace open to see requests. No background notifications yet.'),
              if (error != null)
                Card(
                  color: Colors.amber.shade100,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(error!),
                  ),
                ),
              if (busy) const LinearProgressIndicator(),
              ...displayedTrips.map(tripCard),
              if (displayedTrips.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('No assigned or requested trips yet.'),
                ),
              if (widget.portal == TrackingPortal.hospital &&
                  rows('managed_hospitals').isEmpty)
                const Text(
                    'Hospital authority access and a managed hospital are required. Complete the hospital claim first.',),
              if (widget.portal == TrackingPortal.hospital &&
                  rows('managed_hospitals').isNotEmpty)
                panel('Hospital driver approvals', [
                  const Text(
                    'Verify the driver and vehicle through hospital records before approving.',
                  ),
                  ...rows('registrations').map(
                    (d) => ListTile(
                      title: Text(
                        '${d['driver_name']} • ${d['vehicle_number']}',
                      ),
                      subtitle: Text(
                        '${d['status']} • verification: ${d['verification_reference']}',
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) => action(
                          '/drivers/${d['id']}/review',
                          {'status': v},
                        ),
                        itemBuilder: (_) => [
                          'approved',
                          'rejected',
                          'revoked',
                        ]
                            .where((v) => v != d['status'])
                            .map(
                              (v) => PopupMenuItem(
                                value: v,
                                child: Text(v),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                ]),
              if (patientPortal ||
                  driverPortal &&
                      (registration == null ||
                          ['rejected', 'revoked']
                              .contains(registration['status'])))
                panel('Choose hospital', [hospitalPicker()]),
              if (patientPortal)
                panel('Request hospital ambulance', [
                  CheckboxListTile(
                    value: consent,
                    onChanged: (v) => setState(() => consent = v ?? false),
                    title: const Text(
                      'Share my pickup GPS with this hospital and its assigned driver.',
                    ),
                  ),
                  FilledButton(
                    onPressed: busy || !consent || hospitalId == null
                        ? null
                        : requestTrip,
                    child: const Text('Send transport request'),
                  ),
                ]),
              if (driverPortal)
                panel('Driver registration', [
                  if (registration != null)
                    Text(
                      'Registration status: ${registration['status']} • ${registration['vehicle_number']}',
                    ),
                  const Text(
                    'Sign in with your own account, choose your hospital above, then submit. Hospital approval is required before trips appear here. This does not grant access to medical records.',
                  ),
                  if (registration == null ||
                      ['rejected', 'revoked']
                          .contains(registration['status'])) ...[
                    TextField(
                      controller: name,
                      maxLength: 120,
                      decoration: const InputDecoration(
                        labelText: 'Driver full name',
                      ),
                    ),
                    TextField(
                      controller: vehicle,
                      maxLength: 32,
                      decoration: const InputDecoration(
                        labelText: 'Ambulance registration number',
                      ),
                    ),
                    TextField(
                      controller: reference,
                      maxLength: 120,
                      decoration: const InputDecoration(
                        labelText: 'Hospital employee / verification reference',
                      ),
                    ),
                    FilledButton(
                      onPressed: busy || hospitalId == null
                          ? null
                          : () => action('/drivers', {
                                'hospital_id': hospitalId,
                                'driver_name': name.text.trim(),
                                'vehicle_number':
                                    vehicle.text.trim().toUpperCase(),
                                'verification_reference': reference.text.trim(),
                              }),
                      child: const Text('Register with hospital'),
                    ),
                  ],
                ]),
            ],
          ),
        ),
      ),
    );
  }
}

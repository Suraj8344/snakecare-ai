import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:snakecare_mobile/src/features/hospital_coordination/data/hospital_coordination_repository.dart';
import 'package:snakecare_mobile/src/features/hospital_coordination/domain/hospital_recommendation.dart';
import 'package:url_launcher/url_launcher.dart';

Uri buildHospitalDirectionsUri(
  HospitalFacility hospital, {
  double? originLatitude,
  double? originLongitude,
}) =>
    Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      if (originLatitude != null && originLongitude != null)
        'origin': '$originLatitude,$originLongitude',
      'destination': '${hospital.latitude},${hospital.longitude}',
      'travelmode': 'driving',
    });

class HospitalRecommendationScreen extends ConsumerStatefulWidget {
  const HospitalRecommendationScreen({
    required this.accessToken,
    required this.emergencyId,
    this.latitude,
    this.longitude,
    super.key,
  });

  final String accessToken;
  final String emergencyId;
  final double? latitude;
  final double? longitude;

  @override
  ConsumerState<HospitalRecommendationScreen> createState() =>
      _HospitalRecommendationScreenState();
}

class _HospitalRecommendationScreenState
    extends ConsumerState<HospitalRecommendationScreen> {
  HospitalRecommendationResult? result;
  bool loading = false;
  String? error;
  double? latitude;
  double? longitude;
  String? coordinatingHospitalId;
  String? coordinationStatus;
  bool coordinationStatusIsError = false;

  @override
  void initState() {
    super.initState();
    latitude = widget.latitude;
    longitude = widget.longitude;
    WidgetsBinding.instance.addPostFrameCallback((_) => _find());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Hospital recommendation')),
        body: ListView(
          key: const Key('hospital_recommendation_scroll'),
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Do not wait for a recommendation, pre-alert, or resource response. Call emergency services and begin transport now.',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => launchUrl(Uri(scheme: 'tel', path: '112')),
              icon: const Icon(Icons.call),
              label: const Text('Call 112 now'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: loading ? null : _captureLocationAndFind,
              icon: const Icon(Icons.my_location),
              label: const Text('Update location and search'),
            ),
            if (coordinationStatus != null) ...[
              const SizedBox(height: 12),
              Card(
                color: coordinationStatusIsError
                    ? Theme.of(context).colorScheme.errorContainer
                    : Theme.of(context).colorScheme.secondaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(
                        coordinationStatusIsError
                            ? Icons.error_outline
                            : Icons.info_outline,
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(coordinationStatus!)),
                    ],
                  ),
                ),
              ),
            ],
            if (loading) ...[
              const SizedBox(height: 28),
              const Center(child: CircularProgressIndicator()),
            ] else if (error != null) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Icon(Icons.cloud_off_outlined, size: 42),
                      const SizedBox(height: 8),
                      Text(error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _find,
                        child: const Text('Retry hospital search'),
                      ),
                    ],
                  ),
                ),
              ),
            ] else if (result != null) ...[
              const SizedBox(height: 16),
              Card(
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(result!.notice),
                ),
              ),
              const SizedBox(height: 12),
              if (result!.items.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Text(
                      'No registered hospital data is available in this search area. Call emergency services and go to the nearest emergency facility without delay.',
                    ),
                  ),
                ),
              ...result!.items.map(
                (recommendation) => _HospitalCard(
                  recommendation: recommendation,
                  onCoordinate: () => _coordinate(recommendation),
                  onDirections: () => _openDirections(recommendation.hospital),
                  coordinating:
                      coordinatingHospitalId == recommendation.hospital.id,
                ),
              ),
            ],
          ],
        ),
      );

  Future<void> _find() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final value =
          await ref.read(hospitalCoordinationRepositoryProvider).recommend(
                widget.accessToken,
                emergencyId: widget.emergencyId,
                latitude: latitude,
                longitude: longitude,
              );
      if (mounted) setState(() => result = value);
    } on DioException catch (exception) {
      final data = exception.response?.data;
      final detail = data is Map<String, dynamic> ? data['detail'] : null;
      if (mounted) {
        setState(
          () => error = detail is String
              ? detail
              : 'Live hospital data is unavailable. Call emergency services and proceed to the nearest emergency facility.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Live hospital data is unavailable. Call emergency services and proceed to the nearest emergency facility.',
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _captureLocationAndFind() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _message('Location permission is required to search nearby hospitals.');
      return;
    }
    final position = await Geolocator.getCurrentPosition();
    latitude = position.latitude;
    longitude = position.longitude;
    await _find();
  }

  Future<void> _coordinate(HospitalRecommendation recommendation) async {
    var shareSymptoms = true;
    var shareVitals = true;
    var shareLocation = true;
    var shareNotes = false;
    var antivenom = true;
    var emergencyBed = true;
    var icu = false;
    var ventilator = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Pre-alert ${recommendation.hospital.name}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Choose exactly what SnakeCare may share. This does not confirm acceptance.',
                ),
                if (!recommendation.hospital.isConnectedToSnakeCare) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'This map-listed hospital is not connected to a SnakeCare administrator. The pre-alert will be saved in SnakeCare, but you must call the hospital because electronic delivery cannot be confirmed.',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
                CheckboxListTile(
                  value: shareSymptoms,
                  onChanged: (value) =>
                      setDialogState(() => shareSymptoms = value ?? false),
                  title: const Text('Symptoms and urgency reasons'),
                ),
                CheckboxListTile(
                  value: shareVitals,
                  onChanged: (value) =>
                      setDialogState(() => shareVitals = value ?? false),
                  title: const Text('Recorded vitals'),
                ),
                CheckboxListTile(
                  value: shareLocation,
                  onChanged: (value) =>
                      setDialogState(() => shareLocation = value ?? false),
                  title: const Text('Emergency location'),
                ),
                CheckboxListTile(
                  value: shareNotes,
                  onChanged: (value) =>
                      setDialogState(() => shareNotes = value ?? false),
                  title: const Text('Patient notes'),
                ),
                const Divider(),
                const Text('Request readiness confirmation for:'),
                CheckboxListTile(
                  value: antivenom,
                  onChanged: (value) =>
                      setDialogState(() => antivenom = value ?? false),
                  title: const Text('Antivenom'),
                ),
                CheckboxListTile(
                  value: emergencyBed,
                  onChanged: (value) =>
                      setDialogState(() => emergencyBed = value ?? false),
                  title: const Text('Emergency bed'),
                ),
                CheckboxListTile(
                  value: icu,
                  onChanged: (value) =>
                      setDialogState(() => icu = value ?? false),
                  title: const Text('ICU readiness'),
                ),
                CheckboxListTile(
                  value: ventilator,
                  onChanged: (value) =>
                      setDialogState(() => ventilator = value ?? false),
                  title: const Text('Ventilator readiness'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Send pre-alert'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      coordinatingHospitalId = recommendation.hospital.id;
      coordinationStatus = 'Saving hospital pre-alert...';
      coordinationStatusIsError = false;
    });
    try {
      final repository = ref.read(hospitalCoordinationRepositoryProvider);
      final alert = await repository.createPreAlert(
        widget.accessToken,
        emergencyId: widget.emergencyId,
        hospitalId: recommendation.hospital.id,
        shareSymptoms: shareSymptoms,
        shareVitals: shareVitals,
        shareLocation: shareLocation,
        shareNotes: shareNotes,
      );
      await repository.createResourceRequest(
        widget.accessToken,
        preAlertId: alert['id'] as String,
        antivenom: antivenom,
        emergencyBed: emergencyBed,
        icu: icu,
        ventilator: ventilator,
      );
      if (mounted) {
        final message = recommendation.hospital.isConnectedToSnakeCare
            ? 'Pre-alert saved as pending. Do not wait for a response; continue emergency transport.'
            : 'Pre-alert saved in SnakeCare, but this hospital is not electronically connected. Call the hospital now and continue emergency transport.';
        setState(() {
          coordinationStatus = message;
          coordinationStatusIsError = false;
        });
        _message(message);
      }
    } on DioException catch (exception) {
      final data = exception.response?.data;
      final detail = data is Map<String, dynamic> ? data['detail'] : null;
      if (mounted) {
        final message = detail is String
            ? detail
            : 'Unable to save the hospital pre-alert.';
        setState(() {
          coordinationStatus = message;
          coordinationStatusIsError = true;
        });
        _message(message);
      }
    } catch (_) {
      if (mounted) {
        const message =
            'Unable to save the hospital pre-alert. Call the hospital directly and continue transport.';
        setState(() {
          coordinationStatus = message;
          coordinationStatusIsError = true;
        });
        _message(message);
      }
    } finally {
      if (mounted) setState(() => coordinatingHospitalId = null);
    }
  }

  Future<void> _openDirections(HospitalFacility hospital) async {
    double? originLatitude;
    double? originLongitude;
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission != LocationPermission.denied &&
          permission != LocationPermission.deniedForever) {
        final position = await Geolocator.getCurrentPosition();
        originLatitude = position.latitude;
        originLongitude = position.longitude;
        if (mounted) {
          setState(() {
            latitude = position.latitude;
            longitude = position.longitude;
          });
        }
      }
    } catch (_) {
      // The destination route still opens when live location is unavailable.
    }
    final uri = buildHospitalDirectionsUri(
      hospital,
      originLatitude: originLatitude,
      originLongitude: originLongitude,
    );
    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
    if (!opened && mounted) {
      _message('Unable to open maps. Allow pop-ups and try again.');
    } else if (originLatitude == null && mounted) {
      _message(
        'Map opened with the hospital destination. Allow location permission to include your live starting point.',
      );
    }
  }

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }
}

class _HospitalCard extends StatelessWidget {
  const _HospitalCard({
    required this.recommendation,
    required this.onCoordinate,
    required this.onDirections,
    required this.coordinating,
  });

  final HospitalRecommendation recommendation;
  final Future<void> Function() onCoordinate;
  final Future<void> Function() onDirections;
  final bool coordinating;

  @override
  Widget build(BuildContext context) {
    final hospital = recommendation.hospital;
    final availability = hospital.availability;
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${recommendation.rank}. ${hospital.name}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              '${recommendation.distanceKm.toStringAsFixed(1)} km • ${hospital.sourceLabel}',
            ),
            Text(hospital.address),
            const SizedBox(height: 10),
            Chip(
              avatar: Icon(
                availability?.antivenomStatus == 'available' &&
                        availability!.isCurrent
                    ? Icons.check_circle
                    : Icons.info_outline,
              ),
              label: Text(
                availability == null
                    ? 'No current availability report'
                    : '${availability.stockLabel} • ${availability.isCurrent ? 'current' : 'expired'}',
              ),
            ),
            Wrap(
              spacing: 6,
              children: [
                if (hospital.capabilities['emergency_24x7'] == true)
                  const Chip(label: Text('24/7 emergency')),
                if (hospital.capabilities['icu'] == true)
                  const Chip(label: Text('ICU')),
                if (hospital.capabilities['ventilator'] == true)
                  const Chip(label: Text('Ventilator')),
                if (hospital.capabilities['dialysis'] == true)
                  const Chip(label: Text('Dialysis')),
              ],
            ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Why this hospital?'),
              children: [
                ...recommendation.reasons.map(
                  (reason) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.check, size: 18),
                    title: Text(reason),
                  ),
                ),
                ...recommendation.warnings.map(
                  (warning) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.warning_amber, size: 18),
                    title: Text(warning),
                  ),
                ),
                Text(
                  'Rules: ${recommendation.rulesetVersion}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (hospital.emergencyPhone != null)
                  OutlinedButton.icon(
                    onPressed: () => launchUrl(
                      Uri(scheme: 'tel', path: hospital.emergencyPhone),
                    ),
                    icon: const Icon(Icons.call),
                    label: const Text('Call hospital'),
                  ),
                OutlinedButton.icon(
                  onPressed: onDirections,
                  icon: const Icon(Icons.directions),
                  label: const Text('Directions'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (!hospital.isConnectedToSnakeCare) ...[
              const Text(
                'Electronic delivery is not confirmed for this map-listed hospital. Call directly.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
            ],
            FilledButton.icon(
              onPressed: coordinating ? null : onCoordinate,
              icon: coordinating
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_outlined),
              label: Text(
                coordinating
                    ? 'Saving pre-alert...'
                    : 'Send hospital pre-alert',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

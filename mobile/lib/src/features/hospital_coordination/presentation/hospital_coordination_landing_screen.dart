import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:snakecare_mobile/src/core/localization/app_localizations.dart';
import 'package:snakecare_mobile/src/features/hospital_coordination/data/hospital_coordination_repository.dart';
import 'package:snakecare_mobile/src/features/hospital_coordination/domain/hospital_recommendation.dart';
import 'package:snakecare_mobile/src/features/snakebite_emergency/presentation/snakebite_emergency_screen.dart';

class HospitalCoordinationLandingScreen extends ConsumerStatefulWidget {
  const HospitalCoordinationLandingScreen({
    required this.accessToken,
    super.key,
  });

  final String accessToken;

  @override
  ConsumerState<HospitalCoordinationLandingScreen> createState() =>
      _HospitalCoordinationLandingScreenState();
}

class _HospitalCoordinationLandingScreenState
    extends ConsumerState<HospitalCoordinationLandingScreen> {
  late Future<HospitalDirectoryResult> directory;

  @override
  void initState() {
    super.initState();
    directory = _loadDirectory();
  }

  Future<HospitalDirectoryResult> _loadDirectory() => ref
      .read(hospitalCoordinationRepositoryProvider)
      .listFacilities(widget.accessToken);

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                context.go('/');
              }
            },
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back to home',
          ),
          title: Text(context.tr('hospital_finder')),
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(Icons.emergency, size: 38),
                    SizedBox(height: 8),
                    Text(
                      'Do not wait for an app response during an emergency.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Call emergency services and begin transport to the nearest emergency facility.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              context.tr('find_prepared'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'SnakeCare uses your emergency assessment and location to rank registered hospitals. Every result shows its source, freshness, capabilities, and the reasons for its position.',
            ),
            const SizedBox(height: 18),
            const _FeatureTile(
              icon: Icons.location_on_outlined,
              title: 'Nearby recommendations',
              subtitle:
                  'Distance is considered together with reported clinical readiness.',
            ),
            const _FeatureTile(
              icon: Icons.medical_services_outlined,
              title: 'Readiness information',
              subtitle:
                  'View timestamped antivenom, emergency-bed, ICU, and ventilator reports.',
            ),
            const _FeatureTile(
              icon: Icons.fact_check_outlined,
              title: 'Explainable ranking',
              subtitle:
                  'See why a hospital was recommended and when its data expires.',
            ),
            const _FeatureTile(
              icon: Icons.privacy_tip_outlined,
              title: 'Consent-controlled pre-alert',
              subtitle:
                  'Choose what emergency information may be shared with a hospital.',
            ),
            const SizedBox(height: 18),
            Text(
              context.tr('pune_registry'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            FutureBuilder<HospitalDirectoryResult>(
              future: directory,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  );
                }
                if (snapshot.hasError || !snapshot.hasData) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Text('Unable to load registered hospitals.'),
                          const SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: () => setState(
                              () => directory = _loadDirectory(),
                            ),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return _FacilityDirectory(directory: snapshot.data!);
              },
            ),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How to search',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    const Text('1. Record symptoms, vitals, and location.'),
                    const Text('2. Submit the emergency assessment.'),
                    const Text('3. Select "Find prepared hospitals".'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SnakebiteEmergencyScreen(
                    accessToken: widget.accessToken,
                  ),
                ),
              ),
              icon: const Icon(Icons.emergency),
              label: const Text('Start emergency assessment'),
            ),
            const SizedBox(height: 10),
            const Text(
              'Hospital data is not a guarantee of stock, admission, or treatment availability. Call the hospital to confirm while travelling.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
}

class _FacilityDirectory extends StatelessWidget {
  const _FacilityDirectory({required this.directory});

  final HospitalDirectoryResult directory;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${directory.total} map-listed hospitals found',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(directory.notice),
              const SizedBox(height: 6),
              Text(
                'Source: ${directory.sourceAttribution}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Divider(height: 24),
              ...directory.items.map(
                (hospital) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.local_hospital_outlined),
                  title: Text(hospital.name),
                  subtitle: Text(
                    '${hospital.address}\n${hospital.sourceLabel} • Live readiness unavailable',
                  ),
                  isThreeLine: true,
                ),
              ),
            ],
          ),
        ),
      );
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text(subtitle),
        ),
      );
}

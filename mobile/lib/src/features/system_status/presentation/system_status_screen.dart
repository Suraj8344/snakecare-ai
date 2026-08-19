import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snakecare_mobile/src/features/system_status/domain/service_status.dart';
import 'package:snakecare_mobile/src/features/system_status/presentation/system_status_controller.dart';
import 'package:snakecare_mobile/src/core/config/app_config.dart';
import 'package:snakecare_mobile/src/core/localization/app_localizations.dart';

class SystemStatusScreen extends ConsumerWidget {
  const SystemStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<ServiceStatus> state = ref.watch(systemStatusProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('system_health'))),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Semantics(
                liveRegion: true,
                child: state.when(
                  loading: () => const _LoadingCard(),
                  error: (Object error, StackTrace stack) => _ErrorCard(
                    error: error,
                    onRetry: () => ref.invalidate(systemStatusProvider),
                  ),
                  data: (ServiceStatus status) => _HealthyCard(status: status),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HealthyCard extends StatelessWidget {
  const _HealthyCard({required this.status});
  final ServiceStatus status;

  @override
  Widget build(BuildContext context) {
    final databaseReady = status.readiness == 'ready';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.health_and_safety,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              databaseReady
                  ? context.tr('all_operational')
                  : context.tr('api_degraded'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text('${status.service} • v${status.version}'),
            const SizedBox(height: 16),
            _StatusRow(
              label: context.tr('api_service'),
              value:
                  status.status == 'ok' ? context.tr('online') : status.status,
              healthy: status.status == 'ok',
            ),
            const SizedBox(height: 10),
            _StatusRow(
              label: context.tr('database_readiness'),
              value: databaseReady ? context.tr('ready') : status.readiness,
              healthy: databaseReady,
            ),
            if (status.readinessDetail != null) ...[
              const SizedBox(height: 8),
              Text(
                status.readinessDetail!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
            const Divider(height: 28),
            SelectableText(
              status.apiBaseUrl,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (status.checkedAt.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Checked ${status.checkedAt.replaceFirst('T', ' ').split('.').first}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.label,
    required this.value,
    required this.healthy,
  });

  final String label;
  final String value;
  final bool healthy;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(
            healthy ? Icons.check_circle : Icons.warning_amber_rounded,
            color: healthy ? Colors.green : Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      );
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(context.tr('checking_status')),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.cloud_off, size: 48),
            const SizedBox(height: 16),
            Text(
              context.tr('service_unavailable'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            SelectableText(
              AppConfig.apiBaseUrl,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _friendlyError(error),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(context.tr('retry')),
            ),
          ],
        ),
      ),
    );
  }
}

String _friendlyError(Object error) {
  if (error is DioException) {
    final status = error.response?.statusCode;
    return status == null
        ? 'Could not connect to the configured API.'
        : 'The API returned HTTP $status.';
  }
  return 'The API returned an invalid health response.';
}

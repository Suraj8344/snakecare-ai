import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:snakecare_mobile/src/core/config/app_config.dart';
import 'package:snakecare_mobile/src/features/auth/domain/auth_session.dart';
import 'package:snakecare_mobile/src/features/auth/presentation/auth_controller.dart';
import 'package:snakecare_mobile/src/features/hospital_coordination/domain/hospital_recommendation.dart';
import 'package:snakecare_mobile/src/features/hospital_dashboard/data/hospital_dashboard_repository.dart';
import 'package:snakecare_mobile/src/features/hospital_dashboard/domain/hospital_dashboard.dart';

Uri buildAntivenomQrUri(String token) {
  final configured = AppConfig.publicAppUrl.trim();
  final base = configured.isEmpty ? Uri.base : Uri.parse(configured);
  return base.replace(
    queryParameters: {'module': '7', 'antivenom_token': token},
  );
}

class HospitalDashboardScreen extends ConsumerStatefulWidget {
  const HospitalDashboardScreen({
    required this.accessToken,
    required this.role,
    super.key,
    this.initialQrToken,
  });

  final String accessToken;
  final UserRole role;
  final String? initialQrToken;

  @override
  ConsumerState<HospitalDashboardScreen> createState() =>
      _HospitalDashboardScreenState();
}

class _HospitalDashboardScreenState
    extends ConsumerState<HospitalDashboardScreen> {
  HospitalDashboardData? _dashboard;
  List<HospitalClaim> _claims = [];
  List<HospitalFacility> _facilities = [];
  bool _loading = true;
  bool _searching = false;
  bool _hasSearched = false;
  bool _qrProcessed = false;
  String? _error;
  final _search = TextEditingController();

  HospitalDashboardRepository get _repository =>
      ref.read(hospitalDashboardRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (widget.role == UserRole.governmentAdmin) {
        _claims = await _repository.pendingClaims(widget.accessToken);
      } else if (widget.role == UserRole.hospitalAdmin) {
        try {
          _dashboard = await _repository.dashboard(widget.accessToken);
          if (!_qrProcessed && widget.initialQrToken != null) {
            _qrProcessed = true;
            await _repository.scanBox(
              widget.accessToken,
              widget.initialQrToken!,
            );
            _dashboard = await _repository.dashboard(widget.accessToken);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Scan recorded. An authorized hospital user must approve it before stock changes.',
                  ),
                ),
              );
            }
          }
        } on DioException catch (error) {
          if (error.response?.statusCode != 403) rethrow;
          _dashboard = null;
          _claims = await _repository.myClaims(widget.accessToken);
          if (!_claims.any((claim) => claim.status == 'pending')) {
            _facilities = await _repository.searchFacilities(
              widget.accessToken,
              '',
            );
          }
        }
      } else {
        _error =
            'Module 7 is available to verified hospital and government administrators.';
      }
    } catch (error) {
      _error = _message(error);
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.role == UserRole.governmentAdmin
              ? 'Hospital claim review'
              : 'Hospital operations',
        ),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
          IconButton(
            onPressed: ref.read(authControllerProvider.notifier).logout,
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorState(message: _error!, retry: _load)
              : widget.role == UserRole.governmentAdmin
                  ? _governmentView()
                  : _dashboard == null
                      ? _claimView()
                      : _operationsView(_dashboard!),
    );
  }

  Widget _governmentView() => RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const _SafetyNotice(
              text:
                  'Approve only after checking the facility identity and submitted evidence. Approval connects the account; it does not verify every clinical capability.',
            ),
            const SizedBox(height: 16),
            Text(
              'Pending claims (${_claims.length})',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            if (_claims.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('No hospital claims are waiting for review.'),
                ),
              ),
            for (final claim in _claims)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        claim.facilityName,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      Text(claim.requesterEmail ?? 'No requester email'),
                      Text('Method: ${claim.verificationMethod}'),
                      Text('Evidence: ${claim.evidenceReference}'),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        children: [
                          FilledButton.icon(
                            onPressed: () => _decideClaim(claim.id, true),
                            icon: const Icon(Icons.check),
                            label: const Text('Approve connection'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _decideClaim(claim.id, false),
                            icon: const Icon(Icons.close),
                            label: const Text('Reject'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );

  Widget _claimView() {
    final pending =
        _claims.where((claim) => claim.status == 'pending').toList();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Connect your hospital',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'Find your Pune facility and submit official evidence. A government administrator must approve the claim before the dashboard and QR inventory are enabled.',
        ),
        if (pending.isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.hourglass_top),
              title: Text('${pending.first.facilityName} claim pending'),
              subtitle: Text(pending.first.evidenceReference),
            ),
          ),
        ] else ...[
          const SizedBox(height: 20),
          TextField(
            controller: _search,
            onSubmitted: (_) => _searchFacilities(),
            decoration: InputDecoration(
              labelText: 'Hospital name or address in Pune',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                onPressed: _searching ? null : _searchFacilities,
                icon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.arrow_forward),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_facilities.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _hasSearched
                    ? '${_facilities.length} matching ${_facilities.length == 1 ? 'hospital' : 'hospitals'}'
                    : '${_facilities.length} Pune hospitals available',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          if (_hasSearched && !_searching && _facilities.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(Icons.search_off, size: 42),
                    const SizedBox(height: 8),
                    Text('No Pune hospital matched “${_search.text.trim()}”.'),
                    const SizedBox(height: 4),
                    const Text(
                      'Check the spelling or search using part of the hospital name or address.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          for (final facility in _facilities)
            Card(
              child: ListTile(
                leading: const Icon(Icons.local_hospital_outlined),
                title: Text(facility.name),
                subtitle: Text('${facility.address}\n${facility.sourceLabel}'),
                isThreeLine: true,
                trailing: facility.isConnectedToSnakeCare
                    ? const Chip(label: Text('Connected'))
                    : FilledButton(
                        onPressed: () => _submitClaim(facility),
                        child: const Text('Claim'),
                      ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _operationsView(HospitalDashboardData data) {
    final availability = data.facility.availability;
    final pendingAlerts =
        data.preAlerts.where((item) => item.status == 'pending').toList();
    final pendingResources = data.resourceRequests
        .where((item) => item.status == 'pending')
        .toList();
    final pendingDepletions = data.depletionRequests
        .where((request) => request.status == 'pending')
        .toList();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            data.facility.name,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Text(data.facility.address),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _Metric(
                label: 'Antivenom',
                value: availability == null
                    ? 'Not reported'
                    : '${availability.antivenomVials ?? 0} vials',
                icon: Icons.vaccines_outlined,
              ),
              _Metric(
                label: 'Emergency beds',
                value: '${availability?.emergencyBeds ?? 'Not reported'}',
                icon: Icons.bed_outlined,
              ),
              _Metric(
                label: 'Pending inbox',
                value: '${pendingAlerts.length + pendingResources.length}',
                icon: Icons.inbox_outlined,
              ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _publishAvailability,
            icon: const Icon(Icons.update),
            label: const Text('Publish 30-minute resource update'),
          ),
          const SizedBox(height: 24),
          _sectionTitle('Emergency coordination inbox'),
          if (pendingAlerts.isEmpty && pendingResources.isEmpty)
            const Text('No pending pre-alerts or resource requests.'),
          for (final item in pendingAlerts)
            _inboxCard(item, 'pre-alerts', 'Patient pre-alert'),
          for (final item in pendingResources)
            _inboxCard(item, 'resource-requests', 'Resource request'),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(child: _sectionTitle('Antivenom box inventory')),
              FilledButton.icon(
                onPressed: _registerBox,
                icon: const Icon(Icons.add_box_outlined),
                label: const Text('Register box'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const _SafetyNotice(
            text:
                'SnakeCare QR is an internal workflow code, not product identification. Keep and verify the manufacturer label, GS1 DataMatrix, batch, expiry, and storage requirements.',
          ),
          const SizedBox(height: 12),
          for (final box in data.boxes)
            Card(
              child: ListTile(
                leading: const Icon(Icons.inventory_2_outlined),
                title: Text('${box.productName} · ${box.availableVials} vials'),
                subtitle: Text(
                  'Serial ${box.boxSerial} · Batch ${box.batchNumber}\nExpires ${box.expiryDate.toIso8601String().split('T').first}',
                ),
                isThreeLine: true,
                trailing: Chip(label: Text(box.status)),
              ),
            ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _manualScan,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Enter scanned QR token'),
          ),
          const SizedBox(height: 24),
          _sectionTitle('Pending stock changes'),
          if (pendingDepletions.isEmpty)
            const Text('No scanned stock changes are waiting for approval.'),
          for (final request in pendingDepletions)
            Card(
              color: Theme.of(context).colorScheme.tertiaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${request.requestedUsedVials} vials reported used',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text('Box ${request.boxId}'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      children: [
                        FilledButton(
                          onPressed: () => _decideDepletion(request.id, true),
                          child: const Text('Approve stock update'),
                        ),
                        OutlinedButton(
                          onPressed: () => _decideDepletion(request.id, false),
                          child: const Text('Reject'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _inboxCard(HospitalInboxItem item, String kind, String title) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(item.summary),
              if (item.emergencyId != null)
                SelectableText('Emergency ID: ${item.emergencyId}'),
              Text('Expires ${item.expiresAt.toLocal()}'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                children: [
                  FilledButton(
                    onPressed: () => _decideInbox(kind, item.id, true),
                    child: const Text('Accept'),
                  ),
                  OutlinedButton(
                    onPressed: () => _decideInbox(kind, item.id, false),
                    child: const Text('Reject'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _sectionTitle(String value) => Text(
        value,
        style: Theme.of(context).textTheme.titleLarge,
      );

  Future<void> _searchFacilities() async {
    final query = _search.text.trim();
    if (query.isNotEmpty && query.length < 2) {
      _show('Enter at least 2 characters to search.');
      return;
    }
    setState(() {
      _searching = true;
      _hasSearched = query.isNotEmpty;
    });
    try {
      _facilities = await _repository.searchFacilities(
        widget.accessToken,
        query,
      );
    } catch (error) {
      _show(_message(error));
    }
    if (mounted) setState(() => _searching = false);
  }

  Future<void> _submitClaim(HospitalFacility facility) async {
    final evidence = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Claim ${facility.name}'),
        content: TextField(
          controller: evidence,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'HFR ID or official evidence reference',
            helperText: 'Do not enter Aadhaar or patient information.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, evidence.text.trim()),
            child: const Text('Submit for review'),
          ),
        ],
      ),
    );
    evidence.dispose();
    if (value == null || value.length < 3) return;
    await _run(
      () => _repository.submitClaim(
        widget.accessToken,
        facilityId: facility.id,
        evidenceReference: value,
      ),
    );
  }

  Future<void> _decideClaim(String id, bool approve) => _run(
        () => _repository.decideClaim(widget.accessToken, id, approve),
      );

  Future<void> _decideInbox(String kind, String id, bool approve) => _run(
        () => _repository.decideInbox(
          widget.accessToken,
          kind: kind,
          id: id,
          approve: approve,
        ),
      );

  Future<void> _decideDepletion(String id, bool approve) => _run(
        () => _repository.decideDepletion(
          widget.accessToken,
          id,
          approve,
        ),
      );

  Future<void> _publishAvailability() async {
    final beds = TextEditingController();
    final icu = TextEditingController();
    final ventilators = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Publish current resources'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: beds,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Emergency beds'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: icu,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'ICU beds'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: ventilators,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Ventilators'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Publish for 30 minutes'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _run(
        () => _repository.publishAvailability(
          widget.accessToken,
          emergencyBeds: int.tryParse(beds.text),
          icuBeds: int.tryParse(icu.text),
          ventilators: int.tryParse(ventilators.text),
        ),
      );
    }
    beds.dispose();
    icu.dispose();
    ventilators.dispose();
  }

  Future<void> _registerBox() async {
    final serial = TextEditingController();
    final product = TextEditingController();
    final manufacturer = TextEditingController();
    final batch = TextEditingController();
    final expiry = TextEditingController();
    final vials = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Register antivenom box'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(serial, 'Internal box serial'),
              _field(product, 'Product name'),
              _field(manufacturer, 'Manufacturer'),
              _field(batch, 'Manufacturer batch/lot'),
              _field(expiry, 'Expiry date (YYYY-MM-DD)'),
              _field(vials, 'Vials in box', number: true),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Register and create QR'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        final box = await _repository.registerBox(
          widget.accessToken,
          boxSerial: serial.text,
          productName: product.text,
          manufacturer: manufacturer.text,
          batchNumber: batch.text,
          expiryDate: DateTime.parse(expiry.text),
          initialVials: int.parse(vials.text),
        );
        if (mounted) await _showQr(box);
        await _load();
      } catch (error) {
        _show(_message(error));
      }
    }
    for (final controller in [
      serial,
      product,
      manufacturer,
      batch,
      expiry,
      vials,
    ]) {
      controller.dispose();
    }
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool number = false,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: controller,
          keyboardType: number ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(labelText: label),
        ),
      );

  Future<void> _showQr(AntivenomBoxRecord box) async {
    final token = box.qrToken!;
    final uri = buildAntivenomQrUri(token);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Attach to box ${box.boxSerial}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(12),
                child: QrImageView(data: uri.toString(), size: 220),
              ),
              const SizedBox(height: 12),
              Text(box.qrNotice ?? ''),
              const SizedBox(height: 8),
              SelectableText(uri.toString()),
              if (uri.host == 'localhost' || uri.host == '127.0.0.1')
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'For scanning from another phone, rebuild with PUBLIC_APP_URL set to a reachable HTTPS address.',
                  ),
                ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _manualScan() async {
    final token = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter scanned QR token'),
        content: TextField(
          controller: token,
          decoration: const InputDecoration(labelText: 'SnakeCare box token'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, token.text.trim()),
            child: const Text('Create pending update'),
          ),
        ],
      ),
    );
    token.dispose();
    if (value == null || value.isEmpty) return;
    await _run(() => _repository.scanBox(widget.accessToken, value));
  }

  Future<void> _run(Future<Object?> Function() operation) async {
    setState(() => _loading = true);
    try {
      await operation();
      await _load();
    } catch (error) {
      if (mounted) {
        setState(() => _loading = false);
        _show(_message(error));
      }
    }
  }

  void _show(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _message(Object error) {
    if (error is DioException && error.response?.data is Map) {
      final data = Map<String, dynamic>.from(error.response!.data as Map);
      return data['detail'] as String? ?? 'Hospital operation failed.';
    }
    return error.toString();
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
        child: SizedBox(
          width: 210,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon),
                const SizedBox(width: 10),
                Expanded(child: Text('$label\n$value')),
              ],
            ),
          ),
        ),
      );
}

class _SafetyNotice extends StatelessWidget {
  const _SafetyNotice({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Card(
        color: Theme.of(context).colorScheme.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline),
              const SizedBox(width: 10),
              Expanded(child: Text(text)),
            ],
          ),
        ),
      );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.retry});
  final String message;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 54),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: retry, child: const Text('Retry')),
            ],
          ),
        ),
      );
}

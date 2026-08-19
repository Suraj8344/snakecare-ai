import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snakecare_mobile/src/features/auth/data/user_management_repository.dart';
import 'package:snakecare_mobile/src/features/auth/domain/auth_session.dart';
import 'package:snakecare_mobile/src/features/auth/domain/managed_user.dart';

class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({
    required this.accessToken,
    required this.currentUserId,
    super.key,
  });

  final String accessToken;
  final String currentUserId;

  @override
  ConsumerState<UserManagementScreen> createState() =>
      _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> {
  final _search = TextEditingController();
  List<ManagedUser>? _users;
  Object? _error;
  bool _saving = false;

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
    setState(() => _error = null);
    try {
      final users = await ref
          .read(userManagementRepositoryProvider)
          .listUsers(widget.accessToken);
      if (mounted) setState(() => _users = users);
    } on Object catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final users = (_users ?? <ManagedUser>[]).where((user) {
      if (query.isEmpty) return true;
      return [
        user.displayName,
        user.email,
        user.phoneNumber,
        user.hospitalEmployeeId,
      ].whereType<String>().any((value) => value.toLowerCase().contains(query));
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Users & hospital staff'),
        actions: [
          IconButton(
            onPressed: _saving ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh users',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Search name, email, phone, or employee ID',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 4, 18, 12),
              child: Text(
                'Only verified users can become hospital staff. Employee IDs are assigned by a government administrator—never enter Aadhaar here.',
              ),
            ),
            Expanded(child: _content(users)),
          ],
        ),
      ),
    );
  }

  Widget _content(List<ManagedUser> users) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 52),
              const SizedBox(height: 12),
              Text(_message(_error!)),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (_users == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (users.isEmpty) {
      return const Center(child: Text('No matching users found.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: users.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _userCard(users[index]),
    );
  }

  Widget _userCard(ManagedUser user) {
    final isCurrentAdmin = user.id == widget.currentUserId;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(child: Icon(Icons.person_outline)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.identity,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (user.email != null && user.email != user.identity)
                        Text(user.email!),
                    ],
                  ),
                ),
                _verificationChip(user),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text(_roleLabel(user.role))),
                if (user.hospitalEmployeeId != null)
                  Chip(
                    avatar: const Icon(Icons.badge_outlined, size: 18),
                    label: Text(user.hospitalEmployeeId!),
                  ),
                if (isCurrentAdmin) const Chip(label: Text('Your account')),
              ],
            ),
            if (!isCurrentAdmin && user.role != UserRole.governmentAdmin) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: PopupMenuButton<UserRole>(
                  enabled: !_saving,
                  onSelected: (role) => _changeRole(user, role),
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: UserRole.patient,
                      child: Text('Set as patient'),
                    ),
                    const PopupMenuItem(
                      value: UserRole.doctor,
                      child: Text('Set as doctor'),
                    ),
                    PopupMenuItem(
                      value: UserRole.hospitalAdmin,
                      enabled: user.emailVerified,
                      child: Text(
                        user.emailVerified
                            ? 'Assign hospital employee'
                            : 'Verify email before hospital access',
                      ),
                    ),
                  ],
                  child: const Chip(
                    avatar: Icon(Icons.admin_panel_settings_outlined),
                    label: Text('Manage role'),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _verificationChip(ManagedUser user) => Chip(
        avatar: Icon(
          user.emailVerified ? Icons.verified : Icons.warning_amber,
          size: 18,
        ),
        label: Text(user.emailVerified ? 'Verified' : 'Unverified'),
      );

  Future<void> _changeRole(ManagedUser user, UserRole role) async {
    String? employeeId;
    if (role == UserRole.hospitalAdmin) {
      employeeId = await _employeeIdDialog(
        user,
        title: 'Assign hospital employee',
        label: 'Hospital employee ID',
        hint: 'PUNE-01/EMP-1024',
        currentValue: user.hospitalEmployeeId,
      );
      if (employeeId == null) return;
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Change account role?'),
          content: Text('Set ${user.identity} as ${_roleLabel(role)}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(userManagementRepositoryProvider).assignRole(
            widget.accessToken,
            userId: user.id,
            role: role,
            hospitalEmployeeId: employeeId,
          );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${user.identity} updated successfully.')),
        );
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_message(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<String?> _employeeIdDialog(
    ManagedUser user, {
    required String title,
    required String label,
    required String hint,
    required String? currentValue,
  }) async {
    final controller = TextEditingController(
      text: currentValue ?? '',
    );
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(user.identity),
              const SizedBox(height: 16),
              TextFormField(
                controller: controller,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: label,
                  hintText: hint,
                  helperText:
                      'Use the organization code and staff ID. Do not use Aadhaar.',
                ),
                validator: (value) {
                  final normalized = value?.trim() ?? '';
                  if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9._/-]{2,63}$')
                      .hasMatch(normalized)) {
                    return 'Enter 3–64 letters, numbers, dot, slash, underscore, or dash.';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, controller.text.trim().toUpperCase());
              }
            },
            child: const Text('Grant hospital access'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  static String _roleLabel(UserRole role) => switch (role) {
        UserRole.patient => 'Patient',
        UserRole.doctor => 'Doctor',
        UserRole.hospitalAdmin => 'Hospital administrator',
        UserRole.governmentAdmin => 'Government administrator',
      };

  static String _message(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map) {
        final title = data['title'];
        if (title is String) return title;
        final detail = data['detail'];
        if (detail is String) return detail;
      }
      return 'The server could not update this user. Check the connection and try again.';
    }
    return error.toString().replaceFirst('Exception: ', '');
  }
}

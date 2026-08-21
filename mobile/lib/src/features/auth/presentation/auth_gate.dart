import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:snakecare_mobile/src/core/config/app_config.dart';
import 'package:snakecare_mobile/src/core/localization/app_localizations.dart';
import 'package:snakecare_mobile/src/features/auth/data/auth_repository.dart';
import 'package:snakecare_mobile/src/features/auth/domain/auth_session.dart';
import 'package:snakecare_mobile/src/features/auth/presentation/auth_controller.dart';
import 'package:snakecare_mobile/src/features/auth/presentation/user_management_screen.dart';
import 'package:snakecare_mobile/src/features/emergency_handoff/presentation/emergency_handoff_screen.dart';
import 'package:snakecare_mobile/src/features/hospital_coordination/presentation/hospital_coordination_landing_screen.dart';
import 'package:snakecare_mobile/src/features/hospital_dashboard/presentation/hospital_dashboard_screen.dart';
import 'package:snakecare_mobile/src/features/medical_passport/presentation/medical_passport_screen.dart';
import 'package:snakecare_mobile/src/features/medical_reports/presentation/medical_reports_screen.dart';
import 'package:snakecare_mobile/src/features/offline_resilience/presentation/offline_resilience_screen.dart';
import 'package:snakecare_mobile/src/features/snakebite_emergency/presentation/snakebite_emergency_screen.dart';
import 'package:snakecare_mobile/src/features/system_status/presentation/system_status_screen.dart';

String _friendlyAuthMessage(Object error) {
  if (error is FirebaseAuthException) {
    return switch (error.code) {
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' =>
        'The email address or password is incorrect.',
      'email-already-in-use' =>
        'An account already exists for this email. Sign in or reset the password.',
      'weak-password' => 'Use a stronger password with at least 6 characters.',
      'invalid-email' => 'Enter a valid email address.',
      'too-many-requests' =>
        'Too many attempts were made. Wait a few minutes, then try again.',
      'network-request-failed' =>
        'Authentication could not reach the network. Check your connection and try again.',
      'invalid-verification-code' =>
        'That verification code is incorrect. Check the SMS and try again.',
      'session-expired' => 'The verification code expired. Request a new code.',
      'quota-exceeded' =>
        'The SMS verification limit has been reached. Try again later or use email sign-in.',
      'user-disabled' =>
        'This account has been disabled. Contact a SnakeCare administrator.',
      _ => error.message ?? 'Authentication failed. Please try again.',
    };
  }
  final message = error.toString();
  if (message.contains('canceled') || message.contains('cancelled')) {
    return 'Google sign-in was cancelled.';
  }
  if (message.contains('DioException') ||
      message.contains('XMLHttpRequest') ||
      message.contains('CORS')) {
    return 'The secure SnakeCare service could not be reached. Check your connection and try again. '
        'Emergency tools remain available offline.';
  }
  return message
      .replaceFirst('Bad state: ', '')
      .replaceFirst('StateError: ', '')
      .replaceFirst('Exception: ', '');
}

class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key, this.modulePreview, this.antivenomToken});

  final String? modulePreview;
  final String? antivenomToken;

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  UserRole? _requestedRole;

  @override
  Widget build(BuildContext context) {
    final requestedModule =
        widget.modulePreview ?? Uri.base.queryParameters['module'];
    final requestedAntivenomToken =
        widget.antivenomToken ?? Uri.base.queryParameters['antivenom_token'];
    final auth = ref.watch(authControllerProvider);
    return auth.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => LoginScreen(
        message: _friendlyAuthMessage(error),
        selectedRole: _requestedRole,
        onRoleSelected: _selectRole,
      ),
      data: (session) {
        if (session == null) {
          return LoginScreen(
            selectedRole: _requestedRole,
            onRoleSelected: _selectRole,
          );
        }
        if (_requestedRole case final requested?
            when requested != session.user.role) {
          return RoleAccessMismatchScreen(
            session: session,
            requestedRole: requested,
            onUseAssignedRole: () => setState(
              () => _requestedRole = session.user.role,
            ),
          );
        }
        return RoleHomeScreen(
          session: session,
          modulePreview: requestedModule,
          antivenomToken: requestedAntivenomToken,
        );
      },
    );
  }

  void _selectRole(UserRole role) => setState(() => _requestedRole = role);
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({
    required this.selectedRole,
    required this.onRoleSelected,
    super.key,
    this.message,
  });
  final String? message;
  final UserRole? selectedRole;
  final ValueChanged<UserRole> onRoleSelected;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(28, 26, 28, 24),
                      color: const Color(0xFF1E88E5),
                      child: const Column(
                        children: [
                          CircleAvatar(
                            radius: 31,
                            backgroundColor: Colors.white,
                            child: Icon(
                              Icons.health_and_safety,
                              size: 38,
                              color: Color(0xFF1E88E5),
                            ),
                          ),
                          SizedBox(height: 12),
                          Text(
                            'SnakeCare AI',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Be Prepared. Stay Safe.',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _register
                                ? 'Create your account'
                                : 'Welcome to SnakeCare',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  color: const Color(0xFF263338),
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Secure access for patients and authorized teams',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Color(0xFF5C6870)),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'Choose your interface',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _portalChip(
                                role: UserRole.patient,
                                label: 'Patient',
                                icon: Icons.person_outline,
                              ),
                              _portalChip(
                                role: UserRole.hospitalAdmin,
                                label: 'Hospital Authority',
                                icon: Icons.local_hospital_outlined,
                              ),
                              _portalChip(
                                role: UserRole.governmentAdmin,
                                label: 'Government Authority',
                                icon: Icons.account_balance_outlined,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            widget.selectedRole == null
                                ? 'Select an interface before signing in.'
                                : widget.selectedRole == UserRole.patient
                                    ? 'Patient accounts can register directly.'
                                    : 'Authority access requires a verified role assigned by SnakeCare.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF5C6870),
                              fontSize: 13,
                            ),
                          ),
                          if (!AppConfig.firebaseEnabled) ...[
                            const SizedBox(height: 18),
                            const Card(
                              color: Color(0xFFFFF3CD),
                              child: Padding(
                                padding: EdgeInsets.all(12),
                                child: Text(
                                  'Authentication setup is required. Add Firebase configuration to enable sign-in.',
                                  style: TextStyle(
                                    color: Color(0xFF5F4700),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          if (widget.message != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF3E0),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.info_outline,
                                    color: Color(0xFFFB8C00),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      widget.message!,
                                      style: const TextStyle(
                                        color: Color(0xFF6A4200),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          TextField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email address',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _password,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Password',
                              prefixIcon: Icon(Icons.lock_outline),
                            ),
                          ),
                          const SizedBox(height: 18),
                          FilledButton(
                            onPressed: AppConfig.firebaseEnabled &&
                                    widget.selectedRole != null
                                ? () => ref
                                    .read(authControllerProvider.notifier)
                                    .email(
                                      _email.text,
                                      _password.text,
                                      register: _register,
                                    )
                                : null,
                            child: Text(
                              _register
                                  ? 'Create patient account'
                                  : widget.selectedRole == null
                                      ? 'Select an interface'
                                      : 'Sign in to ${_roleLabel(widget.selectedRole!)}',
                            ),
                          ),
                          if (widget.selectedRole == UserRole.patient)
                            TextButton(
                              onPressed: () =>
                                  setState(() => _register = !_register),
                              child: Text(
                                _register
                                    ? 'Already registered? Sign in'
                                    : 'New patient? Create an account',
                              ),
                            ),
                          if (!_register)
                            TextButton(
                              onPressed: AppConfig.firebaseEnabled
                                  ? _sendPasswordReset
                                  : null,
                              child: const Text('Forgot password?'),
                            ),
                          const Divider(height: 30),
                          OutlinedButton.icon(
                            onPressed: AppConfig.firebaseEnabled &&
                                    widget.selectedRole != null
                                ? ref
                                    .read(authControllerProvider.notifier)
                                    .google
                                : null,
                            icon: const Icon(Icons.g_mobiledata),
                            label: const Text('Continue with Google'),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: AppConfig.firebaseEnabled &&
                                    widget.selectedRole != null
                                ? _showPhoneDialog
                                : null,
                            icon: const Icon(Icons.phone_outlined),
                            label: const Text('Continue with phone'),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Selecting an interface does not grant authority. New accounts begin as Patient; Government administrators approve staff roles.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 18),
                          FilledButton.icon(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const OfflineResilienceScreen(),
                              ),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: colors.error,
                              foregroundColor: colors.onError,
                            ),
                            icon: const Icon(Icons.sos),
                            label:
                                const Text('Emergency tools — works offline'),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Emergency calling, first aid, local triage, cached hospitals and the retry outbox remain available without signing in.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Color(0xFF5C6870)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _portalChip({
    required UserRole role,
    required String label,
    required IconData icon,
  }) =>
      ChoiceChip(
        selected: widget.selectedRole == role,
        onSelected: (_) {
          if (role != UserRole.patient && _register) {
            setState(() => _register = false);
          }
          widget.onRoleSelected(role);
        },
        avatar: Icon(icon, size: 18),
        label: Text(label),
      );

  Future<void> _showPhoneDialog() async {
    final phone = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Phone sign-in'),
        content: TextField(
          controller: phone,
          decoration: const InputDecoration(hintText: '+91...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, phone.text),
            child: const Text('Send code'),
          ),
        ],
      ),
    );
    phone.dispose();
    if (value == null || !mounted) return;
    late final PhoneSignInChallenge challenge;
    try {
      challenge =
          await ref.read(authControllerProvider.notifier).sendPhoneCode(value);
    } catch (error) {
      if (mounted) _showMessage(_friendlyAuthMessage(error));
      return;
    }
    if (challenge.isCompleted || !mounted) return;
    final verificationId = challenge.verificationId!;
    if (!mounted) return;
    final code = TextEditingController();
    final otp = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter verification code'),
        content:
            TextField(controller: code, keyboardType: TextInputType.number),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context, code.text),
            child: const Text('Verify'),
          ),
        ],
      ),
    );
    code.dispose();
    if (otp != null) {
      await ref
          .read(authControllerProvider.notifier)
          .confirmPhone(verificationId, otp);
    }
  }

  Future<void> _sendPasswordReset() async {
    try {
      await ref
          .read(authControllerProvider.notifier)
          .sendPasswordReset(_email.text);
      if (mounted) {
        _showMessage('Password reset email sent. Check your inbox.');
      }
    } catch (error) {
      if (mounted) _showMessage(_friendlyAuthMessage(error));
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class RoleAccessMismatchScreen extends ConsumerWidget {
  const RoleAccessMismatchScreen({
    required this.session,
    required this.requestedRole,
    required this.onUseAssignedRole,
    super.key,
  });

  final AuthSession session;
  final UserRole requestedRole;
  final VoidCallback onUseAssignedRole;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(title: const Text('Interface access check')),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.admin_panel_settings_outlined,
                          size: 56,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${_roleLabel(requestedRole)} access is not assigned',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'This verified account is assigned to the ${_roleLabel(session.user.role)} interface. '
                          'A Government Authority administrator must approve Hospital Authority roles.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: onUseAssignedRole,
                          icon: const Icon(Icons.arrow_forward),
                          label: Text(
                            'Open ${_roleLabel(session.user.role)} interface',
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed:
                              ref.read(authControllerProvider.notifier).logout,
                          icon: const Icon(Icons.logout),
                          label: const Text('Sign in with another account'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

String _roleLabel(UserRole role) => switch (role) {
      UserRole.patient => 'Patient',
      UserRole.doctor => 'Doctor',
      UserRole.hospitalAdmin => 'Hospital Authority',
      UserRole.governmentAdmin => 'Government Authority',
    };

class RoleHomeScreen extends ConsumerWidget {
  const RoleHomeScreen({
    required this.session,
    super.key,
    this.modulePreview,
    this.antivenomToken,
  });

  final AuthSession session;
  final String? modulePreview;
  final String? antivenomToken;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (modulePreview == '6') {
      return HospitalCoordinationLandingScreen(
        accessToken: session.accessToken,
      );
    }
    if (modulePreview == '7') {
      return HospitalDashboardScreen(
        accessToken: session.accessToken,
        role: session.user.role,
        initialQrToken: antivenomToken,
      );
    }
    if (modulePreview == '8') {
      return EmergencyHandoffScreen(accessToken: session.accessToken);
    }
    final label = switch (session.user.role) {
      UserRole.patient => context.tr('patient'),
      UserRole.doctor => context.tr('doctor'),
      UserRole.hospitalAdmin => context.tr('hospital_authority'),
      UserRole.governmentAdmin => context.tr('government_authority'),
    };
    final portalTitle = switch (session.user.role) {
      UserRole.patient => context.tr('patient_portal'),
      UserRole.doctor => context.tr('doctor_portal'),
      UserRole.hospitalAdmin => context.tr('hospital_portal'),
      UserRole.governmentAdmin => context.tr('government_portal'),
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(portalTitle),
        actions: [
          IconButton(
            onPressed: ref.read(authControllerProvider.notifier).logout,
            icon: const Icon(Icons.logout),
            tooltip: context.tr('sign_out'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified_user, size: 56),
                    const SizedBox(height: 12),
                    Text(
                      '$label ${context.tr('interface')}',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      session.user.name ??
                          session.user.email ??
                          'SnakeCare user',
                    ),
                    Chip(label: Text(label)),
                    if (session.user.hospitalEmployeeId != null)
                      Chip(
                        avatar: const Icon(Icons.badge_outlined, size: 18),
                        label: Text(session.user.hospitalEmployeeId!),
                      ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const OfflineResilienceScreen(),
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                        foregroundColor: Theme.of(context).colorScheme.onError,
                      ),
                      icon: const Icon(
                        Icons.signal_cellular_connected_no_internet_0_bar,
                      ),
                      label: Text(context.tr('offline_low_signal')),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => MedicalPassportScreen(
                            accessToken: session.accessToken,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.badge_outlined),
                      label: Text(context.tr('open_passport')),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => MedicalReportsScreen(
                            accessToken: session.accessToken,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.folder_copy_outlined),
                      label: Text(context.tr('medical_reports')),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => SnakebiteEmergencyScreen(
                            accessToken: session.accessToken,
                          ),
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                        foregroundColor: Theme.of(context).colorScheme.onError,
                      ),
                      icon: const Icon(Icons.emergency),
                      label: Text(context.tr('snakebite_emergency')),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => HospitalCoordinationLandingScreen(
                            accessToken: session.accessToken,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.local_hospital_outlined),
                      label: Text(context.tr('find_hospitals')),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => EmergencyHandoffScreen(
                            accessToken: session.accessToken,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.support_agent_outlined),
                      label: Text(context.tr('handoff')),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const SystemStatusScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.monitor_heart_outlined),
                      label: Text(context.tr('system_health')),
                    ),
                    const SizedBox(height: 12),
                    if (session.user.role == UserRole.governmentAdmin) ...[
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => UserManagementScreen(
                              accessToken: session.accessToken,
                              currentUserId: session.user.id,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.manage_accounts_outlined),
                        label: Text(context.tr('manage_users')),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (session.user.role == UserRole.hospitalAdmin ||
                        session.user.role == UserRole.governmentAdmin)
                      FilledButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => HospitalDashboardScreen(
                              accessToken: session.accessToken,
                              role: session.user.role,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.dashboard_outlined),
                        label: Text(
                          session.user.role == UserRole.governmentAdmin
                              ? context.tr('review_claims')
                              : context.tr('hospital_dashboard'),
                        ),
                      )
                    else
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => HospitalDashboardScreen(
                              accessToken: session.accessToken,
                              role: session.user.role,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.lock_outline),
                        label: Text(context.tr('hospital_restricted')),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

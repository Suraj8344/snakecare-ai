import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:snakecare_mobile/src/core/localization/app_localizations.dart';
import 'package:snakecare_mobile/src/features/medical_passport/data/medical_passport_repository.dart';
import 'package:snakecare_mobile/src/features/medical_passport/domain/medical_passport.dart';

class MedicalPassportScreen extends ConsumerWidget {
  const MedicalPassportScreen({required this.accessToken, super.key});
  final String accessToken;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final passport = ref.watch(medicalPassportProvider(accessToken));
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('medical_passport')),
        actions: [
          IconButton(
            onPressed: passport.valueOrNull == null
                ? null
                : () => _edit(context, ref, passport.valueOrNull!),
            icon: const Icon(Icons.edit_outlined),
            tooltip: context.tr('edit_passport'),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PassportAccessScreen(accessToken: accessToken),
              ),
            ),
            icon: const Icon(Icons.admin_panel_settings_outlined),
            tooltip: context.tr('manage_access'),
          ),
        ],
      ),
      body: passport.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, size: 48),
                const SizedBox(height: 12),
                const Text('Unable to load your Medical Passport.'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () =>
                      ref.invalidate(medicalPassportProvider(accessToken)),
                  child: Text(context.tr('retry')),
                ),
              ],
            ),
          ),
        ),
        data: (data) => _PassportBody(
          passport: data,
          onEdit: () => _edit(context, ref, data),
        ),
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    MedicalPassport current,
  ) async {
    final updated = await Navigator.of(context).push<MedicalPassport>(
      MaterialPageRoute(
        builder: (_) => MedicalPassportEditor(initial: current),
      ),
    );
    if (updated == null || !context.mounted) return;
    try {
      await ref
          .read(medicalPassportRepositoryProvider)
          .save(accessToken, updated);
      final refreshedPassport = ref.refresh(
        medicalPassportProvider(accessToken).future,
      );
      await refreshedPassport;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Medical Passport saved securely.')),
        );
      }
    } on DioException catch (error) {
      if (error.response?.statusCode == 409) {
        final refreshedPassport = ref.refresh(
          medicalPassportProvider(accessToken).future,
        );
        await refreshedPassport;
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'A newer passport version was found. The latest information '
                'has been loaded; review it and save again.',
              ),
            ),
          );
        }
        return;
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Save failed. Check the connection and try again.'),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Save failed. Check the information and try again.'),
          ),
        );
      }
    }
  }
}

class _PassportBody extends StatelessWidget {
  const _PassportBody({required this.passport, required this.onEdit});
  final MedicalPassport passport;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final identity = Row(
                      children: [
                        const Icon(Icons.health_and_safety, size: 42),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                passport.fullName?.isNotEmpty == true
                                    ? passport.fullName!
                                    : 'Complete your profile',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const Text('Patient-reported information'),
                            ],
                          ),
                        ),
                      ],
                    );
                    final editButton = FilledButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit information'),
                    );

                    if (constraints.maxWidth < 440) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          identity,
                          const SizedBox(height: 16),
                          editButton,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: identity),
                        const SizedBox(width: 12),
                        editButton,
                      ],
                    );
                  },
                ),
                const Divider(height: 28),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    Chip(
                      avatar: const Icon(Icons.bloodtype),
                      label: Text('Blood: ${passport.bloodGroup}'),
                    ),
                    Chip(
                      label: Text(
                        'DOB: ${passport.dateOfBirth ?? 'Not provided'}',
                      ),
                    ),
                    Chip(
                      label: Text(
                        'Language: ${passport.preferredLanguage ?? 'Not provided'}',
                      ),
                    ),
                    if (passport.organDonor)
                      const Chip(label: Text('Organ donor')),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: SelectableText('Health ID: ${passport.healthId}'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _showHealthQr(context),
                      icon: const Icon(Icons.qr_code_2),
                      label: const Text('Show QR'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        _Section(
          title: 'Critical allergies',
          icon: Icons.warning_amber,
          empty: 'No allergies reported',
          items: passport.allergies
              .map(
                (item) =>
                    '${item.allergen} • ${item.severity}${item.reaction == null ? '' : ' • ${item.reaction}'}',
              )
              .toList(),
        ),
        _Section(
          title: 'Diseases and conditions',
          icon: Icons.monitor_heart_outlined,
          empty: 'No conditions reported',
          items: passport.conditions
              .map((item) => '${item.name} • ${item.status}')
              .toList(),
        ),
        _Section(
          title: 'Current medications',
          icon: Icons.medication_outlined,
          empty: 'No medications reported',
          items: passport.medications
              .map(
                (item) =>
                    '${item.name}${item.dosage == null ? '' : ' • ${item.dosage}'}${item.frequency == null ? '' : ' • ${item.frequency}'}',
              )
              .toList(),
        ),
        _Section(
          title: 'Surgeries',
          icon: Icons.medical_services_outlined,
          empty: 'No surgeries reported',
          items: passport.surgeries
              .map(
                (item) =>
                    '${item.procedure}${item.performedOn == null ? '' : ' • ${item.performedOn}'}${item.hospital == null ? '' : ' • ${item.hospital}'}',
              )
              .toList(),
        ),
        _Section(
          title: 'Family history',
          icon: Icons.family_restroom,
          empty: 'No family history reported',
          items: passport.familyHistory
              .map((item) => '${item.relationship} • ${item.condition}')
              .toList(),
        ),
        _Section(
          title: 'Insurance details',
          icon: Icons.health_and_safety_outlined,
          empty: 'No insurance information provided',
          items: [
            if (passport.insuranceProvider?.isNotEmpty == true)
              'Provider: ${passport.insuranceProvider}',
            if (passport.insurancePlanName?.isNotEmpty == true)
              'Plan: ${passport.insurancePlanName}',
            if (passport.insurancePolicyNumber?.isNotEmpty == true)
              'Policy: ${passport.insurancePolicyNumber}',
            if (passport.insuranceMemberId?.isNotEmpty == true)
              'Member ID: ${passport.insuranceMemberId}',
            if (passport.insuranceGroupNumber?.isNotEmpty == true)
              'Group: ${passport.insuranceGroupNumber}',
            if (passport.insuranceValidThrough?.isNotEmpty == true)
              'Valid through: ${passport.insuranceValidThrough}',
            if (passport.insuranceEmergencyPhone?.isNotEmpty == true)
              'Emergency phone: ${passport.insuranceEmergencyPhone}',
          ],
        ),
        _Section(
          title: 'Emergency contacts',
          icon: Icons.contact_phone_outlined,
          empty: 'No emergency contacts provided',
          items: passport.emergencyContacts
              .map(
                (item) =>
                    '${item.name} • ${item.relationship} • ${item.phoneNumber}',
              )
              .toList(),
        ),
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            'This profile contains patient-reported information and is not medical advice or clinical verification.',
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Future<void> _showHealthQr(BuildContext context) => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Emergency Health ID'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              QrImageView(
                data: 'snakecare://medical-passport/${passport.healthId}',
                size: 220,
                backgroundColor: Colors.white,
              ),
              const SizedBox(height: 12),
              SelectableText(passport.healthId, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Text(
                'The QR contains only your Health ID. Medical information '
                'still requires authorized SnakeCare access.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.empty,
    required this.items,
  });
  final String title;
  final IconData icon;
  final String empty;
  final List<String> items;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon),
                  const SizedBox(width: 10),
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
              const SizedBox(height: 10),
              if (items.isEmpty)
                Text(empty)
              else
                ...items.map(
                  (item) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.circle, size: 8),
                    title: Text(item),
                  ),
                ),
            ],
          ),
        ),
      );
}

class MedicalPassportEditor extends StatefulWidget {
  const MedicalPassportEditor({required this.initial, super.key});
  final MedicalPassport initial;

  @override
  State<MedicalPassportEditor> createState() => _MedicalPassportEditorState();
}

class _MedicalPassportEditorState extends State<MedicalPassportEditor> {
  late final TextEditingController name;
  late final TextEditingController dob;
  late final TextEditingController height;
  late final TextEditingController weight;
  late final TextEditingController language;
  late final TextEditingController insuranceProvider;
  late final TextEditingController insurancePolicy;
  late final TextEditingController insuranceMemberId;
  late final TextEditingController insuranceGroup;
  late final TextEditingController insurancePlan;
  late final TextEditingController insuranceValidThrough;
  late final TextEditingController insurancePhone;
  late String bloodGroup;
  late String sex;
  late bool donor;
  late List<PassportAllergy> allergies;
  late List<PassportCondition> conditions;
  late List<PassportMedication> medications;
  late List<PassportEmergencyContact> contacts;
  late List<PassportSurgery> surgeries;
  late List<PassportFamilyHistory> familyHistory;

  @override
  void initState() {
    super.initState();
    final item = widget.initial;
    name = TextEditingController(text: item.fullName);
    dob = TextEditingController(text: item.dateOfBirth);
    height = TextEditingController(text: item.heightCm?.toString());
    weight = TextEditingController(text: item.weightKg?.toString());
    language = TextEditingController(text: item.preferredLanguage);
    insuranceProvider = TextEditingController(text: item.insuranceProvider);
    insurancePolicy = TextEditingController(text: item.insurancePolicyNumber);
    insuranceMemberId = TextEditingController(text: item.insuranceMemberId);
    insuranceGroup = TextEditingController(text: item.insuranceGroupNumber);
    insurancePlan = TextEditingController(text: item.insurancePlanName);
    insuranceValidThrough =
        TextEditingController(text: item.insuranceValidThrough);
    insurancePhone = TextEditingController(text: item.insuranceEmergencyPhone);
    bloodGroup = item.bloodGroup;
    sex = item.biologicalSex;
    donor = item.organDonor;
    allergies = [...item.allergies];
    conditions = [...item.conditions];
    medications = [...item.medications];
    contacts = [...item.emergencyContacts];
    surgeries = [...item.surgeries];
    familyHistory = [...item.familyHistory];
  }

  @override
  void dispose() {
    for (final controller in [
      name,
      dob,
      height,
      weight,
      language,
      insuranceProvider,
      insurancePolicy,
      insuranceMemberId,
      insuranceGroup,
      insurancePlan,
      insuranceValidThrough,
      insurancePhone,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Medical Passport'),
        actions: [TextButton(onPressed: _save, child: const Text('SAVE'))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Personal and emergency details'),
          const SizedBox(height: 12),
          TextField(
            controller: name,
            decoration: const InputDecoration(labelText: 'Full name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: dob,
            decoration:
                const InputDecoration(labelText: 'Date of birth (YYYY-MM-DD)'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: bloodGroup,
            decoration: const InputDecoration(labelText: 'Blood group'),
            items: ['unknown', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']
                .map(
                  (value) => DropdownMenuItem(value: value, child: Text(value)),
                )
                .toList(),
            onChanged: (value) => setState(() => bloodGroup = value!),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: sex,
            decoration: const InputDecoration(labelText: 'Biological sex'),
            items: const [
              'not_disclosed',
              'female',
              'male',
              'intersex',
              'unknown',
            ]
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text(value.replaceAll('_', ' ')),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => sex = value!),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: height,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Height (cm)'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: weight,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Weight (kg)'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: language,
            decoration: const InputDecoration(labelText: 'Preferred language'),
          ),
          SwitchListTile(
            value: donor,
            onChanged: (value) => setState(() => donor = value),
            title: const Text('Organ donor'),
          ),
          const SizedBox(height: 16),
          Text(
            'Insurance details',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: insuranceProvider,
            decoration: const InputDecoration(labelText: 'Insurance provider'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: insurancePlan,
            decoration: const InputDecoration(labelText: 'Plan name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: insurancePolicy,
            decoration: const InputDecoration(labelText: 'Policy number'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: insuranceMemberId,
            decoration: const InputDecoration(labelText: 'Member ID'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: insuranceGroup,
            decoration: const InputDecoration(labelText: 'Group number'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: insuranceValidThrough,
            decoration: const InputDecoration(
              labelText: 'Valid through (YYYY-MM-DD)',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: insurancePhone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Insurer emergency phone',
            ),
          ),
          _EditableList(
            title: 'Allergies',
            items: allergies.map((item) => item.allergen).toList(),
            onAdd: _addAllergy,
            onDelete: (index) => setState(() => allergies.removeAt(index)),
          ),
          _EditableList(
            title: 'Conditions',
            items: conditions.map((item) => item.name).toList(),
            onAdd: _addCondition,
            onDelete: (index) => setState(() => conditions.removeAt(index)),
          ),
          _EditableList(
            title: 'Medications',
            items: medications.map((item) => item.name).toList(),
            onAdd: _addMedication,
            onDelete: (index) => setState(() => medications.removeAt(index)),
          ),
          _EditableList(
            title: 'Surgeries',
            items: surgeries.map((item) => item.procedure).toList(),
            onAdd: _addSurgery,
            onDelete: (index) => setState(() => surgeries.removeAt(index)),
          ),
          _EditableList(
            title: 'Family history',
            items: familyHistory
                .map((item) => '${item.relationship} • ${item.condition}')
                .toList(),
            onAdd: _addFamilyHistory,
            onDelete: (index) => setState(() => familyHistory.removeAt(index)),
          ),
          _EditableList(
            title: 'Emergency contacts',
            items: contacts
                .map((item) => '${item.name} • ${item.phoneNumber}')
                .toList(),
            onAdd: _addContact,
            onDelete: (index) => setState(() => contacts.removeAt(index)),
          ),
        ],
      ),
    );
  }

  Future<List<String>?> _fields(String title, List<String> labels) async {
    final controllers = labels.map((_) => TextEditingController()).toList();
    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < labels.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TextField(
                    controller: controllers[i],
                    decoration: InputDecoration(labelText: labels[i]),
                  ),
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
            onPressed: () => Navigator.pop(
              context,
              controllers.map((item) => item.text.trim()).toList(),
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    for (final controller in controllers) {
      controller.dispose();
    }
    return result;
  }

  Future<void> _addAllergy() async {
    final values = await _fields(
      'Add allergy',
      ['Allergen', 'Reaction', 'Severity: mild/moderate/severe/unknown'],
    );
    if (values != null && values[0].isNotEmpty) {
      setState(
        () => allergies.add(
          PassportAllergy(
            allergen: values[0],
            reaction: values[1].isEmpty ? null : values[1],
            severity: {'mild', 'moderate', 'severe'}.contains(values[2])
                ? values[2]
                : 'unknown',
          ),
        ),
      );
    }
  }

  Future<void> _addCondition() async {
    final values = await _fields(
      'Add condition',
      ['Condition name', 'Status: active/resolved/unknown'],
    );
    if (values != null && values[0].isNotEmpty) {
      setState(
        () => conditions.add(
          PassportCondition(
            name: values[0],
            status: {'active', 'resolved'}.contains(values[1])
                ? values[1]
                : 'unknown',
          ),
        ),
      );
    }
  }

  Future<void> _addMedication() async {
    final values = await _fields(
      'Add medication',
      ['Medication name', 'Dosage', 'Frequency', 'Route'],
    );
    if (values != null && values[0].isNotEmpty) {
      setState(
        () => medications.add(
          PassportMedication(
            name: values[0],
            dosage: values[1].isEmpty ? null : values[1],
            frequency: values[2].isEmpty ? null : values[2],
            route: values[3].isEmpty ? null : values[3],
          ),
        ),
      );
    }
  }

  Future<void> _addContact() async {
    final values = await _fields(
      'Add emergency contact',
      ['Name', 'Relationship', 'Phone number'],
    );
    if (values != null && values.every((item) => item.isNotEmpty)) {
      setState(
        () => contacts.add(
          PassportEmergencyContact(
            name: values[0],
            relationship: values[1],
            phoneNumber: values[2],
          ),
        ),
      );
    }
  }

  Future<void> _addSurgery() async {
    final values = await _fields(
      'Add surgery',
      ['Procedure', 'Date (YYYY-MM-DD)', 'Hospital', 'Notes'],
    );
    if (values != null && values[0].isNotEmpty) {
      setState(
        () => surgeries.add(
          PassportSurgery(
            procedure: values[0],
            performedOn: values[1].isEmpty ? null : values[1],
            hospital: values[2].isEmpty ? null : values[2],
            notes: values[3].isEmpty ? null : values[3],
          ),
        ),
      );
    }
  }

  Future<void> _addFamilyHistory() async {
    final values = await _fields(
      'Add family history',
      ['Relationship', 'Disease or condition', 'Notes'],
    );
    if (values != null && values[0].isNotEmpty && values[1].isNotEmpty) {
      setState(
        () => familyHistory.add(
          PassportFamilyHistory(
            relationship: values[0],
            condition: values[1],
            notes: values[2].isEmpty ? null : values[2],
          ),
        ),
      );
    }
  }

  void _save() {
    Navigator.pop(
      context,
      MedicalPassport(
        healthId: widget.initial.healthId,
        version: widget.initial.version,
        fullName: name.text.trim().isEmpty ? null : name.text.trim(),
        dateOfBirth: dob.text.trim().isEmpty ? null : dob.text.trim(),
        biologicalSex: sex,
        bloodGroup: bloodGroup,
        heightCm: double.tryParse(height.text),
        weightKg: double.tryParse(weight.text),
        preferredLanguage:
            language.text.trim().isEmpty ? null : language.text.trim(),
        organDonor: donor,
        insuranceProvider: _optionalText(insuranceProvider),
        insurancePolicyNumber: _optionalText(insurancePolicy),
        insuranceMemberId: _optionalText(insuranceMemberId),
        insuranceGroupNumber: _optionalText(insuranceGroup),
        insurancePlanName: _optionalText(insurancePlan),
        insuranceValidThrough: _optionalText(insuranceValidThrough),
        insuranceEmergencyPhone: _optionalText(insurancePhone),
        allergies: allergies,
        conditions: conditions,
        medications: medications,
        emergencyContacts: contacts,
        surgeries: surgeries,
        familyHistory: familyHistory,
      ),
    );
  }

  String? _optionalText(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }
}

class _EditableList extends StatelessWidget {
  const _EditableList({
    required this.title,
    required this.items,
    required this.onAdd,
    required this.onDelete,
  });
  final String title;
  final List<String> items;
  final VoidCallback onAdd;
  final ValueChanged<int> onDelete;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(top: 16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add_circle),
                    tooltip: 'Add $title',
                  ),
                ],
              ),
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Nothing reported'),
                ),
              for (var i = 0; i < items.length; i++)
                ListTile(
                  title: Text(items[i]),
                  trailing: IconButton(
                    onPressed: () => onDelete(i),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ),
            ],
          ),
        ),
      );
}

class PassportAccessScreen extends ConsumerStatefulWidget {
  const PassportAccessScreen({required this.accessToken, super.key});
  final String accessToken;

  @override
  ConsumerState<PassportAccessScreen> createState() =>
      _PassportAccessScreenState();
}

class _PassportAccessScreenState extends ConsumerState<PassportAccessScreen> {
  late Future<List<PassportAccessGrant>> grants;

  @override
  void initState() {
    super.initState();
    grants = _load();
  }

  Future<List<PassportAccessGrant>> _load() => ref
      .read(medicalPassportRepositoryProvider)
      .listGrants(widget.accessToken);

  void _reload() => setState(() => grants = _load());

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Passport access')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _create,
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('Grant access'),
        ),
        body: FutureBuilder<List<PassportAccessGrant>>(
          future: grants,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final items = snapshot.data!;
            if (items.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No clinicians can access your passport. Access is read-only, time-limited, and revocable.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final grant = items[index];
                final active = grant.revokedAt == null &&
                    DateTime.parse(grant.expiresAt).isAfter(DateTime.now());
                return Card(
                  child: ListTile(
                    leading:
                        Icon(active ? Icons.verified_user : Icons.person_off),
                    title: Text('Clinician ${grant.granteeUserId}'),
                    subtitle: Text(
                      active
                          ? 'Expires ${grant.expiresAt}'
                          : 'Revoked or expired',
                    ),
                    trailing: active
                        ? IconButton(
                            onPressed: () async {
                              await ref
                                  .read(medicalPassportRepositoryProvider)
                                  .revokeAccess(widget.accessToken, grant.id);
                              _reload();
                            },
                            icon: const Icon(Icons.block),
                            tooltip: 'Revoke access',
                          )
                        : null,
                  ),
                );
              },
            );
          },
        ),
      );

  Future<void> _create() async {
    final clinician = TextEditingController();
    final days = TextEditingController(text: '1');
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Grant clinician access'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter the email address of a registered and verified doctor or '
              'hospital administrator.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: clinician,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Clinician email'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: days,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'Access duration (days)'),
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
            child: const Text('Grant read access'),
          ),
        ],
      ),
    );
    if (accepted == true && clinician.text.trim().isNotEmpty) {
      final duration = int.tryParse(days.text) ?? 1;
      try {
        await ref.read(medicalPassportRepositoryProvider).grantAccess(
              widget.accessToken,
              clinician.text.trim(),
              DateTime.now().add(Duration(days: duration.clamp(1, 30))),
            );
        _reload();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Clinician access granted.')),
          );
        }
      } on DioException catch (error) {
        final data = error.response?.data;
        final detail =
            data is Map<String, dynamic> ? data['detail'] as String? : null;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                detail ??
                    'Access was not granted. Confirm that this is a registered '
                        'clinician email.',
              ),
            ),
          );
        }
      }
    }
    clinician.dispose();
    days.dispose();
  }
}

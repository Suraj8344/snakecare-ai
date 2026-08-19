import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snakecare_mobile/src/features/offline_resilience/data/offline_resilience_store.dart';

final appLocaleProvider = NotifierProvider<AppLocaleController, Locale>(
  AppLocaleController.new,
);

class AppLocaleController extends Notifier<Locale> {
  @override
  Locale build() {
    if (!OfflineResilienceStore.isReady) return const Locale('en');
    final code = OfflineResilienceStore.box.get(
      'app_language',
      defaultValue: 'en',
    ) as String;
    return Locale(code);
  }

  Future<void> setLanguage(String code) async {
    if (OfflineResilienceStore.isReady) {
      await OfflineResilienceStore.box.put('app_language', code);
    }
    state = Locale(code);
  }
}

class AppLocalizations {
  const AppLocalizations(this.locale);
  final Locale locale;

  static const supportedLocales = [Locale('en'), Locale('hi'), Locale('mr')];

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations) ??
      const AppLocalizations(Locale('en'));

  String text(String key) =>
      _values[locale.languageCode]?[key] ?? _values['en']![key] ?? key;

  static const delegate = _AppLocalizationsDelegate();

  static const _values = <String, Map<String, String>>{
    'en': {
      'language': 'Language',
      'english': 'English',
      'hindi': 'Hindi',
      'marathi': 'Marathi',
      'patient': 'Patient',
      'doctor': 'Doctor',
      'hospital_authority': 'Hospital authority',
      'government_authority': 'Government authority',
      'patient_portal': 'Patient Care Home',
      'doctor_portal': 'Clinical Access Portal',
      'hospital_portal': 'Hospital Authority Console',
      'government_portal': 'Government Authority Console',
      'interface': 'interface',
      'sign_out': 'Sign out',
      'offline_low_signal': 'Offline & Low-Signal Emergency Center',
      'open_passport': 'Open Medical Passport',
      'medical_passport': 'Medical Passport',
      'edit_passport': 'Edit Medical Passport',
      'manage_access': 'Manage access',
      'medical_reports': 'Medical Reports',
      'find_hospitals': 'Find Hospitals',
      'handoff': '112 Handoff Simulation',
      'system_health': 'System Status & Service Health',
      'manage_users': 'Manage Users & Hospital Staff',
      'hospital_dashboard': 'Hospital Dashboard',
      'review_claims': 'Review Hospital Claims',
      'hospital_restricted': 'Hospital Operations (restricted)',
      'hospital_finder': 'Hospital Finder',
      'find_prepared': 'Find prepared hospitals',
      'pune_registry': 'Pune hospital registry',
      'retry': 'Retry',
      'all_operational': 'All core services operational',
      'api_degraded': 'API online · database check degraded',
      'api_service': 'API service',
      'database_readiness': 'Database readiness',
      'online': 'Online',
      'ready': 'Ready',
      'checking_status': 'Checking service status…',
      'service_unavailable':
          'The service is unavailable. Check your connection and try again.',
      'offline_center': 'Offline Emergency Center',
      'snakebite_emergency': 'Snakebite Emergency',
      'emergency': 'SNAKEBITE EMERGENCY',
      'call_first': 'Call first. The SOS is also saved locally.',
      'call_112': 'Call 112',
      'queue_sos': 'Queue SOS',
      'first_aid': 'Immediate first aid',
      'first_aid_available': 'Available even before you submit',
      'video_title': 'What should you do in this situation?',
      'video_needs_data':
          'Video requires data. Emergency steps remain available offline.',
      'symptoms_now': 'Symptoms now',
      'select_symptoms':
          'Select everything observed. Effects can change quickly.',
      'continue_symptoms': 'Continue to symptom form',
      'assess_save': 'Assess urgency and save',
      'do_not_wait':
          'Do not wait for this form if breathing, consciousness, or bleeding is abnormal.',
      'call_112_now': 'Call 112 now',
      'move_away': 'Move away from the snake. Do not try to catch or kill it.',
      'remove_tight': 'Remove rings, anklets, shoes, and other tight items.',
      'keep_still':
          'Keep the person completely still and support the bitten limb with a splint.',
      'carry_hospital':
          'Carry the person and arrange transport to a health facility immediately.',
      'recovery_position':
          'If vomiting or very drowsy, place the person on their side and monitor breathing.',
      'no_tourniquet': 'No tight tourniquet or tight band.',
      'no_cut': 'Do not cut, burn, wash aggressively, or suck the wound.',
      'no_ice':
          'Do not apply ice, chemicals, electric shock, herbs, or black stones.',
      'no_delay': 'Do not delay transport for home or traditional treatments.',
    },
    'hi': {
      'language': 'भाषा',
      'english': 'अंग्रेज़ी',
      'hindi': 'हिन्दी',
      'marathi': 'मराठी',
      'patient': 'रोगी',
      'doctor': 'चिकित्सक',
      'hospital_authority': 'अस्पताल प्राधिकरण',
      'government_authority': 'सरकारी प्राधिकरण',
      'patient_portal': 'रोगी सेवा गृह',
      'doctor_portal': 'चिकित्सकीय प्रवेश पोर्टल',
      'hospital_portal': 'अस्पताल प्राधिकरण कंसोल',
      'government_portal': 'सरकारी प्राधिकरण कंसोल',
      'interface': 'इंटरफ़ेस',
      'sign_out': 'साइन आउट',
      'offline_low_signal': 'ऑफलाइन और कम-सिग्नल आपातकाल केंद्र',
      'open_passport': 'मेडिकल पासपोर्ट खोलें',
      'medical_passport': 'मेडिकल पासपोर्ट',
      'edit_passport': 'मेडिकल पासपोर्ट संपादित करें',
      'manage_access': 'पहुँच प्रबंधित करें',
      'medical_reports': 'चिकित्सा रिपोर्ट',
      'find_hospitals': 'अस्पताल खोजें',
      'handoff': '112 हैंडऑफ सिमुलेशन',
      'system_health': 'सिस्टम स्थिति और सेवा स्वास्थ्य',
      'manage_users': 'उपयोगकर्ता और अस्पताल कर्मचारी प्रबंधित करें',
      'hospital_dashboard': 'अस्पताल डैशबोर्ड',
      'review_claims': 'अस्पताल दावों की समीक्षा करें',
      'hospital_restricted': 'अस्पताल संचालन (प्रतिबंधित)',
      'hospital_finder': 'अस्पताल खोजक',
      'find_prepared': 'तैयार अस्पताल खोजें',
      'pune_registry': 'पुणे अस्पताल रजिस्ट्री',
      'retry': 'पुनः प्रयास करें',
      'all_operational': 'सभी मुख्य सेवाएँ चालू हैं',
      'api_degraded': 'API चालू · डेटाबेस जाँच बाधित',
      'api_service': 'API सेवा',
      'database_readiness': 'डेटाबेस तत्परता',
      'online': 'ऑनलाइन',
      'ready': 'तैयार',
      'checking_status': 'सेवा स्थिति जाँची जा रही है…',
      'service_unavailable':
          'सेवा उपलब्ध नहीं है। कनेक्शन जाँचें और फिर प्रयास करें।',
      'offline_center': 'ऑफलाइन आपातकाल केंद्र',
      'snakebite_emergency': 'सर्पदंश आपातकाल',
      'emergency': 'सर्पदंश आपातकाल',
      'call_first': 'पहले कॉल करें। SOS स्थानीय रूप से भी सुरक्षित होगा।',
      'call_112': '112 पर कॉल करें',
      'queue_sos': 'SOS सुरक्षित करें',
      'first_aid': 'तत्काल प्राथमिक उपचार',
      'first_aid_available': 'फॉर्म भेजने से पहले भी उपलब्ध',
      'video_title': 'इस स्थिति में क्या करना चाहिए?',
      'video_needs_data':
          'वीडियो के लिए डेटा चाहिए। आपातकालीन निर्देश ऑफलाइन उपलब्ध हैं।',
      'symptoms_now': 'अभी के लक्षण',
      'select_symptoms':
          'जो भी लक्षण दिखें उन्हें चुनें। स्थिति तेजी से बदल सकती है।',
      'continue_symptoms': 'लक्षण फॉर्म पर जाएं',
      'assess_save': 'गंभीरता जांचें और सुरक्षित करें',
      'do_not_wait':
          'सांस, होश या रक्तस्राव असामान्य हो तो यह फॉर्म भरने की प्रतीक्षा न करें।',
      'call_112_now': 'अभी 112 पर कॉल करें',
      'move_away': 'सांप से दूर जाएं। उसे पकड़ने या मारने की कोशिश न करें।',
      'remove_tight': 'अंगूठी, पायल, जूते और कसी हुई वस्तुएं हटा दें।',
      'keep_still':
          'व्यक्ति को बिल्कुल स्थिर रखें और काटे हुए अंग को सहारा दें।',
      'carry_hospital': 'व्यक्ति को उठाकर तुरंत स्वास्थ्य केंद्र ले जाएं।',
      'recovery_position':
          'उल्टी या अधिक उनींदापन हो तो करवट लिटाएं और सांस देखें।',
      'no_tourniquet': 'कसकर पट्टी या टूर्निकेट न बांधें।',
      'no_cut': 'घाव को काटें, जलाएं, जोर से धोएं या चूसें नहीं।',
      'no_ice': 'बर्फ, रसायन, बिजली, जड़ी-बूटी या काला पत्थर न लगाएं।',
      'no_delay':
          'घरेलू या पारंपरिक उपचार के लिए अस्पताल जाने में देरी न करें।',
    },
    'mr': {
      'language': 'भाषा',
      'english': 'इंग्रजी',
      'hindi': 'हिंदी',
      'marathi': 'मराठी',
      'patient': 'रुग्ण',
      'doctor': 'डॉक्टर',
      'hospital_authority': 'रुग्णालय प्राधिकरण',
      'government_authority': 'शासकीय प्राधिकरण',
      'patient_portal': 'रुग्ण सेवा गृह',
      'doctor_portal': 'वैद्यकीय प्रवेश पोर्टल',
      'hospital_portal': 'रुग्णालय प्राधिकरण कन्सोल',
      'government_portal': 'शासकीय प्राधिकरण कन्सोल',
      'interface': 'इंटरफेस',
      'sign_out': 'साइन आउट',
      'offline_low_signal': 'ऑफलाइन आणि कमी-सिग्नल आपत्कालीन केंद्र',
      'open_passport': 'वैद्यकीय पासपोर्ट उघडा',
      'medical_passport': 'वैद्यकीय पासपोर्ट',
      'edit_passport': 'वैद्यकीय पासपोर्ट संपादित करा',
      'manage_access': 'प्रवेश व्यवस्थापित करा',
      'medical_reports': 'वैद्यकीय अहवाल',
      'find_hospitals': 'रुग्णालये शोधा',
      'handoff': '112 हँडऑफ सिम्युलेशन',
      'system_health': 'प्रणाली स्थिती आणि सेवा आरोग्य',
      'manage_users': 'वापरकर्ते आणि रुग्णालय कर्मचारी व्यवस्थापित करा',
      'hospital_dashboard': 'रुग्णालय डॅशबोर्ड',
      'review_claims': 'रुग्णालय दाव्यांचे पुनरावलोकन करा',
      'hospital_restricted': 'रुग्णालय कार्यवाही (प्रतिबंधित)',
      'hospital_finder': 'रुग्णालय शोधक',
      'find_prepared': 'तयार रुग्णालये शोधा',
      'pune_registry': 'पुणे रुग्णालय नोंदणी',
      'retry': 'पुन्हा प्रयत्न करा',
      'all_operational': 'सर्व मुख्य सेवा कार्यरत आहेत',
      'api_degraded': 'API सुरू · डेटाबेस तपासणी बाधित',
      'api_service': 'API सेवा',
      'database_readiness': 'डेटाबेस सज्जता',
      'online': 'ऑनलाइन',
      'ready': 'तयार',
      'checking_status': 'सेवा स्थिती तपासत आहे…',
      'service_unavailable':
          'सेवा उपलब्ध नाही. कनेक्शन तपासा आणि पुन्हा प्रयत्न करा.',
      'offline_center': 'ऑफलाइन आपत्कालीन केंद्र',
      'snakebite_emergency': 'सर्पदंश आपत्काल',
      'emergency': 'सर्पदंश आपत्काल',
      'call_first': 'प्रथम कॉल करा. SOS स्थानिकरीत्या देखील जतन होईल.',
      'call_112': '112 वर कॉल करा',
      'queue_sos': 'SOS जतन करा',
      'first_aid': 'तात्काळ प्रथमोपचार',
      'first_aid_available': 'फॉर्म पाठवण्यापूर्वीही उपलब्ध',
      'video_title': 'या परिस्थितीत काय करावे?',
      'video_needs_data':
          'व्हिडिओसाठी डेटा आवश्यक आहे. आपत्कालीन सूचना ऑफलाइन उपलब्ध आहेत.',
      'symptoms_now': 'सध्याची लक्षणे',
      'select_symptoms': 'दिसणारी सर्व लक्षणे निवडा. स्थिती पटकन बदलू शकते.',
      'continue_symptoms': 'लक्षणांच्या फॉर्मवर जा',
      'assess_save': 'गंभीरता तपासा आणि जतन करा',
      'do_not_wait':
          'श्वास, शुद्ध किंवा रक्तस्राव असामान्य असल्यास हा फॉर्म भरण्याची वाट पाहू नका.',
      'call_112_now': 'आता 112 वर कॉल करा',
      'move_away':
          'सापापासून दूर जा. त्याला पकडण्याचा किंवा मारण्याचा प्रयत्न करू नका.',
      'remove_tight': 'अंगठ्या, पैंजण, बूट आणि घट्ट वस्तू काढा.',
      'keep_still':
          'व्यक्तीला पूर्ण स्थिर ठेवा आणि चावलेल्या अवयवाला आधार द्या.',
      'carry_hospital': 'व्यक्तीला उचलून त्वरित आरोग्य केंद्रात न्या.',
      'recovery_position':
          'उलटी किंवा जास्त गुंगी असल्यास कुशीवर झोपवा आणि श्वास तपासा.',
      'no_tourniquet': 'घट्ट टूर्निकेट किंवा पट्टी बांधू नका.',
      'no_cut': 'जखम कापू, जाळू, जोरात धुवू किंवा चोखू नका.',
      'no_ice':
          'बर्फ, रसायने, विजेचा धक्का, औषधी वनस्पती किंवा काळा दगड वापरू नका.',
      'no_delay':
          'घरगुती किंवा पारंपरिक उपचारासाठी रुग्णालयात जाण्यास विलंब करू नका.',
    },
  };
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales.any(
        (item) => item.languageCode == locale.languageCode,
      );

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

extension LocalizedBuildContext on BuildContext {
  String tr(String key) => AppLocalizations.of(this).text(key);
}

class LanguageMenu extends ConsumerWidget {
  const LanguageMenu({super.key, this.offset = Offset.zero});

  final Offset offset;

  @override
  Widget build(BuildContext context, WidgetRef ref) => PopupMenuButton<String>(
        tooltip: context.tr('language'),
        icon: const Icon(Icons.language),
        offset: offset,
        initialValue: ref.watch(appLocaleProvider).languageCode,
        onSelected: ref.read(appLocaleProvider.notifier).setLanguage,
        itemBuilder: (context) => [
          PopupMenuItem(value: 'en', child: Text(context.tr('english'))),
          PopupMenuItem(value: 'hi', child: Text(context.tr('hindi'))),
          PopupMenuItem(value: 'mr', child: Text(context.tr('marathi'))),
        ],
      );
}

class GlobalLanguageButton extends ConsumerStatefulWidget {
  const GlobalLanguageButton({super.key});

  @override
  ConsumerState<GlobalLanguageButton> createState() =>
      _GlobalLanguageButtonState();
}

class _GlobalLanguageButtonState extends ConsumerState<GlobalLanguageButton> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (expanded)
            Material(
              elevation: 5,
              borderRadius: BorderRadius.circular(24),
              color: Theme.of(context).colorScheme.surface,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () => _selectLanguage('en'),
                      child: const Text('EN'),
                    ),
                    TextButton(
                      onPressed: () => _selectLanguage('hi'),
                      child: const Text('हिं'),
                    ),
                    TextButton(
                      onPressed: () => _selectLanguage('mr'),
                      child: const Text('मर'),
                    ),
                  ],
                ),
              ),
            ),
          if (expanded) const SizedBox(width: 8),
          Material(
            elevation: 5,
            color: Theme.of(context).colorScheme.primary,
            shape: const CircleBorder(),
            child: Semantics(
              button: true,
              label: context.tr('language'),
              child: IconButton(
                color: Theme.of(context).colorScheme.onPrimary,
                icon: Icon(expanded ? Icons.close : Icons.language),
                onPressed: () => setState(() => expanded = !expanded),
              ),
            ),
          ),
        ],
      );

  Future<void> _selectLanguage(String code) async {
    await ref.read(appLocaleProvider.notifier).setLanguage(code);
    if (mounted) setState(() => expanded = false);
  }
}

class EmergencyHandoff {
  const EmergencyHandoff({
    required this.id,
    required this.emergencyId,
    required this.simulationOnly,
    required this.status,
    required this.responseStatus,
    required this.countdownSeconds,
    required this.structuredSummary,
  });

  factory EmergencyHandoff.fromJson(Map<String, dynamic> json) =>
      EmergencyHandoff(
        id: json['id'] as String,
        emergencyId: json['emergency_id'] as String,
        simulationOnly: json['simulation_only'] as bool,
        status: json['status'] as String,
        responseStatus: json['response_status'] as String,
        countdownSeconds: json['countdown_seconds'] as int,
        structuredSummary:
            Map<String, dynamic>.from(json['structured_summary'] as Map),
      );

  final String id;
  final String emergencyId;
  final bool simulationOnly;
  final String status;
  final String responseStatus;
  final int countdownSeconds;
  final Map<String, dynamic> structuredSummary;
}

class SimulatedOperatorAnswer {
  const SimulatedOperatorAnswer({
    required this.question,
    required this.answer,
    required this.source,
    required this.missing,
    required this.simulationOnly,
  });

  factory SimulatedOperatorAnswer.fromJson(Map<String, dynamic> json) =>
      SimulatedOperatorAnswer(
        question: json['question'] as String,
        answer: json['answer'] as String,
        source: json['source'] as String,
        missing: json['missing'] as bool,
        simulationOnly: json['simulation_only'] as bool,
      );

  final String question;
  final String answer;
  final String source;
  final bool missing;
  final bool simulationOnly;
}

class VoiceAssistantAnswer extends SimulatedOperatorAnswer {
  const VoiceAssistantAnswer({
    required super.question,
    required super.answer,
    required super.source,
    required super.missing,
    required super.simulationOnly,
    required this.confidence,
    required this.model,
    this.audioBase64,
    this.audioMimeType,
    this.audioModel,
  });

  factory VoiceAssistantAnswer.fromJson(Map<String, dynamic> json) =>
      VoiceAssistantAnswer(
        question: json['question'] as String,
        answer: json['answer'] as String,
        source: json['source'] as String,
        missing: json['missing'] as bool,
        simulationOnly: json['simulation_only'] as bool,
        confidence: (json['confidence'] as num).toDouble(),
        model: json['model'] as String,
        audioBase64: json['audio_base64'] as String?,
        audioMimeType: json['audio_mime_type'] as String?,
        audioModel: json['audio_model'] as String?,
      );

  final double confidence;
  final String model;
  final String? audioBase64;
  final String? audioMimeType;
  final String? audioModel;
}

const operatorQuestions = <String, String>{
  'identity': 'What is the patient name?',
  'location': 'Where is the emergency?',
  'symptoms': 'What symptoms are present?',
  'incident_time': 'When did it happen?',
  'consciousness': 'Is the patient conscious?',
  'allergies': 'Does the patient have allergies?',
  'medicines': 'What medicines do they take?',
  'callback': 'What is the callback number?',
  'emergency_contact': 'Who is the emergency contact?',
  'language': 'What language does the patient prefer?',
};

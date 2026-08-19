class SnakebiteAssessment {
  SnakebiteAssessment({
    required this.id,
    required this.urgency,
    required this.symptoms,
    required this.explanation,
    required this.immediateActions,
    required this.firstAidSteps,
    required this.actionsToAvoid,
    required this.rulesetVersion,
    required this.guidanceVersion,
    required this.assessmentNotice,
    required this.photoAvailable,
    this.latitude,
    this.longitude,
  });

  factory SnakebiteAssessment.fromJson(Map<String, dynamic> json) =>
      SnakebiteAssessment(
        id: json['id'] as String,
        urgency: json['urgency'] as String,
        symptoms: List<String>.from(json['symptoms'] as List),
        explanation: List<String>.from(json['explanation'] as List),
        immediateActions: List<String>.from(json['immediate_actions'] as List),
        firstAidSteps: List<String>.from(json['first_aid_steps'] as List),
        actionsToAvoid: List<String>.from(json['actions_to_avoid'] as List),
        rulesetVersion: json['ruleset_version'] as String,
        guidanceVersion: json['guidance_version'] as String,
        assessmentNotice: json['assessment_notice'] as String,
        photoAvailable: json['photo_available'] as bool,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
      );

  final String id;
  final String urgency;
  final List<String> symptoms;
  final List<String> explanation;
  final List<String> immediateActions;
  final List<String> firstAidSteps;
  final List<String> actionsToAvoid;
  final String rulesetVersion;
  final String guidanceVersion;
  final String assessmentNotice;
  final bool photoAvailable;
  final double? latitude;
  final double? longitude;

  String get displayUrgency => switch (urgency) {
        'critical' => 'Critical danger signs',
        'high_risk' => 'High-risk warning signs',
        _ => 'Urgent clinical assessment',
      };
}

const symptomLabels = <String, String>{
  'breathing_difficulty': 'Breathing difficulty',
  'drooping_eyelids': 'Drooping eyelids',
  'blurred_or_double_vision': 'Blurred or double vision',
  'difficulty_speaking_or_swallowing': 'Difficulty speaking or swallowing',
  'weakness_or_paralysis': 'Weakness or paralysis',
  'drowsiness_or_confusion': 'Drowsiness or confusion',
  'collapse_or_seizure': 'Collapse or seizure',
  'spontaneous_bleeding': 'Unexpected bleeding',
  'rapidly_spreading_swelling': 'Rapidly spreading swelling',
  'severe_local_pain': 'Severe pain at bite',
  'repeated_vomiting': 'Repeated vomiting',
  'dark_urine': 'Dark urine',
  'reduced_urine': 'Reduced urine',
  'abdominal_pain': 'Abdominal pain',
  'none_observed': 'No listed symptom observed',
};

class Goal {
  final String id;
  final String name;
  final double targetAmount;
  final double savedAmount;
  final DateTime targetDate;
  final bool isCompleted;

  Goal({
    required this.id,
    required this.name,
    required this.targetAmount,
    required this.savedAmount,
    required this.targetDate,
    this.isCompleted = false,
  });

  double get progress => targetAmount > 0 ? savedAmount / targetAmount : 0.0;
  double get remaining => (targetAmount - savedAmount).clamp(0.0, double.infinity);

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'targetAmount': targetAmount,
    'savedAmount': savedAmount,
    'targetDate': targetDate.toIso8601String(),
    'isCompleted': isCompleted,
  };

  factory Goal.fromJson(Map<String, dynamic> json) => Goal(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    targetAmount: (json['targetAmount'] ?? 0).toDouble(),
    savedAmount: (json['savedAmount'] ?? 0).toDouble(),
    targetDate: DateTime.parse(json['targetDate'] ?? DateTime.now().toIso8601String()),
    isCompleted: json['isCompleted'] ?? false,
  );

  Goal copyWith({
    String? id,
    String? name,
    double? targetAmount,
    double? savedAmount,
    DateTime? targetDate,
    bool? isCompleted,
  }) => Goal(
    id: id ?? this.id,
    name: name ?? this.name,
    targetAmount: targetAmount ?? this.targetAmount,
    savedAmount: savedAmount ?? this.savedAmount,
    targetDate: targetDate ?? this.targetDate,
    isCompleted: isCompleted ?? this.isCompleted,
  );
}

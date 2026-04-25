class Badge {
  final String id;
  final String title;
  final String description;
  final String icon;
  final int points;
  final bool unlocked;

  Badge({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.points,
    this.unlocked = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'icon': icon,
    'points': points,
    'unlocked': unlocked,
  };

  factory Badge.fromJson(Map<String, dynamic> json) => Badge(
    id: json['id'] ?? '',
    title: json['title'] ?? '',
    description: json['description'] ?? '',
    icon: json['icon'] ?? 'star',
    points: json['points'] ?? 0,
    unlocked: json['unlocked'] ?? false,
  );
  
  // Predefined badges
  static List<Badge> predefined = [
    Badge(id: 'first_goal', title: 'First Goal Created', description: 'Created your first savings goal', icon: 'emoji_events', points: 10),
    Badge(id: 'goal_complete', title: 'First Goal Completed', description: 'Reached 100% on a savings goal', icon: 'celebration', points: 50),
    Badge(id: 'three_goals', title: '3 Goals Added', description: 'Added 3 savings goals', icon: 'flag', points: 20),
    Badge(id: 'bank_connect', title: 'First Bank Connected', description: 'Linked your first bank account', icon: 'account_balance', points: 30),
    Badge(id: 'five_tx', title: '5 Transactions Added', description: 'Added or synced 5 transactions', icon: 'receipt', points: 20),
    Badge(id: 'ten_tx', title: '10 Transactions Added', description: 'Added or synced 10 transactions', icon: 'receipt_long', points: 30),
    Badge(id: 'categories', title: 'Category Explorer', description: 'Visited categories page first time', icon: 'grid_view', points: 5),
    Badge(id: 'budget_start', title: 'Budget Starter', description: 'Created first budget', icon: 'savings', points: 15),
    Badge(id: 'receipt_save', title: 'Receipt Saver', description: 'Saved a receipt transaction', icon: 'image', points: 15),
    Badge(id: 'savings_champ', title: 'Savings Champion', description: 'Saved towards goals consistently', icon: 'trophy', points: 100),
  ];
}

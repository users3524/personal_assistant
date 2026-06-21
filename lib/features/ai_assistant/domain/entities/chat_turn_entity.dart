class ChatTurnEntity {
  final int? id;
  final String turnDate;
  final String role;
  final String content;
  final bool isOffline;
  final bool consumesCloudTurn;
  final String source;
  final DateTime createdAt;

  const ChatTurnEntity({
    this.id,
    required this.turnDate,
    required this.role,
    required this.content,
    this.isOffline = false,
    this.consumesCloudTurn = false,
    this.source = 'daily_review_chat',
    required this.createdAt,
  });

  ChatTurnEntity copyWith({int? id}) => ChatTurnEntity(
    id: id ?? this.id,
    turnDate: turnDate,
    role: role,
    content: content,
    isOffline: isOffline,
    consumesCloudTurn: consumesCloudTurn,
    source: source,
    createdAt: createdAt,
  );
}

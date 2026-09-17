import 'dart:convert';

enum SyncState {
  SYNCED,
  SYNCING,
  OFFLINE,
}

enum SubscriptionTier {
  STARTER(
    title: "Free Starter",
    badge: "Basic Tier",
    monthlyPrice: "\$0",
    annualPrice: "\$0",
    description: "Standard personal speech notes and on-device recording",
    isPopular: false,
    features: [
      "3 voice notes / day",
      "On-device speech transcription",
      "Local offline storage (SQLite)",
      "Basic text search & tags",
    ],
  ),
  EXECUTIVE_PRO(
    title: "Executive Pro",
    badge: "Most Popular",
    monthlyPrice: "\$19",
    annualPrice: "\$15",
    description: "Full executive voice intelligence, minutes & task extraction",
    isPopular: true,
    features: [
      "Unlimited voice & meeting recordings",
      "Gemini 2.5 Flash live meeting minutes",
      "Automated action item extraction & tasks checklist",
      "Real-time cloud sync across devices",
      "Interactive voice note grounded Q&A chat",
      "High-fidelity waveform audio scrub & playback",
    ],
  ),
  ENTERPRISE_SUITE(
    title: "Enterprise Suite",
    badge: "Maximum Security",
    monthlyPrice: "\$49",
    annualPrice: "\$39",
    description: "Advanced security, SSO/SAML 2.0 & hardware enclave",
    isPopular: false,
    features: [
      "Everything in Executive Pro",
      "SOC2 Type II Certified Zero-Knowledge Vault",
      "Enterprise SSO / SAML 2.0 & Passkey Enclave",
      "Biometric session lock",
      "Multi-speaker diarization & priority AI pipeline",
      "Team knowledge base synchronization",
    ],
  );

  final String title;
  final String badge;
  final String monthlyPrice;
  final String annualPrice;
  final String description;
  final bool isPopular;
  final List<String> features;

  const SubscriptionTier({
    required this.title,
    required this.badge,
    required this.monthlyPrice,
    required this.annualPrice,
    required this.description,
    required this.isPopular,
    required this.features,
  });

  int getPriceCents(bool isAnnual) {
    switch (this) {
      case SubscriptionTier.STARTER:
        return 0;
      case SubscriptionTier.EXECUTIVE_PRO:
        return isAnnual ? 18000 : 1900; // $180/yr ($15/mo) or $19/mo
      case SubscriptionTier.ENTERPRISE_SUITE:
        return isAnnual ? 46800 : 4900; // $468/yr ($39/mo) or $49/mo
    }
  }

  String getPriceDisplay(bool isAnnual) {
    switch (this) {
      case SubscriptionTier.STARTER:
        return "\$0";
      case SubscriptionTier.EXECUTIVE_PRO:
        return isAnnual ? "\$15" : "\$19";
      case SubscriptionTier.ENTERPRISE_SUITE:
        return isAnnual ? "\$39" : "\$49";
    }
  }

  static SubscriptionTier fromName(String? name) {
    switch (name?.toUpperCase()) {
      case 'STARTER':
        return SubscriptionTier.STARTER;
      case 'ENTERPRISE_SUITE':
      case 'ENTERPRISE':
        return SubscriptionTier.ENTERPRISE_SUITE;
      case 'EXECUTIVE_PRO':
      default:
        return SubscriptionTier.EXECUTIVE_PRO;
    }
  }
}

class UserProfile {
  final String id;
  final String name;
  final String email;
  final String? photoUrl;
  final bool isAnonymous;
  final String authProvider;
  final String? supabaseId;
  final String? stripeCustomerId;
  final String subscriptionTierName;
  final int createdAt;

  UserProfile({
    this.id = "guest_user",
    this.name = "Demo User",
    this.email = "user@noteflow.ai",
    this.photoUrl,
    this.isAnonymous = false,
    this.authProvider = "supabase_email",
    this.supabaseId,
    this.stripeCustomerId,
    this.subscriptionTierName = "EXECUTIVE_PRO",
    int? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;

  SubscriptionTier get tier => SubscriptionTier.fromName(subscriptionTierName);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'isAnonymous': isAnonymous ? 1 : 0,
      'authProvider': authProvider,
      'supabaseId': supabaseId,
      'stripeCustomerId': stripeCustomerId,
      'subscriptionTierName': subscriptionTierName,
      'createdAt': createdAt,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      photoUrl: map['photoUrl'],
      isAnonymous: map['isAnonymous'] == 1 || map['isAnonymous'] == true,
      authProvider: map['authProvider'] ?? 'supabase_email',
      supabaseId: map['supabaseId'],
      stripeCustomerId: map['stripeCustomerId'],
      subscriptionTierName: map['subscriptionTierName'] ?? 'EXECUTIVE_PRO',
      createdAt: map['createdAt'] is int ? map['createdAt'] : DateTime.now().millisecondsSinceEpoch,
    );
  }

  UserProfile copyWith({
    String? id,
    String? name,
    String? email,
    String? photoUrl,
    bool? isAnonymous,
    String? authProvider,
    String? supabaseId,
    String? stripeCustomerId,
    String? subscriptionTierName,
    int? createdAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      authProvider: authProvider ?? this.authProvider,
      supabaseId: supabaseId ?? this.supabaseId,
      stripeCustomerId: stripeCustomerId ?? this.stripeCustomerId,
      subscriptionTierName: subscriptionTierName ?? this.subscriptionTierName,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class TranscriptSegment {
  final String speaker;
  final String timestamp;
  final String text;

  TranscriptSegment({
    this.speaker = "Speaker 1",
    this.timestamp = "00:00",
    this.text = "",
  });

  Map<String, dynamic> toMap() {
    return {
      'speaker': speaker,
      'timestamp': timestamp,
      'text': text,
    };
  }

  factory TranscriptSegment.fromMap(Map<String, dynamic> map) {
    return TranscriptSegment(
      speaker: map['speaker'] ?? 'Speaker 1',
      timestamp: map['timestamp'] ?? '00:00',
      text: map['text'] ?? '',
    );
  }
}

class NoteEntity {
  final String id;
  final String userId;
  final String title;
  final String type; // VOICE, MEETING, TEXT, IMPORT
  final String? audioPath;
  final int durationSec;
  final String status; // RECORDING, PROCESSING, TRANSCRIBING, ANALYZING, COMPLETED, ERROR
  final String folder;
  final List<String> tags;
  final String transcriptText;
  final List<TranscriptSegment> transcriptSegments;
  final String summaryShort;
  final String summaryDetailed;
  final List<String> summaryBullets;
  final String meetingMinutes;
  final List<String> decisions;
  final List<String> risks;
  final bool isFavorite;
  final bool isArchived;
  final bool isDeleted;
  final int createdAt;
  final int updatedAt;
  final String syncStatus; // SYNCED, PENDING_PUSH, LOCAL_ONLY

  NoteEntity({
    required this.id,
    required this.userId,
    required this.title,
    this.type = "VOICE",
    this.audioPath,
    this.durationSec = 0,
    this.status = "COMPLETED",
    this.folder = "All",
    this.tags = const [],
    this.transcriptText = "",
    this.transcriptSegments = const [],
    this.summaryShort = "",
    this.summaryDetailed = "",
    this.summaryBullets = const [],
    this.meetingMinutes = "",
    this.decisions = const [],
    this.risks = const [],
    this.isFavorite = false,
    this.isArchived = false,
    this.isDeleted = false,
    int? createdAt,
    int? updatedAt,
    this.syncStatus = "SYNCED",
  })  : createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch,
        updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'type': type,
      'audioPath': audioPath,
      'durationSec': durationSec,
      'status': status,
      'folder': folder,
      'tags': jsonEncode(tags),
      'transcriptText': transcriptText,
      'transcriptSegments': jsonEncode(transcriptSegments.map((s) => s.toMap()).toList()),
      'summaryShort': summaryShort,
      'summaryDetailed': summaryDetailed,
      'summaryBullets': jsonEncode(summaryBullets),
      'meetingMinutes': meetingMinutes,
      'decisions': jsonEncode(decisions),
      'risks': jsonEncode(risks),
      'isFavorite': isFavorite ? 1 : 0,
      'isArchived': isArchived ? 1 : 0,
      'isDeleted': isDeleted ? 1 : 0,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'syncStatus': syncStatus,
    };
  }

  factory NoteEntity.fromMap(Map<String, dynamic> map) {
    List<String> parseStringList(dynamic raw) {
      if (raw == null) return [];
      if (raw is List) return raw.map((e) => e.toString()).toList();
      try {
        final decoded = jsonDecode(raw.toString());
        if (decoded is List) return decoded.map((e) => e.toString()).toList();
      } catch (_) {}
      return [];
    }

    List<TranscriptSegment> parseSegments(dynamic raw) {
      if (raw == null) return [];
      try {
        final decoded = raw is String ? jsonDecode(raw) : raw;
        if (decoded is List) {
          return decoded.map((item) => TranscriptSegment.fromMap(Map<String, dynamic>.from(item))).toList();
        }
      } catch (_) {}
      return [];
    }

    return NoteEntity(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      title: map['title'] ?? 'Untitled Note',
      type: map['type'] ?? 'VOICE',
      audioPath: map['audioPath'],
      durationSec: map['durationSec'] is int ? map['durationSec'] : 0,
      status: map['status'] ?? 'COMPLETED',
      folder: map['folder'] ?? 'All',
      tags: parseStringList(map['tags']),
      transcriptText: map['transcriptText'] ?? '',
      transcriptSegments: parseSegments(map['transcriptSegments']),
      summaryShort: map['summaryShort'] ?? '',
      summaryDetailed: map['summaryDetailed'] ?? '',
      summaryBullets: parseStringList(map['summaryBullets']),
      meetingMinutes: map['meetingMinutes'] ?? '',
      decisions: parseStringList(map['decisions']),
      risks: parseStringList(map['risks']),
      isFavorite: map['isFavorite'] == 1 || map['isFavorite'] == true,
      isArchived: map['isArchived'] == 1 || map['isArchived'] == true,
      isDeleted: map['isDeleted'] == 1 || map['isDeleted'] == true,
      createdAt: map['createdAt'] is int ? map['createdAt'] : DateTime.now().millisecondsSinceEpoch,
      updatedAt: map['updatedAt'] is int ? map['updatedAt'] : DateTime.now().millisecondsSinceEpoch,
      syncStatus: map['syncStatus'] ?? 'SYNCED',
    );
  }

  NoteEntity copyWith({
    String? id,
    String? userId,
    String? title,
    String? type,
    String? audioPath,
    int? durationSec,
    String? status,
    String? folder,
    List<String>? tags,
    String? transcriptText,
    List<TranscriptSegment>? transcriptSegments,
    String? summaryShort,
    String? summaryDetailed,
    List<String>? summaryBullets,
    String? meetingMinutes,
    List<String>? decisions,
    List<String>? risks,
    bool? isFavorite,
    bool? isArchived,
    bool? isDeleted,
    int? createdAt,
    int? updatedAt,
    String? syncStatus,
  }) {
    return NoteEntity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      type: type ?? this.type,
      audioPath: audioPath ?? this.audioPath,
      durationSec: durationSec ?? this.durationSec,
      status: status ?? this.status,
      folder: folder ?? this.folder,
      tags: tags ?? this.tags,
      transcriptText: transcriptText ?? this.transcriptText,
      transcriptSegments: transcriptSegments ?? this.transcriptSegments,
      summaryShort: summaryShort ?? this.summaryShort,
      summaryDetailed: summaryDetailed ?? this.summaryDetailed,
      summaryBullets: summaryBullets ?? this.summaryBullets,
      meetingMinutes: meetingMinutes ?? this.meetingMinutes,
      decisions: decisions ?? this.decisions,
      risks: risks ?? this.risks,
      isFavorite: isFavorite ?? this.isFavorite,
      isArchived: isArchived ?? this.isArchived,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}

class ActionItemEntity {
  final String id;
  final String noteId;
  final String userId;
  final String task;
  final String owner;
  final String dueDate;
  final bool isCompleted;
  final int createdAt;
  final int updatedAt;
  final String syncStatus;

  ActionItemEntity({
    required this.id,
    required this.noteId,
    required this.userId,
    required this.task,
    this.owner = "Unassigned",
    this.dueDate = "",
    this.isCompleted = false,
    int? createdAt,
    int? updatedAt,
    this.syncStatus = "SYNCED",
  })  : createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch,
        updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'noteId': noteId,
      'userId': userId,
      'task': task,
      'owner': owner,
      'dueDate': dueDate,
      'isCompleted': isCompleted ? 1 : 0,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'syncStatus': syncStatus,
    };
  }

  factory ActionItemEntity.fromMap(Map<String, dynamic> map) {
    return ActionItemEntity(
      id: map['id'] ?? '',
      noteId: map['noteId'] ?? '',
      userId: map['userId'] ?? '',
      task: map['task'] ?? '',
      owner: map['owner'] ?? 'Unassigned',
      dueDate: map['dueDate'] ?? '',
      isCompleted: map['isCompleted'] == 1 || map['isCompleted'] == true,
      createdAt: map['createdAt'] is int ? map['createdAt'] : DateTime.now().millisecondsSinceEpoch,
      updatedAt: map['updatedAt'] is int ? map['updatedAt'] : DateTime.now().millisecondsSinceEpoch,
      syncStatus: map['syncStatus'] ?? 'SYNCED',
    );
  }

  ActionItemEntity copyWith({
    String? id,
    String? noteId,
    String? userId,
    String? task,
    String? owner,
    String? dueDate,
    bool? isCompleted,
    int? createdAt,
    int? updatedAt,
    String? syncStatus,
  }) {
    return ActionItemEntity(
      id: id ?? this.id,
      noteId: noteId ?? this.noteId,
      userId: userId ?? this.userId,
      task: task ?? this.task,
      owner: owner ?? this.owner,
      dueDate: dueDate ?? this.dueDate,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}

class FolderEntity {
  final String id;
  final String userId;
  final String name;
  final String colorHex;
  final int createdAt;

  FolderEntity({
    required this.id,
    required this.userId,
    required this.name,
    this.colorHex = "#2563EB",
    int? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'colorHex': colorHex,
      'createdAt': createdAt,
    };
  }

  factory FolderEntity.fromMap(Map<String, dynamic> map) {
    return FolderEntity(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      colorHex: map['colorHex'] ?? '#2563EB',
      createdAt: map['createdAt'] is int ? map['createdAt'] : DateTime.now().millisecondsSinceEpoch,
    );
  }
}

class EmailActivityRecord {
  final String id;
  final String noteId;
  final String userId;
  final String recipients;
  final String contentType;
  final String subject;
  final int sentAt;

  EmailActivityRecord({
    required this.id,
    required this.noteId,
    required this.userId,
    required this.recipients,
    required this.contentType,
    required this.subject,
    int? sentAt,
  }) : sentAt = sentAt ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'noteId': noteId,
      'userId': userId,
      'recipients': recipients,
      'contentType': contentType,
      'subject': subject,
      'sentAt': sentAt,
    };
  }

  factory EmailActivityRecord.fromMap(Map<String, dynamic> map) {
    return EmailActivityRecord(
      id: map['id'] ?? '',
      noteId: map['noteId'] ?? '',
      userId: map['userId'] ?? '',
      recipients: map['recipients'] ?? '',
      contentType: map['contentType'] ?? '',
      subject: map['subject'] ?? '',
      sentAt: map['sentAt'] is int ? map['sentAt'] : DateTime.now().millisecondsSinceEpoch,
    );
  }
}

class StripePaymentReceipt {
  final String paymentIntentId;
  final String customerEmail;
  final String amountPaidFormatted;
  final String currency;
  final String cardBrand;
  final String cardLast4;
  final String tierTitle;
  final String billingCycle;
  final int timestamp;
  final String status;
  final String? receiptUrl;

  StripePaymentReceipt({
    required this.paymentIntentId,
    required this.customerEmail,
    required this.amountPaidFormatted,
    this.currency = "USD",
    required this.cardBrand,
    required this.cardLast4,
    required this.tierTitle,
    required this.billingCycle,
    int? timestamp,
    this.status = "succeeded",
    this.receiptUrl,
  }) : timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toMap() {
    return {
      'paymentIntentId': paymentIntentId,
      'customerEmail': customerEmail,
      'amountPaidFormatted': amountPaidFormatted,
      'currency': currency,
      'cardBrand': cardBrand,
      'cardLast4': cardLast4,
      'tierTitle': tierTitle,
      'billingCycle': billingCycle,
      'timestamp': timestamp,
      'status': status,
      'receiptUrl': receiptUrl,
    };
  }

  factory StripePaymentReceipt.fromMap(Map<String, dynamic> map) {
    return StripePaymentReceipt(
      paymentIntentId: map['paymentIntentId'] ?? '',
      customerEmail: map['customerEmail'] ?? '',
      amountPaidFormatted: map['amountPaidFormatted'] ?? '',
      currency: map['currency'] ?? 'USD',
      cardBrand: map['cardBrand'] ?? 'Visa',
      cardLast4: map['cardLast4'] ?? '4242',
      tierTitle: map['tierTitle'] ?? 'Executive Pro',
      billingCycle: map['billingCycle'] ?? 'Billed annually',
      timestamp: map['timestamp'] is int ? map['timestamp'] : DateTime.now().millisecondsSinceEpoch,
      status: map['status'] ?? 'succeeded',
      receiptUrl: map['receiptUrl'],
    );
  }
}

enum StripeCardBrand {
  VISA("Visa"),
  MASTERCARD("Mastercard"),
  AMEX("American Express"),
  DISCOVER("Discover"),
  UNKNOWN("Card");

  final String displayName;
  const StripeCardBrand(this.displayName);
}

class StripeCardInput {
  final String cardNumber;
  final String expMonth;
  final String expYear;
  final String cvc;
  final String cardholderName;
  final String postalCode;

  StripeCardInput({
    this.cardNumber = "",
    this.expMonth = "",
    this.expYear = "",
    this.cvc = "",
    this.cardholderName = "",
    this.postalCode = "",
  });

  StripeCardBrand get brand {
    final clean = cardNumber.replaceAll(" ", "");
    if (clean.startsWith("4")) return StripeCardBrand.VISA;
    if (clean.startsWith("51") || clean.startsWith("52") || clean.startsWith("53") ||
        clean.startsWith("54") || clean.startsWith("55") || clean.startsWith("22")) {
      return StripeCardBrand.MASTERCARD;
    }
    if (clean.startsWith("34") || clean.startsWith("37")) return StripeCardBrand.AMEX;
    if (clean.startsWith("6011") || clean.startsWith("65")) return StripeCardBrand.DISCOVER;
    return StripeCardBrand.UNKNOWN;
  }

  bool get isValid {
    final clean = cardNumber.replaceAll(" ", "");
    final monthInt = int.tryParse(expMonth) ?? 0;
    final yearInt = int.tryParse(expYear) ?? 0;
    return clean.length >= 15 && clean.length <= 16 &&
        monthInt >= 1 && monthInt <= 12 &&
        yearInt >= 24 &&
        cvc.length >= 3 && cvc.length <= 4 &&
        cardholderName.trim().isNotEmpty;
  }
}

class NoteAiAnalysis {
  final String summaryShort;
  final String summaryDetailed;
  final List<String> summaryBullets;
  final String meetingMinutes;
  final List<String> decisions;
  final List<String> risks;
  final List<String> suggestedTags;
  final List<ExtractedActionItem> actionItems;

  NoteAiAnalysis({
    required this.summaryShort,
    required this.summaryDetailed,
    required this.summaryBullets,
    required this.meetingMinutes,
    required this.decisions,
    required this.risks,
    required this.suggestedTags,
    required this.actionItems,
  });
}

class ExtractedActionItem {
  final String task;
  final String owner;
  final String dueDate;

  ExtractedActionItem({
    required this.task,
    required this.owner,
    required this.dueDate,
  });
}

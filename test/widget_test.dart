import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:noteflow_ai/main.dart';
import 'package:noteflow_ai/models/models.dart';
import 'package:noteflow_ai/services/ai/ai_parser_helper.dart';
import 'package:noteflow_ai/services/import_service.dart';
import 'package:noteflow_ai/state/auth_provider.dart';
import 'package:noteflow_ai/state/notes_provider.dart';
import 'package:noteflow_ai/ui/screens/auth_screen.dart';

void main() {
  testWidgets('NoteFlow AI smoke test - renders app root and AuthScreen', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => NotesProvider()),
        ],
        child: const NoteFlowApp(),
      ),
    );

    await tester.pump();

    // Verify NoteFlow AI app builds and shows AuthScreen
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(AuthScreen), findsOneWidget);
    expect(find.text("NoteFlow AI"), findsOneWidget);
    expect(find.text("Welcome back"), findsOneWidget);
    expect(find.text("Sign In"), findsWidgets);
  });

  test('SubscriptionTier pricing calculation', () {
    const starter = SubscriptionTier.STARTER;
    expect(starter.getPriceCents(false), 0);
    expect(starter.getPriceCents(true), 0);

    const pro = SubscriptionTier.EXECUTIVE_PRO;
    expect(pro.getPriceCents(false), 1900);
    expect(pro.getPriceCents(true), 18000);
    expect(pro.getPriceDisplay(false), "\$19");
    expect(pro.getPriceDisplay(true), "\$15");

    const enterprise = SubscriptionTier.ENTERPRISE_SUITE;
    expect(enterprise.getPriceCents(false), 4900);
    expect(enterprise.getPriceCents(true), 46800);
  });

  test('StripeCardInput brand detection & validation', () {
    final visa = StripeCardInput(
      cardNumber: "4242 4242 4242 4242",
      expMonth: "12",
      expYear: "28",
      cvc: "123",
      cardholderName: "Elena Vance",
      postalCode: "94103",
    );
    expect(visa.brand, StripeCardBrand.VISA);
    expect(visa.isValid, true);

    final mastercard = StripeCardInput(cardNumber: "5500 0000 0000 0000");
    expect(mastercard.brand, StripeCardBrand.MASTERCARD);

    final amex = StripeCardInput(cardNumber: "3782 8224 6310 005");
    expect(amex.brand, StripeCardBrand.AMEX);
  });

  test('NoteEntity JSON and Map serialization', () {
    final note = NoteEntity(
      id: "test_id_1",
      userId: "user_01",
      title: "Quarterly Board Sync",
      type: "MEETING",
      durationSec: 120,
      tags: ["#board", "#sync"],
      transcriptText: "Meeting underway.",
      transcriptSegments: [
        TranscriptSegment(speaker: "Chair", timestamp: "00:00", text: "Meeting underway.")
      ],
      summaryShort: "Board approved financial plan.",
    );

    final map = note.toMap();
    expect(map['id'], "test_id_1");
    expect(map['title'], "Quarterly Board Sync");
    expect(map['type'], "MEETING");

    final restored = NoteEntity.fromMap(map);
    expect(restored.id, note.id);
    expect(restored.title, note.title);
    expect(restored.transcriptSegments.length, 1);
    expect(restored.transcriptSegments.first.speaker, "Chair");
  });

  test('AiParserHelper parses structured output and preserves Bengali Unicode', () {
    const rawAiOutput = '''
[SHORT_SUMMARY]
আজকের আলোচনা অনুযায়ী নতুন ফিচার সফলভাবে তৈরি হয়েছে।

[DETAILED_SUMMARY]
We reviewed our quarterly delivery roadmap and Bengali localization support.

[BULLET_POINTS]
• Bengali font rendering works smoothly
• SQLite local sync latency is zero

[MEETING_MINUTES]
Meeting Objective: NoteFlow AI Sprint Review.

[DECISIONS]
• Deploy v1.0.1 immediately
• Keep UI minimalist and clean

[ACTION_ITEMS]
- Task: Complete localization testing | Owner: Alex | Due: Tomorrow 5 PM
''';

    final analysis = AiParserHelper.parseAiResponse(rawAiOutput, "Sprint Review");
    expect(analysis.summaryShort.contains("আজকের আলোচনা"), true);
    expect(analysis.summaryBullets.length, 2);
    expect(analysis.decisions.length, 2);
    expect(analysis.actionItems.length, 1);
    expect(analysis.actionItems.first.task, "Complete localization testing");
    expect(analysis.actionItems.first.owner, "Alex");
  });

  test('ImportService validates YouTube & Instagram URLs', () {
    final importService = ImportService.instance;

    expect(importService.isValidYouTubeUrl("https://www.youtube.com/watch?v=dQw4w9WgXcQ"), true);
    expect(importService.isValidYouTubeUrl("https://youtu.be/dQw4w9WgXcQ"), true);
    expect(importService.isValidYouTubeUrl("https://google.com"), false);
    expect(importService.extractYouTubeId("https://youtu.be/dQw4w9WgXcQ"), "dQw4w9WgXcQ");

    expect(importService.isValidInstagramUrl("https://www.instagram.com/reel/C12345/"), true);
    expect(importService.isValidInstagramUrl("https://example.com/post"), false);
  });
}

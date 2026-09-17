import '../../models/models.dart';

class AiParserHelper {
  static NoteAiAnalysis parseAiResponse(String rawText, String title) {
    String shortSummary = "";
    String detailedSummary = "";
    final bullets = <String>[];
    String meetingMinutes = "";
    final decisions = <String>[];
    final risks = <String>[];
    final tags = <String>[];
    final actionItems = <ExtractedActionItem>[];

    String section(String name) {
      if (!rawText.contains(name)) return "";
      final after = rawText.split(name).last;
      final nextSecIndex = after.indexOf("\n[");
      return (nextSecIndex != -1 ? after.substring(0, nextSecIndex) : after).trim();
    }

    shortSummary = section("[SHORT_SUMMARY]");
    detailedSummary = section("[DETAILED_SUMMARY]");
    meetingMinutes = section("[MEETING_MINUTES]");

    // Bullets
    final rawBullets = section("[BULLET_POINTS]");
    for (final line in rawBullets.split("\n")) {
      final clean = line.replaceAll(RegExp(r'^[-*•\d\.\s]+'), '').trim();
      if (clean.isNotEmpty) bullets.add(clean);
    }

    // Decisions
    final rawDecisions = section("[DECISIONS]");
    for (final line in rawDecisions.split("\n")) {
      final clean = line.replaceAll(RegExp(r'^[-*•\d\.\s]+'), '').trim();
      if (clean.isNotEmpty) decisions.add(clean);
    }

    // Risks
    final rawRisks = section("[RISKS]");
    for (final line in rawRisks.split("\n")) {
      final clean = line.replaceAll(RegExp(r'^[-*•\d\.\s]+'), '').trim();
      if (clean.isNotEmpty) risks.add(clean);
    }

    // Tags
    final rawTags = section("[TAGS]");
    for (final tag in rawTags.split(RegExp(r'[,;\n]'))) {
      final clean = tag.replaceAll('#', '').trim();
      if (clean.isNotEmpty) tags.add("#$clean");
    }

    // Action Items
    final rawActions = section("[ACTION_ITEMS]");
    for (final line in rawActions.split("\n")) {
      final clean = line.replaceAll(RegExp(r'^[-*•\s]+'), '').trim();
      if (clean.isNotEmpty) {
        String task = clean;
        String owner = "Unassigned";
        String due = "Pending";

        if (clean.contains("|")) {
          final parts = clean.split("|");
          for (final part in parts) {
            final pTrim = part.trim();
            if (pTrim.toLowerCase().startsWith("task:")) {
              task = pTrim.substring(5).trim();
            } else if (pTrim.toLowerCase().startsWith("owner:")) {
              owner = pTrim.substring(6).trim();
            } else if (pTrim.toLowerCase().startsWith("due:")) {
              due = pTrim.substring(4).trim();
            }
          }
        }
        actionItems.add(ExtractedActionItem(task: task, owner: owner, dueDate: due));
      }
    }

    // Fallbacks if AI didn't format with tags
    if (shortSummary.isEmpty) {
      final lines = rawText.split("\n").where((l) => l.trim().isNotEmpty).toList();
      shortSummary = lines.isNotEmpty ? lines.first : "Notes synthesized by NoteFlow AI.";
    }
    if (detailedSummary.isEmpty) {
      detailedSummary = rawText.trim();
    }
    if (bullets.isEmpty) {
      bullets.add("Reviewed meeting points and captured notes.");
    }

    return NoteAiAnalysis(
      summaryShort: shortSummary,
      summaryDetailed: detailedSummary,
      summaryBullets: bullets,
      meetingMinutes: meetingMinutes.isNotEmpty ? meetingMinutes : detailedSummary,
      decisions: decisions,
      risks: risks,
      suggestedTags: tags.isNotEmpty ? tags : ["#noteflow", "#notes"],
      actionItems: actionItems,
    );
  }

  static String buildSystemPrompt({String? language}) {
    final langInstruction = (language != null && language != "Auto" && language.isNotEmpty)
        ? "Respond in $language language. If the content is in Bengali (বাংলা) or mixed Bengali+English, preserve Bengali Unicode perfectly."
        : "Preserve the original language of the note, including Bengali (বাংলা) or mixed Bengali+English.";

    return '''
You are NoteFlow AI, an intelligent executive note-taking assistant.
$langInstruction

Analyze the content and respond strictly in the following format:
[SHORT_SUMMARY]
A concise, high-impact summary paragraph.

[DETAILED_SUMMARY]
A structured overview of the key concepts and discussions.

[BULLET_POINTS]
• Key point 1
• Key point 2
• Key point 3

[MEETING_MINUTES]
Structured minutes: Meeting Objective, Key Topics, Discussion, and Conclusion.

[DECISIONS]
• Key decision 1
• Key decision 2

[RISKS]
• Risk or consideration 1

[TAGS]
tag1, tag2, tag3

[ACTION_ITEMS]
- Task: Specific task description | Owner: Assigned person or Unassigned | Due: Date or Pending
''';
  }
}

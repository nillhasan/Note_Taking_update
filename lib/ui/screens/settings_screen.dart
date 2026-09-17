import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/local/preferences_service.dart';
import '../../state/auth_provider.dart';
import '../../theme/app_theme.dart';
import 'account_screen.dart';
import 'ai_providers_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final PreferencesService _prefs = PreferencesService.instance;

  bool _isCalendarPromoDismissed = false;
  bool _isCalendarConnected = false;

  // Recording Settings
  String _recordingQuality = "High";
  bool _noiseReduction = true;
  bool _autoProcess = true;
  String _recordingLanguage = "Auto";

  // Notifications
  bool _notifyProcessingComplete = true;
  bool _notifySummaryReady = true;
  bool _notifyTaskReminders = true;
  bool _notifyMeetingReminders = true;

  @override
  void initState() {
    super.initState();
    _loadLocalSettings();
  }

  Future<void> _loadLocalSettings() async {
    final quality = await _prefs.getRecordingQuality();
    final noise = await _prefs.getNoiseReduction();
    final auto = await _prefs.getAutoProcessRecording();
    final lang = await _prefs.getAiLanguage();

    if (mounted) {
      setState(() {
        _recordingQuality = quality;
        _noiseReduction = noise;
        _autoProcess = auto;
        _recordingLanguage = lang;
      });
    }
  }

  void _showCalendarConnectDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.calendar_today_outlined, size: 20, color: AppColors.textPrimary),
            SizedBox(width: 8),
            Text("Google Calendar", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Text(
          _isCalendarConnected
              ? "Google Calendar is currently connected. Meeting reminders are synced with your daily agenda."
              : "Connect your Google Calendar to automatically fetch meeting titles and receive reminders to start recording in one tap.",
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentDark,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _isCalendarConnected = !_isCalendarConnected;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_isCalendarConnected ? "Google Calendar connected." : "Calendar disconnected."),
                ),
              );
            },
            child: Text(_isCalendarConnected ? "Disconnect" : "Connect"),
          ),
        ],
      ),
    );
  }

  void _showRecordingSettingsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Recording Settings", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Quality
              const Text("Audio Quality", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _recordingQuality,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: "Low", child: Text("Low (64 kbps)")),
                      DropdownMenuItem(value: "Medium", child: Text("Medium (128 kbps)")),
                      DropdownMenuItem(value: "High", child: Text("High (192 kbps)")),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() => _recordingQuality = val);
                        setState(() => _recordingQuality = val);
                        _prefs.setRecordingQuality(val);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Language
              const Text("Transcription Language", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _recordingLanguage,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: "Auto", child: Text("Auto-detect")),
                      DropdownMenuItem(value: "en", child: Text("English")),
                      DropdownMenuItem(value: "es", child: Text("Spanish")),
                      DropdownMenuItem(value: "fr", child: Text("French")),
                      DropdownMenuItem(value: "de", child: Text("German")),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() => _recordingLanguage = val);
                        setState(() => _recordingLanguage = val);
                        _prefs.setAiLanguage(val);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Noise Reduction
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text("Noise Reduction", style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
                value: _noiseReduction,
                onChanged: (val) {
                  setModalState(() => _noiseReduction = val);
                  setState(() => _noiseReduction = val);
                  _prefs.setNoiseReduction(val);
                },
              ),

              // Auto Process
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text("Auto-Process Recording", style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
                value: _autoProcess,
                onChanged: (val) {
                  setModalState(() => _autoProcess = val);
                  setState(() => _autoProcess = val);
                  _prefs.setAutoProcessRecording(val);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showNotificationsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Notifications", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text("Processing Complete", style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
                value: _notifyProcessingComplete,
                onChanged: (val) {
                  setModalState(() => _notifyProcessingComplete = val);
                  setState(() => _notifyProcessingComplete = val);
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text("Summary Ready", style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
                value: _notifySummaryReady,
                onChanged: (val) {
                  setModalState(() => _notifySummaryReady = val);
                  setState(() => _notifySummaryReady = val);
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text("Task Reminders", style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
                value: _notifyTaskReminders,
                onChanged: (val) {
                  setModalState(() => _notifyTaskReminders = val);
                  setState(() => _notifyTaskReminders = val);
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text("Meeting Reminders", style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
                value: _notifyMeetingReminders,
                onChanged: (val) {
                  setModalState(() => _notifyMeetingReminders = val);
                  setState(() => _notifyMeetingReminders = val);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showEmailSharingModal() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Email & Sharing", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: const Text(
          "When sharing notes, you can choose between Short Summary, Detailed Summary, Meeting Minutes, or Full Transcript. Email composer uses the standard system mail client.",
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentDark,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Got it"),
          ),
        ],
      ),
    );
  }

  void _showPrivacySecurityModal() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.shield_outlined, size: 20, color: AppColors.textPrimary),
            SizedBox(width: 8),
            Text("Privacy & Security", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: const Text(
          "• Audio recordings and transcripts are encrypted in transit and at rest.\n"
          "• Provider API keys are stored securely on this device.\n"
          "• Row Level Security (RLS) ensures only authenticated users can access their notes.\n"
          "• You can delete your account and associated data at any time.",
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentDark,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("About NoteFlow AI", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("NoteFlow AI — Version 1.0.0 (Build 1)", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            SizedBox(height: 8),
            Text(
              "Clean, modern, and practical note-taking and voice transcription powered by Google Gemini, OpenAI, and Anthropic Claude.",
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentDark,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  void _showSignOutConfirmation(BuildContext context, AuthProvider auth) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Sign Out", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: const Text(
          "Are you sure you want to sign out? Your notes and audio recordings will remain safely synced to your account.",
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentDark,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              Navigator.pop(context);
              await auth.signOut();
            },
            child: const Text("Sign Out"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.currentUser;

    final avatarInitial = user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : "U";

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          "Settings",
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
            // Calendar Promotional / Integration Card (Dismissible)
            if (!_isCalendarPromoDismissed && !_isCalendarConnected) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.calendar_month_outlined, size: 24, color: AppColors.textPrimary),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Connect your calendar",
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            "Get meeting reminders and start recording in one tap",
                            style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.3),
                          ),
                          const SizedBox(height: 10),
                          GestureDetector(
                            onTap: _showCalendarConnectDialog,
                            child: const Text(
                              "Connect Calendar >",
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _isCalendarPromoDismissed = true),
                      child: const Icon(Icons.close, size: 18, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // SECTION: ACCOUNT
            _buildSectionHeader("ACCOUNT"),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: _buildSettingRow(
                icon: Icons.person_outline,
                leadingWidget: CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.cardBorder,
                  child: Text(
                    avatarInitial,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                ),
                title: "Your Account",
                subtitle: user?.email ?? "Not signed in",
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountScreen()));
                },
              ),
            ),
            const SizedBox(height: 24),

            // SECTION: INTEGRATIONS
            _buildSectionHeader("INTEGRATIONS"),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                children: [
                  _buildSettingRow(
                    icon: Icons.calendar_today_outlined,
                    title: "Connect Google Calendar",
                    subtitle: _isCalendarConnected ? "Connected" : null,
                    onTap: _showCalendarConnectDialog,
                  ),
                  const Divider(height: 1, color: AppColors.dividerColor, indent: 52),
                  _buildSettingRow(
                    icon: Icons.mail_outline,
                    title: "Email & Sharing",
                    onTap: _showEmailSharingModal,
                  ),
                  const Divider(height: 1, color: AppColors.dividerColor, indent: 52),
                  _buildSettingRow(
                    icon: Icons.auto_awesome_outlined,
                    title: "AI Providers",
                    subtitle: "Gemini, OpenAI, Claude",
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AiProvidersScreen()));
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // SECTION: APP
            _buildSectionHeader("APP"),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                children: [
                  _buildSettingRow(
                    icon: Icons.notifications_none_outlined,
                    title: "Notifications",
                    onTap: _showNotificationsModal,
                  ),
                  const Divider(height: 1, color: AppColors.dividerColor, indent: 52),
                  _buildSettingRow(
                    icon: Icons.mic_none_outlined,
                    title: "Recording Settings",
                    subtitle: "$_recordingQuality Quality",
                    onTap: _showRecordingSettingsModal,
                  ),
                  const Divider(height: 1, color: AppColors.dividerColor, indent: 52),
                  _buildSettingRow(
                    icon: Icons.folder_outlined,
                    title: "Manage Folders",
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Folders can be managed directly on notes.")),
                      );
                    },
                  ),
                  const Divider(height: 1, color: AppColors.dividerColor, indent: 52),
                  _buildSettingRow(
                    icon: Icons.storage_outlined,
                    title: "Storage Management",
                    subtitle: "Offline SQLite & Cache",
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("All notes and audio recordings are stored locally and synced.")),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // SECTION: DATA
            _buildSectionHeader("DATA"),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                children: [
                  _buildSettingRow(
                    icon: Icons.file_download_outlined,
                    title: "Export Data",
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Export feature exports notes to Markdown format.")),
                      );
                    },
                  ),
                  const Divider(height: 1, color: AppColors.dividerColor, indent: 52),
                  _buildSettingRow(
                    icon: Icons.delete_outline,
                    title: "Recently Deleted",
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Trash is empty.")),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // SECTION: SUPPORT
            _buildSectionHeader("SUPPORT"),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                children: [
                  _buildSettingRow(
                    icon: Icons.help_outline,
                    title: "Support & Feedback",
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Send feedback to support@noteflow.ai")),
                      );
                    },
                  ),
                  const Divider(height: 1, color: AppColors.dividerColor, indent: 52),
                  _buildSettingRow(
                    icon: Icons.shield_outlined,
                    title: "Privacy & Security",
                    onTap: _showPrivacySecurityModal,
                  ),
                  const Divider(height: 1, color: AppColors.dividerColor, indent: 52),
                  _buildSettingRow(
                    icon: Icons.info_outline,
                    title: "About NoteFlow AI",
                    onTap: _showAboutDialog,
                  ),
                  const Divider(height: 1, color: AppColors.dividerColor, indent: 52),
                  _buildSettingRow(
                    icon: Icons.logout,
                    iconColor: AppColors.recordingRed,
                    title: "Sign Out",
                    titleColor: AppColors.recordingRed,
                    showChevron: false,
                    onTap: () => _showSignOutConfirmation(context, auth),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 14, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.textMuted,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildSettingRow({
    required IconData icon,
    Widget? leadingWidget,
    Color? iconColor,
    required String title,
    Color? titleColor,
    String? subtitle,
    bool showChevron = true,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: leadingWidget ?? Icon(icon, size: 22, color: iconColor ?? AppColors.textPrimary),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          color: titleColor ?? AppColors.textPrimary,
        ),
      ),
      subtitle: subtitle != null
          ? Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))
          : null,
      trailing: showChevron
          ? const Icon(Icons.chevron_right, size: 20, color: AppColors.textMuted)
          : null,
      onTap: onTap,
    );
  }
}

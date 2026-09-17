import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../state/auth_provider.dart';
import '../../theme/app_theme.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  void _showEditProfileDialog(BuildContext context, AuthProvider auth) {
    final nameController = TextEditingController(text: auth.currentUser?.name ?? "");
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Edit Profile", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: TextField(
          controller: nameController,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: "Full Name"),
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
              final newName = nameController.text.trim();
              if (newName.isNotEmpty) {
                Navigator.pop(ctx);
                await auth.updateProfileName(newName);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Profile name updated.")),
                  );
                }
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context, AuthProvider auth) {
    final email = auth.currentUser?.email ?? "";
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Change Password", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: Text(
          "We will send a password reset link to your email ($email).",
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
            onPressed: () async {
              Navigator.pop(ctx);
              await auth.sendPasswordReset(email);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Password reset email sent to $email")),
                );
              }
            },
            child: const Text("Send Reset Email"),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context, AuthProvider auth) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "Delete Account",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.recordingRed),
        ),
        content: const Text(
          "Are you sure you want to permanently delete your NoteFlow AI account? All of your saved notes, audio recordings, transcripts, and summaries will be deleted in accordance with data-retention policies. This action cannot be undone.",
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.recordingRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              Navigator.pop(context); // Exit account screen
              await auth.deleteAccount();
            },
            child: const Text("Delete Forever"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.currentUser;

    final createdDateStr = user != null
        ? DateFormat("MMMM d, yyyy").format(DateTime.fromMillisecondsSinceEpoch(user.createdAt))
        : "Unknown";

    String providerLabel = "Email";
    if (user?.authProvider == 'google') {
      providerLabel = "Google";
    } else if (user?.authProvider == 'apple') {
      providerLabel = "Apple ID";
    } else if (user?.authProvider == 'guest') {
      providerLabel = "Guest Workspace";
    }

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
          "Your Account",
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // Profile Card Header
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: AppColors.cardBorder,
                    child: Text(
                      avatarInitial,
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user?.name ?? "User",
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.email ?? "",
                    style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Account Details Card
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                children: [
                  _buildDetailRow("Authentication", providerLabel),
                  const Divider(height: 1, color: AppColors.dividerColor, indent: 16),
                  _buildDetailRow("Member Since", createdDateStr),
                  const Divider(height: 1, color: AppColors.dividerColor, indent: 16),
                  _buildDetailRow("Subscription", user?.tier.title ?? "Starter"),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                children: [
                  ListTile(
                    title: const Text("Edit Profile", style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
                    trailing: const Icon(Icons.chevron_right, size: 20, color: AppColors.textMuted),
                    onTap: () => _showEditProfileDialog(context, auth),
                  ),
                  if (user?.authProvider == 'supabase_email') ...[
                    const Divider(height: 1, color: AppColors.dividerColor, indent: 16),
                    ListTile(
                      title: const Text("Change Password", style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
                      trailing: const Icon(Icons.chevron_right, size: 20, color: AppColors.textMuted),
                      onTap: () => _showChangePasswordDialog(context, auth),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Sign Out Button
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: ListTile(
                title: const Center(
                  child: Text(
                    "Sign Out",
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.textPrimary),
                  ),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await auth.signOut();
                },
              ),
            ),
            const SizedBox(height: 16),

            // Delete Account Button
            Center(
              child: TextButton(
                onPressed: () => _showDeleteAccountDialog(context, auth),
                child: const Text(
                  "Delete Account",
                  style: TextStyle(color: AppColors.recordingRed, fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}

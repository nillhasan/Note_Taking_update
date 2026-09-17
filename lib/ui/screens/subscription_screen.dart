import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/models.dart';
import '../../services/stripe_payment_manager.dart';
import '../../state/auth_provider.dart';
import '../../state/notes_provider.dart';
import '../../theme/app_theme.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  void _openStripeCheckoutSheet(SubscriptionTier tier, bool isAnnual) {
    final cardNumberController = TextEditingController(text: "4242 4242 4242 4242");
    final expController = TextEditingController(text: "12/28");
    final cvcController = TextEditingController(text: "123");
    final nameController = TextEditingController(text: "Elena Vance");
    final zipController = TextEditingController(text: "94103");

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final cardInput = StripeCardInput(
              cardNumber: cardNumberController.text,
              expMonth: expController.text.contains('/') ? expController.text.split('/').first : '12',
              expYear: expController.text.contains('/') ? expController.text.split('/').last : '28',
              cvc: cvcController.text,
              cardholderName: nameController.text,
              postalCode: zipController.text,
            );

            final brand = cardInput.brand;
            final amountCents = tier.getPriceCents(isAnnual);
            final amountFormatted = NumberFormat.currency(symbol: '\$').format(amountCents / 100.0);

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Upgrade to ${tier.title}",
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isAnnual ? "$amountFormatted billed annually" : "$amountFormatted billed monthly",
                              style: const TextStyle(fontSize: 13, color: AppColors.primarySky),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.lock, size: 12, color: AppColors.primarySky),
                              SizedBox(width: 4),
                              Text("Stripe Secure", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primarySky)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Card Number
                    TextField(
                      controller: cardNumberController,
                      keyboardType: TextInputType.number,
                      onChanged: (v) {
                        final formatted = StripePaymentManager.formatCardNumber(v);
                        if (formatted != v) {
                          cardNumberController.value = TextEditingValue(
                            text: formatted,
                            selection: TextSelection.collapsed(offset: formatted.length),
                          );
                        }
                        setModalState(() {});
                      },
                      decoration: InputDecoration(
                        labelText: "Card Number",
                        hintText: "4242 4242 4242 4242",
                        prefixIcon: const Icon(Icons.credit_card, size: 20),
                        suffixIcon: Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Chip(
                            label: Text(brand.displayName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Expiry & CVC
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: expController,
                            keyboardType: TextInputType.datetime,
                            onChanged: (v) {
                              final formatted = StripePaymentManager.formatExpiry(v);
                              if (formatted != v) {
                                expController.value = TextEditingValue(
                                  text: formatted,
                                  selection: TextSelection.collapsed(offset: formatted.length),
                                );
                              }
                              setModalState(() {});
                            },
                            decoration: const InputDecoration(
                              labelText: "Expires (MM/YY)",
                              hintText: "12/28",
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: cvcController,
                            keyboardType: TextInputType.number,
                            maxLength: 4,
                            decoration: const InputDecoration(
                              labelText: "CVC",
                              hintText: "123",
                              counterText: "",
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Cardholder & Zip
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: nameController,
                            decoration: const InputDecoration(
                              labelText: "Cardholder Name",
                              hintText: "Elena Vance",
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: zipController,
                            keyboardType: TextInputType.text,
                            decoration: const InputDecoration(
                              labelText: "Postal Code",
                              hintText: "94103",
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Pay Button
                    Consumer<NotesProvider>(
                      builder: (context, notesProv, child) {
                        return ElevatedButton(
                          onPressed: notesProv.isStripeProcessing
                              ? null
                              : () async {
                                  final auth = Provider.of<AuthProvider>(context, listen: false);
                                  final email = auth.currentUser?.email ?? "elena@enterprise.com";

                                  final receipt = await notesProv.processStripeCheckout(
                                    card: cardInput,
                                    tier: tier,
                                    isAnnual: isAnnual,
                                    customerEmail: email,
                                  );

                                  if (receipt != null && ctx.mounted) {
                                    auth.updateSubscriptionTier(tier);
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text("Subscribed to ${tier.title}! Payment receipt generated."),
                                        backgroundColor: AppColors.accentEmerald,
                                      ),
                                    );
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: notesProv.isStripeProcessing
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Text(
                                  "Confirm & Pay $amountFormatted",
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Encrypted end-to-end via Stripe API. Cancel anytime with one tap.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: AppColors.darkTextMuted),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final notesProvider = Provider.of<NotesProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAnnual = notesProvider.isAnnualBilling;

    final currentTier = authProvider.currentUser?.tier ?? notesProvider.subscriptionTier;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Executive Subscription & Billing"),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Current Plan Header Banner
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: currentTier == SubscriptionTier.ENTERPRISE_SUITE
                        ? [const Color(0xFF4C1D95), AppColors.darkSurface]
                        : (currentTier == SubscriptionTier.EXECUTIVE_PRO
                            ? [const Color(0xFF1E3A8A), AppColors.darkSurface]
                            : [AppColors.darkSurfaceVariant, AppColors.darkSurface]),
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.primarySky.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.workspace_premium, color: AppColors.primarySky, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                currentTier.title,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.accentEmerald.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  "ACTIVE",
                                  style: TextStyle(color: AppColors.accentEmerald, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            currentTier.description,
                            style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Billing cycle toggle
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Monthly",
                        style: TextStyle(
                          fontWeight: !isAnnual ? FontWeight.bold : FontWeight.normal,
                          color: !isAnnual ? AppColors.primarySky : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                          fontSize: 13,
                        ),
                      ),
                      Switch(
                        value: isAnnual,
                        onChanged: (_) => notesProvider.toggleBillingCycle(),
                        activeThumbColor: AppColors.primarySky,
                      ),
                      Row(
                        children: [
                          Text(
                            "Annual",
                            style: TextStyle(
                              fontWeight: isAnnual ? FontWeight.bold : FontWeight.normal,
                              color: isAnnual ? AppColors.primarySky : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.accentEmerald.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              "SAVE 20%",
                              style: TextStyle(color: AppColors.accentEmerald, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Tier Cards
              ...SubscriptionTier.values.map((tier) {
                final isCurrent = tier == currentTier;
                final price = tier.getPriceDisplay(isAnnual);

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: tier.isPopular
                          ? AppColors.primarySky
                          : (isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                      width: tier.isPopular ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(tier.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          if (tier.badge.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: tier.isPopular
                                    ? AppColors.primarySky.withValues(alpha: 0.15)
                                    : (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                tier.badge,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: tier.isPopular ? AppColors.primarySky : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(price, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                          const SizedBox(width: 4),
                          Text("/ month", style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted, fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(tier.description, style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
                      const SizedBox(height: 16),
                      Divider(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                      const SizedBox(height: 12),
                      ...tier.features.map((f) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle, size: 16, color: AppColors.accentEmerald),
                                const SizedBox(width: 10),
                                Expanded(child: Text(f, style: const TextStyle(fontSize: 13))),
                              ],
                            ),
                          )),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isCurrent
                              ? null
                              : () => _openStripeCheckoutSheet(tier, isAnnual),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: tier.isPopular ? AppColors.primarySky : AppColors.primaryBlue,
                            foregroundColor: tier.isPopular ? Colors.black : Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text(
                            isCurrent ? "Current Active Plan" : (tier == SubscriptionTier.STARTER ? "Downgrade" : "Upgrade to ${tier.title}"),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 16),

              // Past Receipts & Invoices
              const Text("Billing History & Receipts", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),
              StreamBuilder<List<StripePaymentReceipt>>(
                stream: notesProvider.stripePaymentManager.receiptsStream,
                initialData: notesProvider.stripePaymentManager.pastReceipts,
                builder: (context, snap) {
                  final receipts = snap.data ?? [];
                  if (receipts.isEmpty) {
                    return const Text("No past billing transactions found.", style: TextStyle(fontSize: 12));
                  }
                  return Column(
                    children: receipts.map((r) {
                      final dateStr = DateFormat("MMM d, yyyy").format(DateTime.fromMillisecondsSinceEpoch(r.timestamp));
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.receipt_long, color: AppColors.primarySky, size: 22),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("${r.tierTitle} (${r.amountPaidFormatted})", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  const SizedBox(height: 2),
                                  Text("${r.cardBrand} •••• ${r.cardLast4}  •  $dateStr", style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted)),
                                ],
                              ),
                            ),
                            TextButton.icon(
                              icon: const Icon(Icons.open_in_new, size: 14),
                              label: const Text("View", style: TextStyle(fontSize: 11)),
                              onPressed: () {
                                if (r.receiptUrl != null) {
                                  launchUrl(Uri.parse(r.receiptUrl!));
                                }
                              },
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

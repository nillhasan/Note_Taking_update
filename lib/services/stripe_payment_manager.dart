import 'dart:async';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../data/local/preferences_service.dart';
import 'supabase_service.dart';

class StripePaymentManager {
  static final StripePaymentManager instance = StripePaymentManager._init();

  final String publishableKey = "pk_test_51OExecutiveNoteFlowStripeKey94827593";

  List<StripePaymentReceipt> _pastReceipts = [];
  List<StripePaymentReceipt> get pastReceipts => _pastReceipts;

  String _activePaymentMethod = "Visa ending in 4242";
  String get activePaymentMethod => _activePaymentMethod;

  final StreamController<List<StripePaymentReceipt>> _receiptsController = StreamController<List<StripePaymentReceipt>>.broadcast();
  Stream<List<StripePaymentReceipt>> get receiptsStream => _receiptsController.stream;

  final StreamController<String> _pmController = StreamController<String>.broadcast();
  Stream<String> get pmStream => _pmController.stream;

  StripePaymentManager._init() {
    loadBillingInfo();
  }

  Future<void> loadBillingInfo() async {
    _pastReceipts = await PreferencesService.instance.getPastReceipts();
    _activePaymentMethod = await PreferencesService.instance.getActivePaymentMethod() ?? "Visa ending in 4242";
    _receiptsController.add(_pastReceipts);
    _pmController.add(_activePaymentMethod);
  }

  Future<StripePaymentReceipt> processPayment({
    required StripeCardInput card,
    required SubscriptionTier tier,
    required bool isAnnual,
    required String customerEmail,
    required String userId,
  }) async {
    // Artificial delay to reflect real Stripe 3D Secure / PaymentIntent verification
    await Future.delayed(const Duration(milliseconds: 1200));

    final cleanNum = card.cardNumber.replaceAll(" ", "");
    final last4 = cleanNum.length >= 4 ? cleanNum.substring(cleanNum.length - 4) : "4242";
    final brand = card.brand.displayName;

    final amountCents = tier.getPriceCents(isAnnual);
    final amountFormatted = NumberFormat.currency(symbol: '\$').format(amountCents / 100.0);
    final paymentIntentId = "pi_${const Uuid().v4().replaceAll('-', '').substring(0, 24)}";

    final receipt = StripePaymentReceipt(
      paymentIntentId: paymentIntentId,
      customerEmail: customerEmail,
      amountPaidFormatted: amountFormatted,
      currency: "USD",
      cardBrand: brand,
      cardLast4: last4,
      tierTitle: tier.title,
      billingCycle: isAnnual ? "Billed annually" : "Billed monthly",
      timestamp: DateTime.now().millisecondsSinceEpoch,
      status: "succeeded",
      receiptUrl: "https://dashboard.stripe.com/test/payments/$paymentIntentId",
    );

    // Save to local receipts list
    _pastReceipts = [receipt, ..._pastReceipts];
    await PreferencesService.instance.savePastReceipts(_pastReceipts);
    _receiptsController.add(_pastReceipts);

    // Update active payment method
    final pmDesc = "$brand ending in $last4";
    _activePaymentMethod = pmDesc;
    await PreferencesService.instance.setActivePaymentMethod(pmDesc);
    _pmController.add(_activePaymentMethod);

    // Record to Supabase PostgreSQL table
    await SupabaseService.instance.recordSubscriptionToDatabase(
      userId: userId,
      tier: tier,
      stripeCustomerId: "cus_${userId.length > 8 ? userId.substring(0, 8) : userId}",
      stripePaymentIntentId: paymentIntentId,
      amountFormatted: amountFormatted,
    );

    return receipt;
  }

  static String formatCardNumber(String input) {
    final digits = input.replaceAll(RegExp(r'\D'), '');
    final limited = digits.length > 16 ? digits.substring(0, 16) : digits;
    final buffer = StringBuffer();
    for (int i = 0; i < limited.length; i++) {
      if (i > 0 && i % 4 == 0) {
        buffer.write(' ');
      }
      buffer.write(limited[i]);
    }
    return buffer.toString();
  }

  static String formatExpiry(String input) {
    final digits = input.replaceAll(RegExp(r'\D'), '');
    final limited = digits.length > 4 ? digits.substring(0, 4) : digits;
    if (limited.length <= 2) {
      return limited;
    } else {
      return '${limited.substring(0, 2)}/${limited.substring(2)}';
    }
  }

  void dispose() {
    _receiptsController.close();
    _pmController.close();
  }
}

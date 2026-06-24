import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../dev/mock_trips.dart';
import '../../../shared/theme.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class WalletData {
  final double balance;
  final double minimumFloat;
  final bool canAcceptRides;
  final List<WalletTx> transactions;

  const WalletData({
    required this.balance,
    required this.minimumFloat,
    required this.canAcceptRides,
    required this.transactions,
  });

  factory WalletData.fromJson(Map<String, dynamic> j, List<dynamic> txList) => WalletData(
        balance: double.parse(j['balance'].toString()),
        minimumFloat: double.parse(j['minimum_float'].toString()),
        canAcceptRides: j['can_accept_rides'] as bool,
        transactions: txList.map((t) => WalletTx.fromJson(t as Map<String, dynamic>)).toList(),
      );
}

class WalletTx {
  final int id;
  final String txType;
  final double amount;
  final String description;
  final DateTime createdAt;

  const WalletTx({
    required this.id,
    required this.txType,
    required this.amount,
    required this.description,
    required this.createdAt,
  });

  factory WalletTx.fromJson(Map<String, dynamic> j) => WalletTx(
        id: j['id'] as int,
        txType: j['transaction_type'] as String? ?? j['tx_type'] as String? ?? '',
        amount: double.parse(j['amount'].toString()),
        description: j['description'] ?? '',
        createdAt: DateTime.parse(j['created_at'] as String),
      );

  bool get isCredit => txType == 'credit';
}

// ── Provider ──────────────────────────────────────────────────────────────────

final walletProvider = FutureProvider<WalletData>((ref) async {
  if (kUseMockData) {
    await Future.delayed(const Duration(milliseconds: 200));
    return WalletData.fromJson(mockWallet, mockWalletTxs);
  }
  final results = await Future.wait([
    ApiClient.dio.get(Endpoints.wallet),
    ApiClient.dio.get(Endpoints.walletTransactions),
  ]);
  final txRaw = results[1].data;
  final txList = txRaw is List ? txRaw : (txRaw['results'] as List? ?? []);
  return WalletData.fromJson(results[0].data as Map<String, dynamic>, txList);
});

// ── Screen ────────────────────────────────────────────────────────────────────

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0D0D0D) : TwamboColors.bg;
    final textColor = isDark ? Colors.white : TwamboColors.textPrimary;
    final walletAsync = ref.watch(walletProvider);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.canPop() ? context.pop() : context.go('/driver'),
                    child: Icon(Icons.arrow_back, color: textColor, size: 22),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    decoration: const BoxDecoration(
                      border: Border(left: BorderSide(color: TwamboColors.primary, width: 4)),
                    ),
                    padding: const EdgeInsets.only(left: 10),
                    child: Text('FLOAT WALLET',
                        style: GoogleFonts.spaceGrotesk(
                            fontSize: 18, fontWeight: FontWeight.w800, color: textColor)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Expanded(
              child: walletAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: TwamboColors.primary)),
                error: (e, _) => Center(
                  child: Text('Could not load wallet', style: GoogleFonts.manrope(color: TwamboColors.textSecondary)),
                ),
                data: (wallet) => RefreshIndicator(
                  color: TwamboColors.primary,
                  onRefresh: () => ref.refresh(walletProvider.future),
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      _BalanceCard(wallet: wallet, isDark: isDark),
                      const SizedBox(height: 12),
                      _TopUpButton(onSuccess: () => ref.invalidate(walletProvider), isDark: isDark),
                      const SizedBox(height: 28),
                      Text('TRANSACTIONS',
                          style: GoogleFonts.spaceGrotesk(
                              fontSize: 10, fontWeight: FontWeight.w800,
                              color: TwamboColors.textSecondary, letterSpacing: 1.6)),
                      const SizedBox(height: 10),
                      if (wallet.transactions.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Center(
                            child: Text('No transactions yet',
                                style: GoogleFonts.manrope(color: TwamboColors.textSecondary)),
                          ),
                        )
                      else
                        ...wallet.transactions.map((tx) => _TxCard(tx: tx, isDark: isDark)),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Balance card ──────────────────────────────────────────────────────────────

class _BalanceCard extends StatelessWidget {
  final WalletData wallet;
  final bool isDark;
  const _BalanceCard({required this.wallet, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final ok = wallet.canAcceptRides;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        border: const Border(left: BorderSide(color: TwamboColors.primary, width: 5)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('BALANCE', style: GoogleFonts.spaceGrotesk(
            fontSize: 9, fontWeight: FontWeight.w800,
            color: TwamboColors.textSecondary, letterSpacing: 1.6)),
        const SizedBox(height: 6),
        Text('K${wallet.balance.toStringAsFixed(2)}',
            style: GoogleFonts.spaceGrotesk(
                fontSize: 40, fontWeight: FontWeight.w800,
                color: ok ? TwamboColors.success : TwamboColors.error)),
        const SizedBox(height: 14),
        Row(children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ok ? TwamboColors.success : TwamboColors.error,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            ok ? 'Ready to accept rides' : 'Low float — top up to go online',
            style: GoogleFonts.manrope(fontSize: 12,
                color: ok ? TwamboColors.success : TwamboColors.error,
                fontWeight: FontWeight.w600),
          ),
        ]),
        const SizedBox(height: 4),
        Text('Minimum float: K${wallet.minimumFloat.toStringAsFixed(0)}',
            style: GoogleFonts.manrope(fontSize: 11, color: TwamboColors.textSecondary)),
      ]),
    );
  }
}

// ── Top-up button + dialog ────────────────────────────────────────────────────

class _TopUpButton extends StatefulWidget {
  final VoidCallback onSuccess;
  final bool isDark;
  const _TopUpButton({required this.onSuccess, required this.isDark});

  @override
  State<_TopUpButton> createState() => _TopUpButtonState();
}

class _TopUpButtonState extends State<_TopUpButton> {
  final _amountCtrl = TextEditingController();
  final _refCtrl    = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _refCtrl.dispose();
    super.dispose();
  }

  void _show() {
    _amountCtrl.clear();
    _refCtrl.clear();
    setState(() => _error = null);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) => _TopUpSheet(
          amountCtrl: _amountCtrl,
          refCtrl: _refCtrl,
          loading: _loading,
          error: _error,
          isDark: widget.isDark,
          onSubmit: () async {
            final amt = double.tryParse(_amountCtrl.text.trim());
            if (amt == null || amt <= 0) {
              setSheet(() => _error = 'Enter a valid amount');
              return;
            }
            setSheet(() { _loading = true; _error = null; });
            try {
              if (kUseMockData) {
                await Future.delayed(const Duration(milliseconds: 500));
                mockWallet['balance'] = ((mockWallet['balance'] as num).toDouble() + amt).toString();
              } else {
                await ApiClient.dio.post(Endpoints.walletTopup, data: {
                  'amount': amt,
                  'reference': _refCtrl.text.trim(),
                });
              }
              if (ctx.mounted) Navigator.pop(ctx);
              widget.onSuccess();
            } catch (_) {
              setSheet(() { _loading = false; _error = 'Top-up failed — try again'; });
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _show,
      child: Container(
        height: 48,
        color: TwamboColors.primary,
        alignment: Alignment.center,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.add, size: 18, color: TwamboColors.textPrimary),
          const SizedBox(width: 8),
          Text('TOP UP FLOAT',
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 11, fontWeight: FontWeight.w800,
                  color: TwamboColors.textPrimary, letterSpacing: 1)),
        ]),
      ),
    );
  }
}

class _TopUpSheet extends StatelessWidget {
  final TextEditingController amountCtrl;
  final TextEditingController refCtrl;
  final bool loading;
  final String? error;
  final bool isDark;
  final VoidCallback onSubmit;

  const _TopUpSheet({
    required this.amountCtrl,
    required this.refCtrl,
    required this.loading,
    required this.error,
    required this.isDark,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final textColor = isDark ? Colors.white : TwamboColors.textPrimary;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        color: bg,
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            decoration: const BoxDecoration(
              border: Border(left: BorderSide(color: TwamboColors.primary, width: 4)),
            ),
            padding: const EdgeInsets.only(left: 12),
            child: Text('TOP UP FLOAT',
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 16, fontWeight: FontWeight.w800, color: textColor)),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Text('Via MTN Mobile Money or Zamtel Kwacha',
                style: GoogleFonts.manrope(fontSize: 12, color: TwamboColors.textSecondary)),
          ),
          const SizedBox(height: 20),
          _Field(label: 'AMOUNT (ZMW)', controller: amountCtrl,
              hint: 'e.g. 100', keyboardType: TextInputType.number, isDark: isDark),
          const SizedBox(height: 12),
          _Field(label: 'TRANSACTION REFERENCE (optional)', controller: refCtrl,
              hint: 'e.g. MTN-TXN-12345', isDark: isDark),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(error!, style: GoogleFonts.manrope(fontSize: 11, color: TwamboColors.error)),
          ],
          const SizedBox(height: 20),
          GestureDetector(
            onTap: loading ? null : onSubmit,
            child: Container(
              height: 48, width: double.infinity,
              color: TwamboColors.primary,
              alignment: Alignment.center,
              child: loading
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: TwamboColors.textPrimary))
                  : Text('CONFIRM TOP-UP',
                      style: GoogleFonts.spaceGrotesk(
                          fontSize: 11, fontWeight: FontWeight.w800,
                          color: TwamboColors.textPrimary, letterSpacing: 1)),
            ),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final TextInputType keyboardType;
  final bool isDark;

  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
    this.keyboardType = TextInputType.text,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : TwamboColors.textPrimary;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: GoogleFonts.spaceGrotesk(
          fontSize: 9, fontWeight: FontWeight.w700,
          color: TwamboColors.textSecondary, letterSpacing: 1.4)),
      const SizedBox(height: 6),
      Container(
        decoration: BoxDecoration(border: Border.all(color: TwamboColors.line)),
        child: TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: GoogleFonts.manrope(fontSize: 14, color: textColor),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.manrope(fontSize: 13, color: TwamboColors.textSecondary),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: InputBorder.none,
          ),
        ),
      ),
    ]);
  }
}

// ── Transaction card ──────────────────────────────────────────────────────────

class _TxCard extends StatelessWidget {
  final WalletTx tx;
  final bool isDark;
  const _TxCard({required this.tx, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final isCredit = tx.isCredit;
    final cardBg = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final textColor = isDark ? Colors.white : TwamboColors.textPrimary;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      color: cardBg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          color: (isCredit ? TwamboColors.success : TwamboColors.error).withValues(alpha: 0.12),
          child: Icon(
            isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
            size: 18,
            color: isCredit ? TwamboColors.success : TwamboColors.error,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tx.description.isNotEmpty ? tx.description : tx.txType.toUpperCase(),
                style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600, color: textColor)),
            Text('${tx.createdAt.day}/${tx.createdAt.month}/${tx.createdAt.year}',
                style: GoogleFonts.manrope(fontSize: 11, color: TwamboColors.textSecondary)),
          ]),
        ),
        Text(
          '${isCredit ? '+' : '-'}K${tx.amount.toStringAsFixed(2)}',
          style: GoogleFonts.spaceGrotesk(
              fontSize: 14, fontWeight: FontWeight.w800,
              color: isCredit ? TwamboColors.success : TwamboColors.error),
        ),
      ]),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../dev/mock_trips.dart';
import '../../../shared/driver_nav_bar.dart';
import '../../../shared/theme.dart';

// ── Data models ───────────────────────────────────────────────────────────────

class _EarningsData {
  final double balance;
  final double minimumFloat;
  final bool canAcceptRides;
  final List<_EarningsTx> transactions;
  final double totalCommission;

  const _EarningsData({
    required this.balance, required this.minimumFloat,
    required this.canAcceptRides, required this.transactions,
    required this.totalCommission,
  });
}

class _EarningsTx {
  final int id;
  final String txType;
  final double amount;
  final String description;
  final DateTime createdAt;
  const _EarningsTx({
    required this.id, required this.txType, required this.amount,
    required this.description, required this.createdAt,
  });
  bool get isCredit => txType == 'credit';

  factory _EarningsTx.fromJson(Map<String, dynamic> j) => _EarningsTx(
        id: j['id'],
        txType: j['tx_type'] ?? j['transaction_type'] ?? 'debit',
        amount: double.parse((j['amount'] ?? '0').toString()),
        description: j['description'] ?? '',
        createdAt: DateTime.parse(j['created_at']),
      );
}

class _OpLog {
  final int id;
  final String logType;
  final String description;
  final double costZmw;
  final String date;
  const _OpLog({required this.id, required this.logType,
      required this.description, required this.costZmw, required this.date});

  factory _OpLog.fromJson(Map<String, dynamic> j) => _OpLog(
        id: j['id'],
        logType: j['log_type'] ?? 'other',
        description: j['description'] ?? '',
        costZmw: double.parse((j['cost_zmw'] ?? '0').toString()),
        date: j['date'] ?? '',
      );
}

class _VehicleHealth {
  final String make;
  final String model;
  final String fuelType;
  final double fuelConsumption;
  final DateTime? lastServiceDate;
  final int serviceIntervalKm;
  final int serviceIntervalMonths;
  final double serviceCostZmw;
  final String adminNotes;
  final double fuelPricePerLitre;
  final String vehicleNotes;

  const _VehicleHealth({
    required this.make, required this.model, required this.fuelType,
    required this.fuelConsumption, this.lastServiceDate,
    required this.serviceIntervalKm, required this.serviceIntervalMonths,
    required this.serviceCostZmw, required this.adminNotes,
    required this.fuelPricePerLitre, required this.vehicleNotes,
  });

  int get daysSinceService {
    if (lastServiceDate == null) return -1;
    return DateTime.now().difference(lastServiceDate!).inDays;
  }

  bool get serviceOverdue {
    if (lastServiceDate == null) return false;
    return daysSinceService >= (serviceIntervalMonths * 30);
  }

  bool get serviceDueSoon {
    if (lastServiceDate == null) return false;
    return daysSinceService >= (serviceIntervalMonths * 30 - 14);
  }
}

class _BudgetData {
  final bool hasEnoughData;
  final double earnings;
  final double estimatedFuelCost;
  final double serviceFund;
  final double loggedCosts;
  final double net;
  final double totalKm;
  final List<String> advice;
  final bool isDismissed;

  const _BudgetData({
    required this.hasEnoughData, required this.earnings,
    required this.estimatedFuelCost, required this.serviceFund,
    required this.loggedCosts, required this.net, required this.totalKm,
    required this.advice, required this.isDismissed,
  });

  factory _BudgetData.fromJson(Map<String, dynamic> j) => _BudgetData(
        hasEnoughData: j['has_enough_data'] as bool? ?? false,
        earnings: double.parse((j['earnings'] ?? '0').toString()),
        estimatedFuelCost: double.parse((j['estimated_fuel_cost'] ?? '0').toString()),
        serviceFund: double.parse((j['service_fund'] ?? '0').toString()),
        loggedCosts: double.parse((j['logged_costs'] ?? '0').toString()),
        net: double.parse((j['net'] ?? '0').toString()),
        totalKm: double.parse((j['total_km'] ?? '0').toString()),
        advice: List<String>.from(j['advice'] ?? []),
        isDismissed: j['is_dismissed'] as bool? ?? false,
      );
}

// ── Providers ─────────────────────────────────────────────────────────────────

final _earningsProvider = FutureProvider<_EarningsData>((ref) async {
  if (kUseMockData) {
    await Future.delayed(const Duration(milliseconds: 300));
    final txs = mockWalletTxs.map<_EarningsTx>((j) => _EarningsTx.fromJson(j)).toList();
    final totalComm = txs
        .where((t) => t.description.contains('commission'))
        .fold<double>(0, (sum, t) => sum + t.amount);
    return _EarningsData(
      balance: double.parse(mockWallet['balance'].toString()),
      minimumFloat: double.parse(mockWallet['minimum_float'].toString()),
      canAcceptRides: mockWallet['can_accept_rides'] as bool,
      transactions: txs,
      totalCommission: totalComm,
    );
  }
  final results = await Future.wait([
    ApiClient.dio.get(Endpoints.wallet),
    ApiClient.dio.get(Endpoints.walletTransactions),
  ]);

  final walletData = results[0].data as Map<String, dynamic>;
  final txRaw = results[1].data is List
      ? results[1].data as List
      : (results[1].data['results'] as List? ?? []);
  final txs = txRaw.map<_EarningsTx>((j) => _EarningsTx.fromJson(j as Map<String, dynamic>)).toList();

  double totalComm = 0;
  try {
    final commResp = await ApiClient.dio.get(Endpoints.commissions);
    final commRaw = commResp.data is List
        ? commResp.data as List
        : (commResp.data['results'] as List? ?? []);
    totalComm = commRaw.fold<double>(
        0, (sum, c) => sum + double.parse(((c as Map)['amount'] ?? '0').toString()));
  } catch (_) {}

  return _EarningsData(
    balance: double.parse((walletData['balance'] ?? '0').toString()),
    minimumFloat: double.parse((walletData['minimum_float'] ?? '10').toString()),
    canAcceptRides: walletData['can_accept_rides'] as bool? ?? true,
    transactions: txs,
    totalCommission: totalComm,
  );
});

final _opLogsProvider = FutureProvider<List<_OpLog>>((ref) async {
  if (kUseMockData) {
    await Future.delayed(const Duration(milliseconds: 150));
    return mockOpLogs.map<_OpLog>((j) => _OpLog.fromJson(j)).toList();
  }
  try {
    final resp = await ApiClient.dio.get(Endpoints.operationalLogs);
    final raw = resp.data is List ? resp.data as List : (resp.data['results'] as List? ?? []);
    return raw.map<_OpLog>((j) => _OpLog.fromJson(j as Map<String, dynamic>)).toList();
  } catch (_) { return []; }
});

final _vehicleHealthProvider = FutureProvider<_VehicleHealth>((ref) async {
  if (kUseMockData) {
    await Future.delayed(const Duration(milliseconds: 150));
    final v = mockVehicle;
    DateTime? lastSvcDate;
    try {
      final s = v['last_service_date'] as String?;
      if (s != null && s.isNotEmpty) lastSvcDate = DateTime.parse(s);
    } catch (_) {}
    return _VehicleHealth(
      make: v['make'] as String,
      model: v['model'] as String,
      fuelType: v['fuel_type'] as String,
      fuelConsumption: double.parse(v['fuel_consumption_l_per_100km'].toString()),
      lastServiceDate: lastSvcDate,
      serviceIntervalKm: v['service_interval_km'] as int,
      serviceIntervalMonths: v['service_interval_months'] as int,
      serviceCostZmw: double.parse(v['estimated_service_cost_zmw'].toString()),
      adminNotes: v['admin_notes'] as String,
      fuelPricePerLitre: double.parse(mockDriverProfile['fuel_price_per_litre'].toString()),
      vehicleNotes: mockDriverProfile['vehicle_notes'] as String,
    );
  }
  final results = await Future.wait([
    ApiClient.dio.get(Endpoints.driverVehicle),
    ApiClient.dio.get(Endpoints.driverProfile),
  ]);
  final v = results[0].data as Map<String, dynamic>;
  final p = results[1].data as Map<String, dynamic>;
  final profile = p['driver_profile'] ?? p;

  DateTime? lastSvcDate;
  try {
    final s = v['last_service_date'] as String?;
    if (s != null && s.isNotEmpty) lastSvcDate = DateTime.parse(s);
  } catch (_) {}

  return _VehicleHealth(
    make: v['make'] ?? '',
    model: v['model'] ?? '',
    fuelType: v['fuel_type'] ?? 'petrol',
    fuelConsumption: double.parse((v['fuel_consumption_l_per_100km'] ?? '10').toString()),
    lastServiceDate: lastSvcDate,
    serviceIntervalKm: (v['service_interval_km'] as num?)?.toInt() ?? 5000,
    serviceIntervalMonths: (v['service_interval_months'] as num?)?.toInt() ?? 3,
    serviceCostZmw: double.parse((v['estimated_service_cost_zmw'] ?? '500').toString()),
    adminNotes: v['admin_notes'] as String? ?? '',
    fuelPricePerLitre: double.parse((profile['fuel_price_per_litre'] ?? '35').toString()),
    vehicleNotes: profile['vehicle_notes'] as String? ?? '',
  );
});

final _budgetProvider = FutureProvider.family<_BudgetData, String>((ref, period) async {
  if (kUseMockData) {
    await Future.delayed(const Duration(milliseconds: 150));
    return _BudgetData.fromJson(mockBudget);
  }
  try {
    final resp = await ApiClient.dio.get(Endpoints.budgetSuggestion, queryParameters: {'period': period});
    return _BudgetData.fromJson(resp.data as Map<String, dynamic>);
  } catch (_) {
    return const _BudgetData(
      hasEnoughData: false, earnings: 0, estimatedFuelCost: 0, serviceFund: 0,
      loggedCosts: 0, net: 0, totalKm: 0, advice: [], isDismissed: false,
    );
  }
});

// ── Screen ────────────────────────────────────────────────────────────────────

class DriverEarningsScreen extends ConsumerStatefulWidget {
  const DriverEarningsScreen({super.key});

  @override
  ConsumerState<DriverEarningsScreen> createState() => _DriverEarningsScreenState();
}

class _DriverEarningsScreenState extends ConsumerState<DriverEarningsScreen> {
  bool _showMonthly = false;
  bool _weeklyDismissed = false;
  bool _monthlyDismissed = false;

  Future<void> _dismissBudget(String period) async {
    try {
      if (!kUseMockData) {
        await ApiClient.dio.post(Endpoints.dismissBudget, data: {'period': period});
      }
    } catch (_) {}
    setState(() {
      if (period == 'weekly') { _weeklyDismissed = true; }
      else { _monthlyDismissed = true; }
    });
  }

  @override
  Widget build(BuildContext context) {
    final earningsAsync = ref.watch(_earningsProvider);
    final opLogsAsync = ref.watch(_opLogsProvider);
    final vehicleAsync = ref.watch(_vehicleHealthProvider);
    final budgetPeriod = _showMonthly ? 'monthly' : 'weekly';
    final budgetAsync = ref.watch(_budgetProvider(budgetPeriod));

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0D0D0D) : TwamboColors.bg;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : TwamboColors.textPrimary;

    final isCurrentlyDismissed = _showMonthly ? _monthlyDismissed : _weeklyDismissed;

    return Scaffold(
      backgroundColor: bg,
      bottomNavigationBar: const DriverNavBar(currentIndex: 3),
      body: SafeArea(
        bottom: false,
        child: earningsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: TwamboColors.primary)),
          error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: TwamboColors.error))),
          data: (data) => RefreshIndicator(
            color: TwamboColors.primary,
            onRefresh: () async {
              ref.invalidate(_earningsProvider);
              ref.invalidate(_opLogsProvider);
              ref.invalidate(_vehicleHealthProvider);
              ref.invalidate(_budgetProvider);
            },
            child: CustomScrollView(
              slivers: [
                // ── Header ─────────────────────────────────────────────────
                SliverToBoxAdapter(child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    border: const Border(left: BorderSide(color: TwamboColors.primary, width: 4)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('EARNINGS', style: GoogleFonts.spaceGrotesk(
                        fontSize: 9, fontWeight: FontWeight.w700,
                        color: TwamboColors.textSecondary, letterSpacing: 2)),
                    Text('Wallet & Financial Health', style: GoogleFonts.spaceGrotesk(
                        fontSize: 18, fontWeight: FontWeight.w800, color: textColor)),
                  ]),
                )),

                const SliverToBoxAdapter(child: SizedBox(height: 12)),

                // ── Float balance card ──────────────────────────────────────
                SliverToBoxAdapter(child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    color: TwamboColors.primary,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('FLOAT BALANCE', style: GoogleFonts.spaceGrotesk(
                          fontSize: 9, fontWeight: FontWeight.w700,
                          color: TwamboColors.textPrimary.withValues(alpha: 0.6), letterSpacing: 2)),
                      const SizedBox(height: 6),
                      Text('K${data.balance.toStringAsFixed(2)}',
                          style: GoogleFonts.spaceGrotesk(
                              fontSize: 36, fontWeight: FontWeight.w800, color: TwamboColors.textPrimary)),
                      const SizedBox(height: 12),
                      Container(height: 1, color: TwamboColors.textPrimary.withValues(alpha: 0.15)),
                      const SizedBox(height: 10),
                      Row(children: [
                        Icon(
                          data.canAcceptRides ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                          size: 16,
                          color: data.canAcceptRides
                              ? TwamboColors.textPrimary.withValues(alpha: 0.8)
                              : TwamboColors.error,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(
                          data.canAcceptRides ? 'Ready to accept rides' : 'Low float — top up to accept rides',
                          style: GoogleFonts.manrope(fontSize: 12,
                              color: data.canAcceptRides
                                  ? TwamboColors.textPrimary.withValues(alpha: 0.8)
                                  : TwamboColors.error),
                        )),
                        Text('Min: K${data.minimumFloat.toStringAsFixed(0)}',
                            style: GoogleFonts.manrope(
                                fontSize: 11, color: TwamboColors.textPrimary.withValues(alpha: 0.6))),
                      ]),
                    ]),
                  ),
                )),

                const SliverToBoxAdapter(child: SizedBox(height: 8)),

                // ── Commission card ─────────────────────────────────────────
                SliverToBoxAdapter(child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: cardBg,
                      border: const Border(left: BorderSide(color: TwamboColors.error, width: 3)),
                    ),
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('COMMISSION DEDUCTED', style: GoogleFonts.spaceGrotesk(
                            fontSize: 9, fontWeight: FontWeight.w700,
                            color: TwamboColors.textSecondary, letterSpacing: 1.5)),
                        const SizedBox(height: 4),
                        Text('K${data.totalCommission.toStringAsFixed(2)}',
                            style: GoogleFonts.spaceGrotesk(
                                fontSize: 22, fontWeight: FontWeight.w800, color: TwamboColors.error)),
                      ])),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        color: TwamboColors.error.withValues(alpha: 0.08),
                        child: Text('10%', style: GoogleFonts.spaceGrotesk(
                            fontSize: 18, fontWeight: FontWeight.w800, color: TwamboColors.error)),
                      ),
                    ]),
                  ),
                )),

                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // ── Operational costs ───────────────────────────────────────
                SliverToBoxAdapter(child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _OpLogsSection(opLogsAsync: opLogsAsync, isDark: isDark, textColor: textColor, cardBg: cardBg),
                )),

                const SliverToBoxAdapter(child: SizedBox(height: 12)),

                // ── Vehicle health ──────────────────────────────────────────
                SliverToBoxAdapter(child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: vehicleAsync.when(
                    loading: () => const SizedBox(),
                    error: (_, __) => const SizedBox(),
                    data: (vh) => _VehicleHealthCard(vehicle: vh, isDark: isDark, textColor: textColor, cardBg: cardBg, ref: ref),
                  ),
                )),

                const SliverToBoxAdapter(child: SizedBox(height: 12)),

                // ── Budget suggestion ───────────────────────────────────────
                SliverToBoxAdapter(child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: budgetAsync.when(
                    loading: () => const SizedBox(),
                    error: (_, __) => const SizedBox(),
                    data: (budget) {
                      if (!budget.hasEnoughData) return const SizedBox();
                      if (isCurrentlyDismissed || budget.isDismissed) return const SizedBox();
                      return _BudgetCard(
                        budget: budget,
                        showMonthly: _showMonthly,
                        isDark: isDark,
                        textColor: textColor,
                        onTogglePeriod: () => setState(() => _showMonthly = !_showMonthly),
                        onDismiss: () => _dismissBudget(budgetPeriod),
                      );
                    },
                  ),
                )),

                const SliverToBoxAdapter(child: SizedBox(height: 20)),

                // ── Transactions header ─────────────────────────────────────
                SliverToBoxAdapter(child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    'TRANSACTIONS (${data.transactions.length})',
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 9, fontWeight: FontWeight.w800,
                        color: TwamboColors.textSecondary, letterSpacing: 2),
                  ),
                )),

                // ── Transaction list ────────────────────────────────────────
                if (data.transactions.isEmpty)
                  SliverToBoxAdapter(child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Column(children: [
                      const Icon(Icons.receipt_long_outlined, size: 40, color: TwamboColors.textSecondary),
                      const SizedBox(height: 8),
                      Text('No transactions yet', style: GoogleFonts.manrope(
                          fontSize: 12, color: TwamboColors.textSecondary)),
                    ]),
                  ))
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    sliver: SliverList(delegate: SliverChildBuilderDelegate(
                      (_, i) => _TxCard(tx: data.transactions[i], isDark: isDark),
                      childCount: data.transactions.length,
                    )),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Operational logs section ──────────────────────────────────────────────────

class _OpLogsSection extends StatelessWidget {
  final AsyncValue<List<_OpLog>> opLogsAsync;
  final bool isDark;
  final Color textColor;
  final Color cardBg;

  const _OpLogsSection({
    required this.opLogsAsync, required this.isDark,
    required this.textColor, required this.cardBg,
  });

  static const _logIcons = {
    'fuel': Icons.local_gas_station,
    'parts': Icons.build_outlined,
    'repair': Icons.car_repair,
    'other': Icons.receipt_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return opLogsAsync.when(
      loading: () => const SizedBox(),
      error: (_, __) => const SizedBox(),
      data: (logs) {
        final totalCost = logs.fold<double>(0, (s, l) => s + l.costZmw);
        final recent = logs.take(3).toList();

        return Container(
          decoration: BoxDecoration(
            color: cardBg,
            border: const Border(left: BorderSide(color: TwamboColors.accent, width: 4)),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('OPERATIONAL COSTS', style: GoogleFonts.spaceGrotesk(
                    fontSize: 9, fontWeight: FontWeight.w800,
                    color: TwamboColors.accent, letterSpacing: 1.5)),
                const SizedBox(height: 2),
                Text('K${totalCost.toStringAsFixed(2)}', style: GoogleFonts.spaceGrotesk(
                    fontSize: 22, fontWeight: FontWeight.w800, color: textColor)),
              ])),
              GestureDetector(
                onTap: () => _showLogSheet(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  color: TwamboColors.primary,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.add, size: 14, color: TwamboColors.textPrimary),
                    const SizedBox(width: 4),
                    Text('LOG EXPENSE', style: GoogleFonts.spaceGrotesk(
                        fontSize: 9, fontWeight: FontWeight.w800,
                        color: TwamboColors.textPrimary, letterSpacing: 1)),
                  ]),
                ),
              ),
            ]),

            if (recent.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...recent.map((log) => Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(children: [
                  Container(
                    width: 28, height: 28,
                    color: TwamboColors.accent.withValues(alpha: 0.1),
                    child: Icon(_logIcons[log.logType] ?? Icons.receipt_outlined,
                        size: 14, color: TwamboColors.accent),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(log.description.isNotEmpty ? log.description : log.logType,
                        style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w600, color: textColor),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(log.date, style: GoogleFonts.manrope(fontSize: 10, color: TwamboColors.textSecondary)),
                  ])),
                  Text('K${log.costZmw.toStringAsFixed(2)}', style: GoogleFonts.spaceGrotesk(
                      fontSize: 12, fontWeight: FontWeight.w700, color: TwamboColors.accent)),
                ]),
              )),
              if (logs.length > 3) ...[
                const SizedBox(height: 8),
                Text('+ ${logs.length - 3} more entries',
                    style: GoogleFonts.manrope(fontSize: 10, color: TwamboColors.textSecondary)),
              ],
            ] else ...[
              const SizedBox(height: 8),
              Text('No expenses logged yet. Track fuel, parts, and repairs.',
                  style: GoogleFonts.manrope(fontSize: 11, color: TwamboColors.textSecondary)),
            ],
          ]),
        );
      },
    );
  }

  void _showLogSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _LogExpenseSheet(),
    );
  }
}

// ── Log expense bottom sheet ──────────────────────────────────────────────────

class _LogExpenseSheet extends StatefulWidget {
  const _LogExpenseSheet();

  @override
  State<_LogExpenseSheet> createState() => _LogExpenseSheetState();
}

class _LogExpenseSheetState extends State<_LogExpenseSheet> {
  String _type = 'fuel';
  final _descCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  static const _types = ['fuel', 'parts', 'repair', 'other'];
  static const _typeLabels = {'fuel': 'Fuel', 'parts': 'Parts', 'repair': 'Repair', 'other': 'Other'};
  static const _typeIcons = {
    'fuel': Icons.local_gas_station,
    'parts': Icons.build_outlined,
    'repair': Icons.car_repair,
    'other': Icons.receipt_outlined,
  };

  @override
  void dispose() {
    _descCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_descCtrl.text.trim().isEmpty || _amountCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Fill in description and amount');
      return;
    }
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter a valid amount');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      if (kUseMockData) {
        await Future.delayed(const Duration(milliseconds: 400));
        mockOpLogs.insert(0, {
          'id': DateTime.now().millisecondsSinceEpoch,
          'log_type': _type,
          'description': _descCtrl.text.trim(),
          'cost_zmw': amount.toString(),
          'created_at': DateTime.now().toIso8601String(),
        });
      } else {
        await ApiClient.dio.post(Endpoints.operationalLogs, data: {
          'log_type': _type,
          'description': _descCtrl.text.trim(),
          'cost_zmw': amount,
        });
      }
      if (mounted) { Navigator.pop(context, true); }
    } catch (e) {
      setState(() { _loading = false; _error = 'Failed to save log'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2E2E2E) : TwamboColors.line;
    final textColor = isDark ? Colors.white : TwamboColors.textPrimary;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          border: const Border(left: BorderSide(color: TwamboColors.accent, width: 4)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 16), color: TwamboColors.line),
          Text('LOG EXPENSE', style: GoogleFonts.spaceGrotesk(
              fontSize: 16, fontWeight: FontWeight.w800, color: textColor, letterSpacing: 0.5)),
          const SizedBox(height: 16),

          // Type chips
          Text('TYPE', style: GoogleFonts.spaceGrotesk(
              fontSize: 9, fontWeight: FontWeight.w700,
              color: TwamboColors.textSecondary, letterSpacing: 1.5)),
          const SizedBox(height: 8),
          Row(children: _types.map((t) {
            final sel = _type == t;
            return Expanded(child: Padding(
              padding: EdgeInsets.only(right: t == _types.last ? 0 : 6),
              child: GestureDetector(
                onTap: () => setState(() => _type = t),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: sel ? TwamboColors.accent : (isDark ? const Color(0xFF2A2A2A) : TwamboColors.surfaceAlt),
                    border: Border.all(color: sel ? TwamboColors.accent : borderColor),
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(_typeIcons[t]!, size: 16, color: sel ? Colors.white : TwamboColors.textSecondary),
                    const SizedBox(height: 3),
                    Text(_typeLabels[t]!, style: GoogleFonts.spaceGrotesk(
                        fontSize: 8, fontWeight: FontWeight.w700,
                        color: sel ? Colors.white : TwamboColors.textSecondary, letterSpacing: 0.5)),
                  ]),
                ),
              ),
            ));
          }).toList()),
          const SizedBox(height: 14),

          // Description
          Text('DESCRIPTION', style: GoogleFonts.spaceGrotesk(
              fontSize: 9, fontWeight: FontWeight.w700,
              color: TwamboColors.textSecondary, letterSpacing: 1.5)),
          const SizedBox(height: 6),
          TextField(
            controller: _descCtrl,
            style: GoogleFonts.manrope(fontSize: 13, color: textColor),
            decoration: InputDecoration(
              hintText: 'e.g. Filled 20L petrol at Kobil',
              hintStyle: GoogleFonts.manrope(fontSize: 13, color: TwamboColors.textSecondary),
            ),
          ),
          const SizedBox(height: 12),

          // Amount
          Text('AMOUNT (ZMW)', style: GoogleFonts.spaceGrotesk(
              fontSize: 9, fontWeight: FontWeight.w700,
              color: TwamboColors.textSecondary, letterSpacing: 1.5)),
          const SizedBox(height: 6),
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: GoogleFonts.manrope(fontSize: 13, color: textColor),
            decoration: InputDecoration(
              hintText: '0.00',
              prefixText: 'K ',
              hintStyle: GoogleFonts.manrope(fontSize: 13, color: TwamboColors.textSecondary),
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: GoogleFonts.manrope(fontSize: 12, color: TwamboColors.error)),
          ],

          const SizedBox(height: 20),
          GestureDetector(
            onTap: _loading ? null : _submit,
            child: Container(
              height: 50, color: TwamboColors.accent,
              alignment: Alignment.center,
              child: _loading
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text('SAVE EXPENSE', style: GoogleFonts.spaceGrotesk(
                      fontSize: 13, fontWeight: FontWeight.w800,
                      color: Colors.white, letterSpacing: 1.5)),
            ),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}

// ── Vehicle health card ───────────────────────────────────────────────────────

class _VehicleHealthCard extends StatefulWidget {
  final _VehicleHealth vehicle;
  final bool isDark;
  final Color textColor;
  final Color cardBg;
  final WidgetRef ref;

  const _VehicleHealthCard({
    required this.vehicle, required this.isDark,
    required this.textColor, required this.cardBg, required this.ref,
  });

  @override
  State<_VehicleHealthCard> createState() => _VehicleHealthCardState();
}

class _VehicleHealthCardState extends State<_VehicleHealthCard> {
  bool _editingNotes = false;
  late final TextEditingController _notesCtrl;
  bool _savingNotes = false;

  @override
  void initState() {
    super.initState();
    _notesCtrl = TextEditingController(text: widget.vehicle.vehicleNotes);
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveNotes() async {
    setState(() => _savingNotes = true);
    try {
      if (kUseMockData) {
        await Future.delayed(const Duration(milliseconds: 300));
        mockDriverProfile['vehicle_notes'] = _notesCtrl.text.trim();
      } else {
        await ApiClient.dio.patch(Endpoints.driverFinancePrefs, data: {
          'vehicle_notes': _notesCtrl.text.trim(),
          'fuel_price_per_litre': widget.vehicle.fuelPricePerLitre.toString(),
        });
      }
      widget.ref.invalidate(_vehicleHealthProvider);
    } catch (_) {}
    if (mounted) { setState(() { _savingNotes = false; _editingNotes = false; }); }
  }

  @override
  Widget build(BuildContext context) {
    final vh = widget.vehicle;
    final days = vh.daysSinceService;
    final daysUntilSvc = (vh.serviceIntervalMonths * 30) - days;
    final progress = days < 0 ? 0.0 : (days / (vh.serviceIntervalMonths * 30)).clamp(0.0, 1.0);

    Color statusColor;
    String statusLabel;
    if (vh.serviceOverdue) {
      statusColor = TwamboColors.error;
      statusLabel = 'OVERDUE';
    } else if (vh.serviceDueSoon) {
      statusColor = TwamboColors.accent;
      statusLabel = 'DUE SOON';
    } else {
      statusColor = TwamboColors.success;
      statusLabel = 'GOOD';
    }

    return Container(
      decoration: BoxDecoration(
        color: widget.cardBg,
        border: Border(left: BorderSide(color: statusColor, width: 4)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header row
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('VEHICLE HEALTH', style: GoogleFonts.spaceGrotesk(
                fontSize: 9, fontWeight: FontWeight.w800,
                color: statusColor, letterSpacing: 1.5)),
            const SizedBox(height: 2),
            Text(
              '${vh.make} ${vh.model}'.trim().isNotEmpty ? '${vh.make} ${vh.model}' : 'Your vehicle',
              style: GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.w700, color: widget.textColor),
            ),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            color: statusColor.withValues(alpha: 0.12),
            child: Text(statusLabel, style: GoogleFonts.spaceGrotesk(
                fontSize: 9, fontWeight: FontWeight.w800, color: statusColor, letterSpacing: 1)),
          ),
        ]),
        const SizedBox(height: 12),

        // Service countdown
        if (days >= 0) ...[
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('SERVICE INTERVAL', style: GoogleFonts.spaceGrotesk(
                  fontSize: 8, fontWeight: FontWeight.w700,
                  color: TwamboColors.textSecondary, letterSpacing: 1.5)),
              const SizedBox(height: 4),
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: widget.isDark ? const Color(0xFF2E2E2E) : TwamboColors.surfaceAlt,
                  border: Border.all(color: TwamboColors.line, width: 0.5),
                ),
                child: FractionallySizedBox(
                  widthFactor: progress,
                  alignment: Alignment.centerLeft,
                  child: Container(color: statusColor),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                daysUntilSvc > 0
                    ? '${daysUntilSvc}d until service · ${vh.serviceIntervalKm}km interval'
                    : 'Service is overdue by ${-daysUntilSvc} days',
                style: GoogleFonts.manrope(fontSize: 10, color: TwamboColors.textSecondary),
              ),
            ])),
            const SizedBox(width: 16),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('SAVE FOR', style: GoogleFonts.spaceGrotesk(
                  fontSize: 8, fontWeight: FontWeight.w700,
                  color: TwamboColors.textSecondary, letterSpacing: 1.5)),
              Text('K${vh.serviceCostZmw.toStringAsFixed(0)}',
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 18, fontWeight: FontWeight.w800, color: widget.textColor)),
            ]),
          ]),
          const SizedBox(height: 10),
        ],

        // Fuel info row
        Row(children: [
          _InfoChip(label: '${vh.fuelType[0].toUpperCase()}${vh.fuelType.substring(1)}',
              icon: Icons.local_gas_station, isDark: widget.isDark),
          const SizedBox(width: 8),
          _InfoChip(label: '${vh.fuelConsumption.toStringAsFixed(1)}L/100km',
              icon: Icons.speed, isDark: widget.isDark),
          const SizedBox(width: 8),
          _InfoChip(label: 'K${vh.fuelPricePerLitre.toStringAsFixed(0)}/L',
              icon: Icons.attach_money, isDark: widget.isDark),
        ]),

        // Admin notes
        if (vh.adminNotes.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            color: widget.isDark ? const Color(0xFF222222) : TwamboColors.surfaceAlt,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('INSPECTOR NOTE', style: GoogleFonts.spaceGrotesk(
                  fontSize: 8, fontWeight: FontWeight.w700,
                  color: TwamboColors.secondary, letterSpacing: 1.5)),
              const SizedBox(height: 4),
              Text(vh.adminNotes, style: GoogleFonts.manrope(
                  fontSize: 12, color: TwamboColors.textSecondary)),
            ]),
          ),
        ],

        // Driver notes
        const SizedBox(height: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('MY NOTES', style: GoogleFonts.spaceGrotesk(
                fontSize: 8, fontWeight: FontWeight.w700,
                color: TwamboColors.textSecondary, letterSpacing: 1.5))),
            GestureDetector(
              onTap: () => setState(() => _editingNotes = !_editingNotes),
              child: Text(_editingNotes ? 'CANCEL' : 'EDIT', style: GoogleFonts.spaceGrotesk(
                  fontSize: 8, fontWeight: FontWeight.w700,
                  color: TwamboColors.secondary, letterSpacing: 1.5)),
            ),
          ]),
          const SizedBox(height: 6),
          if (_editingNotes) ...[
            TextField(
              controller: _notesCtrl,
              maxLines: 3,
              style: GoogleFonts.manrope(fontSize: 12, color: widget.textColor),
              decoration: InputDecoration(
                hintText: 'e.g. Brakes feel soft, check next week…',
                hintStyle: GoogleFonts.manrope(fontSize: 12, color: TwamboColors.textSecondary),
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _savingNotes ? null : _saveNotes,
              child: Container(
                height: 40, color: TwamboColors.secondary,
                alignment: Alignment.center,
                child: _savingNotes
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text('SAVE NOTE', style: GoogleFonts.spaceGrotesk(
                        fontSize: 10, fontWeight: FontWeight.w800,
                        color: Colors.white, letterSpacing: 1)),
              ),
            ),
          ] else
            Text(
              vh.vehicleNotes.isNotEmpty ? vh.vehicleNotes : 'No notes yet. Tap EDIT to add.',
              style: GoogleFonts.manrope(
                  fontSize: 12,
                  color: vh.vehicleNotes.isNotEmpty ? widget.textColor : TwamboColors.textSecondary),
            ),
        ]),
      ]),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isDark;
  const _InfoChip({required this.label, required this.icon, required this.isDark});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    color: isDark ? const Color(0xFF2A2A2A) : TwamboColors.surfaceAlt,
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 11, color: TwamboColors.textSecondary),
      const SizedBox(width: 4),
      Text(label, style: GoogleFonts.manrope(fontSize: 10, color: TwamboColors.textSecondary, fontWeight: FontWeight.w600)),
    ]),
  );
}

// ── Budget suggestion card ────────────────────────────────────────────────────

class _BudgetCard extends StatelessWidget {
  final _BudgetData budget;
  final bool showMonthly;
  final bool isDark;
  final Color textColor;
  final VoidCallback onTogglePeriod;
  final VoidCallback onDismiss;

  const _BudgetCard({
    required this.budget, required this.showMonthly, required this.isDark,
    required this.textColor, required this.onTogglePeriod, required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final label = showMonthly ? 'MONTHLY' : 'WEEKLY';
    final periodWord = showMonthly ? 'month' : 'week';

    return Container(
      decoration: BoxDecoration(
        color: TwamboColors.primary.withValues(alpha: isDark ? 0.1 : 0.05),
        border: const Border(left: BorderSide(color: TwamboColors.primary, width: 4)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 28, height: 28,
            color: TwamboColors.primary.withValues(alpha: 0.15),
            child: const Icon(Icons.lightbulb_outline, size: 16, color: TwamboColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text('$label BUDGET HELPER', style: GoogleFonts.spaceGrotesk(
              fontSize: 11, fontWeight: FontWeight.w800,
              color: isDark ? TwamboColors.primary : TwamboColors.textPrimary, letterSpacing: 1))),
          // Period toggle
          GestureDetector(
            onTap: onTogglePeriod,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              color: TwamboColors.primary.withValues(alpha: 0.15),
              child: Text(showMonthly ? '→ Weekly' : '→ Monthly',
                  style: GoogleFonts.spaceGrotesk(fontSize: 8, fontWeight: FontWeight.w700,
                      color: isDark ? TwamboColors.primary : TwamboColors.textPrimary, letterSpacing: 0.5)),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onDismiss,
            child: const Icon(Icons.close, size: 16, color: TwamboColors.textSecondary),
          ),
        ]),
        const SizedBox(height: 12),

        // Summary row
        Row(children: [
          _BudgetStat(label: 'EARNED', value: 'K${budget.earnings.toStringAsFixed(0)}', color: TwamboColors.success),
          _BudgetStat(label: 'FUEL EST.', value: 'K${budget.estimatedFuelCost.toStringAsFixed(0)}', color: TwamboColors.error),
          _BudgetStat(label: 'TAKE-HOME', value: 'K${budget.net.toStringAsFixed(0)}',
              color: budget.net >= 0 ? TwamboColors.success : TwamboColors.error),
        ]),

        if (budget.advice.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(height: 1, color: TwamboColors.primary.withValues(alpha: 0.2)),
          const SizedBox(height: 10),
          ...budget.advice.take(3).map((line) => Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Padding(
                padding: EdgeInsets.only(top: 4, right: 6),
                child: Icon(Icons.circle, size: 5, color: TwamboColors.primary),
              ),
              Expanded(child: Text(line, style: GoogleFonts.manrope(
                  fontSize: 11, color: isDark ? Colors.white70 : TwamboColors.textSecondary))),
            ]),
          )),
        ],

        if (budget.totalKm > 0) ...[
          const SizedBox(height: 8),
          Text('Based on ${budget.totalKm.toStringAsFixed(0)} km driven this $periodWord',
              style: GoogleFonts.manrope(fontSize: 9, color: TwamboColors.textSecondary)),
        ],
      ]),
    );
  }
}

class _BudgetStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _BudgetStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Text(value, style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
    const SizedBox(height: 2),
    Text(label, style: GoogleFonts.spaceGrotesk(
        fontSize: 7, fontWeight: FontWeight.w700, color: TwamboColors.textSecondary, letterSpacing: 1)),
  ]));
}

// ── Transaction card ──────────────────────────────────────────────────────────

class _TxCard extends StatelessWidget {
  final _EarningsTx tx;
  final bool isDark;
  const _TxCard({required this.tx, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : TwamboColors.textPrimary;
    final amountColor = tx.isCredit ? TwamboColors.success : TwamboColors.error;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cardBg,
        border: Border(left: BorderSide(color: amountColor, width: 3)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          color: amountColor.withValues(alpha: 0.1),
          child: Icon(
            tx.isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
            color: amountColor, size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            tx.description.isNotEmpty ? tx.description : tx.txType.toUpperCase(),
            style: GoogleFonts.spaceGrotesk(fontSize: 12, fontWeight: FontWeight.w700, color: textColor),
            maxLines: 1, overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text('${tx.createdAt.day}/${tx.createdAt.month}/${tx.createdAt.year}',
              style: GoogleFonts.manrope(fontSize: 10, color: TwamboColors.textSecondary)),
        ])),
        Text('${tx.isCredit ? '+' : '-'}K${tx.amount.toStringAsFixed(2)}',
            style: GoogleFonts.spaceGrotesk(
                fontSize: 14, fontWeight: FontWeight.w800, color: amountColor)),
      ]),
    );
  }
}

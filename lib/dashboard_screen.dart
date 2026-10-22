import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  int _currentTabIndex = 0; // 0: Floor Jobs, 1: 100-Mark Scorecard, 2: History, 3: Profile
  bool _isLoading = true;

  String _currentWorker = "MALIK10";
  String _workerFullName = "malik";
  String _workerPhone = "-";

  // Real 100-Mark Factory Evaluation Metrics
  int _score100 = 88;
  double _myRating = 4.4;
  String _ratingTag = "FACTORY STANDARD";
  String _ratingComment = "Dressing and wiring torque checked. Keep ferrule spacing uniform.";

  // 6 Quality Parameters Breakdown
  int _wiringMarks = 23;     // Max 25
  int _dressingMarks = 18;   // Max 20
  int _ferruleMarks = 13;    // Max 15
  int _plcSignalMarks = 13;  // Max 15
  int _mountingMarks = 13;   // Max 15
  int _safetyQcMarks = 8;    // Max 10

  List<Map<String, dynamic>> _myAllJobs = [];
  String _searchQuery = '';
  String _activeFilter = 'ALL';
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _historySearchCtrl = TextEditingController();
  String _historySearchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadWorkerSession();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _historySearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadWorkerSession() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUser = prefs.getString('logged_worker_username') ??
          prefs.getString('logged_operator_username') ??
          'MALIK10';

      _currentWorker = savedUser.trim().toUpperCase();

      // Fetch Worker profile with 100-mark evaluation
      final workerData = await _supabase
          .from('workers')
          .select()
          .eq('username', _currentWorker)
          .maybeSingle();

      if (workerData != null) {
        _workerFullName = (workerData['full_name'] ?? _currentWorker).toString();
        _workerPhone = (workerData['phone'] ?? '-').toString();
        _myRating = (workerData['rating'] as num?)?.toDouble() ?? 4.4;
        _score100 = (workerData['score_100'] as num?)?.toInt() ?? 88;
        _ratingTag = (workerData['rating_tag'] ?? 'FACTORY STANDARD').toString();
        _ratingComment = (workerData['rating_comment'] ?? 'Dressing and wiring torque verified.').toString();

        // Parse breakdown tags if available
        final rawBreakdown = (workerData['qc_breakdown'] ?? '').toString();
        if (rawBreakdown.contains("SCORE:")) {
          final wMatch = RegExp(r'W:(\d+)').firstMatch(rawBreakdown);
          final dMatch = RegExp(r'D:(\d+)').firstMatch(rawBreakdown);
          final fMatch = RegExp(r'F:(\d+)').firstMatch(rawBreakdown);
          final pMatch = RegExp(r'P:(\d+)').firstMatch(rawBreakdown);
          final mMatch = RegExp(r'M:(\d+)').firstMatch(rawBreakdown);
          final sMatch = RegExp(r'S:(\d+)').firstMatch(rawBreakdown);

          if (wMatch != null) _wiringMarks = int.tryParse(wMatch.group(1)!) ?? _wiringMarks;
          if (dMatch != null) _dressingMarks = int.tryParse(dMatch.group(1)!) ?? _dressingMarks;
          if (fMatch != null) _ferruleMarks = int.tryParse(fMatch.group(1)!) ?? _ferruleMarks;
          if (pMatch != null) _plcSignalMarks = int.tryParse(pMatch.group(1)!) ?? _plcSignalMarks;
          if (mMatch != null) _mountingMarks = int.tryParse(mMatch.group(1)!) ?? _mountingMarks;
          if (sMatch != null) _safetyQcMarks = int.tryParse(sMatch.group(1)!) ?? _safetyQcMarks;
        }
      }

      // Fetch jobs assigned OR previously assigned to this builder
      final allJobs = await _supabase
          .from('job_cards')
          .select()
          .order('id', ascending: false);

      final filtered = List<Map<String, dynamic>>.from(allJobs).where((j) {
        final assigned = (j['assigned_to'] ?? '').toString().trim().toUpperCase();
        final specs = (j['specs_detail'] ?? '').toString().toUpperCase();

        final bool isDirectAssigned = (assigned == _currentWorker);
        final bool isPreviouslyAssigned = specs.contains("[PREV_WORKER:$_currentWorker]") || specs.contains("FROM:$_currentWorker");

        return isDirectAssigned || isPreviouslyAssigned;
      }).toList();

      if (mounted) {
        setState(() {
          _myAllJobs = filtered;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  static String _extractCleanScope(String specs) {
    return specs
        .replaceAll(RegExp(r'\[QUOTE:.*?\]'), '')
        .replaceAll(RegExp(r'\[PO:.*?\]'), '')
        .replaceAll(RegExp(r'\[BY:.*?\]'), '')
        .replaceAll(RegExp(r'\[WORKER:.*?\]'), '')
        .replaceAll(RegExp(r'\[PREV_WORKER:.*?\]'), '')
        .replaceAll(RegExp(r'\[TRANSFER:.*?\]'), '')
        .replaceAll(RegExp(r'\[SCORE:.*?\]'), '')
        .replaceAll(RegExp(r'\[DONE:.*?\]'), '')
        .trim();
  }

  void _showJobDetailsBottomSheet(Map<String, dynamic> job) {
    final jobNo = (job['job_no'] ?? '-').toString();
    final client = (job['client'] ?? '-').toString();
    final panelType = (job['panel_type'] ?? '').toString().replaceAll('[PANEL]', '').replaceAll(RegExp(r'\[ITEM:.*?\]'), '').trim();
    final stage = (job['stage'] ?? 'Fabrication & Layout').toString();
    final status = (job['status'] ?? '').toString().toUpperCase();
    final startDate = (job['start_date'] ?? '-').toString();
    final targetDate = (job['target_date'] ?? '-').toString();
    final scope = _extractCleanScope((job['specs_detail'] ?? '').toString());
    final double progress = (job['progress'] as num?)?.toDouble() ?? 0.25;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF091722),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFF244866), borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(jobNo, style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 16, fontWeight: FontWeight.w900)),
                      Text(client, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withOpacity(0.18),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF0284C7)),
                    ),
                    child: Text(
                      status,
                      style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(color: Color(0xFF193B54)),
              const SizedBox(height: 8),
              _buildDetailInfoRow("Panel Type:", panelType),
              const SizedBox(height: 6),
              _buildDetailInfoRow("Current Stage:", stage),
              const SizedBox(height: 6),
              _buildDetailInfoRow("Start Date:", startDate),
              const SizedBox(height: 6),
              _buildDetailInfoRow("Target Delivery:", targetDate, isAlert: true),
              const SizedBox(height: 14),
              const Text("Assembly Scope & Instructions:", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0C2030),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF1E4362)),
                ),
                child: Text(
                  scope.isNotEmpty ? scope : "Standard assembly and wiring guidelines applicable.",
                  style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.35),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Progress Tracker:", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5)),
                  Text("${(progress * 100).toInt()}% Done", style: const TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: const Color(0xFF132A3E),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                  minHeight: 5,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 42,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Close Window", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showHistoryInspectionModal(Map<String, dynamic> job) {
    final jobNo = (job['job_no'] ?? '-').toString();
    final client = (job['client'] ?? '-').toString();
    final panelType = (job['panel_type'] ?? '').toString().replaceAll('[PANEL]', '').replaceAll(RegExp(r'\[ITEM:.*?\]'), '').trim();
    final status = (job['status'] ?? 'COMPLETED').toString().toUpperCase();
    final targetDate = (job['target_date'] ?? '-').toString();
    final startDate = (job['start_date'] ?? '-').toString();
    final scope = _extractCleanScope((job['specs_detail'] ?? '').toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF091722),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFF244866), borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("$jobNo History Log", style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 16, fontWeight: FontWeight.w900)),
                      Text(client, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF10B981)),
                    ),
                    child: Text(
                      status,
                      style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(color: Color(0xFF193B54)),
              const SizedBox(height: 8),

              // Director Quality Review Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0C2232),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE88226).withOpacity(0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Director Quality Review", style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w900)),
                        Row(
                          children: List.generate(5, (i) => const Icon(Icons.star_rounded, color: Color(0xFFE88226), size: 16)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text("Standing: $_ratingTag", style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text("\"$_ratingComment\"", style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 11, fontStyle: FontStyle.italic)),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Milestones Completed Checklist
              const Text("Milestones Completed:", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildMilestoneRow("1. Fabrication & Component Mounting", "Completed (Verified)", true),
              _buildMilestoneRow("2. Power & Control Wiring Dressing", "Completed (Verified)", true),
              _buildMilestoneRow("3. Ferrule Numbering & Drawing Check", "Completed (Verified)", true),
              _buildMilestoneRow("4. HV & Logic Quality Control (QC)", "Passed (Factory Cleared)", true),

              const SizedBox(height: 12),
              _buildDetailInfoRow("Panel Type:", panelType),
              const SizedBox(height: 4),
              _buildDetailInfoRow("Production Started:", startDate),
              const SizedBox(height: 4),
              _buildDetailInfoRow("Dispatch Date:", targetDate),
              const SizedBox(height: 8),

              if (scope.isNotEmpty) ...[
                const Text("Scope of Work Summary:", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0C2030),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF1E4362)),
                  ),
                  child: Text(scope, style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.3)),
                ),
                const SizedBox(height: 12),
              ],

              SizedBox(
                width: double.infinity,
                height: 42,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Close Log", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static Widget _buildMilestoneRow(String title, String status, bool isDone) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: isDone ? const Color(0xFF10B981) : Colors.grey, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600)),
          ),
          Text(status, style: TextStyle(color: isDone ? const Color(0xFF10B981) : Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  static Widget _buildDetailInfoRow(String label, String value, {bool isAlert = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 120, child: Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 11.5))),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: isAlert ? const Color(0xFFE88226) : Colors.white,
              fontSize: 11.5,
              fontWeight: isAlert ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07121A),

      // Top AppBar with NextGen Logo and live 100-mark score pill
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFF0C2232),
        elevation: 0.5,
        titleSpacing: 12,
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF0284C7), width: 1.2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.asset(
                  'assets/images/nextgen_logo_1.jpg',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(Icons.precision_manufacturing_rounded, size: 20, color: Color(0xFF0284C7)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Floor Operations", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
                  Text("Builder: $_currentWorker", style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 10.5, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            // ⭐ 100-Mark Score Pill (Tap to view Scorecard tab)
            GestureDetector(
              onTap: () => setState(() => _currentTabIndex = 1),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.18),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: const Color(0xFF10B981)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 14),
                    const SizedBox(width: 4),
                    Text("$_score100/100", style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 21),
              onPressed: _loadWorkerSession,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),

      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE88226)))
          : IndexedStack(
              index: _currentTabIndex,
              children: [
                _buildFloorJobsTab(),
                _build100MarkScorecardTab(), // TAB 1: 100-Mark Audit Breakdown
                _buildHistoryTab(),          // TAB 2: Dispatched & QC Passed Archive
                _buildProfileTab(),          // TAB 3: Profile
              ],
            ),

      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF091824),
          border: Border(top: BorderSide(color: Color(0xFF193B54), width: 1.2)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentTabIndex,
          onTap: (index) => setState(() => _currentTabIndex = index),
          backgroundColor: Colors.transparent,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFF38BDF8),
          unselectedItemColor: const Color(0xFF64748B),
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 10.5),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.assignment_outlined), activeIcon: Icon(Icons.assignment_rounded), label: "Floor Jobs"),
            BottomNavigationBarItem(icon: Icon(Icons.fact_check_outlined), activeIcon: Icon(Icons.fact_check_rounded, color: Color(0xFF10B981)), label: "My Score (100)"),
            BottomNavigationBarItem(icon: Icon(Icons.history_toggle_off_rounded), activeIcon: Icon(Icons.history_rounded, color: Color(0xFF38BDF8)), label: "History"),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline_rounded), activeIcon: Icon(Icons.person_rounded), label: "Profile"),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // TAB 0: FLOOR JOBS WITH STRIKETHROUGH ON REASSIGNED CARDS
  // =========================================================================
  Widget _buildFloorJobsTab() {
    final activeOnlyJobs = _myAllJobs.where((j) => (j['assigned_to'] ?? '').toString().toUpperCase() == _currentWorker).toList();
    final assignedCount = activeOnlyJobs.length;
    final inProgressCount = activeOnlyJobs.where((j) {
      final s = (j['status'] ?? '').toString().toUpperCase();
      return s == 'RUNNING' || s == 'TESTING' || s == 'PENDING';
    }).length;
    final completedCount = activeOnlyJobs.where((j) {
      final s = (j['status'] ?? '').toString().toUpperCase();
      return s == 'COMPLETED' || s == 'DISPATCHED';
    }).length;

    final runningCount = activeOnlyJobs.where((j) => (j['status'] ?? '').toString().toUpperCase() == 'RUNNING').length;
    final testingCount = activeOnlyJobs.where((j) => (j['status'] ?? '').toString().toUpperCase() == 'TESTING').length;

    final filtered = _myAllJobs.where((j) {
      final status = (j['status'] ?? '').toString().toUpperCase();
      final jobNo = (j['job_no'] ?? '').toString().toLowerCase();
      final client = (j['client'] ?? '').toString().toLowerCase();
      final panel = (j['panel_type'] ?? '').toString().toLowerCase();

      bool matchesFilter = true;
      if (_activeFilter == 'RUNNING') {
        matchesFilter = (status == 'RUNNING');
      } else if (_activeFilter == 'TESTING') {
        matchesFilter = (status == 'TESTING');
      } else if (_activeFilter == 'DONE') {
        matchesFilter = (status == 'COMPLETED' || status == 'DISPATCHED');
      }

      bool matchesSearch = _searchQuery.isEmpty ||
          jobNo.contains(_searchQuery) ||
          client.contains(_searchQuery) ||
          panel.contains(_searchQuery);

      return matchesFilter && matchesSearch;
    }).toList();

    return RefreshIndicator(
      color: const Color(0xFFE88226),
      backgroundColor: const Color(0xFF0C2232),
      onRefresh: _loadWorkerSession,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
        children: [
          // 1. TOP PROFILE STANDING BANNER (PHOTO MATCH)
          GestureDetector(
            onTap: () => setState(() => _currentTabIndex = 3),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0C2232),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF193B54)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.engineering_rounded, color: Color(0xFF38BDF8), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              _workerFullName.toLowerCase(),
                              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE88226).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFFE88226).withOpacity(0.6)),
                              ),
                              child: Text(
                                _ratingTag.toUpperCase(),
                                style: const TextStyle(color: Color(0xFFE88226), fontSize: 8.5, fontWeight: FontWeight.w900),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          "\"★ ${_myRating.toStringAsFixed(1)} • Score: $_score100/100\"",
                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Color(0xFF64748B), size: 20),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // 2. THE 3 METRIC CARDS ROW (PHOTO MATCH)
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  "Assigned",
                  "$assignedCount",
                  "Total Panels",
                  const Color(0xFF38BDF8),
                  Icons.assignment_outlined,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  "In-Progress",
                  "$inProgressCount",
                  "Floor Active",
                  const Color(0xFFE88226),
                  Icons.timelapse_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  "Completed",
                  "$completedCount",
                  "QC Pass",
                  const Color(0xFF10B981),
                  Icons.check_circle_outline_rounded,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 3. SEARCH BAR
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0C2030),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF193B54)),
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: InputDecoration(
                icon: const Icon(Icons.search_rounded, size: 17, color: Color(0xFF0284C7)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 15, color: Colors.grey),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                hintText: "Search by Job #, Client, or Panel type...",
                hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // 4. FILTER CHIPS
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildFilterChip("ALL", "All Jobs ($assignedCount)"),
                const SizedBox(width: 6),
                _buildFilterChip("RUNNING", "Running ($runningCount)"),
                const SizedBox(width: 6),
                _buildFilterChip("TESTING", "Testing ($testingCount)"),
                const SizedBox(width: 6),
                _buildFilterChip("DONE", "Done ($completedCount)"),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // 5. JOB CARDS LIST
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 60),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.inventory_2_outlined, color: Color(0xFF334155), size: 44),
                    const SizedBox(height: 8),
                    Text(
                      _searchQuery.isNotEmpty ? "No panel found for '$_searchQuery'" : "No active jobs assigned on floor yet.",
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            )
          else
            ...filtered.map((job) {
              final jobNo = (job['job_no'] ?? '-').toString();
              final client = (job['client'] ?? '-').toString();
              final panelType = (job['panel_type'] ?? '').toString().replaceAll('[PANEL]', '').replaceAll(RegExp(r'\[ITEM:.*?\]'), '').trim();
              final stage = (job['stage'] ?? 'Fabrication & Layout Stage').toString();
              final status = (job['status'] ?? '').toString().toUpperCase();
              final targetDateStr = (job['target_date'] ?? '-').toString();
              final double progress = (job['progress'] as num?)?.toDouble() ?? 0.25;
              final specsStr = (job['specs_detail'] ?? '').toString();
              final assignedWorker = (job['assigned_to'] ?? '').toString().toUpperCase();

              // Check if this card was reassigned away from this worker
              final bool isReassignedAway = (assignedWorker != _currentWorker);

              // Extract who it was reassigned to and the specific reason
              String transferTo = assignedWorker;
              String transferReason = "Reassigned to another technician by Director";
              final transferMatch = RegExp(r'\[TRANSFER:FROM:.*?\|TO:(.*?)\|REASON:(.*?)\|').firstMatch(specsStr);
              if (transferMatch != null) {
                transferTo = transferMatch.group(1) ?? assignedWorker;
                transferReason = transferMatch.group(2) ?? transferReason;
              }

              final bool isDone = (status == 'COMPLETED' || status == 'DISPATCHED');
              final Color statusClr = isDone
                  ? const Color(0xFF10B981)
                  : (status == 'TESTING' ? const Color(0xFFEA580C) : const Color(0xFF0284C7));

              return Stack(
                children: [
                  // Base Panel Card
                  Opacity(
                    opacity: isReassignedAway ? 0.40 : 1.0,
                    child: GestureDetector(
                      onTap: isReassignedAway ? null : () => _showJobDetailsBottomSheet(job),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0C2232),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isReassignedAway ? const Color(0xFFEF4444).withOpacity(0.5) : const Color(0xFF193B54),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0284C7).withOpacity(0.18),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.5)),
                                      ),
                                      child: Text(
                                        jobNo,
                                        style: TextStyle(
                                          color: isReassignedAway ? Colors.grey : const Color(0xFF38BDF8),
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w900,
                                          decoration: isReassignedAway ? TextDecoration.lineThrough : null,
                                          decorationColor: Colors.red,
                                          decorationThickness: 2.2,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      client,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        decoration: isReassignedAway ? TextDecoration.lineThrough : null,
                                        decorationColor: Colors.red,
                                        decorationThickness: 2.2,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: statusClr.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: statusClr),
                                  ),
                                  child: Text(
                                    status,
                                    style: TextStyle(color: statusClr, fontSize: 9.5, fontWeight: FontWeight.w900),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            if (panelType.isNotEmpty)
                              Text(
                                panelType,
                                style: const TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w600),
                              ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(stage, style: const TextStyle(color: Color(0xFF67B0D8), fontSize: 10.5, fontWeight: FontWeight.w600)),
                                Text("${(progress * 100).toInt()}% Done", style: TextStyle(color: statusClr, fontSize: 10.5, fontWeight: FontWeight.w900)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: progress.clamp(0.0, 1.0),
                                minHeight: 3.5,
                                backgroundColor: const Color(0xFF132A3E),
                                valueColor: AlwaysStoppedAnimation<Color>(statusClr),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Divider(color: Color(0xFF16344C), height: 1),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.flag_rounded, size: 12, color: Color(0xFFE88226)),
                                    const SizedBox(width: 4),
                                    Text(
                                      "Target: $targetDateStr",
                                      style: const TextStyle(color: Color(0xFFE88226), fontSize: 10.5, fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                                const Text(
                                  "Tap for scope ➔",
                                  style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.5, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ❌ STRIKETHROUGH CROSS-LINE OVERLAY & REASSIGNMENT REASON BANNER
                  if (isReassignedAway) ...[
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: CustomPaint(
                          painter: CrossLinePainter(),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      left: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF450A0A).withOpacity(0.96),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFEF4444), width: 1.3),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 6),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.cancel_rounded, color: Color(0xFFEF4444), size: 15),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    "REASSIGNED TO: $transferTo",
                                    style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 11, fontWeight: FontWeight.w900),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              "Reason: \"$transferReason\"",
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontStyle: FontStyle.italic),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              );
            }).toList(),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 1: 100-MARK FACTORY SCORECARD & BREAKDOWN (WORKER'S OWN SCORE)
  // =========================================================================
  Widget _build100MarkScorecardTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Scorecard Header Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF0C2232),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF10B981).withOpacity(0.5), width: 1.4),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Factory Quality Audit", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF10B981)),
                    ),
                    child: Text("$_score100 / 100", style: const TextStyle(color: Color(0xFF10B981), fontSize: 16, fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text("Standing Grade: $_ratingTag", style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11.5, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Text("${_myRating.toStringAsFixed(1)} ★", style: const TextStyle(color: Color(0xFFE88226), fontSize: 13, fontWeight: FontWeight.w900)),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFF071420), borderRadius: BorderRadius.circular(8)),
                child: Text("\"$_ratingComment\"", style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 11.5, fontStyle: FontStyle.italic)),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
        const Text("Inspection Parameters Breakdown (100 Marks):", style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),

        _buildParameterCard("1. Wiring & Crimping Quality", "Lug tightness, torque, wire gauge rating", _wiringMarks, 25),
        _buildParameterCard("2. Wiring Dressing & Aesthetics", "Duct trunking, door loop wrap, tie spacing", _dressingMarks, 20),
        _buildParameterCard("3. Ferrule & Tagging Match", "Schematic DWG cross-ferruling, TB numbering", _ferruleMarks, 15),
        _buildParameterCard("4. PLC & Signal Noise Isolation", "24VDC/Analog AC separation, shield wire earthing", _plcSignalMarks, 15),
        _buildParameterCard("5. Component Mounting Alignment", "DIN rail alignment, heavy item sturdiness", _mountingMarks, 15),
        _buildParameterCard("6. Safety & QC Factory Check", "Body earthing bonding, Megger insulation, HV", _safetyQcMarks, 10),
      ],
    );
  }

  Widget _buildParameterCard(String title, String desc, int marks, int max) {
    final double ratio = (marks / max).clamp(0.0, 1.0);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0C2232),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF193B54)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              Text("$marks / $max", style: const TextStyle(color: Color(0xFF10B981), fontSize: 12.5, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 2),
          Text(desc, style: const TextStyle(color: Color(0xFF64748B), fontSize: 10)),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 4,
              backgroundColor: const Color(0xFF132A3E),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 2: HISTORY (COMPLETED & INSPECTED PANELS ARCHIVE)
  // =========================================================================
  Widget _buildHistoryTab() {
    final completedPanels = _myAllJobs.where((j) {
      final s = (j['status'] ?? '').toString().toUpperCase();
      return s == 'COMPLETED' || s == 'DISPATCHED';
    }).toList();

    final filteredHistory = completedPanels.where((job) {
      if (_historySearchQuery.isEmpty) return true;
      final jNo = (job['job_no'] ?? '').toString().toLowerCase();
      final cName = (job['client'] ?? '').toString().toLowerCase();
      final pDesc = (job['panel_type'] ?? '').toString().toLowerCase();
      return jNo.contains(_historySearchQuery) || cName.contains(_historySearchQuery) || pDesc.contains(_historySearchQuery);
    }).toList();

    return RefreshIndicator(
      color: const Color(0xFFE88226),
      backgroundColor: const Color(0xFF0C2232),
      onRefresh: _loadWorkerSession,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
        children: [
          // 1. TOP MONTHLY PERFORMANCE SCORECARD
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0C2232),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF193B54)),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0F2638), Color(0xFF081824)],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Factory Scorecard", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.18),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Text("Verified Floor Logs", style: TextStyle(color: Color(0xFF10B981), fontSize: 9.5, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("${completedPanels.length}", style: const TextStyle(color: Color(0xFF10B981), fontSize: 20, fontWeight: FontWeight.w900)),
                          const Text("Panels Built", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 28, color: const Color(0xFF193B54)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text("100%", style: TextStyle(color: Color(0xFF38BDF8), fontSize: 20, fontWeight: FontWeight.w900)),
                          Text("On-Time Rate", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 28, color: const Color(0xFF193B54)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("$_score100/100", style: const TextStyle(color: Color(0xFFE88226), fontSize: 17, fontWeight: FontWeight.w900)),
                          const Text("Average Quality", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // 2. SEARCH ARCHIVE BAR
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0C2030),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF193B54)),
            ),
            child: TextField(
              controller: _historySearchCtrl,
              onChanged: (v) => setState(() => _historySearchQuery = v.trim().toLowerCase()),
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: InputDecoration(
                icon: const Icon(Icons.search_rounded, size: 16, color: Color(0xFF0284C7)),
                suffixIcon: _historySearchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 14, color: Colors.grey),
                        onPressed: () {
                          _historySearchCtrl.clear();
                          setState(() => _historySearchQuery = '');
                        },
                      )
                    : null,
                hintText: "Search dispatched panels by Job #, Client...",
                hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 9),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // 3. ARCHIVED / DISPATCHED PANELS LIST
          if (filteredHistory.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 60),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.history_toggle_off_rounded, color: Color(0xFF334155), size: 44),
                    const SizedBox(height: 8),
                    Text(
                      _historySearchQuery.isNotEmpty ? "No past panel matches '$_historySearchQuery'" : "No completed panels in archive yet.",
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                    ),
                  ],
                ),
              ),
            )
          else
            ...filteredHistory.map((job) {
              final jobNo = (job['job_no'] ?? '-').toString();
              final client = (job['client'] ?? '-').toString();
              final panel = (job['panel_type'] ?? '').toString().replaceAll('[PANEL]', '').replaceAll(RegExp(r'\[ITEM:.*?\]'), '').trim();
              final targetDate = (job['target_date'] ?? '-').toString();
              final status = (job['status'] ?? 'COMPLETED').toString().toUpperCase();

              return GestureDetector(
                onTap: () => _showHistoryInspectionModal(job),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0C2232),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: const Color(0xFF0284C7).withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                                child: Text(jobNo, style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 10, fontWeight: FontWeight.w900)),
                              ),
                              const SizedBox(width: 8),
                              Text(client, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withOpacity(0.18),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFF10B981)),
                            ),
                            child: Text(status, style: const TextStyle(color: Color(0xFF10B981), fontSize: 9.5, fontWeight: FontWeight.w900)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(panel, style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 11.5, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),

                      // Director Inspection Tag & Stars
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFFE88226).withOpacity(0.18), borderRadius: BorderRadius.circular(4)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star_rounded, color: Color(0xFFE88226), size: 12),
                                const SizedBox(width: 3),
                                Text("${_myRating.toStringAsFixed(1)}", style: const TextStyle(color: Color(0xFFE88226), fontSize: 10, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text("• $_ratingTag", style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10.5, fontWeight: FontWeight.w600)),
                        ],
                      ),

                      const SizedBox(height: 8),
                      const Divider(color: Color(0xFF16344C), height: 1),
                      const SizedBox(height: 6),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Dispatched: $targetDate", style: const TextStyle(color: Color(0xFF64748B), fontSize: 10)),
                          const Text("View Inspection Details ➔", style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 3: WORKER PROFILE
  // =========================================================================
  Widget _buildProfileTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0C2232),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF193B54)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: const Color(0xFF0284C7).withOpacity(0.2),
                    child: const Icon(Icons.engineering_rounded, color: Color(0xFF38BDF8), size: 30),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_workerFullName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                        Text("Builder ID: $_currentWorker", style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.bold)),
                        Text("Phone: $_workerPhone", style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(color: Color(0xFF193B54)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Factory Quality Standing:", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                  Text("$_score100/100 • $_ratingTag", style: const TextStyle(color: Color(0xFF10B981), fontSize: 11.5, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildProfileTile(Icons.verified_user_rounded, "System Role", "Panel Fabrication & Control Wiring Specialist"),
        _buildProfileTile(Icons.factory_rounded, "Plant Location", "NextGen Controls - Bhiwandi Operations Floor"),
        _buildProfileTile(Icons.workspace_premium_rounded, "Certified Grade", "$_ratingTag (${_myRating.toStringAsFixed(1)} ★)"),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFEF4444)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 18),
            label: const Text("Sign Out / Switch Builder", style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('logged_worker_username');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Session closed."), backgroundColor: Colors.orange),
                );
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProfileTile(IconData icon, String title, String val) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0C2030),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF193B54)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF38BDF8), size: 18),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Color(0xFF64748B), fontSize: 10)),
              const SizedBox(height: 2),
              Text(val, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(String title, String count, String sub, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0C2232),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF193B54)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10.5, fontWeight: FontWeight.bold)),
              Icon(icon, color: color, size: 14),
            ],
          ),
          const SizedBox(height: 4),
          Text(count, style: TextStyle(color: color, fontSize: 17, fontWeight: FontWeight.w900)),
          Text(sub, style: const TextStyle(color: Color(0xFF64748B), fontSize: 9)),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final bool isSelected = _activeFilter == key;
    return GestureDetector(
      onTap: () => setState(() => _activeFilter = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE88226) : const Color(0xFF0F2638),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? const Color(0xFFE88226) : const Color(0xFF1E4362)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF94A3B8),
            fontSize: 10.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// 🎨 CUSTOM PAINTER: CARD STRIKETHROUGH / RED DIAGONAL CROSS LINES
// ===========================================================================
class CrossLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFEF4444).withOpacity(0.55)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // Diagonal strikethrough from top-left to bottom-right
    canvas.drawLine(const Offset(4, 4), Offset(size.width - 4, size.height - 4), paint);
    // Diagonal strikethrough from bottom-left to top-right
    canvas.drawLine(Offset(4, size.height - 4), Offset(size.width - 4, 4), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
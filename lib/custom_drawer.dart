import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'annual_analytics_screen.dart';
import 'sing_in.dart';

final ValueNotifier<bool> isDarkModeNotifier = ValueNotifier<bool>(true);

class CustomDrawer extends StatefulWidget {
  final String activeRoute;

  const CustomDrawer({
    super.key,
    this.activeRoute = 'dashboard',
  });

  @override
  State<CustomDrawer> createState() => _CustomDrawerState();
}

class _CustomDrawerState extends State<CustomDrawer> {
  String _operatorName = "SUPERVISOR";

  @override
  void initState() {
    super.initState();
    _loadOperator();
  }

  Future<void> _loadOperator() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('logged_operator_username');
    if (saved != null && saved.isNotEmpty && mounted) {
      setState(() => _operatorName = saved.toUpperCase());
    }
  }

  Future<void> _exportWorkerReport(BuildContext context) async {
    final report = StringBuffer();
    report.writeln("NEXTGEN CONTROLS - WORKER PERFORMANCE & RATING REPORT");
    report.writeln("Generated On: ${DateTime.now()}");
    report.writeln("-----------------------------------------------------");
    report.writeln("WORKER NAME,TASK,STATUS,RATING,EFFICIENCY");
    report.writeln("Ramesh Kumar,50 HP VFD Panel Wiring,RUNNING,4.5,94%");
    report.writeln("Mohd Imran,PLC FX5U Ladder Debugging,TESTING,4.8,98%");
    report.writeln("Suresh Patil,APFC Bank Fabrication,PENDING,3.5,82%");
    report.writeln("Junaid Ansari,AMF Panel Final QC,READY,5.0,99%");

    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File("${dir.path}/Worker_Performance_Report.csv");
      await file.writeAsString(report.toString());
      await Share.shareXFiles([XFile(file.path, mimeType: 'text/csv')], text: 'Worker Performance & Rating Report');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isDarkModeNotifier,
      builder: (context, isDark, child) {
        final Color bgColor = isDark ? const Color(0xFF071420) : const Color(0xFFF1F5F9);
        final Color borderColor = isDark ? const Color(0xFF1E3E5A) : const Color(0xFFCBD5E1);

        return Drawer(
          backgroundColor: bgColor,
          child: SafeArea(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: borderColor))),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          'assets/images/nextgen_logo_1.jpg',
                          width: 40,
                          height: 40,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(Icons.engineering_rounded, color: Color(0xFFE88226)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("NEXTGEN CONTROLS", style: TextStyle(color: Color(0xFF38BDF8), fontSize: 13, fontWeight: FontWeight.w900)),
                          Text("Operator: $_operatorName", style: const TextStyle(color: Colors.grey, fontSize: 10)),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      ListTile(
                        leading: const Icon(Icons.badge_rounded, color: Color(0xFF0284C7)),
                        title: const Text("Worker Task Board", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                        subtitle: const Text("Running, Pending, Testing, Ready", style: TextStyle(color: Colors.grey, fontSize: 10)),
                        selected: widget.activeRoute == 'dashboard',
                        onTap: () => Navigator.pop(context),
                      ),
                      ListTile(
                        leading: const Icon(Icons.star_rate_rounded, color: Color(0xFFF59E0B)),
                        title: const Text("Performance & Ratings", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                        subtitle: const Text("Worker scorecards & charts", style: TextStyle(color: Colors.grey, fontSize: 10)),
                        selected: widget.activeRoute == 'analytics',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const AnnualAnalyticsScreen()));
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.file_download_outlined, color: Color(0xFF10B981)),
                        title: const Text("Export Rating Report", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                        subtitle: const Text("Download CSV scorecard", style: TextStyle(color: Colors.grey, fontSize: 10)),
                        onTap: () {
                          Navigator.pop(context);
                          _exportWorkerReport(context);
                        },
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
                      icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 16),
                      label: const Text("Sign Out", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      onPressed: () {
                        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const SignInScreen()), (r) => false);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
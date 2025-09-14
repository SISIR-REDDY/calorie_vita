import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../ui/app_colors.dart';
import '../models/weight_log.dart';
import '../services/weight_log_service.dart';

/// Weight Log Screen for viewing and managing weight entries
class WeightLogScreen extends StatefulWidget {
  const WeightLogScreen({super.key});

  @override
  State<WeightLogScreen> createState() => _WeightLogScreenState();
}

class _WeightLogScreenState extends State<WeightLogScreen> {
  final WeightLogService _weightLogService = WeightLogService();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  
  DateTime _selectedDate = DateTime.now();
  WeightLog? _editingLog;
  bool _isLoading = false;

  @override
  void dispose() {
    _weightController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  /// Show add/edit weight dialog
  void _showWeightDialog({WeightLog? weightLog}) async {
    _editingLog = weightLog;
    
    if (weightLog != null) {
      _weightController.text = weightLog.weight.toString();
      _notesController.text = weightLog.notes ?? '';
      _selectedDate = weightLog.date;
    } else {
      _weightController.clear();
      _notesController.clear();
      _selectedDate = DateTime.now();
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            weightLog != null ? 'Edit Weight' : 'Log Weight',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Weight input
                TextField(
                  controller: _weightController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Weight (kg)',
                    prefixIcon: const Icon(Icons.monitor_weight, color: kAccentBlue),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: kAccentBlue, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Date picker
                GestureDetector(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setDialogState(() {
                        _selectedDate = date;
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, color: kAccentBlue),
                        const SizedBox(width: 12),
                        Text(
                          DateFormat('MMM dd, yyyy').format(_selectedDate),
                          style: GoogleFonts.poppins(),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Notes input
                TextField(
                  controller: _notesController,
                  decoration: InputDecoration(
                    labelText: 'Notes (optional)',
                    prefixIcon: const Icon(Icons.note, color: kAccentBlue),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: kAccentBlue, width: 2),
                    ),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(color: kTextSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final weight = double.tryParse(_weightController.text);
                if (weight == null || weight <= 0) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter a valid weight'),
                        backgroundColor: kErrorColor,
                      ),
                    );
                  }
                  return;
                }
                
                setState(() => _isLoading = true);
                
                try {
                  if (_editingLog != null) {
                    await _weightLogService.updateWeightLog(
                      id: _editingLog!.id,
                      weight: weight,
                      date: _selectedDate,
                      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
                    );
                  } else {
                    await _weightLogService.addWeightLog(
                      weight: weight,
                      date: _selectedDate,
                      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
                    );
                  }
                  
                  if (mounted) {
                    Navigator.pop(context, true);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(weightLog != null ? 'Weight updated!' : 'Weight logged!'),
                          backgroundColor: kAccentGreen,
                        ),
                      );
                    }
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: kErrorColor,
                      ),
                    );
                  }
                } finally {
                  if (mounted) {
                    setState(() => _isLoading = false);
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kAccentBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      weightLog != null ? 'Update' : 'Log Weight',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      setState(() {});
    }
  }

  /// Delete weight log entry
  void _deleteWeightLog(WeightLog weightLog) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Weight Entry',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete this weight entry?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: kTextSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(color: kErrorColor, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _weightLogService.deleteWeightLog(weightLog.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Weight entry deleted'),
              backgroundColor: kAccentGreen,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting weight entry: $e'),
              backgroundColor: kErrorColor,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAppBackground,
      appBar: AppBar(
        title: Text(
          'Weight Log',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        backgroundColor: kSurfaceColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kTextDark),
          onPressed: () => Navigator.pop(context),
        ),
        actions: const [],
      ),
      body: Column(
        children: [
          // Statistics Card
          _buildStatsCard(),
          
          // Weight Log List
          Expanded(
            child: _buildWeightLogList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showWeightDialog(),
        backgroundColor: kAccentBlue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  /// Build statistics card
  Widget _buildStatsCard() {
    return StreamBuilder<WeightLogStats>(
      stream: _weightLogService.getWeightLogStatsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [kTextSecondary.withValues(alpha: 0.1), kTextSecondary.withValues(alpha: 0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: kTextSecondary.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: kTextSecondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.analytics_outlined,
                    size: 32,
                    color: kTextSecondary.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Statistics Unavailable',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: kTextDark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Weight statistics will appear here once you log your first entry',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: kTextSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final stats = snapshot.data ?? const WeightLogStats(
          currentWeight: 0.0,
          totalEntries: 0,
        );

        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [kAccentBlue, kAccentBlue.withValues(alpha: 0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: kAccentBlue.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    'Current Weight',
                    '${stats.currentWeight.toStringAsFixed(1)} kg',
                    Icons.monitor_weight,
                  ),
                  _buildStatItem(
                    'Total Entries',
                    stats.totalEntries.toString(),
                    Icons.analytics,
                  ),
                  if (stats.weightChange != null)
                    _buildStatItem(
                      'Change',
                      '${stats.weightChange!.toStringAsFixed(1)} kg',
                      stats.weightChange! > 0 ? Icons.trending_up : Icons.trending_down,
                    ),
                ],
              ),
              if (stats.averageWeight != null) ...[
                const SizedBox(height: 16),
                Text(
                  'Average Weight: ${stats.averageWeight!.toStringAsFixed(1)} kg',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Build stat item
  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  /// Build weight log list
  Widget _buildWeightLogList() {
    return StreamBuilder<List<WeightLog>>(
      stream: _weightLogService.getWeightLogsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: kErrorColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.cloud_off_outlined,
                      size: 48,
                      color: kErrorColor.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Connection Issue',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: kTextDark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Unable to load your weight logs. Please check your internet connection and try again.',
                    style: GoogleFonts.poppins(
                      color: kTextSecondary,
                      fontSize: 14,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {});
                      },
                      icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
                      label: Text(
                        'Try Again',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kAccentBlue,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: Text(
                      'Go Back',
                      style: GoogleFonts.poppins(
                        color: kTextSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final weightLogs = snapshot.data ?? [];

        if (weightLogs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: kAccentBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.monitor_weight_outlined,
                      size: 64,
                      color: kAccentBlue.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Start Tracking Your Weight',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      color: kTextDark,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Log your weight to see your progress and track your fitness journey',
                    style: GoogleFonts.poppins(
                      color: kTextSecondary,
                      fontSize: 14,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () => _showWeightDialog(),
                      icon: const Icon(Icons.add, color: Colors.white, size: 20),
                      label: Text(
                        'Log Your First Weight',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kAccentBlue,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: weightLogs.length,
          itemBuilder: (context, index) {
            final weightLog = weightLogs[index];
            final isToday = _isToday(weightLog.date);
            final isYesterday = _isYesterday(weightLog.date);

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: isToday ? Border.all(color: kAccentGreen.withValues(alpha: 0.3), width: 1) : null,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _showWeightDialog(weightLog: weightLog),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isToday 
                                ? kAccentGreen.withValues(alpha: 0.15) 
                                : kAccentBlue.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.monitor_weight,
                            color: isToday ? kAccentGreen : kAccentBlue,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    '${weightLog.weight.toStringAsFixed(1)} kg',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: kTextDark,
                                    ),
                                  ),
                                  if (isToday) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: kAccentGreen,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'Today',
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _getDateText(weightLog.date, isToday, isYesterday),
                                style: GoogleFonts.poppins(
                                  color: kTextSecondary,
                                  fontSize: 13,
                                ),
                              ),
                              if (weightLog.notes != null && weightLog.notes!.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: kTextSecondary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    weightLog.notes!,
                                    style: GoogleFonts.poppins(
                                      color: kTextSecondary,
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') {
                              _showWeightDialog(weightLog: weightLog);
                            } else if (value == 'delete') {
                              _deleteWeightLog(weightLog);
                            }
                          },
                          icon: Icon(
                            Icons.more_vert,
                            color: kTextSecondary.withValues(alpha: 0.7),
                          ),
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  const Icon(Icons.edit, color: kAccentBlue, size: 20),
                                  const SizedBox(width: 12),
                                  Text('Edit', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  const Icon(Icons.delete, color: kErrorColor, size: 20),
                                  const SizedBox(width: 12),
                                  Text('Delete', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Check if date is today
  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  /// Check if date is yesterday
  bool _isYesterday(DateTime date) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day;
  }

  /// Get formatted date text
  String _getDateText(DateTime date, bool isToday, bool isYesterday) {
    if (isToday) return 'Today';
    if (isYesterday) return 'Yesterday';
    return DateFormat('MMM dd, yyyy').format(date);
  }
}

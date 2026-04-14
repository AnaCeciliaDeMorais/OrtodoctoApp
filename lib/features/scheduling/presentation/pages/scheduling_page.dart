import 'package:flutter/material.dart';

import '../../data/scheduling_repository.dart';
import '../../models/appointment_model.dart';
import '../../models/clinic_day_model.dart';
import '../widgets/appointment_editor_sheet.dart';

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey.shade200,
        ),
        padding: const EdgeInsets.all(8),
        child: Icon(icon, size: 20),
      ),
    );
  }
}

class _ScheduleHeader extends StatelessWidget {
  final DateTime selectedDate;
  final String formattedDate;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onAddReminder;
  final bool isAlpha;

  const _ScheduleHeader({
    required this.selectedDate,
    required this.formattedDate,
    required this.onPrevious,
    required this.onNext,
    required this.onAddReminder,
    required this.isAlpha,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isAlpha ? 'Agenda • Staff Alpha' : 'Agenda • Staff Beta',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  formattedDate,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                onPressed: onAddReminder,
                icon: const Icon(Icons.notifications_outlined),
                tooltip: 'Adicionar lembrete',
              ),
              _CircleButton(
                icon: Icons.chevron_left,
                onTap: onPrevious,
              ),
              const SizedBox(width: 8),
              _CircleButton(
                icon: Icons.chevron_right,
                onTap: onNext,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SchedulingPage extends StatefulWidget {
  final String profileLevel;

  const SchedulingPage({
    super.key,
    required this.profileLevel,
  });

  @override
  State<SchedulingPage> createState() => _SchedulingPageState();
}

class _SchedulingPageState extends State<SchedulingPage> {
  final SchedulingRepository _repository = SchedulingRepository();

  late DateTime _selectedDate;
  bool _isLoading = true;

  List<AppointmentModel> _appointments = [];
  List<ClinicDayModel> _clinicDays = [];

  bool get _isAlpha => widget.profileLevel == 'staff_alpha';

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _loadInitialData();
  }

  List<String> _buildTimeSlots() {
    final List<String> slots = [];

    void addRange({
      required int startHour,
      required int startMinute,
      required int endHour,
      required int endMinute,
    }) {
      int current = startHour * 60 + startMinute;
      final int end = endHour * 60 + endMinute;

      while (current <= end) {
        final hour = (current ~/ 60).toString().padLeft(2, '0');
        final minute = (current % 60).toString().padLeft(2, '0');
        slots.add('$hour:$minute');
        current += 15;
      }
    }

    addRange(startHour: 9, startMinute: 0, endHour: 12, endMinute: 0);
    addRange(startHour: 14, startMinute: 0, endHour: 18, endMinute: 30);

    return slots;
  }

  

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);

    try {
      final clinicDays = await _repository.getAvailableClinicDays();
      final appointments = await _repository.getAppointmentsByDate(_selectedDate);

      setState(() {
        _clinicDays = clinicDays;
        _appointments = appointments;
      });
    } catch (e) {
      _showMessage('Erro ao carregar agenda: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadAppointmentsByDate(DateTime date) async {
    setState(() => _isLoading = true);

    try {
      final appointments = await _repository.getAppointmentsByDate(date);

      setState(() {
        _selectedDate = date;
        _appointments = appointments;
      });
    } catch (e) {
      _showMessage('Erro ao carregar agendamentos: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  AppointmentModel? _findAppointmentBySlot(String time) {
    try {
      return _appointments.firstWhere((item) => item.timeSlot == time);
    } catch (_) {
      return null;
    }
  }

  Future<void> _openCreateSheet(String time) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AppointmentEditorSheet(
        selectedDate: _selectedDate,
        initialTime: time,
        clinicDays: _clinicDays,
        repository: _repository,
      ),
    );

    if (changed == true) {
      await _loadAppointmentsByDate(_selectedDate);
    }
  }

  Future<void> _openEditSheet(AppointmentModel appointment) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AppointmentEditorSheet(
        selectedDate: _selectedDate,
        initialAppointment: appointment,
        initialTime: appointment.timeSlot,
        clinicDays: _clinicDays,
        repository: _repository,
      ),
    );

    if (changed == true) {
      await _loadAppointmentsByDate(_selectedDate);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final slots = _buildTimeSlots();

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: slots.length,
              itemBuilder: (context, index) {
                final time = slots[index];
                final item = _findAppointmentBySlot(time);

                return ListTile(
                  title: Text(time),
                  subtitle: Text(item?.patientName ?? 'Livre'),
                  trailing: Icon(item == null ? Icons.add : Icons.edit),
                  onTap: () {
                    if (item == null) {
                      _openCreateSheet(time);
                    } else {
                      _openEditSheet(item);
                    }
                  },
                );
              },
            ),
    );
  }
}
import 'package:flutter/material.dart';

import '../../data/scheduling_repository.dart';
import '../../models/appointment_model.dart';
import '../../models/clinic_day_model.dart';
import '../widgets/appointment_editor_sheet.dart';
import '../widgets/reminders_section.dart';
import '../widgets/reminder_editor_sheet.dart';
import 'staff_alpha_clinic_days_page.dart';

class SchedulingPage extends StatefulWidget {
  final String profileLevel;

  const SchedulingPage({super.key, required this.profileLevel});

  @override
  State<SchedulingPage> createState() => _SchedulingPageState();
}

class _SchedulingPageState extends State<SchedulingPage> {
  final SchedulingRepository _repository = SchedulingRepository();

  late DateTime _selectedDate;
  bool _isLoading = true;
  int _selectedTabIndex = 0; // 0 = Agendamentos | 1 = Lembretes

  List<AppointmentModel> _appointments = [];
  List<ClinicDayModel> _clinicDays = [];

  bool get _isAlpha => widget.profileLevel == 'staff_alpha';
  bool get _isClient => widget.profileLevel == 'client';

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

  String _formatDayMonth(DateTime date) {
    const months = [
      '',
      'Janeiro',
      'Fevereiro',
      'Março',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro',
    ];

    return '${date.day} de ${months[date.month]}';
  }

  Future<void> _pickScheduleDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );

    if (picked == null) return;

    await _loadAppointmentsByDate(picked);
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);

    try {
      if (_isClient) {
        // Para clientes: carregar próximos agendamentos e dias disponíveis
        final appointments = await _repository.getClientUpcomingAppointments();
        final clinicDays = await _repository.getAvailableClinicDays();
        setState(() {
          _appointments = appointments;
          _clinicDays = clinicDays;
        });
      } else {
        // Para staff: carregar dias disponíveis e agendamentos do dia
        final clinicDays = await _repository.getAvailableClinicDays();
        final appointments = await _repository.getAppointmentsByDate(
          _selectedDate,
        );

        setState(() {
          _clinicDays = clinicDays;
          _appointments = appointments;
        });
      }
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

  void _goToPreviousDay() {
    _loadAppointmentsByDate(_selectedDate.subtract(const Duration(days: 1)));
  }

  void _goToNextDay() {
    _loadAppointmentsByDate(_selectedDate.add(const Duration(days: 1)));
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

  Future<void> _openReminderSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ReminderEditorSheet(),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildClientView() {
    final currentMonth = DateTime.now();
    final availableDays = _clinicDays.where((day) {
      final dayDate = day.clinicDate;
      return dayDate.year == currentMonth.year &&
          dayDate.month == currentMonth.month;
    }).toList();

    final groupedAppointments = <String, List<AppointmentModel>>{};
    final appointmentOrder = <String>[];

    for (final appointment in _appointments) {
      final appointmentDate = appointment.clinicDate;
      final groupKey = _formatMonthYear(appointmentDate);
      if (!groupedAppointments.containsKey(groupKey)) {
        appointmentOrder.add(groupKey);
      }
      groupedAppointments.putIfAbsent(groupKey, () => []).add(appointment);
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dias disponíveis em ${_formatMonthYear(currentMonth)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (availableDays.isEmpty)
                      const Text('Nenhum dia disponível neste mês.')
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: availableDays.map((day) {
                          final dayDate = day.clinicDate;
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF7D8DB),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              '${dayDate.day}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFDD6B7B),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Meus próximos agendamentos',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (_appointments.isEmpty)
                    const Text('Nenhum agendamento futuro encontrado.')
                  else
                    ...appointmentOrder.map((monthLabel) {
                      final appointments = groupedAppointments[monthLabel]!;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            monthLabel,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFB71C1C),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...appointments.map(
                            (appointment) => Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFE2E2),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: const Color(0xFFE57373),
                                  width: 1.2,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _formatAppointmentDate(
                                      appointment.clinicDate,
                                    ),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFB71C1C),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Horário: ${appointment.timeSlot}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFFC62828),
                                    ),
                                  ),
                                  if (appointment.notes != null &&
                                      appointment.notes!.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      'Observações: ${appointment.notes}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      );
                    }).toList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatAppointmentDate(DateTime date) {
    const months = [
      '',
      'Jan',
      'Fev',
      'Mar',
      'Abr',
      'Mai',
      'Jun',
      'Jul',
      'Ago',
      'Set',
      'Out',
      'Nov',
      'Dez',
    ];
    return '${date.day} ${months[date.month]} ${date.year}';
  }

  String _formatMonthYear(DateTime date) {
    const months = [
      '',
      'Janeiro',
      'Fevereiro',
      'Março',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro',
    ];
    return '${months[date.month]} ${date.year}';
  }

  Widget _buildStaffAlphaEditButton() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: TextButton(
        style: TextButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFFB71C1C),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const StaffAlfaClinicDaysPage(),
            ),
          );
        },
        child: const Text(
          'Editar',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildTopTabs() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTabIndex = 0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _selectedTabIndex == 0
                      ? const Color(0xFFF7D8DB)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Center(
                  child: Text(
                    'Agendamentos',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTabIndex = 1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _selectedTabIndex == 1
                      ? const Color(0xFFF7D8DB)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Center(
                  child: Text(
                    'Lembretes',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentsTab() {
    final slots = _buildTimeSlots();

    return Column(
      children: [
        _ScheduleHeader(
          formattedDate: _formatDayMonth(_selectedDate),
          onPrevious: _goToPreviousDay,
          onNext: _goToNextDay,
          onPickDate: _pickScheduleDate,
          isAlpha: _isAlpha,
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: slots.length,
            itemBuilder: (context, index) {
              final time = slots[index];
              final item = _findAppointmentBySlot(time);
              final bool isOccupied = item != null;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 64,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 18),
                        child: Text(
                          time,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () {
                          if (item == null) {
                            _openCreateSheet(time);
                          } else {
                            _openEditSheet(item);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isOccupied
                                ? const Color(0xFFFFE2E2)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isOccupied
                                  ? const Color(0xFFE57373)
                                  : const Color(0xFFF0D3D7),
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item?.patientName ?? 'Livre',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: isOccupied
                                            ? const Color(0xFFB71C1C)
                                            : Colors.black,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item == null
                                          ? 'Toque para agendar'
                                          : 'Horário ocupado',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isOccupied
                                            ? const Color(0xFFC62828)
                                            : Colors.black.withOpacity(0.65),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Icon(
                                item == null
                                    ? Icons.add_circle_outline
                                    : Icons.edit_outlined,
                                color: Colors.black54,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRemindersTab() {
    return RemindersSection(onAddReminder: _openReminderSheet);
  }

  @override
  Widget build(BuildContext context) {
    if (_isClient) {
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text(
            'Meus Agendamentos',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        backgroundColor: const Color(0xFFFBECEE),
        body: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(child: _buildClientView()),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFFBECEE),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  _buildTopTabs(),
                  _buildStaffAlphaEditButton(),
                  Expanded(
                    child: _selectedTabIndex == 0
                        ? _buildAppointmentsTab()
                        : _buildRemindersTab(),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ScheduleHeader extends StatelessWidget {
  final String formattedDate;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPickDate;
  final bool isAlpha;

  const _ScheduleHeader({
    required this.formattedDate,
    required this.onPrevious,
    required this.onNext,
    required this.onPickDate,
    required this.isAlpha,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: onPickDate,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            formattedDate,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.calendar_month, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
              _CircleButton(icon: Icons.chevron_left, onTap: onPrevious),
              const SizedBox(width: 8),
              _CircleButton(icon: Icons.chevron_right, onTap: onNext),
            ],
          ),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        height: 36,
        width: 36,
        decoration: const BoxDecoration(
          color: Color(0xFFF7D8DB),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: Color(0xFFDD6B7B)),
      ),
    );
  }
}

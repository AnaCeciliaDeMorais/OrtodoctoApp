import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StaffAlfaClinicDaysPage extends StatefulWidget {
  const StaffAlfaClinicDaysPage({super.key});

  @override
  State<StaffAlfaClinicDaysPage> createState() =>
      _StaffAlfaClinicDaysPageState();
}

class _StaffAlfaClinicDaysPageState extends State<StaffAlfaClinicDaysPage> {
  final supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> _getCompanies() async {
    final response = await supabase.from('companies').select().order('name');
    return List<Map<String, dynamic>>.from(response);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Selecionar empresa'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _getCompanies(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final companies = snapshot.data!;

          if (companies.isEmpty) {
            return const Center(child: Text('Nenhuma empresa cadastrada.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: companies.length,
            itemBuilder: (context, index) {
              final company = companies[index];

              return Card(
                child: ListTile(
                  leading: const Icon(Icons.business),
                  title: Text(company['name'] ?? 'Empresa'),
                  subtitle: Text(company['location'] ?? ''),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ClinicAvailableDaysPage(
                          company: company,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class ClinicAvailableDaysPage extends StatefulWidget {
  final Map<String, dynamic> company;

  const ClinicAvailableDaysPage({
    super.key,
    required this.company,
  });

  @override
  State<ClinicAvailableDaysPage> createState() =>
      _ClinicAvailableDaysPageState();
}

class _ClinicAvailableDaysPageState extends State<ClinicAvailableDaysPage> {
  final supabase = Supabase.instance.client;

  String get companyId => widget.company['id'].toString();

  Future<List<Map<String, dynamic>>> _getAvailableDays() async {
    final response = await supabase
        .from('clinic_available_days')
        .select()
        .eq('company_id', companyId)
        .order('available_date');

    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> _addDay() async {
    final selectedDate = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime(2035),
      initialDate: DateTime.now(),
    );

    if (selectedDate == null) return;

    await supabase.from('clinic_available_days').insert({
      'company_id': companyId,
      'available_date': selectedDate.toIso8601String().substring(0, 10),
    });

    setState(() {});
  }

  Future<void> _deleteDay(String id) async {
    await supabase.from('clinic_available_days').delete().eq('id', id);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.company['name'] ?? 'Dias de atendimento'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _getAvailableDays(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final days = snapshot.data!;

          if (days.isEmpty) {
            return const Center(
              child: Text('Nenhum dia de atendimento cadastrado.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: days.length,
            itemBuilder: (context, index) {
              final day = days[index];

              return Card(
                child: ListTile(
                  leading: const Icon(Icons.calendar_month),
                  title: Text(day['available_date'].toString()),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => _deleteDay(day['id']),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addDay,
        child: const Icon(Icons.add),
      ),
    );
  }
}
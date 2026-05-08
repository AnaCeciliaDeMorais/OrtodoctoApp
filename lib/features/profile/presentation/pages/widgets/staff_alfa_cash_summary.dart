import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StaffAlfaCashSummary extends StatefulWidget {
  const StaffAlfaCashSummary({super.key});

  @override
  State<StaffAlfaCashSummary> createState() => _StaffAlfaCashSummaryState();
}

class _StaffAlfaCashSummaryState extends State<StaffAlfaCashSummary> {
  final supabase = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> _cashEntriesFuture;

  @override
  void initState() {
    super.initState();
    _cashEntriesFuture = _getCashEntries();
  }

  Future<List<Map<String, dynamic>>> _getCashEntries() async {
    try {
      final response = await supabase
          .from('cash_entries')
          .select('*, profiles(name)')
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Erro ao carregar entradas de caixa: $e');
      return [];
    }
  }

  double _sumByType(List<Map<String, dynamic>> entries, String type) {
    return entries.where((entry) => entry['type'] == type).fold<double>(0, (
      sum,
      entry,
    ) {
      final value = entry['value'] ?? 0;
      return sum + double.tryParse(value.toString())!;
    });
  }

  Map<String, List<Map<String, dynamic>>> _groupByEmployee(
    List<Map<String, dynamic>> entries,
  ) {
    final grouped = <String, List<Map<String, dynamic>>>{};

    for (final entry in entries) {
      final profile = entry['profiles'];
      final name = profile != null
          ? profile['name'] ?? 'Funcionário'
          : 'Funcionário';

      grouped.putIfAbsent(name, () => []);
      grouped[name]!.add(entry);
    }

    return grouped;
  }

  void _exportCashEntries() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Exportação de caixas iniciada.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _cashEntriesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Erro ao carregar: ${snapshot.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _cashEntriesFuture = _getCashEntries();
                    });
                  },
                  child: const Text('Tentar novamente'),
                ),
              ],
            ),
          );
        }

        final entries = snapshot.data ?? [];
        final totalEntradas = _sumByType(entries, 'income');
        final totalSaidas = _sumByType(entries, 'expense');
        final grouped = _groupByEmployee(entries);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Caixa geral',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            Card(
              child: ListTile(
                title: const Text('Total de entradas'),
                trailing: Text(
                  'R\$ ${totalEntradas.toStringAsFixed(2).replaceAll('.', ',')}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),

            Card(
              child: ListTile(
                title: const Text('Total de saídas'),
                trailing: Text(
                  'R\$ ${totalSaidas.toStringAsFixed(2).replaceAll('.', ',')}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),

            const SizedBox(height: 16),
            const Text(
              'Total geral de entradas e saídas de todos os caixas dos funcionários.',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _exportCashEntries,
                icon: const Icon(Icons.upload_file),
                label: const Text('Exportar caixas'),
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              'Caixas dos funcionários',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            ...grouped.entries.map((employee) {
              final employeeEntries = employee.value;
              final entradas = _sumByType(employeeEntries, 'income');
              final saidas = _sumByType(employeeEntries, 'expense');

              return Card(
                child: ExpansionTile(
                  title: Text(employee.key),
                  subtitle: Text(
                    'Entradas: R\$ ${entradas.toStringAsFixed(2).replaceAll('.', ',')} | Saídas: R\$ ${saidas.toStringAsFixed(2).replaceAll('.', ',')}',
                  ),
                  children: employeeEntries.map((entry) {
                    final isIncome = entry['type'] == 'income';
                    final value =
                        double.tryParse(entry['value'].toString()) ?? 0;

                    return ListTile(
                      leading: Icon(
                        isIncome ? Icons.arrow_upward : Icons.arrow_downward,
                      ),
                      title: Text(entry['description'] ?? 'Movimentação'),
                      subtitle: Text(isIncome ? 'Entrada' : 'Saída'),
                      trailing: Text(
                        'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}',
                      ),
                    );
                  }).toList(),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
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
          .select('*, profiles(nome)')
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Erro ao carregar entradas de caixa: $e');
      return [];
    }
  }

  double _sumIncomeEntries(List<Map<String, dynamic>> entries) {
    return entries.where(_isIncomeEntry).fold<double>(0, (sum, entry) {
      final value = entry['value'] ?? 0;
      return sum + double.tryParse(value.toString())!;
    });
  }

  bool _isIncomeEntry(Map<String, dynamic> entry) {
    final type = (entry['type'] as String?)?.toLowerCase();
    final status = (entry['status'] as String?)?.toLowerCase();
    return type == 'income' || status == 'ok';
  }

  double _sumByType(List<Map<String, dynamic>> entries, String type) {
    return entries
        .where(
          (entry) =>
              (entry['type'] as String?)?.toLowerCase() == type.toLowerCase(),
        )
        .fold<double>(0, (sum, entry) {
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
          ? profile['nome'] ?? 'Funcionário'
          : 'Funcionário';

      grouped.putIfAbsent(name, () => []);
      grouped[name]!.add(entry);
    }

    return grouped;
  }

  Future<void> _exportCashEntries() async {
    try {
      final entries = await _getCashEntries();
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Relatório de entradas de caixa',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 16),
                pw.Text(
                  'Data do relatório: ${DateTime.now().day.toString().padLeft(2, '0')}/${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}',
                  style: const pw.TextStyle(fontSize: 12),
                ),
                pw.SizedBox(height: 16),
                pw.TableHelper.fromTextArray(
                  headers: [
                    'Descrição',
                    'Tipo',
                    'Status',
                    'Valor',
                    'Criado por',
                    'Data',
                  ],
                  data: entries.map((entry) {
                    final createdAt = entry['created_at'] != null
                        ? DateTime.parse(entry['created_at'] as String)
                        : DateTime.now();
                    return [
                      entry['description'] ?? 'N/A',
                      entry['type'] ?? 'N/A',
                      entry['status'] ?? 'N/A',
                      'R\$ ${double.tryParse(entry['value'].toString())?.toStringAsFixed(2).replaceAll('.', ',') ?? '0,00'}',
                      (entry['profiles'] as Map<String, dynamic>?)?['nome'] ??
                          'N/A',
                      '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year}',
                    ];
                  }).toList(),
                  headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 10,
                  ),
                  cellStyle: const pw.TextStyle(fontSize: 9),
                  headerDecoration: const pw.BoxDecoration(
                    color: PdfColors.grey300,
                  ),
                  border: pw.TableBorder.all(color: PdfColors.grey),
                  cellAlignment: pw.Alignment.centerLeft,
                ),
              ],
            );
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    } catch (e) {
      debugPrint('Erro ao exportar entradas: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao exportar entradas: $e')),
        );
      }
    }
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
        final totalEntradas = _sumIncomeEntries(entries);
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

            const SizedBox(height: 24),

            const Text(
              'Total geral de entradas e saídas de todos os caixas dos funcionários.',
              style: TextStyle(color: Colors.grey),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _exportCashEntries,
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Exportar caixas'),
              ),
            ),
          ],
        );
      },
    );
  }
}

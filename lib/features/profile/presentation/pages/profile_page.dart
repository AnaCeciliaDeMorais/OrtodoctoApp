import 'package:flutter/material.dart';

import '../../data/profile_repository.dart';
import '../../models/cash_entry_model.dart';
import '../../models/profile_employee_model.dart';
import '../../models/treatment_item_model.dart';
import '../../../../core/theme/app_theme_controller.dart';
import 'widgets/staff_alfa_cash_summary.dart';

class ProfilePage extends StatefulWidget {
  final AppThemeController themeController;

  const ProfilePage({super.key, required this.themeController});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final ProfileRepository _repository = ProfileRepository();

  int _tabIndex = 0;

  ProfileEmployeeModel? _profile;
  List<CashEntryModel> _cash = [];
  List<TreatmentItemModel> _treatments = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _openAddCashEntrySheet() async {
    final valueController = TextEditingController();
    final reasonController = TextEditingController();
    final methodController = TextEditingController();
    String selectedStatus = 'entrada';
    DateTime selectedDate = DateTime.now();

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        final bottom = MediaQuery.of(context).viewInsets.bottom;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(
                        child: Text(
                          'Nova movimentação',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: selectedStatus,
                        items: const [
                          DropdownMenuItem(
                            value: 'entrada',
                            child: Text('Entrada'),
                          ),
                          DropdownMenuItem(
                            value: 'saida',
                            child: Text('Saída'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setModalState(() {
                              selectedStatus = value;
                            });
                          }
                        },
                        decoration: const InputDecoration(
                          labelText: 'Tipo',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: valueController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Valor',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '${selectedDate.day.toString().padLeft(2, '0')}/'
                          '${selectedDate.month.toString().padLeft(2, '0')}/'
                          '${selectedDate.year}',
                        ),
                        trailing: const Icon(Icons.calendar_month),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime.now().subtract(
                              const Duration(days: 365),
                            ),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365 * 2),
                            ),
                          );

                          if (picked != null) {
                            setModalState(() {
                              selectedDate = picked;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: reasonController,
                        decoration: const InputDecoration(
                          labelText: 'Motivo',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: methodController,
                        decoration: const InputDecoration(
                          labelText: 'Forma de pagamento',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: () async {
                          final rawValue = valueController.text
                              .replaceAll('.', '')
                              .replaceAll(',', '.');

                          final parsedValue = double.tryParse(rawValue);

                          if (parsedValue == null) return;

                          await _repository.insertCashEntry(
                            status: selectedStatus,
                            value: selectedStatus == 'saida'
                                ? -parsedValue
                                : parsedValue,
                            paymentDate: selectedDate,
                            reason: reasonController.text.trim(),
                            paymentMethod: methodController.text.trim(),
                          );

                          if (!mounted) return;
                          Navigator.pop(context, true);
                        },
                        child: const Text('Salvar'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    valueController.dispose();
    reasonController.dispose();
    methodController.dispose();

    if (saved == true) {
      await _load();
    }
  }

  Future<void> _openAddTreatmentSheet() async {
    String selectedType = 'Tratamento';
    final notesController = TextEditingController();

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        final bottom = MediaQuery.of(context).viewInsets.bottom;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(
                        child: Text(
                          'Adicionar',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<String>(
                        initialValue: selectedType,
                        items: const [
                          DropdownMenuItem(
                            value: 'Tratamento',
                            child: Text('Tratamento'),
                          ),
                          DropdownMenuItem(
                            value: 'Promoção',
                            child: Text('Promoção'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setModalState(() {
                              selectedType = value;
                            });
                          }
                        },
                        decoration: const InputDecoration(
                          labelText: 'Promoção ou Serviço?',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: notesController,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Observações',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: () async {
                          await _repository.insertTreatment(
                            title: selectedType,
                            description: notesController.text.trim().isEmpty
                                ? null
                                : notesController.text.trim(),
                            isPromotion: selectedType == 'Promoção',
                          );

                          if (!mounted) return;
                          Navigator.pop(context, true);
                        },
                        child: const Text('Salvar'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancelar'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    notesController.dispose();

    if (saved == true) {
      await _load();
    }
  }

  Future<void> _load() async {
    final profile = await _repository.getMyProfile();
    final cash = await _repository.getMyCashEntries(
      showAll: profile.profileLevel == 'staff_alfa',
    );
    final treatments = await _repository.getMyTreatments();

    setState(() {
      _profile = profile;
      _cash = cash;
      _treatments = treatments;
    });
  }

  double get totalCash {
    double total = 0;
    for (var e in _cash) {
      total += e.value;
    }
    return total;
  }

  // ================= TABS =================

  Widget _tabs() {
    final labels = ['Meus dados', 'Meu caixa', 'Tratamentos'];

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          final selected = _tabIndex == i;

          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _tabIndex = i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFFF7D8DB)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
                    labels[i],
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ================= MEUS DADOS =================

  Widget _meusDados() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _info('Nome', _profile?.nome),
        _info('Telefone', _profile?.telefone),
        _info('Cargo', _profile?.profileLevel),
      ],
    );
  }

  Widget _info(String label, String? value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade700)),
          const SizedBox(height: 4),
          Text(
            value ?? '-',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  // ================= MEU CAIXA =================

  Widget _meuCaixa() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                const Text('Valor em caixa'),
                const SizedBox(height: 10),
                Text(
                  'R\$ ${totalCash.toStringAsFixed(2).replaceAll('.', ',')}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {},
                        child: const Text('Entrada'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {},
                        child: const Text('Saída'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _cash.length,
            itemBuilder: (_, i) {
              final e = _cash[i];

              return ListTile(
                leading: Icon(Icons.arrow_circle_down, color: Colors.green),
                title: Text(
                  'R\$ ${e.value.toStringAsFixed(2).replaceAll('.', ',')}',
                ),
                subtitle: Text(e.observation ?? '-'),
                trailing: Text(
                  '${e.createdAt.day}/${e.createdAt.month}/${e.createdAt.year}',
                ),
              );
            },
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () {},
                  child: const Text('Relatório'),
                ),
              ),
              const SizedBox(width: 10),
              FloatingActionButton(
                onPressed: () {},
                child: const Icon(Icons.add),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ================= TRATAMENTOS =================

  Widget _tratamentos() {
    final promo = _treatments.where((e) => e.isPromotion).toList();
    final normal = _treatments.where((e) => !e.isPromotion).toList();

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Promoções',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              ...promo.map((e) => _card(e)),

              const SizedBox(height: 20),

              const Text(
                'Nossos serviços',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              ...normal.map((e) => _card(e)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Align(
            alignment: Alignment.bottomRight,
            child: FloatingActionButton(
              onPressed: _openAddTreatmentSheet,
              child: const Icon(Icons.add),
            ),
          ),
        ),
      ],
    );
  }

  Widget _card(TreatmentItemModel e) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(child: Text(e.title)),
          const Icon(Icons.more_vert),
        ],
      ),
    );
  }

  // ================= BUILD =================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBECEE),
      body: Column(
        children: [
          const SizedBox(height: 40),
          const Text(
            'Perfil',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          _tabs(),
          Expanded(
            child: _tabIndex == 0
                ? _meusDados()
                : _tabIndex == 1
                ? const StaffAlfaCashSummary()
                : _tratamentos(),
          ),
        ],
      ),
    );
  }
}

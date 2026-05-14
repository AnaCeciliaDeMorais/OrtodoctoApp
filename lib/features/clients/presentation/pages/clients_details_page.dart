import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'package:ortodoctor/shared/models/client_model.dart';
import '../../../../repositories/client_repository.dart';

class ClientDetailsPage extends StatefulWidget {
  final String clientId;

  const ClientDetailsPage({
    super.key,
    required this.clientId,
  });

  @override
  State<ClientDetailsPage> createState() => _ClientDetailsPageState();
}

class _ClientDetailsPageState extends State<ClientDetailsPage> {
  final ClientRepository _repository = ClientRepository();

  bool _isLoading = true;
  int _selectedTabIndex = 0;
  ClientModel? _client;

Future<void> _openEditClientForm() async {
  final client = _client;
  if (client == null) return;

  final nameController = TextEditingController(text: client.name);
  final rgController = TextEditingController(text: client.rg ?? '');
  final cpfController = TextEditingController(text: client.cpf ?? '');
  final phoneController = TextEditingController(text: client.phone ?? '');
  final streetController = TextEditingController(text: client.addressStreet ?? '');
  final numberController = TextEditingController(text: client.addressNumber ?? '');
  final neighborhoodController = TextEditingController(text: client.neighborhood ?? '');
  final cityController = TextEditingController(text: client.city ?? '');
  final guardianNameController = TextEditingController(text: client.guardianName ?? '');
  final guardianCpfController = TextEditingController(text: client.guardianCpf ?? '');

  await showDialog(
    context: context,
    builder: (_) {
      return AlertDialog(
        title: const Text('Editar cliente'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nome')),
              TextField(controller: rgController, decoration: const InputDecoration(labelText: 'RG')),
              TextField(controller: cpfController, decoration: const InputDecoration(labelText: 'CPF')),
              TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Telefone')),
              TextField(controller: streetController, decoration: const InputDecoration(labelText: 'Rua')),
              TextField(controller: numberController, decoration: const InputDecoration(labelText: 'Número')),
              TextField(controller: neighborhoodController, decoration: const InputDecoration(labelText: 'Bairro')),
              TextField(controller: cityController, decoration: const InputDecoration(labelText: 'Cidade')),
              TextField(controller: guardianNameController, decoration: const InputDecoration(labelText: 'Responsável')),
              TextField(controller: guardianCpfController, decoration: const InputDecoration(labelText: 'CPF do responsável')),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              await _repository.updatePatient(
                id: widget.clientId,
                name: nameController.text.trim(),
                rg: rgController.text.trim(),
                cpf: cpfController.text.trim(),
                phone: phoneController.text.trim(),
                addressStreet: streetController.text.trim(),
                addressNumber: numberController.text.trim(),
                neighborhood: neighborhoodController.text.trim(),
                city: cityController.text.trim(),
                guardianName: guardianNameController.text.trim(),
                guardianCpf: guardianCpfController.text.trim(),
              );

              if (!mounted) return;

              Navigator.pop(context);
              await _loadClient();

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cliente atualizado com sucesso')),
              );
            },
            child: const Text('Salvar'),
          ),
        ],
      );
    },
  );
}

  Future<void> _openFinancialTypeOptions() async {
  await showModalBottomSheet(
    context: context,
    builder: (_) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.calendar_month),
                title: const Text('Parcelamento'),
                subtitle: const Text('Criar várias parcelas para o cliente'),
                onTap: () {
                  Navigator.pop(context);
                  _openInstallmentForm();
                },
              ),
              ListTile(
                leading: const Icon(Icons.add_card),
                title: const Text('Lançamento'),
                subtitle: const Text('Criar uma pendência única'),
                onTap: () {
                  Navigator.pop(context);
                  _openSingleFinancialEntryForm();
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> _openInstallmentForm() async {
  final valueController = TextEditingController();
  final descriptionController = TextEditingController();
  final installmentsController = TextEditingController(text: '1');

  DateTime? firstInstallmentDate;

  await showDialog(
    context: context,
    builder: (_) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Novo parcelamento'),
            content: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(
                    controller: valueController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Valor'),
                  ),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(labelText: 'Descrição'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: firstInstallmentDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );

                      if (picked != null) {
                        setDialogState(() => firstInstallmentDate = picked);
                      }
                    },
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      firstInstallmentDate == null
                          ? 'Data da primeira parcela'
                          : '${firstInstallmentDate!.day}/${firstInstallmentDate!.month}/${firstInstallmentDate!.year}',
                    ),
                  ),
                  TextField(
                    controller: installmentsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Quantidade de parcelas',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                  onPressed: () async {
                      try {
                        final value = double.tryParse(
                          valueController.text.replaceAll(',', '.'),
                        );

                        final installments = int.tryParse(
                          installmentsController.text,
                        );

                        if (value == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Informe um valor válido')),
                          );
                          return;
                        }

                        if (installments == null || installments <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Informe a quantidade de parcelas')),
                          );
                          return;
                        }

                        if (firstInstallmentDate == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Selecione a data da primeira parcela')),
                          );
                          return;
                        }

                        if (descriptionController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Informe a descrição')),
                          );
                          return;
                        }

                        final installmentGroupId = const Uuid().v4();

                        for (int i = 0; i < installments; i++) {
                          final dueDate = DateTime(
                            firstInstallmentDate!.year,
                            firstInstallmentDate!.month + i,
                            firstInstallmentDate!.day,
                          );

                          await _repository.createFinancialEntry(
                            clientId: widget.clientId,
                            status: 'x',
                            value: value,
                            dueDate: dueDate,
                            description:
                                '${descriptionController.text.trim()} - ${i + 1}/$installments',
                            entryType: 'installment',
                            installmentGroupId: installmentGroupId,
                            installmentNumber: i + 1,
                            installmentTotal: installments,
                          );
                        }

                        if (!mounted) return;

                        Navigator.pop(context);
                        setState(() {});

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Parcelamento criado com sucesso')),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Erro ao criar parcelamento: $e')),
                        );
                      }
                    },
                  child: const Text('Salvar'),
                ),

            ],
          );
        },
      );
    },
  );
}
  Future<void> _openSingleFinancialEntryForm({
  Map<String, dynamic>? entry,
    }) async {
  final valueController = TextEditingController(
    text: entry?['value']?.toString() ?? '',
  );

  final descriptionController = TextEditingController(
    text: entry?['description'] ?? '',
  );

  DateTime? dueDate = entry?['due_date'] != null
    ? DateTime.tryParse(entry!['due_date'])
    : null;

  await showDialog(
    context: context,
    builder: (_) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Novo lançamento'),
            content: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(
                    controller: valueController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Valor'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: dueDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );

                      if (picked != null) {
                        setDialogState(() => dueDate = picked);
                      }
                    },
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      dueDate == null
                          ? 'Data de vencimento'
                          : '${dueDate!.day}/${dueDate!.month}/${dueDate!.year}',
                    ),
                  ),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(labelText: 'Descrição'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () async {
                  final value = double.tryParse(
                    valueController.text.replaceAll(',', '.'),
                  );

                  if (value == null ||
                      dueDate == null ||
                      descriptionController.text.trim().isEmpty) {
                    return;
                  }

                  if (entry == null) {
                    await _repository.createFinancialEntry(
                      clientId: widget.clientId,
                      status: 'x',
                      value: value,
                      dueDate: dueDate!,
                      description: descriptionController.text.trim(),
                      entryType: 'launch',
                    );
                  } else {
                    await _repository.updateFinancialEntry(
                      id: entry['id'],
                      status: 'x',
                      value: value,
                      dueDate: dueDate!,
                      description: descriptionController.text.trim(),
                    );
                  }
                  if (!mounted) return;
                  Navigator.pop(context);
                  setState(() {});
                },
                child: const Text('Salvar'),
              ),
            ],
          );
        },
      );
    },
  );
}

  Future<void> _openFinancialForm({Map<String, dynamic>? entry}) async {
  String status = entry?['status'] ?? 'x';
  final valueController = TextEditingController(
    text: entry?['value']?.toString() ?? '',
  );

  DateTime? dueDate = entry?['due_date'] != null
      ? DateTime.tryParse(entry!['due_date'])
      : null;

  await showDialog(
    context: context,
    builder: (_) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(entry == null ? 'Nova pendência' : 'Editar pendência'),
            content: SingleChildScrollView(
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: const [
                      DropdownMenuItem(value: 'ok', child: Text('Ok - Pago')),
                      DropdownMenuItem(value: 'x', child: Text('X - Não pago')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => status = value);
                      }
                    },
                  ),
                  TextField(
                    controller: valueController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Valor'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: dueDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );

                      if (picked != null) {
                        setDialogState(() => dueDate = picked);
                      }
                    },
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      dueDate == null
                          ? 'Data vencimento'
                          : '${dueDate!.day}/${dueDate!.month}/${dueDate!.year}',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () async {
                  final value = double.tryParse(
                    valueController.text.replaceAll(',', '.'),
                  );

                  if (value == null || dueDate == null) return;

                  if (entry == null) {
                    await _repository.createFinancialEntry(
                      clientId: widget.clientId,
                      status: status,
                      value: value,
                      dueDate: dueDate!,
                    );
                  } else {
                    await _repository.updateFinancialEntry(
                      id: entry['id'],
                      status: status,
                      value: value,
                      dueDate: dueDate!,
                    );
                  }

                  if (!mounted) return;
                  Navigator.pop(context);
                  setState(() {});
                },
                child: const Text('Salvar'),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<void> _openConfirmPayment(String entryId) async {
  String paymentMethod = 'pix';

  await showDialog(
    context: context,
    builder: (_) {
      return AlertDialog(
        title: const Text('Confirmar pagamento'),
        content: DropdownButtonFormField<String>(
          value: paymentMethod,
          decoration: const InputDecoration(labelText: 'Forma de pagamento'),
          items: const [
            DropdownMenuItem(value: 'boleto', child: Text('Boleto')),
            DropdownMenuItem(value: 'pix', child: Text('Pix')),
            DropdownMenuItem(value: 'dinheiro', child: Text('Dinheiro')),
            DropdownMenuItem(value: 'cartao_credito', child: Text('Cartão de crédito')),
            DropdownMenuItem(value: 'cartao_debito', child: Text('Cartão de débito')),
          ],
          onChanged: (value) {
            if (value != null) paymentMethod = value;
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              await _repository.confirmPayment(
                id: entryId,
                paymentMethod: paymentMethod,
              );

              if (!mounted) return;
              Navigator.pop(context);
              setState(() {});
            },
            child: const Text('Confirmar'),
          ),
        ],
      );
    },
  );
}

Future<void> _deleteFinancialEntry(String id) async {
  await _repository.deleteFinancialEntry(id);
  setState(() {});
}
  @override
  void initState() {
    super.initState();
    _loadClient();
  }

  Future<void> _loadClient() async {
    setState(() => _isLoading = true);

    try {
      final client = await _repository.getClientById(widget.clientId);
      setState(() {
        _client = client;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar ficha: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteClient() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Excluir cliente'),
          content: const Text('Tem certeza que deseja excluir este cliente?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await _repository.deletePatient(widget.clientId);

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paciente excluído com sucesso')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao excluir paciente: $e')),
      );
    }
  }

  Widget _buildTabs() {
    final labels = ['Dados', 'Financeiro', 'Agendamentos'];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: List.generate(labels.length, (index) {
          final selected = _selectedTabIndex == index;

          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTabIndex = index),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFFF7D8DB)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Center(
                  child: Text(
                    labels[index],
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

  Widget _buildDataTab() {
    final client = _client!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: _openEditClientForm,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Editar'),
          ),
        ),
        const SizedBox(height: 16),
        _InfoTile(label: 'Nome', value: client.name),
        _InfoTile(label: 'RG', value: client.rg),
        _InfoTile(label: 'CPF', value: client.cpf),
        _InfoTile(label: 'Telefone', value: client.phone),
        _InfoTile(label: 'Rua', value: client.addressStreet),
        _InfoTile(label: 'Número', value: client.addressNumber),
        _InfoTile(label: 'Bairro', value: client.neighborhood),
        _InfoTile(label: 'Cidade', value: client.city),
        _InfoTile(label: 'Responsável', value: client.guardianName),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: _deleteClient,
          icon: const Icon(Icons.delete_outline),
          label: const Text('Excluir cliente'),
        ),
      ],
    );
  }

  Widget _buildFinancialTab() {
  return FutureBuilder<List<Map<String, dynamic>>>(
    future: _repository.getClientFinancialEntries(widget.clientId),
    builder: (context, snapshot) {
      final entries = snapshot.data ?? [];

      return Scaffold(
        backgroundColor: const Color(0xFFFBECEE),
       floatingActionButton: FloatingActionButton(
        onPressed: () => _openFinancialTypeOptions(),
        child: const Icon(Icons.add),
       ),
        body: snapshot.connectionState == ConnectionState.waiting
            ? const Center(child: CircularProgressIndicator())
            : entries.isEmpty
                ? const Center(child: Text('Nenhuma pendência cadastrada'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      final confirmed = entry['confirmed'] == true;

                      return Card(
                        child: ListTile(
                          title: Text('R\$ ${entry['value']}'),
                          subtitle: Text(
                            'Status: ${confirmed ? 'Ok' : 'X'}\n'
                            'Vencimento: ${entry['due_date'] ?? '-'}\n'
                            'Forma de pagamento: ${entry['payment_method'] ?? '-'}',
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'confirm') {
                                _openConfirmPayment(entry['id']);         
                                } else if (value == 'edit') {
                                  _openSingleFinancialEntryForm(
                                    entry: entry,
                                  );
                              } else if (value == 'delete') {
                                _deleteFinancialEntry(entry['id']);
                              }
                            },
                            itemBuilder: (_) => [
                              if (!confirmed)
                                const PopupMenuItem(
                                  value: 'confirm',
                                  child: Text('Confirmar pagamento'),
                                ),
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('Editar'),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('Excluir'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      );
    },
  );
}

Widget _buildAppointmentsTab() {
  return FutureBuilder<List<Map<String, dynamic>>>(
    future: _repository.getClientAppointments(widget.clientId),
    builder: (context, snapshot) {
      final appointments = snapshot.data ?? [];

      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      }

      final attendedCount = appointments.where((appointment) {
        final status =
            appointment['attendance_status'] ?? appointment['status'];

        return status == 'Atendido';
      }).length;

      final missedCount = appointments.where((appointment) {
        final status =
            appointment['attendance_status'] ?? appointment['status'];

        return status == 'Faltou';
      }).length;

      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  title: 'Atendidos',
                  value: attendedCount.toString(),
                  icon: Icons.check_circle_outline,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryCard(
                  title: 'Faltas',
                  value: missedCount.toString(),
                  icon: Icons.cancel_outlined,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              children: [
                Expanded(
                  child: Text(
                    'Data',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Situação',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Observação',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          if (appointments.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(
                child: Text('Nenhum agendamento encontrado'),
              ),
            )
          else
            ...appointments.map((appointment) {
              final status =
                  appointment['attendance_status'] ??
                  appointment['status'] ??
                  '-';

              final procedure =
                  appointment['appointment_labels']?['name'] ??
                  appointment['custom_label'] ??
                  'Sem observação';

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        appointment['clinic_date'] ?? '-',
                      ),
                    ),
                    Expanded(
                      child: Text(
                        status,
                        style: TextStyle(
                          color: status == 'Faltou'
                              ? Colors.red
                              : Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(procedure),
                    ),
                  ],
                ),
              );
            }),
        ],
      );
    },
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBECEE),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back),
                        ),
                        Expanded(
                          child: Text(
                            _client?.name ?? 'Cliente',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildTabs(),
                  Expanded(
                    child: _selectedTabIndex == 0
                        ? _buildDataTab()
                        : _selectedTabIndex == 1
                            ? _buildFinancialTab()
                            : _buildAppointmentsTab(),
                  ),
                ],
              ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String? value;

  const _InfoTile({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
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
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            (value?.trim().isNotEmpty ?? false) ? value! : '-',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(icon, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(title),
        ],
      ),
    );
  }
}

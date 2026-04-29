import 'package:flutter/material.dart';

import '../../data/payments_repository.dart';
import '../../../../shared/models/payment_model.dart';

class CashierPage extends StatefulWidget {
  const CashierPage({super.key});

  @override
  State<CashierPage> createState() => _CashierPageState();
}

class _CashierPageState extends State<CashierPage> {
  final PaymentsRepository _repository = PaymentsRepository();

  bool _isLoading = true;
  List<PaymentModel> _payments = [];

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    setState(() => _isLoading = true);

    try {
      final payments = await _repository.getPayments();
      setState(() => _payments = payments);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar lançamentos: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _addPayment() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _PaymentDialog(),
    );

    if (result != null) {
      try {
        await _repository.createPayment(
          value: result['value'],
          status: result['status'],
          observation: result['observation'],
          paymentMethod: result['paymentMethod'],
        );
        await _loadPayments();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Lançamento criado com sucesso')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao criar lançamento: $e')),
          );
        }
      }
    }
  }

  Future<void> _editPayment(PaymentModel payment) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _PaymentDialog(payment: payment),
    );

    if (result != null) {
      try {
        await _repository.updatePayment(
          paymentId: payment.id,
          value: result['value'],
          status: result['status'],
          observation: result['observation'],
          paymentMethod: result['paymentMethod'],
        );
        await _loadPayments();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Lançamento atualizado com sucesso')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao atualizar lançamento: $e')),
          );
        }
      }
    }
  }

  Future<void> _deletePayment(PaymentModel payment) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: Text('Deseja excluir este lançamento de R\$ ${payment.value.toStringAsFixed(2).replaceAll('.', ',')}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _repository.deletePayment(payment.id);
        await _loadPayments();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Lançamento excluído com sucesso')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao excluir lançamento: $e')),
          );
        }
      }
    }
  }

  void _openEntryMenu(PaymentModel payment) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (_) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Editar'),
                onTap: () => Navigator.pop(context, 'edit'),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Excluir'),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
            ],
          ),
        );
      },
    );

    if (action == 'edit') {
      await _editPayment(payment);
    } else if (action == 'delete') {
      await _deletePayment(payment);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBECEE),
      floatingActionButton: FloatingActionButton(
        onPressed: _addPayment,
        child: const Icon(Icons.add),
      ),
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
                    child: const Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Meu Caixa',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _payments.isEmpty
                        ? const Center(
                            child: Text('Nenhum lançamento encontrado'),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemCount: _payments.length,
                            itemBuilder: (context, index) {
                              final payment = _payments[index];

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      payment.status == 'paid'
                                          ? Icons.check_circle
                                          : Icons.cancel_outlined,
                                      color: payment.status == 'paid'
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'R\$ ${payment.value.toStringAsFixed(2).replaceAll('.', ',')}',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(payment.observation ?? '-'),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Forma: ${payment.paymentMethod ?? '-'}',
                                            style: TextStyle(
                                              color: Colors.grey.shade700,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () => _openEntryMenu(payment),
                                      icon: const Icon(Icons.more_vert),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {},
                        child: const Text('Relatório de vendas'),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _PaymentDialog extends StatefulWidget {
  final PaymentModel? payment;

  const _PaymentDialog({this.payment});

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _valueController = TextEditingController();
  final _observationController = TextEditingController();

  String _status = 'paid';
  String? _paymentMethod = 'pix';

  final List<String> _paymentMethods = ['pix', 'card', 'cash', 'bank_slip'];
  final List<String> _statuses = ['paid', 'pending', 'cancelled'];

  @override
  void initState() {
    super.initState();
    if (widget.payment != null) {
      _valueController.text = widget.payment!.value.toString();
      _observationController.text = widget.payment!.observation ?? '';
      _status = widget.payment!.status ?? 'paid';
      _paymentMethod = widget.payment!.paymentMethod ?? 'pix';
    }
  }

  @override
  void dispose() {
    _valueController.dispose();
    _observationController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final result = {
        'value': double.parse(_valueController.text.trim()),
        'status': _status,
        'observation': _observationController.text.trim().isEmpty
            ? null
            : _observationController.text.trim(),
        'paymentMethod': _paymentMethod,
      };
      Navigator.pop(context, result);
    }
  }

  String _getPaymentMethodLabel(String method) {
    switch (method) {
      case 'pix':
        return 'Pix';
      case 'card':
        return 'Cartão';
      case 'cash':
        return 'Dinheiro';
      case 'bank_slip':
        return 'Boleto';
      default:
        return method;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'paid':
        return 'Pago';
      case 'pending':
        return 'Pendente';
      case 'cancelled':
        return 'Cancelado';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.payment == null ? 'Novo Lançamento' : 'Editar Lançamento'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _valueController,
                decoration: const InputDecoration(
                  labelText: 'Valor *',
                  border: OutlineInputBorder(),
                  prefixText: 'R\$ ',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Campo obrigatório';
                  }
                  final parsed = double.tryParse(value.trim());
                  if (parsed == null || parsed <= 0) {
                    return 'Valor deve ser maior que zero';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(
                  labelText: 'Status *',
                  border: OutlineInputBorder(),
                ),
                items: _statuses.map((status) {
                  return DropdownMenuItem(
                    value: status,
                    child: Text(_getStatusLabel(status)),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _status = value!);
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _paymentMethod,
                decoration: const InputDecoration(
                  labelText: 'Forma de Pagamento',
                  border: OutlineInputBorder(),
                ),
                items: _paymentMethods.map((method) {
                  return DropdownMenuItem(
                    value: method,
                    child: Text(_getPaymentMethodLabel(method)),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _paymentMethod = value);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _observationController,
                decoration: const InputDecoration(
                  labelText: 'Observação',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}

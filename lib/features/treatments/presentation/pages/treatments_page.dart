import 'package:flutter/material.dart';

import '../../data/treatments_repository.dart';
import '../../../../shared/models/treatment_model.dart';

class TreatmentsPage extends StatefulWidget {
  const TreatmentsPage({super.key});

  @override
  State<TreatmentsPage> createState() => _TreatmentsPageState();
}

class _TreatmentsPageState extends State<TreatmentsPage> {
  final TreatmentsRepository _repository = TreatmentsRepository();

  bool _isLoading = true;
  List<TreatmentModel> _treatments = [];

  @override
  void initState() {
    super.initState();
    _loadTreatments();
  }

  Future<void> _loadTreatments() async {
    setState(() => _isLoading = true);

    try {
      final treatments = await _repository.getTreatments();
      setState(() => _treatments = treatments);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar tratamentos: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _addTreatment() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _TreatmentDialog(),
    );

    if (result != null) {
      try {
        await _repository.createTreatment(
          title: result['title'],
          description: result['description'],
          originalPrice: result['originalPrice'],
          promotionalPrice: result['promotionalPrice'],
          isPromotion: result['isPromotion'],
        );
        await _loadTreatments();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tratamento criado com sucesso')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao criar tratamento: $e')),
          );
        }
      }
    }
  }

  Future<void> _editTreatment(TreatmentModel treatment) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _TreatmentDialog(treatment: treatment),
    );

    if (result != null) {
      try {
        await _repository.updateTreatment(
          treatmentId: treatment.id,
          title: result['title'],
          description: result['description'],
          originalPrice: result['originalPrice'],
          promotionalPrice: result['promotionalPrice'],
          isPromotion: result['isPromotion'],
        );
        await _loadTreatments();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tratamento atualizado com sucesso')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao atualizar tratamento: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteTreatment(TreatmentModel treatment) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: Text('Deseja excluir "${treatment.title}"?'),
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
        await _repository.deleteTreatment(treatment.id);
        await _loadTreatments();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tratamento excluído com sucesso')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao excluir tratamento: $e')),
          );
        }
      }
    }
  }

  void _openItemMenu(TreatmentModel treatment) async {
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
      await _editTreatment(treatment);
    } else if (action == 'delete') {
      await _deleteTreatment(treatment);
    }
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildCard(TreatmentModel treatment) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  treatment.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                if (treatment.description != null) ...[
                  const SizedBox(height: 6),
                  Text(treatment.description!),
                ],
                if (treatment.promotionalPrice != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'R\$ ${treatment.promotionalPrice!.toStringAsFixed(2).replaceAll('.', ',')}',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ] else if (treatment.originalPrice != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'R\$ ${treatment.originalPrice!.toStringAsFixed(2).replaceAll('.', ',')}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: () => _openItemMenu(treatment),
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final promotions = _treatments.where((e) => e.isPromotion).toList();
    final clinicTreatments = _treatments.where((e) => !e.isPromotion).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFFBECEE),
      floatingActionButton: FloatingActionButton(
        onPressed: _addTreatment,
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
                            'Tratamentos',
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
                    child: ListView(
                      children: [
                        _buildSectionTitle('Promoções'),
                        if (promotions.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text('Nenhuma promoção cadastrada'),
                          ),
                        ...promotions.map(_buildCard),
                        _buildSectionTitle('Nossos serviços'),
                        if (clinicTreatments.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text('Nenhum tratamento cadastrado'),
                          ),
                        ...clinicTreatments.map(_buildCard),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _TreatmentDialog extends StatefulWidget {
  final TreatmentModel? treatment;

  const _TreatmentDialog({this.treatment});

  @override
  State<_TreatmentDialog> createState() => _TreatmentDialogState();
}

class _TreatmentDialogState extends State<_TreatmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _originalPriceController = TextEditingController();
  final _promotionalPriceController = TextEditingController();

  bool _isPromotion = false;

  @override
  void initState() {
    super.initState();
    if (widget.treatment != null) {
      _titleController.text = widget.treatment!.title;
      _descriptionController.text = widget.treatment!.description ?? '';
      _originalPriceController.text = widget.treatment!.originalPrice?.toString() ?? '';
      _promotionalPriceController.text = widget.treatment!.promotionalPrice?.toString() ?? '';
      _isPromotion = widget.treatment!.isPromotion;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _originalPriceController.dispose();
    _promotionalPriceController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final result = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        'originalPrice': _originalPriceController.text.trim().isEmpty
            ? null
            : double.tryParse(_originalPriceController.text.trim()),
        'promotionalPrice': _promotionalPriceController.text.trim().isEmpty
            ? null
            : double.tryParse(_promotionalPriceController.text.trim()),
        'isPromotion': _isPromotion,
      };
      Navigator.pop(context, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.treatment == null ? 'Novo Tratamento' : 'Editar Tratamento'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Título *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Campo obrigatório';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Descrição',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _originalPriceController,
                      decoration: const InputDecoration(
                        labelText: 'Preço Original',
                        border: OutlineInputBorder(),
                        prefixText: 'R\$ ',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _promotionalPriceController,
                      decoration: const InputDecoration(
                        labelText: 'Preço Promocional',
                        border: OutlineInputBorder(),
                        prefixText: 'R\$ ',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                value: _isPromotion,
                onChanged: (value) {
                  setState(() => _isPromotion = value ?? false);
                },
                title: const Text('É uma promoção?'),
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
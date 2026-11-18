import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/formatters.dart' as f;
import '../../shared/models/models.dart';
import 'patients_repository.dart';

/// Busca e escolhe um cliente da empresa.
Future<Patient?> pickPatient(BuildContext context, String companyId) =>
    showDialog<Patient>(context: context, builder: (_) => _PatientPicker(companyId: companyId));

class _PatientPicker extends StatefulWidget {
  const _PatientPicker({required this.companyId});
  final String companyId;

  @override
  State<_PatientPicker> createState() => _PatientPickerState();
}

class _PatientPickerState extends State<_PatientPicker> {
  final _repo = PatientsRepository();
  List<Patient>? _items;
  Object? _error;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _search(String q) async {
    try {
      final items = await _repo.list(widget.companyId, query: q);
      if (mounted) setState(() => _items = items.where((p) => p.active).toList());
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Escolher cliente'),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: SizedBox(
        width: 420,
        height: 420,
        child: Column(children: [
          TextField(
            autofocus: true,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Nome, CPF ou telefone',
            ),
            onChanged: (q) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 300), () => _search(q));
            },
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _error != null
                ? Center(child: Text('Erro ao buscar: $_error'))
                : _items == null
                    ? const Center(child: CircularProgressIndicator())
                    : _items!.isEmpty
                        ? const Center(child: Text('Nenhum cliente encontrado.'))
                        : ListView.builder(
                            itemCount: _items!.length,
                            itemBuilder: (context, i) {
                              final p = _items![i];
                              return ListTile(
                                title: Text(p.fullName),
                                subtitle: Text([
                                  if (p.phone != null) f.phone(p.phone),
                                  if (p.cpf != null) f.cpf(p.cpf),
                                ].join(' · ')),
                                onTap: () => Navigator.pop(context, p),
                              );
                            },
                          ),
          ),
        ]),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar'))],
    );
  }
}

import 'package:flutter/material.dart';

import '../../data/clients_repository.dart';
import 'package:ortodoctor/shared/models/client_model.dart';

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
  final ClientsRepository _repository = ClientsRepository();

  bool _isLoading = true;
  int _selectedTabIndex = 0;
  ClientModel? _client;

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
      await _repository.deleteClient(widget.clientId);

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cliente excluído com sucesso')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao excluir cliente: $e')),
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
            onPressed: () {},
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
    return const Center(
      child: Text('Aba Financeiro'),
    );
  }

  Widget _buildAppointmentsTab() {
    return const Center(
      child: Text('Aba Agendamentos'),
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
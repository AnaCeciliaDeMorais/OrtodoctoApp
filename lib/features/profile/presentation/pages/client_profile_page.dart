import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../clients/data/clients_repository.dart';
import '../../../treatments/presentation/pages/treatments_page.dart';
import '../../../../shared/models/client_model.dart';

class ClientProfilePage extends StatefulWidget {
  const ClientProfilePage({super.key});

  @override
  State<ClientProfilePage> createState() => _ClientProfilePageState();
}

class _ClientProfilePageState extends State<ClientProfilePage> {
  final ClientsRepository _repository = ClientsRepository();
  bool _isLoading = true;
  ClientModel? _client;
  String? _error;
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadClientProfile();
  }

  Future<void> _loadClientProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        setState(() => _error = 'Usuário não autenticado.');
        return;
      }

      final client = await _repository.getClientById(currentUser.id);
      setState(() => _client = client);
    } catch (e) {
      setState(() => _error = 'Erro ao carregar dados: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _formatAddress(ClientModel client) {
    final street = client.addressStreet ?? '-';
    final number = client.addressNumber ?? '';
    final neighborhood = client.neighborhood ?? '-';
    final city = client.city ?? '-';

    final address = [
      street,
      number,
    ].where((part) => part.isNotEmpty).join(', ');
    return '$address\n$neighborhood · $city';
  }

  Widget _tabs() {
    final labels = ['Meus dados', 'Tratamentos'];

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

  Widget _meusDados() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _infoTile('Nome', _client!.name),
        _infoTile('Data de nascimento', _formatDate(_client!.birthDate)),
        _infoTile('Endereço', _formatAddress(_client!)),
        if (_client!.phone != null && _client!.phone!.isNotEmpty) ...[
          _infoTile('Telefone', _client!.phone!),
        ],
      ],
    );
  }

  Widget _infoTile(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBECEE),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(child: Text(_error!))
            : _client == null
            ? const Center(child: Text('Dados do cliente não encontrados.'))
            : Column(
                children: [
                  const SizedBox(height: 8),
                  const Text(
                    'Perfil',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  _tabs(),
                  Expanded(
                    child: _tabIndex == 0
                        ? _meusDados()
                        : TreatmentsPage(profileLevel: 'client'),
                  ),
                ],
              ),
      ),
    );
  }
}

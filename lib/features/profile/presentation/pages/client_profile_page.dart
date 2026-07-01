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
    final street = client.street ?? '-';
    final number = client.number ?? '';
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
        _readOnlyField('Nome', Icons.person, _client!.name),
        _readOnlyField(
          'Data de nascimento',
          Icons.calendar_month,
          _formatDate(_client!.birthDate),
        ),
        _readOnlyField('Telefone', Icons.phone, _client!.phone ?? '-'),
        const SizedBox(height: 12),
        Text(
          'Dados de cadastro, não editáveis.',
          style: TextStyle(color: Colors.grey.shade700),
        ),
        const SizedBox(height: 8),
        Text(
          'Nome salvo para login: ${_client!.name}',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
      ],
    );
  }

  Widget _readOnlyField(String label, IconData icon, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        initialValue: value,
        enabled: false,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixIcon: const Icon(Icons.lock),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
        ),
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
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Row(
                      children: [
                        const Text(
                          'Perfil',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.symmetric(
                      vertical: 24,
                      horizontal: 18,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26.withOpacity(0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const CircleAvatar(
                          radius: 36,
                          backgroundColor: Color(0xFFECECEC),
                          child: Icon(
                            Icons.person,
                            size: 40,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _client!.name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Meus Dados',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
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

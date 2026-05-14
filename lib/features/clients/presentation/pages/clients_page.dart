import 'package:flutter/material.dart';
import '../../../../repositories/client_repository.dart';
import 'clients_details_page.dart';

class ClientsPage extends StatefulWidget {
  const ClientsPage({super.key});

  @override
  State<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends State<ClientsPage> {
  final ClientRepository _repository = ClientRepository();

  List<Map<String, dynamic>> _patients = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  Future<void> _loadPatients() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final patients = await _repository.getPatients();

      setState(() {
        _patients = patients;
      });
    } catch (e) {
      _showMessage('Erro ao carregar clientes: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _openPatientForm({Map<String, dynamic>? patient}) {
    final nameController = TextEditingController(text: patient?['name'] ?? '');
    final phoneController = TextEditingController(text: patient?['phone'] ?? '');
    final cpfController = TextEditingController(text: patient?['cpf'] ?? '');
    final guardianNameController =
        TextEditingController(text: patient?['guardian_name'] ?? '');
    final guardianCpfController =
        TextEditingController(text: patient?['guardian_cpf'] ?? '');

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text(patient == null ? 'Novo cliente' : 'Editar cliente'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Nome'),
                ),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: 'Telefone'),
                ),
                TextField(
                  controller: cpfController,
                  decoration: const InputDecoration(labelText: 'CPF'),
                ),
                TextField(
                  controller: guardianNameController,
                  decoration: const InputDecoration(
                    labelText: 'Nome do responsável',
                  ),
                ),
                TextField(
                  controller: guardianCpfController,
                  decoration: const InputDecoration(
                    labelText: 'CPF do responsável',
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
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  _showMessage('Informe o nome do cliente');
                  return;
                }

                try {
                  if (patient == null) {
                    await _repository.createPatient(
                      name: nameController.text.trim(),
                      phone: phoneController.text.trim(),
                      cpf: cpfController.text.trim(),
                      guardianName: guardianNameController.text.trim(),
                      guardianCpf: guardianCpfController.text.trim(),
                    );
                  } else {
                    await _repository.updatePatient(
                      id: patient['id'],
                      name: nameController.text.trim(),
                      phone: phoneController.text.trim(),
                      cpf: cpfController.text.trim(),
                      guardianName: guardianNameController.text.trim(),
                      guardianCpf: guardianCpfController.text.trim(),
                    );
                  }

                  if (!mounted) return;
                  Navigator.pop(context);
                  _loadPatients();
                  _showMessage('Cliente salvo com sucesso');
                } catch (e) {
                  _showMessage('Erro ao salvar cliente: $e');
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deletePatient(String id) async {
    try {
      await _repository.deletePatient(id);
      _loadPatients();
      _showMessage('Cliente excluído com sucesso');
    } catch (e) {
      _showMessage('Erro ao excluir cliente: $e');
    }
  }

  void _confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Excluir cliente'),
          content: const Text('Tem certeza que deseja excluir este cliente?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _deletePatient(id);
              },
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clientes'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openPatientForm(),
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _patients.isEmpty
              ? const Center(child: Text('Nenhum cliente cadastrado'))
              : RefreshIndicator(
                  onRefresh: _loadPatients,
                  child: ListView.builder(
                    itemCount: _patients.length,
                    itemBuilder: (context, index) {
                      final patient = _patients[index];

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child:ListTile(
                          title: Text(patient['name'] ?? 'Sem nome'),

                          subtitle: Text(
                            'Telefone: ${patient['phone'] ?? '-'}\nCPF: ${patient['cpf'] ?? '-'}',
                          ),

                          isThreeLine: true,

                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ClientDetailsPage(
                                  clientId: patient['id'],
                                ),
                              ),
                            ).then((_) => _loadPatients());
                          },

                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') {
                                _openPatientForm(patient: patient);
                              }

                              if (value == 'delete') {
                                _confirmDelete(patient['id']);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'edit',
                                child: Text('Editar'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Excluir'),
                              ),
                            ],
                          ),
                        )
                      );
                    },
                  ),
                ),
    );
  }
}
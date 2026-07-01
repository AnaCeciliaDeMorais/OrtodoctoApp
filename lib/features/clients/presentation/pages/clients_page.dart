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
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _patients = [];
  String _searchQuery = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Widget> _buildPatientList() {
    final query = _searchQuery;
    final filteredPatients = query.isEmpty
        ? _patients
        : _patients.where((patient) {
            final name = (patient['name'] as String?)?.toLowerCase() ?? '';
            final phone = (patient['phone'] as String?)?.toLowerCase() ?? '';
            final cpf = (patient['cpf'] as String?)?.toLowerCase() ?? '';
            return name.contains(query) ||
                phone.contains(query) ||
                cpf.contains(query);
          }).toList();

    if (filteredPatients.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Text('Nenhum cliente encontrado.'),
        ),
      ];
    }

    return filteredPatients.map((patient) {
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: ListTile(
          title: Text(patient['name'] ?? 'Sem nome'),
          subtitle: Text(
            'Telefone: ${patient['phone'] ?? '-'}\nCPF: ${patient['cpf'] ?? '-'}',
          ),
          isThreeLine: true,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ClientDetailsPage(clientId: patient['id']),
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
              PopupMenuItem(value: 'edit', child: Text('Editar')),
              PopupMenuItem(value: 'delete', child: Text('Excluir')),
            ],
          ),
        ),
      );
    }).toList();
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
    final phoneController = TextEditingController(
      text: patient?['phone'] ?? '',
    );
    final cpfController = TextEditingController(text: patient?['cpf'] ?? '');
    final guardianNameController = TextEditingController(
      text: patient?['guardian_name'] ?? '',
    );
    final guardianCpfController = TextEditingController(
      text: patient?['guardian_cpf'] ?? '',
    );
    final emailController = TextEditingController(
      text: patient?['email'] ?? '',
    );
    final passwordController = TextEditingController();
    bool _createWithAccess = patient == null;

    showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
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
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      value: _createWithAccess,
                      onChanged: (value) {
                        setDialogState(() {
                          _createWithAccess = value ?? false;
                        });
                      },
                      title: const Text('Criar acesso ao app'),
                      subtitle: const Text('O cliente poderá acessar o app'),
                    ),
                    if (_createWithAccess) ...[
                      const Divider(),
                      TextField(
                        controller: emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email para acesso',
                          hintText: 'email@exemplo.com',
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      TextField(
                        controller: passwordController,
                        decoration: const InputDecoration(
                          labelText: 'Senha',
                          hintText: 'Mínimo 6 caracteres',
                        ),
                        obscureText: true,
                      ),
                    ],
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

                    if (_createWithAccess) {
                      final email = emailController.text.trim();
                      final password = passwordController.text.trim();

                      if (email.isEmpty || !email.contains('@')) {
                        _showMessage('Informe um email válido');
                        return;
                      }
                      if (password.length < 6) {
                        _showMessage('Senha deve ter no mínimo 6 caracteres');
                        return;
                      }
                    }

                    try {
                      if (patient == null) {
                        if (_createWithAccess) {
                          // Implement createPatientWithAuth in repository
                          await _repository.createPatient(
                            name: nameController.text.trim(),
                            phone: phoneController.text.trim(),
                            cpf: cpfController.text.trim(),
                            guardianName: guardianNameController.text.trim(),
                            guardianCpf: guardianCpfController.text.trim(),
                          );
                        } else {
                          await _repository.createPatient(
                            name: nameController.text.trim(),
                            phone: phoneController.text.trim(),
                            cpf: cpfController.text.trim(),
                            guardianName: guardianNameController.text.trim(),
                            guardianCpf: guardianCpfController.text.trim(),
                          );
                        }
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

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Clientes')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openPatientForm(),
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadPatients,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value.trim().toLowerCase();
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Pesquisar clientes',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchQuery = '';
                                  });
                                },
                                icon: const Icon(Icons.clear),
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),
                  if (_patients.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 24,
                      ),
                      child: Text('Nenhum cliente cadastrado'),
                    )
                  else ...[
                    ..._buildPatientList(),
                  ],
                ],
              ),
            ),
    );
  }
}

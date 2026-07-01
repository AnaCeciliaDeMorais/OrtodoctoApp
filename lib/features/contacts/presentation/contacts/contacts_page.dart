import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ContactsPage extends StatefulWidget {
  const ContactsPage({super.key});

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  final supabase = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> _companiesFuture;

  @override
  void initState() {
    super.initState();
    _companiesFuture = _getCompanies();
  }

  Future<String> _generateUniqueCompanyCode() async {
    final supabase = Supabase.instance.client;

    // Gera um código numérico de 3 dígitos baseado no timestamp e tenta garantir unicidade
    for (var i = 0; i < 10; i++) {
      final code = (DateTime.now().millisecondsSinceEpoch % 1000).toString().padLeft(3, '0');
      final exists = await supabase.from('companies').select('id').eq('code', code).limit(1).maybeSingle();
      if (exists == null) return code;
      await Future.delayed(const Duration(milliseconds: 50));
    }

    // Fallback: gerar código aleatório
    final randomCode = (DateTime.now().millisecondsSinceEpoch % 100000).toString();
    return randomCode;
  }

  Future<List<Map<String, dynamic>>> _getCompanies() async {
    try {
      final response = await supabase
          .from('companies')
          .select('id, name, location, code, created_by, created_at')
          .order('name', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Erro ao carregar empresas: $e');
      return [];
    }
  }

  void _openAddCompanySheet() {
    final nameController = TextEditingController();
    final locationController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Nova empresa',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nome da empresa',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: locationController,
                decoration: const InputDecoration(
                  labelText: 'Local',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  final location = locationController.text.trim();

                  if (name.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Informe o nome da empresa')),
                    );
                    return;
                  }

                  try {
                    final code = await _generateUniqueCompanyCode();
                    final payload = <String, dynamic>{
                      'name': name,
                      'location': location,
                      'code': code,
                    };

                    final currentUserId = supabase.auth.currentUser?.id;
                    if (currentUserId != null) {
                      payload['created_by'] = currentUserId;
                    }

                    await supabase.from('companies').insert(payload);

                    if (mounted) {
                      Navigator.pop(context);
                      setState(() {
                        _companiesFuture = _getCompanies();
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Empresa criada com sucesso')),
                      );
                    }
                  } catch (e) {
                    debugPrint('Erro ao criar empresa: $e');
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Não foi possível criar a empresa: $e')),
                      );
                    }
                  }
                },
                child: const Text('Salvar'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openCompanyPeople(Map<String, dynamic> company) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CompanyPeoplePage(company: company)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _companiesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Erro ao carregar: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _companiesFuture = _getCompanies();
                      });
                    },
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
            );
          }

          final companies = snapshot.data ?? [];

          if (companies.isEmpty) {
            return const Center(child: Text('Nenhuma empresa cadastrada.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: companies.length,
            itemBuilder: (context, index) {
              final company = companies[index];

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text('Empresa: ${company['name'] ?? ''}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Local: ${company['location'] ?? ''}'),
                      Text('Cod: ${company['code'] ?? ''}'),
                    ],
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openCompanyPeople(company),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddCompanySheet,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class CompanyPeoplePage extends StatefulWidget {
  final Map<String, dynamic> company;

  const CompanyPeoplePage({super.key, required this.company});

  @override
  State<CompanyPeoplePage> createState() => _CompanyPeoplePageState();
}

class _CompanyPeoplePageState extends State<CompanyPeoplePage> {
  final supabase = Supabase.instance.client;

  int selectedTab = 0;
  Map<String, dynamic>? selectedEmployee;

  String get companyId => widget.company['id'].toString();

  Future<List<Map<String, dynamic>>> _getClients() async {
    final response = await supabase
        .from('profiles')
        .select()
        .eq('company_id', companyId)
        .eq('profile_level', 'client')
        .order('nome', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> _getEmployees() async {
    final response = await supabase
        .from('profiles')
        .select()
        .eq('company_id', companyId)
        .eq('profile_level', 'staff_beta')
        .order('nome', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> _getEmployeeCash(String employeeId) async {
    final response = await supabase
        .from('cash_entries')
        .select()
        .eq('created_by', employeeId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  void _openAddPersonSheet() {
    final nameController = TextEditingController();
    final birthDateController = TextEditingController();
    final guardianNameController = TextEditingController();
    final cpfController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            bool createWithAccess = false;
            bool isMinor = false;
            String selectedProfileLevel = selectedTab == 0 ? 'client' : 'staff_beta';

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      selectedTab == 0 ? 'Novo cliente' : 'Novo funcionário',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nome',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (selectedTab == 0) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: birthDateController,
                        decoration: const InputDecoration(
                          labelText: 'Data de nascimento',
                          hintText: 'YYYY-MM-DD',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      CheckboxListTile(
                        value: isMinor,
                        onChanged: (value) {
                          setModalState(() {
                            isMinor = value ?? false;
                          });
                        },
                        title: const Text('Menor de idade'),
                        contentPadding: EdgeInsets.zero,
                      ),
                      if (isMinor) ...[
                        const SizedBox(height: 8),
                        TextField(
                          controller: guardianNameController,
                          decoration: const InputDecoration(
                            labelText: 'Nome do responsável',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ],
                    if (selectedTab == 1) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: cpfController,
                        decoration: const InputDecoration(
                          labelText: 'CPF',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedProfileLevel,
                        decoration: const InputDecoration(
                          labelText: 'Profile level',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'staff_beta',
                            child: Text('staff_beta'),
                          ),
                          DropdownMenuItem(
                            value: 'staff_alfa',
                            child: Text('staff_alfa'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setModalState(() {
                              selectedProfileLevel = value;
                            });
                          }
                        },
                      ),
                    ],
                    const SizedBox(height: 12),
                    StatefulBuilder(
                      builder: (context, setCheckboxState) {
                        return CheckboxListTile(
                          value: createWithAccess,
                          onChanged: (value) {
                            setCheckboxState(() {
                              createWithAccess = value ?? false;
                            });
                            setModalState(() {});
                          },
                          title: const Text('Criar acesso ao app'),
                          subtitle: const Text(
                            'O usuário poderá acessar o app com email e senha',
                          ),
                        );
                      },
                    ),
                    if (createWithAccess) ...[
                      const Divider(),
                      TextField(
                        controller: emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email para acesso',
                          hintText: 'email@exemplo.com',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: passwordController,
                        decoration: const InputDecoration(
                          labelText: 'Senha',
                          hintText: 'Mínimo 6 caracteres',
                          border: OutlineInputBorder(),
                        ),
                        obscureText: true,
                      ),
                    ],
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () async {
                        if (nameController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Informe o nome')),
                          );
                          return;
                        }

                        if (selectedTab == 0 && isMinor && guardianNameController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Informe o nome do responsável')),
                          );
                          return;
                        }

                        if (selectedTab == 1 && cpfController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Informe o CPF')),
                          );
                          return;
                        }

                        if (createWithAccess) {
                          final email = emailController.text.trim();
                          final password = passwordController.text.trim();

                          if (email.isEmpty || !email.contains('@')) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Informe um email válido'),
                              ),
                            );
                            return;
                          }
                          if (password.length < 6) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Senha deve ter no mínimo 6 caracteres',
                                ),
                              ),
                            );
                            return;
                          }
                        }

                        try {
                          final payload = <String, dynamic>{
                            'nome': nameController.text.trim(),
                            'company_id': companyId,
                            'is_active': true,
                            'profile_level': selectedTab == 0 ? 'client' : selectedProfileLevel,
                          };

                          if (selectedTab == 0) {
                            payload['birth_date'] = birthDateController.text.trim().isNotEmpty
                                ? birthDateController.text.trim()
                                : null;
                            if (isMinor) {
                              payload['guardian_name'] = guardianNameController.text.trim();
                            }
                          } else {
                            payload['cpf'] = cpfController.text.trim();
                            payload['profile_level'] = selectedProfileLevel;
                          }

                          if (createWithAccess) {
                            final authResponse = await supabase.auth.signUp(
                              email: emailController.text.trim(),
                              password: passwordController.text.trim(),
                            );

                            if (authResponse.user != null) {
                              final userId = authResponse.user!.id;
                              payload['id'] = userId;
                              payload['email'] = emailController.text.trim();
                              await supabase.from('profiles').insert(payload);

                              if (mounted) {
                                Navigator.pop(context);
                                setState(() {});
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '${selectedTab == 0 ? 'Cliente' : 'Funcionário'} criado com sucesso! Verifique o email para confirmar.',
                                    ),
                                  ),
                                );
                              }
                            }
                          } else {
                            await supabase.from('profiles').insert(payload);

                            if (mounted) {
                              Navigator.pop(context);
                              setState(() {});
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${selectedTab == 0 ? 'Cliente' : 'Funcionário'} salvo com sucesso',
                                  ),
                                ),
                              );
                            }
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('Erro: $e')));
                        }
                      },
                      child: const Text('Salvar'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildClients() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getClients(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final clients = snapshot.data!;

        if (clients.isEmpty) {
          return const Center(child: Text('Nenhum cliente cadastrado.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: clients.length,
          itemBuilder: (context, index) {
            final client = clients[index];

            return Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(client['nome'] ?? ''),
                subtitle: Text(client['telefone'] ?? ''),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmployees() {
    if (selectedEmployee != null) {
      return _buildEmployeeDetails();
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getEmployees(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final employees = snapshot.data!;

        if (employees.isEmpty) {
          return const Center(child: Text('Nenhum funcionário cadastrado.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: employees.length,
          itemBuilder: (context, index) {
            final employee = employees[index];

            return Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.badge)),
                title: Text(employee['nome'] ?? ''),
                subtitle: Text(employee['telefone'] ?? ''),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  setState(() {
                    selectedEmployee = employee;
                  });
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmployeeDetails() {
    final employeeId = selectedEmployee!['id'].toString();

    return Column(
      children: [
        ListTile(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              setState(() {
                selectedEmployee = null;
              });
            },
          ),
          title: Text(selectedEmployee!['nome'] ?? ''),
          subtitle: Text(selectedEmployee!['telefone'] ?? ''),
        ),
        const Divider(),
        const Padding(
          padding: EdgeInsets.all(16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Caixa do funcionário',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _getEmployeeCash(employeeId),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final entries = snapshot.data!;

              if (entries.isEmpty) {
                return const Center(
                  child: Text('Nenhuma movimentação encontrada.'),
                );
              }

              double totalIncome = 0.0;
              double totalExpense = 0.0;

              for (final entry in entries) {
                final raw = entry['value'];
                double v = 0.0;
                if (raw is num) {
                  v = raw.toDouble();
                } else if (raw is String) {
                  v = double.tryParse(raw) ?? 0.0;
                }

                final type = (entry['type'] as String?)?.toLowerCase();
                final status = (entry['status'] as String?)?.toLowerCase();

                bool isExpense = false;
                if (type != null && (type.contains('exp') || type.contains('saida') || type.contains('out') || type.contains('cost'))) {
                  isExpense = true;
                }
                if (status != null && (status.contains('saida') || status.contains('expense') || status.contains('out'))) {
                  isExpense = true;
                }
                if (!isExpense && v < 0) isExpense = true;

                if (isExpense) {
                  totalExpense += v.abs();
                } else {
                  totalIncome += v;
                }
              }

              final net = totalIncome - totalExpense;

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Total Entrada', style: TextStyle(fontWeight: FontWeight.bold)),
                                Text('R\$ ${totalIncome.toStringAsFixed(2)}'),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Text('Total Saída', style: TextStyle(fontWeight: FontWeight.bold)),
                                Text('R\$ ${totalExpense.toStringAsFixed(2)}'),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('Saldo', style: TextStyle(fontWeight: FontWeight.bold)),
                                Text('R\$ ${net.toStringAsFixed(2)}', style: TextStyle(color: net < 0 ? Colors.red : Colors.green)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        final entry = entries[index];

                        return Card(
                          child: ListTile(
                            title: Text(entry['description'] ?? 'Movimentação'),
                            subtitle: Text((entry['type'] ?? entry['status'] ?? '').toString()),
                            trailing: Text('R\$ ${entry['value'] ?? 0}'),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = selectedTab == 0 ? _buildClients() : _buildEmployees();

    return Scaffold(
      appBar: AppBar(title: Text(widget.company['name'] ?? 'Empresa')),
      body: Column(
        children: [
          const SizedBox(height: 12),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(
                value: 0,
                label: Text('Clientes'),
                icon: Icon(Icons.people),
              ),
              ButtonSegment(
                value: 1,
                label: Text('Funcionários'),
                icon: Icon(Icons.badge),
              ),
            ],
            selected: {selectedTab},
            onSelectionChanged: (value) {
              setState(() {
                selectedTab = value.first;
                selectedEmployee = null;
              });
            },
          ),
          Expanded(child: body),
        ],
      ),
      floatingActionButton: selectedEmployee == null
          ? FloatingActionButton(
              onPressed: _openAddPersonSheet,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

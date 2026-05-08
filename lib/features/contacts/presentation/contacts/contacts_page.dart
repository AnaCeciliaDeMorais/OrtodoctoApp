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

  Future<List<Map<String, dynamic>>> _getCompanies() async {
    try {
      final response = await supabase
          .from('companies')
          .select()
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
    final codeController = TextEditingController();

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
              const SizedBox(height: 12),
              TextField(
                controller: codeController,
                decoration: const InputDecoration(
                  labelText: 'Código',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  if (nameController.text.trim().isEmpty) return;

                  await supabase.from('companies').insert({
                    'name': nameController.text.trim(),
                    'location': locationController.text.trim(),
                    'code': codeController.text.trim(),
                  });

                  if (mounted) {
                    Navigator.pop(context);
                    setState(() {});
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
        .eq('role', 'client')
        .order('name', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> _getEmployees() async {
    final response = await supabase
        .from('profiles')
        .select()
        .eq('company_id', companyId)
        .eq('role', 'staff_beta')
        .order('name', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> _getEmployeeCash(String employeeId) async {
    final response = await supabase
        .from('cash_entries')
        .select()
        .eq('staff_id', employeeId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  void _openAddPersonSheet() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    final role = selectedTab == 0 ? 'client' : 'staff_beta';

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
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Telefone',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  if (nameController.text.trim().isEmpty) return;

                  await supabase.from('profiles').insert({
                    'name': nameController.text.trim(),
                    'phone': phoneController.text.trim(),
                    'role': role,
                    'company_id': companyId,
                  });

                  if (mounted) {
                    Navigator.pop(context);
                    setState(() {});
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
                title: Text(client['name'] ?? ''),
                subtitle: Text(client['phone'] ?? ''),
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
                title: Text(employee['name'] ?? ''),
                subtitle: Text(employee['phone'] ?? ''),
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
          title: Text(selectedEmployee!['name'] ?? ''),
          subtitle: Text(selectedEmployee!['phone'] ?? ''),
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

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  final entry = entries[index];

                  return Card(
                    child: ListTile(
                      title: Text(entry['description'] ?? 'Movimentação'),
                      subtitle: Text(entry['type'] ?? ''),
                      trailing: Text('R\$ ${entry['value'] ?? 0}'),
                    ),
                  );
                },
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

import 'package:flutter/material.dart';

import '../../app/session.dart';
import '../../core/widgets/common.dart';
import '../../shared/models/models.dart';
import '../home/company_switcher.dart';
import 'product_card.dart';
import 'product_form_sheet.dart';
import 'products_repository.dart';

enum _Filter { all, promo, inactive }

/// Produtos e tratamentos da empresa. Promoções e itens fixados aparecem em
/// destaque no topo. Funcionário e chefe cadastram; cliente só vê.
class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  final _repo = ProductsRepository();
  final _loader = GlobalKey<AsyncLoaderState<List<Product>>>();
  _Filter _filter = _Filter.all;
  String _query = '';

  Future<void> _edit(Company company, [Product? p]) async {
    final saved = await showFormSheet<bool>(context, (_) => ProductFormSheet(companyId: company.id, product: p));
    if (saved == true) _loader.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    return RequireCompany(
      title: 'Produtos',
      child: Builder(builder: (context) {
        final session = SessionScope.of(context);
        final company = session.current!;
        final manager = session.isManager;
        return Scaffold(
          appBar: AppBar(title: const CompanyTitle('Produtos e promoções')),
          floatingActionButton: manager
              ? FloatingActionButton.extended(
                  onPressed: () => _edit(company),
                  icon: const Icon(Icons.add),
                  label: const Text('Novo produto'),
                )
              : null,
          body: AsyncLoader<List<Product>>(
            key: _loader,
            load: () => _repo.list(company.id),
            builder: (context, all, _) {
              final visible = all.where((p) {
                if (_query.isNotEmpty && !p.name.toLowerCase().contains(_query.toLowerCase())) return false;
                return switch (_filter) {
                  _Filter.all => manager || p.active,
                  _Filter.promo => p.onPromotion && p.active,
                  _Filter.inactive => !p.active,
                };
              }).toList();
              final highlights = all.where((p) => p.active && (p.onPromotion || p.featured)).toList();

              return CustomScrollView(slivers: [
                if (highlights.isNotEmpty && _filter == _Filter.all && _query.isEmpty) ...[
                  const SliverToBoxAdapter(child: SectionTitle('Em destaque')),
                  SliverToBoxAdapter(
                    child: ContentWidth(
                      child: PromoBanner(
                        products: highlights,
                        onTap: (p) => manager ? _edit(company, p) : showProductDetail(context, p),
                      ),
                    ),
                  ),
                ],
                SliverToBoxAdapter(
                  child: ContentWidth(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Column(children: [
                        TextField(
                          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Buscar'),
                          onChanged: (q) => setState(() => _query = q.trim()),
                        ),
                        const SizedBox(height: 8),
                        Wrap(spacing: 6, children: [
                          ChoiceChip(
                            label: const Text('Todos'),
                            selected: _filter == _Filter.all,
                            onSelected: (_) => setState(() => _filter = _Filter.all),
                          ),
                          ChoiceChip(
                            label: const Text('Promoções'),
                            selected: _filter == _Filter.promo,
                            onSelected: (_) => setState(() => _filter = _Filter.promo),
                          ),
                          if (manager)
                            ChoiceChip(
                              label: const Text('Inativos'),
                              selected: _filter == _Filter.inactive,
                              onSelected: (_) => setState(() => _filter = _Filter.inactive),
                            ),
                        ]),
                      ]),
                    ),
                  ),
                ),
                if (visible.isEmpty)
                  SliverToBoxAdapter(
                    child: EmptyState(
                      icon: Icons.storefront_outlined,
                      message: all.isEmpty
                          ? (manager ? 'Cadastre os produtos e tratamentos da empresa.' : 'Nenhum produto disponível.')
                          : 'Nenhum produto neste filtro.',
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 260,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.72,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          final p = visible[i];
                          return ProductCard(
                            product: p,
                            showAdminBadges: manager,
                            onTap: () => manager ? _edit(company, p) : showProductDetail(context, p),
                          );
                        },
                        childCount: visible.length,
                      ),
                    ),
                  ),
              ]);
            },
          ),
        );
      }),
    );
  }
}

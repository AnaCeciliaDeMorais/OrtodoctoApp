import 'package:flutter/material.dart';

import '../../core/formatters.dart' as f;
import '../../core/theme.dart';
import '../../shared/models/models.dart';

class ProductImage extends StatelessWidget {
  const ProductImage({super.key, required this.url, this.fit = BoxFit.cover});
  final String? url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(Icons.image_outlined, size: 40, color: Theme.of(context).colorScheme.onSurfaceVariant),
    );
    if (url == null) return placeholder;
    return Image.network(
      url!,
      fit: fit,
      errorBuilder: (_, _, _) => placeholder,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}

class PromoBadge extends StatelessWidget {
  const PromoBadge(this.product, {super.key});
  final Product product;

  @override
  Widget build(BuildContext context) {
    final pct = product.discountPercent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: AppTheme.promo, borderRadius: BorderRadius.circular(6)),
      child: Text(pct == null ? 'PROMOÇÃO' : 'PROMOÇÃO −$pct%',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
    );
  }
}

class PriceText extends StatelessWidget {
  const PriceText(this.product, {super.key, this.large = false});
  final Product product;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final t = large ? Theme.of(context).textTheme.titleLarge : Theme.of(context).textTheme.titleSmall;
    final promo = product.onPromotion && product.promoPrice != null;
    return Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, children: [
      if (promo)
        Text(f.money(product.price),
            style: TextStyle(
                decoration: TextDecoration.lineThrough,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: large ? 14 : 12)),
      Text(product.currentPrice == 0 ? 'Consulte' : f.money(product.currentPrice),
          style: t?.copyWith(fontWeight: FontWeight.bold, color: promo ? AppTheme.promo : null)),
    ]);
  }
}

/// Cartão da vitrine. Promoções ganham borda e selo em destaque.
class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product, this.onTap, this.showAdminBadges = false});
  final Product product;
  final VoidCallback? onTap;
  final bool showAdminBadges;

  @override
  Widget build(BuildContext context) {
    final p = product;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: p.onPromotion ? AppTheme.promo : scheme.outlineVariant, width: p.onPromotion ? 2 : 1),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Stack(fit: StackFit.expand, children: [
              Opacity(opacity: p.active ? 1 : 0.4, child: ProductImage(url: p.imageUrl)),
              if (p.onPromotion) Positioned(left: 8, top: 8, child: PromoBadge(p)),
              if (p.featured)
                Positioned(
                  right: 6,
                  top: 6,
                  child: CircleAvatar(
                    radius: 14,
                    backgroundColor: scheme.primary,
                    child: Icon(Icons.push_pin, size: 16, color: scheme.onPrimary),
                  ),
                ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              PriceText(p),
              if (p.onPromotion && p.promoUntil != null)
                Text('Até ${f.date(p.promoUntil)}', style: const TextStyle(fontSize: 11)),
              if (showAdminBadges && !p.active)
                Text('Inativo (cliente não vê)', style: TextStyle(fontSize: 11, color: scheme.error)),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Banner grande das promoções no topo da vitrine.
class PromoBanner extends StatefulWidget {
  const PromoBanner({super.key, required this.products, required this.onTap});
  final List<Product> products;
  final ValueChanged<Product> onTap;

  @override
  State<PromoBanner> createState() => _PromoBannerState();
}

class _PromoBannerState extends State<PromoBanner> {
  final _controller = PageController(viewportFraction: 0.92);
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.products;
    return Column(children: [
      SizedBox(
        height: 210,
        child: PageView.builder(
          controller: _controller,
          itemCount: items.length,
          onPageChanged: (i) => setState(() => _page = i),
          itemBuilder: (context, i) {
            final p = items[i];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: () => widget.onTap(p),
                  child: Stack(fit: StackFit.expand, children: [
                    ProductImage(url: p.imageUrl),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black87],
                        ),
                      ),
                    ),
                    Positioned(left: 12, top: 12, child: PromoBadge(p)),
                    Positioned(
                      left: 14,
                      right: 14,
                      bottom: 12,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(p.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                        Row(children: [
                          if (p.promoPrice != null && p.promoPrice! < p.price) ...[
                            Text(f.money(p.price),
                                style: const TextStyle(
                                    color: Colors.white70, decoration: TextDecoration.lineThrough)),
                            const SizedBox(width: 8),
                          ],
                          Text(f.money(p.currentPrice),
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          if (p.promoUntil != null) ...[
                            const Spacer(),
                            Text('até ${f.date(p.promoUntil)}', style: const TextStyle(color: Colors.white70)),
                          ],
                        ]),
                      ]),
                    ),
                  ]),
                ),
              ),
            );
          },
        ),
      ),
      if (items.length > 1)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < items.length; i++)
              Container(
                width: i == _page ? 16 : 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: i == _page ? AppTheme.promo : Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
          ]),
        ),
    ]);
  }
}

Future<void> showProductDetail(BuildContext context, Product p) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        builder: (ctx, scroll) => ListView(controller: scroll, children: [
          AspectRatio(aspectRatio: 4 / 3, child: ProductImage(url: p.imageUrl)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (p.onPromotion) ...[PromoBadge(p), const SizedBox(height: 8)],
              Text(p.name, style: Theme.of(ctx).textTheme.headlineSmall),
              if (p.category != null) Text(p.category!, style: Theme.of(ctx).textTheme.bodySmall),
              const SizedBox(height: 8),
              PriceText(p, large: true),
              if (p.onPromotion && p.promoUntil != null) Text('Promoção válida até ${f.date(p.promoUntil)}'),
              const SizedBox(height: 16),
              if (p.description != null) Text(p.description!),
            ]),
          ),
        ]),
      ),
    );

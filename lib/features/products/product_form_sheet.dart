import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/formatters.dart' as f;
import '../../core/validators.dart';
import '../../core/widgets/common.dart';
import '../../shared/models/models.dart';
import 'product_card.dart';
import 'products_repository.dart';

/// Cadastro / edição de produto ou tratamento, com foto e promoção.
class ProductFormSheet extends StatefulWidget {
  const ProductFormSheet({super.key, required this.companyId, this.product});
  final String companyId;
  final Product? product;

  @override
  State<ProductFormSheet> createState() => _ProductFormSheetState();
}

class _ProductFormSheetState extends State<ProductFormSheet> {
  final _repo = ProductsRepository();
  final _form = GlobalKey<FormState>();
  late final p = widget.product;
  late final _name = TextEditingController(text: p?.name);
  late final _desc = TextEditingController(text: p?.description);
  late final _category = TextEditingController(text: p?.category);
  late final _price = TextEditingController(text: f.moneyInput(p?.price));
  late final _promoPrice = TextEditingController(text: f.moneyInput(p?.promoPrice));
  late bool _promo = p?.isPromotion ?? false;
  late DateTime? _promoUntil = p?.promoUntil;
  late bool _featured = p?.featured ?? false;
  late bool _active = p?.active ?? true;

  // Foto: a atual (url/caminho) ou uma nova escolhida (bytes).
  late final String? _imageUrl = p?.imageUrl;
  late final String? _imagePath = p?.imagePath;
  Uint8List? _newImage;
  String _newImageType = 'image/jpeg';
  bool _removeImage = false;
  bool _saving = false;

  Future<void> _pick(ImageSource source) async {
    final file = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 85);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _newImage = bytes;
      _newImageType = file.mimeType ?? (file.name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg');
      _removeImage = false;
    });
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final price = f.parseMoney(_price.text) ?? 0;
    final promoPrice = _promo ? f.parseMoney(_promoPrice.text) : null;
    if (_promo && promoPrice != null && price > 0 && promoPrice >= price) {
      showSnack(context, 'O preço promocional precisa ser menor que o normal.', error: true);
      return;
    }
    setState(() => _saving = true);
    final oldPath = p?.imagePath;
    final ok = await runGuarded(context, () async {
      var url = _removeImage ? null : _imageUrl;
      var path = _removeImage ? null : _imagePath;
      if (_newImage != null) {
        final up = await _repo.uploadImage(widget.companyId, _newImage!, _newImageType);
        path = up.$1;
        url = up.$2;
      }
      await _repo.save(
        id: p?.id,
        companyId: widget.companyId,
        name: _name.text.trim(),
        description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
        category: _category.text.trim().isEmpty ? null : _category.text.trim(),
        price: price,
        isPromotion: _promo,
        promoPrice: promoPrice,
        promoUntil: _promoUntil,
        featured: _featured,
        active: _active,
        imageUrl: url,
        imagePath: path,
      );
      if (oldPath != null && oldPath != path) await _repo.removeImage(oldPath);
    }, success: 'Produto salvo.');
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context, true);
  }

  Future<void> _delete() async {
    if (!await confirm(context, 'Excluir produto', 'Excluir "${p!.name}"? Para só esconder dos clientes, desative.',
        ok: 'Excluir', danger: true)) {
      return;
    }
    if (!mounted) return;
    if (await runGuarded(context, () => _repo.delete(p!), success: 'Produto excluído.')) {
      if (mounted) Navigator.pop(context, true);
    }
  }

  Widget _imagePreview() {
    Widget content;
    if (_newImage != null) {
      content = Image.memory(_newImage!, fit: BoxFit.cover);
    } else if (_imageUrl != null && !_removeImage) {
      content = ProductImage(url: _imageUrl);
    } else {
      content = const ProductImage(url: null);
    }
    return ClipRRect(borderRadius: BorderRadius.circular(12), child: AspectRatio(aspectRatio: 4 / 3, child: content));
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = _newImage != null || (_imageUrl != null && !_removeImage);
    return Form(
      key: _form,
      child: FormSheet(
        title: p == null ? 'Novo produto' : 'Editar produto',
        saving: _saving,
        onSave: _save,
        extraActions: [
          if (p != null) IconButton(tooltip: 'Excluir', icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
        children: [
          _imagePreview(),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(hasImage ? 'Trocar foto' : 'Escolher foto'),
              onPressed: () => _pick(ImageSource.gallery),
            ),
            if (!kIsWeb)
              OutlinedButton.icon(
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Câmera'),
                onPressed: () => _pick(ImageSource.camera),
              ),
            if (hasImage)
              TextButton.icon(
                icon: const Icon(Icons.hide_image_outlined),
                label: const Text('Remover foto'),
                onPressed: () => setState(() {
                  _newImage = null;
                  _removeImage = true;
                }),
              ),
          ]),
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Nome do produto ou tratamento'),
            validator: Validators.required,
          ),
          TextFormField(
            controller: _category,
            decoration: const InputDecoration(labelText: 'Categoria (opcional)', hintText: 'Ex.: Clareamento'),
          ),
          TextFormField(
            controller: _desc,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Descrição'),
          ),
          TextFormField(
            controller: _price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
                labelText: 'Preço', prefixText: r'R$ ', helperText: 'Deixe 0 para mostrar "Consulte"'),
            validator: (v) => Validators.money(v, allowZero: true),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.local_offer_outlined),
            title: const Text('Em promoção'),
            subtitle: const Text('Aparece em destaque no topo da vitrine'),
            value: _promo,
            onChanged: (v) => setState(() => _promo = v),
          ),
          if (_promo) ...[
            TextFormField(
              controller: _promoPrice,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Preço promocional', prefixText: r'R$ '),
              validator: (v) => (v == null || v.trim().isEmpty) ? null : Validators.money(v),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.event),
              label: Text(_promoUntil == null ? 'Sem data de término' : 'Válida até ${f.date(_promoUntil)}'),
              onPressed: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _promoUntil ?? DateTime.now().add(const Duration(days: 30)),
                  firstDate: DateTime.now().subtract(const Duration(days: 1)),
                  lastDate: DateTime(2100),
                );
                setState(() => _promoUntil = d);
              },
            ),
          ],
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.push_pin_outlined),
            title: const Text('Fixar no topo'),
            subtitle: const Text('Mostra este item primeiro, mesmo fora de promoção'),
            value: _featured,
            onChanged: (v) => setState(() => _featured = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.visibility_outlined),
            title: const Text('Visível para clientes'),
            value: _active,
            onChanged: (v) => setState(() => _active = v),
          ),
        ],
      ),
    );
  }
}

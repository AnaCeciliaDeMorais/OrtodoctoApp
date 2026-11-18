import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Gerador simples de planilha .xlsx (uma aba), sem dependências pesadas.
/// Abre no Excel, Google Planilhas e LibreOffice.

/// Estilos disponíveis (índices do styles.xml abaixo).
enum XStyle {
  normal, // 0
  title, // 1  faixa verde, branco, grande
  band, // 2  faixa verde, branco, negrito
  bandSmall, // 3  faixa verde, branco, pequeno
  header, // 4  cabeçalho da tabela
  text, // 5
  textAlt, // 6  linha zebrada
  money, // 7
  moneyAlt, // 8
  date, // 9
  dateAlt, // 10
  label, // 11 negrito
  labelMoney, // 12 negrito + moeda
  sectionTitle, // 13 negrito, borda de baixo
  number, // 14 inteiro
  labelNumber, // 15 negrito inteiro
  bandRight, // 16 faixa verde, branco pequeno, à direita
  numberRow, // 17 inteiro em linha da tabela
  numberAlt, // 18 inteiro em linha zebrada
}

class XCell {
  const XCell.text(this.text, [this.style = XStyle.text]) : number = null, date = null;
  const XCell.money(double this.number, [this.style = XStyle.money]) : text = null, date = null;
  const XCell.number(num this.number, [this.style = XStyle.number]) : text = null, date = null;
  const XCell.date(DateTime this.date, [this.style = XStyle.date]) : text = null, number = null;
  const XCell.empty([this.style = XStyle.normal]) : text = null, number = null, date = null;

  final String? text;
  final num? number;
  final DateTime? date;
  final XStyle style;
}

class XSheet {
  XSheet(this.name, {required this.columnWidths});
  final String name;
  final List<double> columnWidths;
  final Map<int, Map<int, XCell>> _rows = {};
  final Map<int, double> _heights = {};
  final List<String> _merges = [];

  /// [row] e [col] começam em 0.
  void set(int row, int col, XCell cell) => (_rows[row] ??= {})[col] = cell;

  void height(int row, double h) => _heights[row] = h;

  /// Junta células da mesma linha (de [c1] até [c2]).
  void merge(int row, int c1, int c2) => _merges.add('${ref(row, c1)}:${ref(row, c2)}');

  static String col(int c) {
    var n = c + 1;
    var s = '';
    while (n > 0) {
      final m = (n - 1) % 26;
      s = String.fromCharCode(65 + m) + s;
      n = (n - 1) ~/ 26;
    }
    return s;
  }

  static String ref(int row, int c) => '${col(c)}${row + 1}';

  String _xml() {
    final b = StringBuffer()
      ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
      ..write('<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
          'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">')
      ..write('<sheetPr><pageSetUpPr fitToPage="1"/></sheetPr>')
      ..write('<sheetViews><sheetView workbookViewId="0" showGridLines="0"/></sheetViews>')
      ..write('<sheetFormatPr defaultRowHeight="18"/>')
      ..write('<cols>');
    for (var i = 0; i < columnWidths.length; i++) {
      b.write('<col min="${i + 1}" max="${i + 1}" width="${columnWidths[i]}" customWidth="1"/>');
    }
    b.write('</cols><sheetData>');
    final rowIdx = _rows.keys.toList()..sort();
    for (final r in rowIdx) {
      final h = _heights[r];
      b.write('<row r="${r + 1}"${h != null ? ' ht="$h" customHeight="1"' : ''}>');
      final cells = _rows[r]!;
      final cols = cells.keys.toList()..sort();
      for (final c in cols) {
        final cell = cells[c]!;
        final s = cell.style.index;
        final at = ref(r, c);
        if (cell.text != null) {
          b.write('<c r="$at" s="$s" t="inlineStr"><is><t xml:space="preserve">${_esc(cell.text!)}</t></is></c>');
        } else if (cell.number != null) {
          b.write('<c r="$at" s="$s"><v>${cell.number}</v></c>');
        } else if (cell.date != null) {
          b.write('<c r="$at" s="$s"><v>${_serial(cell.date!)}</v></c>');
        } else {
          b.write('<c r="$at" s="$s"/>');
        }
      }
      b.write('</row>');
    }
    b.write('</sheetData>');
    if (_merges.isNotEmpty) {
      b.write('<mergeCells count="${_merges.length}">');
      for (final m in _merges) {
        b.write('<mergeCell ref="$m"/>');
      }
      b.write('</mergeCells>');
    }
    b.write('<pageMargins left="0.4" right="0.4" top="0.5" bottom="0.5" header="0.3" footer="0.3"/>');
    b.write('<pageSetup orientation="landscape" paperSize="9" fitToWidth="1" fitToHeight="0"/>');
    b.write('</worksheet>');
    return b.toString();
  }

  /// Data do Excel: dias desde 30/12/1899.
  static int _serial(DateTime d) =>
      DateTime.utc(d.year, d.month, d.day).difference(DateTime.utc(1899, 12, 30)).inDays;

  Uint8List toBytes() {
    final archive = Archive()
      ..addFile(ArchiveFile.string('[Content_Types].xml', _contentTypes))
      ..addFile(ArchiveFile.string('_rels/.rels', _rels))
      ..addFile(ArchiveFile.string('xl/workbook.xml', _workbook(name)))
      ..addFile(ArchiveFile.string('xl/_rels/workbook.xml.rels', _workbookRels))
      ..addFile(ArchiveFile.string('xl/styles.xml', _styles))
      ..addFile(ArchiveFile.string('xl/worksheets/sheet1.xml', _xml()));
    return ZipEncoder().encodeBytes(archive);
  }
}

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');

const _contentTypes = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
    '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
    '<Default Extension="xml" ContentType="application/xml"/>'
    '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
    '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
    '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
    '</Types>';

const _rels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
    '</Relationships>';

String _workbook(String sheetName) => '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
    'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
    '<sheets><sheet name="${_esc(sheetName.length > 31 ? sheetName.substring(0, 31) : sheetName)}" sheetId="1" r:id="rId1"/></sheets>'
    '</workbook>';

const _workbookRels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>'
    '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
    '</Relationships>';

// Fontes: 0 normal, 1 título branco 20, 2 branco negrito 11, 3 branco 9,
//         4 cinza escuro 10 (cabeçalho), 5 negrito.
// Preenchimentos: 0 none, 1 gray125 (obrigatórios), 2 verde, 3 cinza claro (zebra), 4 cinza cabeçalho.
// Bordas: 0 nenhuma, 1 linha fina à direita (colunas), 2 linha embaixo.
// Formatos: 164 moeda R$, 165 data dd/mm/aaaa.
const _styles = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
    '<numFmts count="2">'
    '<numFmt numFmtId="164" formatCode="&quot;R\$&quot;\\ #,##0.00"/>'
    '<numFmt numFmtId="165" formatCode="dd/mm/yyyy"/>'
    '</numFmts>'
    '<fonts count="6">'
    '<font><sz val="10"/><name val="Arial"/></font>'
    '<font><sz val="20"/><color rgb="FFFFFFFF"/><name val="Arial"/></font>'
    '<font><b/><sz val="11"/><color rgb="FFFFFFFF"/><name val="Arial"/></font>'
    '<font><sz val="9"/><color rgb="FFFFFFFF"/><name val="Arial"/></font>'
    '<font><sz val="10"/><color rgb="FF424242"/><name val="Arial"/></font>'
    '<font><b/><sz val="10"/><name val="Arial"/></font>'
    '</fonts>'
    '<fills count="5">'
    '<fill><patternFill patternType="none"/></fill>'
    '<fill><patternFill patternType="gray125"/></fill>'
    '<fill><patternFill patternType="solid"><fgColor rgb="FF0F9D58"/><bgColor indexed="64"/></patternFill></fill>'
    '<fill><patternFill patternType="solid"><fgColor rgb="FFF3F3F3"/><bgColor indexed="64"/></patternFill></fill>'
    '<fill><patternFill patternType="solid"><fgColor rgb="FFE8E8E8"/><bgColor indexed="64"/></patternFill></fill>'
    '</fills>'
    '<borders count="3">'
    '<border><left/><right/><top/><bottom/><diagonal/></border>'
    '<border><left/><right style="thin"><color rgb="FFC8C8C8"/></right><top/><bottom/><diagonal/></border>'
    '<border><left/><right/><top/><bottom style="thin"><color rgb="FF9E9E9E"/></bottom><diagonal/></border>'
    '</borders>'
    '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
    '<cellXfs count="19">'
    // 0 normal
    '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
    // 1 title
    '<xf numFmtId="0" fontId="1" fillId="2" borderId="0" xfId="0" applyFont="1" applyFill="1"><alignment vertical="center"/></xf>'
    // 2 band
    '<xf numFmtId="0" fontId="2" fillId="2" borderId="0" xfId="0" applyFont="1" applyFill="1"><alignment vertical="center"/></xf>'
    // 3 bandSmall
    '<xf numFmtId="0" fontId="3" fillId="2" borderId="0" xfId="0" applyFont="1" applyFill="1"><alignment vertical="center"/></xf>'
    // 4 header
    '<xf numFmtId="0" fontId="4" fillId="4" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1"><alignment vertical="center" wrapText="1"/></xf>'
    // 5 text
    '<xf numFmtId="0" fontId="0" fillId="0" borderId="1" xfId="0" applyBorder="1"><alignment vertical="center"/></xf>'
    // 6 textAlt
    '<xf numFmtId="0" fontId="0" fillId="3" borderId="1" xfId="0" applyFill="1" applyBorder="1"><alignment vertical="center"/></xf>'
    // 7 money
    '<xf numFmtId="164" fontId="0" fillId="0" borderId="1" xfId="0" applyNumberFormat="1" applyBorder="1"><alignment vertical="center"/></xf>'
    // 8 moneyAlt
    '<xf numFmtId="164" fontId="0" fillId="3" borderId="1" xfId="0" applyNumberFormat="1" applyFill="1" applyBorder="1"><alignment vertical="center"/></xf>'
    // 9 date
    '<xf numFmtId="165" fontId="0" fillId="0" borderId="1" xfId="0" applyNumberFormat="1" applyBorder="1"><alignment horizontal="left" vertical="center"/></xf>'
    // 10 dateAlt
    '<xf numFmtId="165" fontId="0" fillId="3" borderId="1" xfId="0" applyNumberFormat="1" applyFill="1" applyBorder="1"><alignment horizontal="left" vertical="center"/></xf>'
    // 11 label
    '<xf numFmtId="0" fontId="5" fillId="0" borderId="0" xfId="0" applyFont="1"/>'
    // 12 labelMoney
    '<xf numFmtId="164" fontId="5" fillId="0" borderId="0" xfId="0" applyNumberFormat="1" applyFont="1"/>'
    // 13 sectionTitle
    '<xf numFmtId="0" fontId="5" fillId="0" borderId="2" xfId="0" applyFont="1" applyBorder="1"/>'
    // 14 number
    '<xf numFmtId="1" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"><alignment horizontal="left"/></xf>'
    // 15 labelNumber
    '<xf numFmtId="1" fontId="5" fillId="0" borderId="0" xfId="0" applyNumberFormat="1" applyFont="1"><alignment horizontal="left"/></xf>'
    // 16 bandRight
    '<xf numFmtId="0" fontId="3" fillId="2" borderId="0" xfId="0" applyFont="1" applyFill="1"><alignment horizontal="right" vertical="center"/></xf>'
    // 17 numberRow
    '<xf numFmtId="1" fontId="0" fillId="0" borderId="1" xfId="0" applyNumberFormat="1" applyBorder="1"><alignment horizontal="left" vertical="center"/></xf>'
    // 18 numberAlt
    '<xf numFmtId="1" fontId="0" fillId="3" borderId="1" xfId="0" applyNumberFormat="1" applyFill="1" applyBorder="1"><alignment horizontal="left" vertical="center"/></xf>'
    '</cellXfs>'
    '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>'
    '</styleSheet>';

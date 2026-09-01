import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../models/category.dart';
import '../../models/product.dart';
import '../../services/category_repository.dart';
import '../../services/product_repository.dart';
import '../../services/reports_repository.dart';
import '../../services/stock_movement_repository.dart';
import '../../utils/currency_format_cl.dart';
import '../../widgets/currency_text.dart';
import '../../widgets/error_state.dart';
import '../../widgets/loading_indicator.dart';

enum ReportRange { today, week, month, year, custom }

const _monthAbbrevEs = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

String _formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final ReportsRepository _repository = ReportsRepository();
  final StockMovementRepository _stockMovementRepository = StockMovementRepository();
  final ProductRepository _productRepository = ProductRepository();
  final CategoryRepository _categoryRepository = CategoryRepository();
  ReportRange _range = ReportRange.today;
  DateTimeRange? _customRange;
  SalesSummary? _summary;
  double? _previousTotal;
  List<NamedTotal> _byCategory = [];
  List<NamedTotal> _byEmployee = [];
  List<ModifierUsage> _byModifier = [];
  double _inboundCostTotal = 0;
  // Estos tres son un estado del inventario ahora mismo (no dependen del
  // rango de fechas elegido arriba): venta de hoy vs. ayer, y qué
  // productos están sin stock o con stock bajo en este momento.
  double _todayTotal = 0;
  double _yesterdayTotal = 0;
  List<Product> _outOfStockProducts = [];
  List<Product> _lowStockProducts = [];
  List<Product> _nearExpiryProducts = [];
  List<Category> _categories = [];
  // Filtro de categoría para las 3 grillas de estado del inventario (sin
  // stock, stock bajo, por vencer) — null muestra todas las categorías.
  String? _statusCategoryFilter;
  bool _loading = true;
  String? _error;

  static const _paymentLabels = {
    'cash': 'Efectivo',
    'card': 'Tarjeta',
    'other': 'Otro',
  };

  @override
  void initState() {
    super.initState();
    _load();
    // Independiente del resto de _load(): las categorías no dependen del
    // rango de fechas elegido y casi nunca cambian, así que no hace falta
    // volver a pedirlas cada vez que se recarga el resto de Reportes.
    _categoryRepository.getAll().then((categories) {
      if (mounted) setState(() => _categories = categories);
    });
  }

  List<Product> _filterByCategory(List<Product> products) {
    final categoryId = _statusCategoryFilter;
    if (categoryId == null) return products;
    return products.where((p) => p.categoryId == categoryId).toList();
  }

  DateTime get _fromDate {
    final now = DateTime.now();
    switch (_range) {
      case ReportRange.today:
        return DateTime(now.year, now.month, now.day);
      case ReportRange.week:
        return DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
      case ReportRange.month:
        return DateTime(now.year, now.month, 1);
      case ReportRange.year:
        return DateTime(now.year, 1, 1);
      case ReportRange.custom:
        return _customRange?.start ?? DateTime(now.year, now.month, now.day);
    }
  }

  DateTime get _toDate {
    if (_range == ReportRange.custom && _customRange != null) {
      final end = _customRange!.end;
      return DateTime(end.year, end.month, end.day, 23, 59, 59);
    }
    return DateTime.now();
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
      initialDateRange: _customRange ?? DateTimeRange(start: _fromDate, end: now),
    );
    if (picked == null) return;
    setState(() {
      _range = ReportRange.custom;
      _customRange = picked;
    });
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final from = _fromDate;
    final to = _toDate;
    final duration = to.difference(from);
    final previousTo = from.subtract(const Duration(seconds: 1));
    final previousFrom = previousTo.subtract(duration);

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final yesterdayStart = todayStart.subtract(const Duration(days: 1));
    final yesterdayEnd = todayStart.subtract(const Duration(seconds: 1));

    try {
      final results = await Future.wait([
        _repository.getSummary(from: from, to: to),
        _repository.getTotalSales(from: previousFrom, to: previousTo),
        _repository.getByCategory(from: from, to: to),
        _repository.getByEmployee(from: from, to: to),
        _repository.getByModifier(from: from, to: to),
        _stockMovementRepository.getInboundCostTotal(from: from, to: to),
        _repository.getTotalSales(from: todayStart, to: now),
        _repository.getTotalSales(from: yesterdayStart, to: yesterdayEnd),
        _productRepository.getOutOfStockProducts(),
        _productRepository.getLowStockCandidates(),
        _productRepository.getProductsWithExpiration(),
      ]).timeout(const Duration(seconds: 15));
      if (!mounted) return;
      setState(() {
        _summary = results[0] as SalesSummary;
        _previousTotal = results[1] as double;
        _byCategory = results[2] as List<NamedTotal>;
        _byEmployee = results[3] as List<NamedTotal>;
        _byModifier = results[4] as List<ModifierUsage>;
        _inboundCostTotal = results[5] as double;
        _todayTotal = results[6] as double;
        _yesterdayTotal = results[7] as double;
        _outOfStockProducts = results[8] as List<Product>;
        _lowStockProducts = (results[9] as List<Product>).where((p) => p.isLowStock).toList();
        _nearExpiryProducts =
            (results[10] as List<Product>).where((p) => p.isNearExpiry || p.isExpired).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      // Se muestra el texto real del error (no uno genérico) para poder
      // diagnosticar de una sola vez si vuelve a fallar, en vez de tener
      // que adivinar a ciegas qué fue.
      setState(() {
        _error = 'No se pudieron cargar los reportes: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    final previous = _previousTotal;
    final percentChange = (summary != null && previous != null && previous > 0)
        ? ((summary.totalSales - previous) / previous) * 100
        : null;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SegmentedButton<ReportRange>(
                segments: const [
                  ButtonSegment(value: ReportRange.today, label: Text('Hoy')),
                  ButtonSegment(value: ReportRange.week, label: Text('7 días')),
                  ButtonSegment(value: ReportRange.month, label: Text('Este mes')),
                  ButtonSegment(value: ReportRange.year, label: Text('Este año')),
                ],
                selected: {_range == ReportRange.custom ? ReportRange.today : _range},
                onSelectionChanged: (value) {
                  setState(() => _range = value.first);
                  _load();
                },
              ),
              OutlinedButton.icon(
                onPressed: _pickCustomRange,
                icon: const Icon(Icons.date_range),
                label: Text(_range == ReportRange.custom && _customRange != null
                    ? '${_formatDate(_customRange!.start)} - ${_formatDate(_customRange!.end)}'
                    : 'Rango personalizado'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading)
            const LoadingIndicator(padding: EdgeInsets.all(32))
          else if (_error != null)
            ErrorState(message: _error!, onRetry: _load)
          else if (summary == null)
            ErrorState(message: 'No se pudieron cargar los reportes', onRetry: _load)
          else ...[
            // IntrinsicHeight es necesario porque este Row usa
            // crossAxisAlignment.stretch y vive directo dentro de un
            // ListView: el ListView le da altura infinita (es el eje de
            // scroll), y sin este envoltorio Flutter intenta "estirar" los
            // hijos a esa altura infinita. En modo debug eso lanza un error
            // bien visible; en el build de producción (release) esa
            // comprobación es un `assert` que se elimina, así que el layout
            // queda roto en silencio (sin ninguna excepción) y deja todo lo
            // que sigue en la lista sin pintarse — la causa real del bug de
            // Reportes en blanco.
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _StatCard(
                      label: 'Ventas totales',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CurrencyText(summary.totalSales, bold: true),
                          if (percentChange != null)
                            Text(
                              '${percentChange >= 0 ? '+' : ''}${percentChange.toStringAsFixed(1)}% vs período anterior',
                              style: TextStyle(
                                fontSize: 12,
                                color: percentChange >= 0 ? Colors.green : Colors.red,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      label: 'Transacciones',
                      child: Text(formatNumberCl(summary.transactionCount),
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _StatCard(label: 'Ticket promedio', child: CurrencyText(summary.averageTicket, bold: true)),
            const SizedBox(height: 12),
            _StatCard(
              label: 'Gastado en mercadería (entradas de stock)',
              child: CurrencyText(_inboundCostTotal, bold: true),
            ),
            const SizedBox(height: 16),
            Text('Hoy vs. ayer', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _BarChartFrame(
              barCount: 2,
              values: [_yesterdayTotal, _todayTotal],
              labelFor: (index) => index == 0 ? 'Ayer' : 'Hoy',
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            // El resto va en secciones plegables: antes era una sola lista
            // larga y había que bajar mucho con el mouse para llegar al
            // final. Las 3 de estado del inventario (sin stock/stock
            // bajo/por vencer) parten abiertas por ser las más urgentes de
            // revisar; el resto parte cerrado y se abre solo si interesa —
            // el subtítulo de cada una ya adelanta cuántos ítems tiene.
            if (_range == ReportRange.year && summary.dailyTotals.isNotEmpty)
              _Section(
                key: const ValueKey('ventas_por_periodo'),
                title: 'Ventas por mes',
                subtitle: '${summary.dailyTotals.length} mes(es)',
                children: [_MonthlyBarChart(dailyTotals: summary.dailyTotals)],
              )
            else if (summary.dailyTotals.length > 1)
              _Section(
                key: const ValueKey('ventas_por_periodo'),
                title: 'Ventas por día',
                subtitle: '${summary.dailyTotals.length} día(s)',
                children: [_DailyBarChart(dailyTotals: summary.dailyTotals)],
              ),
            const SizedBox(height: 12),
            _Section(
              key: const ValueKey('por_metodo_pago'),
              title: 'Por método de pago',
              subtitle: '${summary.byPaymentMethod.length} método(s)',
              children: [
                _PieChartCard(
                  items: summary.byPaymentMethod.entries
                      .map((e) => (label: _paymentLabels[e.key] ?? e.key, value: e.value))
                      .toList(),
                ),
                ...summary.byPaymentMethod.entries.map((entry) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(_paymentLabels[entry.key] ?? entry.key),
                      trailing: CurrencyText(entry.value, bold: true),
                    )),
              ],
            ),
            const SizedBox(height: 12),
            _Section(
              key: const ValueKey('mas_vendidos'),
              title: 'Productos más vendidos',
              subtitle: '${summary.topProducts.length} producto(s)',
              children: [
                if (summary.topProducts.isEmpty)
                  const Text('Sin ventas en este período')
                else
                  ...summary.topProducts.map((product) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                        subtitle: Text('${formatNumberCl(product.quantity)} unidades'),
                        trailing: CurrencyText(product.total, bold: true),
                      )),
              ],
            ),
            const SizedBox(height: 12),
            _Section(
              key: const ValueKey('por_categoria'),
              title: 'Por categoría',
              subtitle: '${_byCategory.length} categoría(s)',
              children: [
                if (_byCategory.isEmpty)
                  const Text('Sin ventas en este período')
                else ...[
                  _PieChartCard(items: _byCategory.map((c) => (label: c.name, value: c.total)).toList()),
                  ..._byCategory.map((c) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(c.name),
                        trailing: CurrencyText(c.total, bold: true),
                      )),
                ],
              ],
            ),
            const SizedBox(height: 12),
            _Section(
              key: const ValueKey('por_empleado'),
              title: 'Por empleado',
              subtitle: '${_byEmployee.length} empleado(s)',
              children: [
                if (_byEmployee.isEmpty)
                  const Text('Sin ventas en este período')
                else
                  ..._byEmployee.map((e) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(e.name),
                        trailing: CurrencyText(e.total, bold: true),
                      )),
              ],
            ),
            if (_byModifier.isNotEmpty) ...[
              const SizedBox(height: 12),
              _Section(
                key: const ValueKey('por_modificador'),
                title: 'Por modificador',
                subtitle: '${_byModifier.length} modificador(es)',
                children: _byModifier
                    .map((m) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(m.name),
                          trailing: Text('${formatNumberCl(m.count)} veces'),
                        ))
                    .toList(),
              ),
            ],
            // Estado del inventario ahora mismo — no depende del rango de
            // fechas elegido arriba, siempre muestra la situación actual.
            // Se muestran como grilla de tarjetas chicas (no una fila por
            // producto) para que quepan varias por pantalla, y las 3
            // comparten el mismo filtro de categoría de acá abajo.
            const SizedBox(height: 12),
            if (_categories.isNotEmpty) ...[
              Text('Filtrar por categoría', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Todas'),
                    selected: _statusCategoryFilter == null,
                    onSelected: (_) => setState(() => _statusCategoryFilter = null),
                  ),
                  ..._categories.map((c) => ChoiceChip(
                        label: Text(c.name),
                        selected: _statusCategoryFilter == c.id,
                        onSelected: (_) => setState(() => _statusCategoryFilter = c.id),
                      )),
                ],
              ),
              const SizedBox(height: 12),
            ],
            _Section(
              key: const ValueKey('sin_stock'),
              title: 'Productos sin stock',
              subtitle: '${_filterByCategory(_outOfStockProducts).length} producto(s)',
              initiallyExpanded: true,
              children: [
                if (_filterByCategory(_outOfStockProducts).isEmpty)
                  Text(_statusCategoryFilter == null
                      ? 'Ningún producto sin stock ahora mismo'
                      : 'Ningún producto sin stock en esta categoría')
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _filterByCategory(_outOfStockProducts)
                        .map((p) => _ProductStatusCard(
                              product: p,
                              subtitle: 'Sin stock',
                              onAddStock: () => _quickAddStock(p),
                            ))
                        .toList(),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _Section(
              key: const ValueKey('stock_bajo'),
              title: 'Productos con stock bajo',
              subtitle: '${_filterByCategory(_lowStockProducts).length} producto(s)',
              initiallyExpanded: true,
              children: [
                if (_filterByCategory(_lowStockProducts).isEmpty)
                  Text(_statusCategoryFilter == null
                      ? 'Ningún producto con stock bajo ahora mismo'
                      : 'Ningún producto con stock bajo en esta categoría')
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _filterByCategory(_lowStockProducts)
                        .map((p) => _ProductStatusCard(
                              product: p,
                              subtitle: 'Stock: ${formatNumberCl(p.stockQuantity)}',
                              onAddStock: () => _quickAddStock(p),
                            ))
                        .toList(),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _Section(
              key: const ValueKey('por_vencer'),
              title: 'Productos por vencer',
              subtitle: '${_filterByCategory(_nearExpiryProducts).length} producto(s)',
              initiallyExpanded: true,
              children: [
                if (_filterByCategory(_nearExpiryProducts).isEmpty)
                  Text(_statusCategoryFilter == null
                      ? 'Ningún producto por vencer ahora mismo'
                      : 'Ningún producto por vencer en esta categoría')
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _filterByCategory(_nearExpiryProducts)
                        .map((p) => _ProductStatusCard(
                              product: p,
                              subtitle:
                                  '${p.isExpired ? 'Vencido' : 'Por vencer'} · ${_formatExpiration(p.expirationDate!)}',
                              onAddStock: () => _quickAddStock(p),
                            ))
                        .toList(),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatExpiration(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  /// Entrada de stock rápida desde una de las listas de productos de
  /// Reportes (sin stock, stock bajo, por vencer) — sin salir de la
  /// pantalla ni pasar por Movimientos de stock. Registra el movimiento
  /// igual que allá, para que quede en el historial.
  Future<void> _quickAddStock(Product product) async {
    final formKey = GlobalKey<FormState>();
    final quantityController = TextEditingController(text: '1');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Agregar stock: ${product.name}'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: quantityController,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Cantidad a agregar', border: OutlineInputBorder()),
            validator: (value) {
              final qty = double.tryParse(value ?? '');
              return (qty == null || qty <= 0) ? 'Cantidad inválida' : null;
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.of(context).pop(true);
            },
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final quantity = double.parse(quantityController.text);
    try {
      await _productRepository.adjustStock(product.id, quantity);
      await _stockMovementRepository.create(
        productId: product.id,
        productName: product.name,
        type: 'in',
        quantity: quantity,
        costAtTime: product.cost,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Stock agregado a ${product.name}')));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo agregar stock: $e')));
    }
  }
}

/// Sección plegable de Reportes: título + subtítulo corto (ej. "5
/// producto(s)") siempre visibles, contenido que se muestra solo al
/// tocarla. El subtítulo deja ver de un vistazo si hay algo ahí sin tener
/// que abrirla, así que colapsar una sección no esconde la información,
/// solo el detalle.
class _Section extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool initiallyExpanded;
  final List<Widget> children;

  const _Section({
    super.key,
    required this.title,
    required this.subtitle,
    this.initiallyExpanded = false,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(title, style: Theme.of(context).textTheme.titleMedium),
          subtitle: Text(subtitle),
          initiallyExpanded: initiallyExpanded,
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }
}

/// Tarjeta chica para las grillas de "sin stock" / "stock bajo" / "por
/// vencer" — varias caben por fila, a diferencia de una fila completa por
/// producto como antes.
class _ProductStatusCard extends StatelessWidget {
  final Product product;
  final String subtitle;
  final VoidCallback onAddStock;

  const _ProductStatusCard({required this.product, required this.subtitle, required this.onAddStock});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      child: Card(
        margin: EdgeInsets.zero,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(subtitle, style: const TextStyle(color: Color(0xFF616161), fontSize: 12)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_box_outlined, size: 20),
                    tooltip: 'Agregar stock',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: onAddStock,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final Widget child;

  const _StatCard({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: const Color(0xFF616161))),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

/// Un color fijo por posición, para que categorías/métodos de pago y las
/// barras del gráfico usen la misma paleta en toda la pantalla.
const _chartPalette = [
  Color(0xFFEF6C00), // naranja de marca
  Color(0xFF1976D2),
  Color(0xFF43A047),
  Color(0xFF8E24AA),
  Color(0xFFFDD835),
  Color(0xFF00897B),
  Color(0xFFD81B60),
  Color(0xFF5D4037),
];

/// Ancho aproximado que ocupa cada barra (barra + separación), para decidir
/// cuánto espacio horizontal darle al gráfico — con pocos días se estira al
/// ancho disponible, con muchos se puede desplazar horizontalmente en vez
/// de aplastarse.
const double _barSlotWidth = 44;

/// Gráfico de barras con fl_chart: una barra por día, con grilla, animación
/// al cambiar de rango y un total exacto al tocar una barra.
class _DailyBarChart extends StatelessWidget {
  final List<DailyTotal> dailyTotals;

  const _DailyBarChart({required this.dailyTotals});

  @override
  Widget build(BuildContext context) {
    return _BarChartFrame(
      barCount: dailyTotals.length,
      values: dailyTotals.map((d) => d.total).toList(),
      labelFor: (index) => _formatDate(dailyTotals[index].date),
      color: Theme.of(context).colorScheme.primary,
    );
  }
}

/// Agrupa los totales diarios del año por mes (una barra por mes) y agrega
/// debajo el mes con más ventas y el promedio mensual, para tener algo de
/// contexto además del gráfico.
class _MonthlyBarChart extends StatelessWidget {
  final List<DailyTotal> dailyTotals;

  const _MonthlyBarChart({required this.dailyTotals});

  @override
  Widget build(BuildContext context) {
    final byMonth = <int, double>{};
    for (final d in dailyTotals) {
      byMonth[d.date.month] = (byMonth[d.date.month] ?? 0) + d.total;
    }
    final months = byMonth.keys.toList()..sort();
    final bestMonth = months.reduce((a, b) => byMonth[a]! >= byMonth[b]! ? a : b);
    final average = byMonth.values.fold<double>(0, (a, b) => a + b) / months.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BarChartFrame(
          barCount: months.length,
          values: months.map((m) => byMonth[m]!).toList(),
          labelFor: (index) => _monthAbbrevEs[months[index] - 1],
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Mejor mes', style: TextStyle(color: const Color(0xFF616161), fontSize: 12)),
                  Row(
                    children: [
                      Text('${_monthAbbrevEs[bestMonth - 1]}: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                      CurrencyText(byMonth[bestMonth]!, bold: true),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Promedio mensual', style: TextStyle(color: const Color(0xFF616161), fontSize: 12)),
                  CurrencyText(average, bold: true),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Base compartida entre [_DailyBarChart] y [_MonthlyBarChart]: arma un
/// `BarChart` de fl_chart con grilla, tooltip al tocar una barra y
/// animación al cambiar los datos, desplazable horizontalmente si hay
/// muchas barras para que no queden aplastadas.
class _BarChartFrame extends StatelessWidget {
  final int barCount;
  final List<double> values;
  final String Function(int index) labelFor;
  final Color color;

  const _BarChartFrame({
    required this.barCount,
    required this.values,
    required this.labelFor,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final maxTotal = values.fold<double>(0, (a, b) => a > b ? a : b);
    final maxY = maxTotal == 0 ? 1.0 : maxTotal * 1.2;

    final chart = BarChart(
      BarChartData(
        maxY: maxY,
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: maxY / 4,
          getDrawingHorizontalLine: (_) => FlLine(color: const Color(0xFF616161).withOpacity(0.2), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= barCount) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(labelFor(index), style: const TextStyle(fontSize: 10)),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
              formatCurrencyCl(rod.toY),
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < values.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: values[i],
                  color: color,
                  width: 18,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            ),
        ],
      ),
      duration: const Duration(milliseconds: 300),
    );

    return SizedBox(
      height: 160,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = barCount * _barSlotWidth;
          if (width <= constraints.maxWidth) return chart;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(width: width, child: chart),
          );
        },
      ),
    );
  }
}

/// Gráfico de torta con fl_chart (con leyenda de colores debajo) para
/// mostrar de un vistazo el peso de cada categoría o método de pago,
/// complementando la lista con los montos exactos que ya se muestra abajo.
class _PieChartCard extends StatelessWidget {
  final List<({String label, double value})> items;

  const _PieChartCard({required this.items});

  @override
  Widget build(BuildContext context) {
    final total = items.fold<double>(0, (sum, item) => sum + item.value);
    if (total <= 0) return const SizedBox.shrink();
    final sorted = [...items]..sort((a, b) => b.value.compareTo(a.value));

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          SizedBox(
            height: 160,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 28,
                sections: [
                  for (var i = 0; i < sorted.length; i++)
                    PieChartSectionData(
                      value: sorted[i].value,
                      color: _chartPalette[i % _chartPalette.length],
                      radius: 56,
                      title: '${(sorted[i].value / total * 100).round()}%',
                      titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                ],
              ),
              duration: const Duration(milliseconds: 300),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            alignment: WrapAlignment.center,
            children: [
              for (var i = 0; i < sorted.length; i++)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _chartPalette[i % _chartPalette.length],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(sorted[i].label, style: const TextStyle(fontSize: 12)),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

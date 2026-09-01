import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../models/product.dart';
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
            if (_range == ReportRange.year && summary.dailyTotals.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Ventas por mes', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              _MonthlyBarChart(dailyTotals: summary.dailyTotals),
            ] else if (summary.dailyTotals.length > 1) ...[
              const SizedBox(height: 16),
              Text('Ventas por día', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              _DailyBarChart(dailyTotals: summary.dailyTotals),
            ],
            const SizedBox(height: 16),
            Text('Por método de pago', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
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
            const SizedBox(height: 16),
            Text('Productos más vendidos', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (summary.topProducts.isEmpty)
              const Text('Sin ventas en este período')
            else
              ...summary.topProducts.map((product) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Text('${formatNumberCl(product.quantity)} unidades'),
                    trailing: CurrencyText(product.total, bold: true),
                  )),
            const SizedBox(height: 16),
            Text('Por categoría', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
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
            const SizedBox(height: 16),
            Text('Por empleado', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_byEmployee.isEmpty)
              const Text('Sin ventas en este período')
            else
              ..._byEmployee.map((e) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(e.name),
                    trailing: CurrencyText(e.total, bold: true),
                  )),
            if (_byModifier.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Por modificador', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ..._byModifier.map((m) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(m.name),
                    trailing: Text('${formatNumberCl(m.count)} veces'),
                  )),
            ],
            // Estado del inventario ahora mismo — no depende del rango de
            // fechas elegido arriba, siempre muestra la situación actual.
            const SizedBox(height: 16),
            Text('Productos sin stock', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_outOfStockProducts.isEmpty)
              const Text('Ningún producto sin stock ahora mismo')
            else ...[
              Text('${_outOfStockProducts.length} producto(s)',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              ..._outOfStockProducts.map((p) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                  )),
            ],
            const SizedBox(height: 16),
            Text('Productos con stock bajo', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_lowStockProducts.isEmpty)
              const Text('Ningún producto con stock bajo ahora mismo')
            else ...[
              Text('${_lowStockProducts.length} producto(s)',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              ..._lowStockProducts.map((p) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                    trailing: Text('Stock: ${formatNumberCl(p.stockQuantity)}'),
                  )),
            ],
            const SizedBox(height: 16),
            Text('Productos por vencer', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_nearExpiryProducts.isEmpty)
              const Text('Ningún producto por vencer ahora mismo')
            else ...[
              Text('${_nearExpiryProducts.length} producto(s)',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              ..._nearExpiryProducts.map((p) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Text(p.isExpired ? 'Vencido' : 'Por vencer'),
                    trailing: Text(_formatExpiration(p.expirationDate!)),
                  )),
            ],
          ],
        ],
      ),
    );
  }

  String _formatExpiration(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/app_database.dart';
import '../../../providers/database_providers.dart';
import '../../../services/returns_service.dart';

class ReturnsPage extends ConsumerStatefulWidget {
  const ReturnsPage({super.key});

  @override
  ConsumerState<ReturnsPage> createState() => _ReturnsPageState();
}

class _ReturnsPageState extends ConsumerState<ReturnsPage> {
  int _tab = 0;
  String _search = '';

  Future<void> _createReturn() async {
    final invoice = TextEditingController();
    final reason = TextEditingController();
    final formKey = GlobalKey<FormState>();
    int? sourceId;
    List<ReturnLineInput> sourceLines = [];
    final selected = <int, double>{};
    var loading = false;

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> loadSource() async {
              if (!formKey.currentState!.validate()) return;
              setDialogState(() => loading = true);
              try {
                if (_tab == 0) {
                  final sale = await ref
                      .read(salesDaoProvider)
                      .getByInvoiceNumber(invoice.text);
                  if (sale == null) throw Exception('فاتورة البيع غير موجودة');
                  sourceId = sale.id;
                  sourceLines = await ref
                      .read(returnsServiceProvider)
                      .saleLines(sale.id);
                } else {
                  final purchase = await ref
                      .read(purchasesDaoProvider)
                      .getByInvoiceNumber(invoice.text);
                  if (purchase == null)
                    throw Exception('فاتورة الشراء غير موجودة');
                  sourceId = purchase.id;
                  sourceLines = await ref
                      .read(returnsServiceProvider)
                      .purchaseLines(purchase.id);
                }
                selected.clear();
                setDialogState(() => loading = false);
              } catch (error) {
                setDialogState(() => loading = false);
                if (context.mounted)
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(error.toString())));
              }
            }

            return AlertDialog(
              title: Text(_tab == 0 ? 'مرتجع مبيعات' : 'مرتجع مشتريات'),
              content: SizedBox(
                width: 700,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: invoice,
                                decoration: const InputDecoration(
                                  labelText: 'رقم الفاتورة',
                                ),
                                validator: (value) =>
                                    value == null || value.trim().isEmpty
                                    ? 'أدخل رقم الفاتورة'
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: loading ? null : loadSource,
                              child: const Text('تحميل'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (sourceLines.isEmpty)
                          const Text('ابحث عن فاتورة مكتملة لعرض أصنافها'),
                        ...sourceLines.asMap().entries.map((entry) {
                          final line = entry.value;
                          final index = entry.key;
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${line.productName}\nالمتاح للإرجاع: ${line.quantity} × ${line.unitPrice.toStringAsFixed(2)}',
                                    ),
                                  ),
                                  SizedBox(
                                    width: 110,
                                    child: TextFormField(
                                      key: ValueKey('${sourceId}_$index'),
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText: 'المرتجع',
                                      ),
                                      onChanged: (value) => setDialogState(
                                        () => selected[index] =
                                            double.tryParse(value) ?? 0,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                        TextField(
                          controller: reason,
                          decoration: const InputDecoration(
                            labelText: 'سبب المرتجع',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('إلغاء'),
                ),
                FilledButton(
                  onPressed: sourceId == null
                      ? null
                      : () async {
                          final items = <ReturnLineInput>[];
                          for (
                            var index = 0;
                            index < sourceLines.length;
                            index++
                          ) {
                            final quantity = selected[index] ?? 0;
                            if (quantity > 0) {
                              final line = sourceLines[index];
                              items.add(
                                ReturnLineInput(
                                  productId: line.productId,
                                  productName: line.productName,
                                  barcode: line.barcode,
                                  unitPrice: line.unitPrice,
                                  quantity: quantity,
                                ),
                              );
                            }
                          }
                          try {
                            if (_tab == 0) {
                              await ref
                                  .read(returnsServiceProvider)
                                  .createSaleReturn(
                                    saleId: sourceId!,
                                    items: items,
                                    reason: reason.text.trim().isEmpty
                                        ? null
                                        : reason.text.trim(),
                                  );
                            } else {
                              await ref
                                  .read(returnsServiceProvider)
                                  .createPurchaseReturn(
                                    purchaseId: sourceId!,
                                    items: items,
                                    reason: reason.text.trim().isEmpty
                                        ? null
                                        : reason.text.trim(),
                                  );
                            }
                            if (dialogContext.mounted)
                              Navigator.pop(dialogContext);
                            if (mounted) setState(() {});
                          } catch (error) {
                            if (dialogContext.mounted)
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                SnackBar(content: Text(error.toString())),
                              );
                          }
                        },
                  child: const Text('حفظ المرتجع'),
                ),
              ],
            );
          },
        ),
      );
    } finally {
      invoice.dispose();
      reason.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dao = ref.watch(returnsDaoProvider);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('المرتجعات'),
          actions: [
            IconButton(
              onPressed: _createReturn,
              icon: const Icon(Icons.assignment_return),
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(
                          value: 0,
                          label: Text('مرتجعات المبيعات'),
                          icon: Icon(Icons.point_of_sale),
                        ),
                        ButtonSegment(
                          value: 1,
                          label: Text('مرتجعات المشتريات'),
                          icon: Icon(Icons.shopping_cart),
                        ),
                      ],
                      selected: {_tab},
                      onSelectionChanged: (value) =>
                          setState(() => _tab = value.first),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      onChanged: (value) => setState(() => _search = value),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        labelText: 'بحث برقم المرتجع أو النوع',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Return>>(
                future: dao.search(_search),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting)
                    return const Center(child: CircularProgressIndicator());
                  if (snapshot.hasError)
                    return Center(
                      child: Text('تعذر تحميل المرتجعات: ${snapshot.error}'),
                    );
                  final values = (snapshot.data ?? [])
                      .where(
                        (item) => _tab == 0
                            ? item.type == 'sale_return'
                            : item.type == 'purchase_return',
                      )
                      .toList();
                  if (values.isEmpty)
                    return const Center(child: Text('لا توجد مرتجعات'));
                  return ListView.separated(
                    itemCount: values.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final item = values[index];
                      return ListTile(
                        leading: const Icon(Icons.assignment_return),
                        title: Text(item.returnNumber),
                        subtitle: Text(
                          '${item.returnDate.toLocal()}\n${item.reason ?? 'بدون سبب'}',
                        ),
                        trailing: Text(
                          item.total.toStringAsFixed(2),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

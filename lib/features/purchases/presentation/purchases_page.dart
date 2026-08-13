import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/app_database.dart';
import '../../../providers/database_providers.dart';
import '../../../services/purchase_service.dart';

class PurchasesPage extends ConsumerStatefulWidget {
  const PurchasesPage({super.key});

  @override
  ConsumerState<PurchasesPage> createState() => _PurchasesPageState();
}

class _PurchasesPageState extends ConsumerState<PurchasesPage> {
  String _search = '';

  Future<void> _newPurchase() async {
    final invoice = TextEditingController(
      text: 'PUR-${DateTime.now().millisecondsSinceEpoch}',
    );
    final barcode = TextEditingController();
    final name = TextEditingController();
    final price = TextEditingController(text: '0');
    final quantity = TextEditingController(text: '1');
    final discount = TextEditingController(text: '0');
    final paid = TextEditingController(text: '0');
    final notes = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final lines = <PurchaseLineInput>[];
    final suppliers = await ref.read(suppliersDaoProvider).getAll();
    int? supplierId;
    String payment = 'cash';

    try {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) {
            final service = ref.read(purchaseServiceProvider);
            final subtotal = lines.fold<double>(
              0,
              (sum, line) => sum + service.lineTotal(line),
            );
            final invoiceDiscount = double.tryParse(discount.text) ?? 0;
            final total = (subtotal - invoiceDiscount).clamp(
              0,
              double.infinity,
            );

            return AlertDialog(
              title: const Text('فاتورة شراء جديدة'),
              content: SizedBox(
                width: 760,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: invoice,
                          decoration: const InputDecoration(
                            labelText: 'رقم الفاتورة',
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'رقم الفاتورة مطلوب'
                              : null,
                        ),
                        DropdownButtonFormField<int?>(
                          value: supplierId,
                          decoration: const InputDecoration(
                            labelText: 'المورد',
                          ),
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('بدون مورد'),
                            ),
                            ...suppliers.map(
                              (supplier) => DropdownMenuItem<int?>(
                                value: supplier.id,
                                child: Text(supplier.name),
                              ),
                            ),
                          ],
                          onChanged: (value) =>
                              setDialogState(() => supplierId = value),
                        ),
                        DropdownButtonFormField<String>(
                          value: payment,
                          decoration: const InputDecoration(
                            labelText: 'طريقة الدفع',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'cash',
                              child: Text('نقدي'),
                            ),
                            DropdownMenuItem(
                              value: 'credit',
                              child: Text('آجل'),
                            ),
                          ],
                          onChanged: (value) =>
                              setDialogState(() => payment = value ?? 'cash'),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: barcode,
                                decoration: const InputDecoration(
                                  labelText: 'الباركود',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: name,
                                decoration: const InputDecoration(
                                  labelText: 'اسم المنتج',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 110,
                              child: TextField(
                                controller: price,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'السعر',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 90,
                              child: TextField(
                                controller: quantity,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'الكمية',
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                final line = PurchaseLineInput(
                                  barcode: barcode.text.trim(),
                                  productName: name.text.trim(),
                                  unitPrice: double.tryParse(price.text) ?? -1,
                                  quantity: double.tryParse(quantity.text) ?? 0,
                                );
                                if (line.barcode.isEmpty ||
                                    line.productName.isEmpty ||
                                    line.unitPrice < 0 ||
                                    line.quantity <= 0) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'أدخل بيانات الصنف بشكل صحيح',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                setDialogState(() {
                                  lines.add(line);
                                  barcode.clear();
                                  name.clear();
                                  price.text = '0';
                                  quantity.text = '1';
                                });
                              },
                              icon: const Icon(Icons.add_circle),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (lines.isEmpty)
                          const Text('لم تتم إضافة أصناف بعد')
                        else
                          ...lines.asMap().entries.map(
                            (entry) => ListTile(
                              dense: true,
                              title: Text(entry.value.productName),
                              subtitle: Text(
                                '${entry.value.quantity} × ${entry.value.unitPrice.toStringAsFixed(2)}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    service
                                        .lineTotal(entry.value)
                                        .toStringAsFixed(2),
                                  ),
                                  IconButton(
                                    onPressed: () => setDialogState(
                                      () => lines.removeAt(entry.key),
                                    ),
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        TextField(
                          controller: discount,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'خصم الفاتورة',
                          ),
                          onChanged: (_) => setDialogState(() {}),
                        ),
                        TextField(
                          controller: paid,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'المدفوع',
                          ),
                        ),
                        TextField(
                          controller: notes,
                          decoration: const InputDecoration(
                            labelText: 'ملاحظات',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'الإجمالي: ${total.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
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
                  onPressed: () async {
                    if (!formKey.currentState!.validate() || lines.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('أضف صنفًا واحدًا على الأقل'),
                        ),
                      );
                      return;
                    }
                    try {
                      await ref
                          .read(purchaseServiceProvider)
                          .createPurchase(
                            invoiceNumber: invoice.text,
                            items: lines,
                            discount: double.tryParse(discount.text) ?? 0,
                            paid: double.tryParse(paid.text) ?? 0,
                            paymentMethod: payment,
                            supplierId: supplierId,
                            notes: notes.text.trim().isEmpty
                                ? null
                                : notes.text.trim(),
                          );
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                      if (mounted) setState(() {});
                    } catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(error.toString())),
                        );
                      }
                    }
                  },
                  child: const Text('حفظ الفاتورة'),
                ),
              ],
            );
          },
        ),
      );
    } finally {
      invoice.dispose();
      barcode.dispose();
      name.dispose();
      price.dispose();
      quantity.dispose();
      discount.dispose();
      paid.dispose();
      notes.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dao = ref.watch(purchasesDaoProvider);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إدارة المشتريات'),
          actions: [
            IconButton(onPressed: _newPurchase, icon: const Icon(Icons.add)),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              TextField(
                onChanged: (value) => setState(() => _search = value),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  labelText: 'بحث برقم الفاتورة أو طريقة الدفع',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: FutureBuilder<List<Purchase>>(
                  future: dao.search(_search),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting)
                      return const Center(child: CircularProgressIndicator());
                    if (snapshot.hasError)
                      return Center(
                        child: Text('تعذر تحميل المشتريات: ${snapshot.error}'),
                      );
                    final purchases = snapshot.data ?? [];
                    return ListView.separated(
                      itemCount: purchases.length,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (context, index) {
                        final purchase = purchases[index];
                        return ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.shopping_cart),
                          ),
                          title: Text(purchase.invoiceNumber),
                          subtitle: Text(
                            '${purchase.purchaseDate.toLocal()}\nالحالة: ${purchase.status} | المتبقي: ${purchase.remaining.toStringAsFixed(2)}',
                          ),
                          isThreeLine: true,
                          trailing: Text(
                            purchase.total.toStringAsFixed(2),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          onLongPress: purchase.status == 'cancelled'
                              ? null
                              : () async {
                                  await ref
                                      .read(purchaseServiceProvider)
                                      .cancelPurchase(purchase.id);
                                  if (mounted) setState(() {});
                                },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

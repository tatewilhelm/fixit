import 'dart:core';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PartsPage extends StatefulWidget {
  final String shopId;

  const PartsPage({required this.shopId, Key? key}) : super(key: key);

  @override
  _PartsPageState createState() => _PartsPageState();
}

class _PartsPageState extends State<PartsPage> {
  final TextEditingController _skuController = TextEditingController();
  final TextEditingController _costPriceController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _stockController = TextEditingController();
  final TextEditingController _minStockController = TextEditingController();
  final TextEditingController _skuEntryController = TextEditingController();

  final int _rowsPerPage = 5; // Set the number of rows per page for pagination

  Future<void> _addPartEntry() async {
    final String sku = _skuController.text;
    final String costPriceStr = _costPriceController.text;
    final String description = _descriptionController.text;
    final String stockStr = _stockController.text;
    final String minStockStr = _minStockController.text;

    // Validate cost price and stock are numbers
    if (!_isNumeric(costPriceStr) ||
        !_isNumeric(stockStr) ||
        !_isNumeric(minStockStr)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Cost Price, Stock, and Inventory Minimum must be valid numbers.')));
      return;
    }

    final double costPrice = double.parse(costPriceStr);
    final int stock = int.parse(stockStr);
    final int minStock = int.parse(minStockStr);

    await FirebaseFirestore.instance
        .collection('shops')
        .doc(widget.shopId)
        .collection('parts')
        .add({
      'sku': sku,
      'costPrice': costPrice,
      'description': description,
      'stock': stock,
      'minStock': minStock,
    });

    _skuController.clear();
    _costPriceController.clear();
    _descriptionController.clear();
    _stockController.clear();
    _minStockController.clear();
  }

  Future<void> _updateStock(String sku, int increment) async {
    final partsCollection = FirebaseFirestore.instance
        .collection('shops')
        .doc(widget.shopId)
        .collection('parts');

    final querySnapshot =
        await partsCollection.where('sku', isEqualTo: sku).limit(1).get();
    if (querySnapshot.docs.isNotEmpty) {
      final doc = querySnapshot.docs.first;
      final newStock =
          (doc['stock'] + increment).clamp(0, double.infinity).toInt();
      if (newStock < 0 && increment < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Cannot remove part with zero quantity.')));
        return;
      }
      await partsCollection.doc(doc.id).update({'stock': newStock});
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('SKU not found.')));
    }
    _skuEntryController.clear();
  }

  Future<void> _removePart(String id) async {
    await FirebaseFirestore.instance
        .collection('shops')
        .doc(widget.shopId)
        .collection('parts')
        .doc(id)
        .delete();
  }

  void _showEditPartDialog(DocumentSnapshot partDoc) {
    final data = partDoc.data() as Map<String, dynamic>;
    final TextEditingController _skuController =
        TextEditingController(text: data['sku']);
    final TextEditingController _costPriceController =
        TextEditingController(text: data['costPrice'].toString());
    final TextEditingController _descriptionController =
        TextEditingController(text: data['description']);
    final TextEditingController _stockController =
        TextEditingController(text: data['stock'].toString());
    final TextEditingController _minStockController =
        TextEditingController(text: data['minStock'].toString());

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edit Part'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _skuController,
                decoration: InputDecoration(labelText: 'SKU'),
              ),
              TextField(
                controller: _costPriceController,
                decoration: InputDecoration(labelText: 'Cost Price'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: _descriptionController,
                decoration: InputDecoration(labelText: 'Description'),
              ),
              TextField(
                controller: _stockController,
                decoration: InputDecoration(labelText: 'Stock'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: _minStockController,
                decoration: InputDecoration(labelText: 'Inventory Minimum'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final String sku = _skuController.text;
                final double costPrice =
                    double.parse(_costPriceController.text);
                final String description = _descriptionController.text;
                final int stock = int.parse(_stockController.text);
                final int minStock = int.parse(_minStockController.text);

                await FirebaseFirestore.instance
                    .collection('shops')
                    .doc(widget.shopId)
                    .collection('parts')
                    .doc(partDoc.id)
                    .update({
                  'sku': sku,
                  'costPrice': costPrice,
                  'description': description,
                  'stock': stock,
                  'minStock': minStock,
                });

                Navigator.of(context).pop();
              },
              child: Text('Save'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showLowInventoryParts() async {
    final partsCollection = FirebaseFirestore.instance
        .collection('shops')
        .doc(widget.shopId)
        .collection('parts');

    // Fetch all parts and filter in-memory
    final querySnapshot = await partsCollection.get();

    final lowInventoryParts = querySnapshot.docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return data['stock'] < data['minStock'];
    }).toList();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Low Inventory Parts'),
          content: SingleChildScrollView(
            child: ListBody(
              children: lowInventoryParts.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final int requiredQuantity = data['minStock'] - data['stock'];
                return ListTile(
                  title: Text(data['description']),
                  subtitle: Text(
                      'SKU: ${data['sku']}, Need to purchase: $requiredQuantity'),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  bool _isNumeric(String str) {
    if (str.isEmpty) {
      return false;
    }
    return double.tryParse(str) != null;
  }

  void _showCreatePartEntryDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Create Part Entry'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _skuController,
                decoration: InputDecoration(labelText: 'SKU'),
              ),
              TextField(
                controller: _costPriceController,
                decoration: InputDecoration(labelText: 'Cost Price'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: _descriptionController,
                decoration: InputDecoration(labelText: 'Description'),
              ),
              TextField(
                controller: _stockController,
                decoration: InputDecoration(labelText: 'Stock'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: _minStockController,
                decoration: InputDecoration(labelText: 'Inventory Minimum'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _addPartEntry();
                Navigator.of(context).pop();
              },
              child: Text('Add'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _showUpdateStockDialog(int increment) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(increment > 0 ? 'Add Part' : 'Remove Part'),
          content: TextField(
            controller: _skuEntryController,
            decoration: InputDecoration(labelText: 'SKU'),
            onSubmitted: (_) =>
                _updateStock(_skuEntryController.text, increment),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _updateStock(_skuEntryController.text, increment);
                Navigator.of(context).pop();
              },
              child: Text('OK'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Color(0xFF6290C8), // Lighter blue background
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _showCreatePartEntryDialog,
                    child: Text('Create a Part Entry'),
                  ),
                ),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _showUpdateStockDialog(1),
                    child: Text('Add a Part'),
                  ),
                ),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _showUpdateStockDialog(-1),
                    child: Text('Remove a Part'),
                  ),
                ),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _showLowInventoryParts,
                    child: Text('Low Inventory Parts'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder(
              stream: FirebaseFirestore.instance
                  .collection('shops')
                  .doc(widget.shopId)
                  .collection('parts')
                  .snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }
                if (snapshot.data!.docs.isEmpty) {
                  return Center(child: Text('Add a part!'));
                }

                // Calculate total parts and total value
                double totalParts = 0;
                double totalValue = 0;
                for (var doc in snapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;

                    totalParts += data['stock'].toInt();
                    totalValue += data['stock'] * data['costPrice'];
                }

                return Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: PaginatedDataTable(
                        header: Text('Parts Inventory'),
                        columns: const [
                          DataColumn(label: Text('SKU')),
                          DataColumn(label: Text('Description')),
                          DataColumn(label: Text('Cost Price')),
                          DataColumn(label: Text('Stock')),
                          DataColumn(label: Text('Minimum Amount')),
                          DataColumn(label: Text('Actions')),
                        ],
                        source: PartsDataSource(snapshot.data!.docs, _showEditPartDialog, _removePart),
                        rowsPerPage: _rowsPerPage,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Total Parts: $totalParts'),
                          Text('Total Value: \$${totalValue.toStringAsFixed(2)}'),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class PartsDataSource extends DataTableSource {
  final List<QueryDocumentSnapshot> parts;
  final Function(DocumentSnapshot) onEdit;
  final Function(String) onRemove;

  PartsDataSource(this.parts, this.onEdit, this.onRemove);

  @override
  DataRow getRow(int index) {
    final part = parts[index];
    final data = part.data() as Map<String, dynamic>;

    return DataRow(cells: [
      DataCell(Text(data['sku'])),
      DataCell(Text(data['description'])),
      DataCell(Text('\$${data['costPrice'].toStringAsFixed(2)}')),
      DataCell(Text('${data['stock']}')),
      DataCell(Text('${data['minStock']}')),
      DataCell(Row(
        children: [
          IconButton(
            icon: Icon(Icons.edit),
            onPressed: () => onEdit(part),
          ),
          IconButton(
            icon: Icon(Icons.delete),
            onPressed: () => onRemove(part.id),
          ),
        ],
      )),
    ]);
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => parts.length;

  @override
  int get selectedRowCount => 0;
}

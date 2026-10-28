import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

String? authToken;

const apiBase = String.fromEnvironment('API_BASE',
    defaultValue: 'https://lavazza-cafe-api.onrender.com');
void main() => runApp(const CafeApp());

class CafeApp extends StatelessWidget {
  const CafeApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Lavazza Cafe Demo',
      theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6D4935)),
          scaffoldBackgroundColor: const Color(0xFFF7F3ED),
          useMaterial3: true),
      home: const LoginGate());
}

class LoginGate extends StatefulWidget {
  const LoginGate({super.key});
  @override
  State<LoginGate> createState() => _LoginGateState();
}

class _LoginGateState extends State<LoginGate> {
  bool checking = true;
  String? token;
  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    authToken = prefs.getString('auth_token');
    if (mounted) {
      setState(() {
        token = authToken;
        checking = false;
      });
    }
  }

  Future<void> _onLogin(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', value);
    authToken = value;
    if (mounted) setState(() => token = value);
  }

  Future<void> _onLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    authToken = null;
    if (mounted) setState(() => token = null);
  }

  @override
  Widget build(BuildContext context) {
    if (checking) {
      return const Material(child: Center(child: CircularProgressIndicator()));
    }
    if (token == null) return LoginPage(onLogin: _onLogin);
    return CafeHome(key: ValueKey(token), onLogout: _onLogout);
  }
}

class LoginPage extends StatefulWidget {
  final Future<void> Function(String token) onLogin;
  const LoginPage({super.key, required this.onLogin});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool busy = false;
  bool obscure = true;
  String? error;
  Future<void> _login() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final response = await http.post(
        Uri.parse('$apiBase/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body:
            jsonEncode({'email': email.text.trim(), 'password': password.text}),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode >= 300) {
        throw Exception(data['error'] ?? 'Login failed.');
      }
      await widget.onLogin(data['token'] as String);
    } catch (e) {
      setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
            child: SingleChildScrollView(
                child: Container(
          width: 420,
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x18000000),
                    blurRadius: 24,
                    offset: Offset(0, 8))
              ]),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.coffee, size: 48, color: Color(0xFF6D4935)),
                const SizedBox(height: 12),
                const Text('LAVAZZA CAFE',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.4,
                        color: Color(0xFF2E211B))),
                const SizedBox(height: 4),
                const Text('MANAGEMENT PORTAL',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.8,
                        color: Colors.black54)),
                const SizedBox(height: 30),
                const Text('Sign in',
                    style:
                        TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                const Text(
                    'Authorized staff only. Please sign in to continue.'),
                const SizedBox(height: 22),
                TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.username],
                    decoration: const InputDecoration(
                        labelText: 'Email address',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder())),
                const SizedBox(height: 14),
                TextField(
                    controller: password,
                    obscureText: obscure,
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: (_) {
                      if (!busy) _login();
                    },
                    decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                            onPressed: () => setState(() => obscure = !obscure),
                            icon: Icon(obscure
                                ? Icons.visibility
                                : Icons.visibility_off)))),
                if (error != null)
                  Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(error!,
                          style: const TextStyle(color: Colors.red))),
                const SizedBox(height: 20),
                SizedBox(
                    height: 48,
                    child: FilledButton(
                        onPressed: busy ? null : _login,
                        child: busy
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Text('LOGIN'))),
                const SizedBox(height: 18),
                const Text('Access is provided by your administrator.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.black54)),
              ]),
        ))),
      );
}

class CafeHome extends StatefulWidget {
  final Future<void> Function() onLogout;
  const CafeHome({super.key, required this.onLogout});
  @override
  State<CafeHome> createState() => _CafeHomeState();
}

class _CafeHomeState extends State<CafeHome> {
  int tab = 0;
  bool loading = true;
  String? error;
  Map<String, dynamic> dashboard = {};
  List products = [];
  List suppliers = [];
  List purchases = [];
  final Map<int, int> cart = {};
  String payment = 'UPI';
  String category = 'All';
  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<dynamic> getApi(String path) async {
    final r = await http.get(Uri.parse('$apiBase$path'),
        headers:
            authToken == null ? {} : {'Authorization': 'Bearer $authToken'});
    if (r.statusCode >= 300) throw Exception(r.body);
    return jsonDecode(r.body);
  }

  Future<dynamic> postApi(String path, Map body) async {
    final r = await http.post(Uri.parse('$apiBase$path'),
        headers: {
          'Content-Type': 'application/json',
          if (authToken != null) 'Authorization': 'Bearer $authToken'
        },
        body: jsonEncode(body));
    final data = jsonDecode(r.body);
    if (r.statusCode >= 300) throw Exception(data['error'] ?? r.body);
    return data;
  }

  Future<void> refresh() async {
    setState(() => loading = true);
    try {
      final results = await Future.wait([
        getApi('/dashboard'),
        getApi('/products'),
        getApi('/suppliers'),
        getApi('/purchases')
      ]);
      setState(() {
        dashboard = results[0];
        products = results[1];
        suppliers = results[2];
        purchases = results[3];
        error = null;
        loading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  double get cartTotal {
    double total = 0;
    for (final e in cart.entries) {
      final p = products.firstWhere((x) => x['id'] == e.key);
      total += double.parse(p['price'].toString()) * e.value;
    }
    return total;
  }

  void toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  @override
  Widget build(BuildContext context) {
    final titles = [
      'Overview',
      'POS Billing',
      'Inventory',
      'Purchases',
      'Suppliers & Payments',
      'Reports'
    ];
    return Scaffold(
        body: Row(children: [
      Container(
          width: 220,
          color: const Color(0xFF2E211B),
          padding: const EdgeInsets.all(18),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 14),
            const Icon(Icons.coffee, color: Colors.white, size: 32),
            const SizedBox(height: 8),
            const Text('LAVAZZA CAFE',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1)),
            const Text('MANAGEMENT DEMO',
                style: TextStyle(
                    color: Colors.white70, fontSize: 10, letterSpacing: 1)),
            const Divider(height: 35, color: Colors.white24),
            ...List.generate(
                titles.length,
                (i) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: ListTile(
                        dense: true,
                        selected: tab == i,
                        selectedTileColor: const Color(0xFF6D4935),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        leading: Icon(
                            [
                              Icons.dashboard,
                              Icons.point_of_sale,
                              Icons.inventory_2,
                              Icons.shopping_cart,
                              Icons.account_balance_wallet,
                              Icons.bar_chart
                            ][i],
                            color: Colors.white,
                            size: 20),
                        title: Text(titles[i],
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13)),
                        onTap: () => setState(() => tab = i)))),
            const Spacer(),
            const Text('Demo data only • Not production software',
                style: TextStyle(color: Colors.white60, fontSize: 10))
          ])),
      Expanded(
          child: Column(children: [
        Container(
            height: 66,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            color: Colors.white,
            child: Row(children: [
              Expanded(
                  child: Text(titles[tab],
                      style: const TextStyle(
                          fontSize: 21, fontWeight: FontWeight.bold))),
              const Chip(
                  avatar: Icon(Icons.science_outlined, size: 16),
                  label: Text('SAMPLE DATA')),
              IconButton(onPressed: refresh, icon: const Icon(Icons.refresh)),
              IconButton(
                onPressed: () async => await widget.onLogout(),
                tooltip: 'Log out',
                icon: const Icon(Icons.logout),
              )
            ])),
        Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : error != null
                    ? Center(
                        child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.cloud_off, size: 42),
                                  const SizedBox(height: 12),
                                  Text('Could not connect to API\n$error',
                                      textAlign: TextAlign.center),
                                  const SizedBox(height: 12),
                                  FilledButton(
                                      onPressed: refresh,
                                      child: const Text('Retry'))
                                ])))
                    : Padding(
                        padding: const EdgeInsets.all(22),
                        child: IndexedStack(index: tab, children: [
                          dashboardPage(),
                          posPage(),
                          inventoryPage(),
                          purchasesPage(),
                          suppliersPage(),
                          reportsPage()
                        ])))
      ]))
    ]));
  }

  Widget dashboardPage() {
    final inv = (dashboard['inventory'] as List? ?? []);
    final recent = (dashboard['recentSales'] as List? ?? []);
    return ListView(children: [
      const Text('Good afternoon 👋',
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
      const Text('Your cafe at a glance • illustrative demo records'),
      const SizedBox(height: 18),
      Wrap(spacing: 12, runSpacing: 12, children: [
        metric(
            'Today’s sales',
            '₹${numVal(dashboard['sales']).toStringAsFixed(2)}',
            Icons.currency_rupee),
        metric('Orders', '${dashboard['orders'] ?? 0}', Icons.receipt_long),
        metric('Low-stock items', '${dashboard['lowStock'] ?? 0}',
            Icons.warning_amber,
            color: Colors.red),
        metric(
            'Unpaid purchases',
            '₹${numVal(dashboard['unpaidInvoices']).toStringAsFixed(2)}',
            Icons.pending_actions),
      ]),
      const SizedBox(height: 18),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            child: panel(
                'Inventory snapshot',
                Column(
                    children: inv
                        .take(6)
                        .map((x) => ListTile(
                            dense: true,
                            title: Text(x['name']),
                            subtitle: Text(
                                'Reorder at ${x['reorder_level']} ${x['unit']}'),
                            trailing: Text('${x['quantity']} ${x['unit']}',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: numVal(x['quantity']) <=
                                            numVal(x['reorder_level'])
                                        ? Colors.red
                                        : Colors.green))))
                        .toList()))),
        const SizedBox(width: 14),
        Expanded(
            child: panel(
                'Recent sales',
                Column(
                    children: recent
                        .take(6)
                        .map((x) => ListTile(
                            dense: true,
                            title: Text(
                                'Sale #${x['id']} • ${x['payment_method']}'),
                            subtitle: Text(x['status']),
                            trailing: Text(
                                '₹${numVal(x['total']).toStringAsFixed(2)}')))
                        .toList())))
      ]),
      const SizedBox(height: 12),
      const Text(
          'Note: sales are counted for today; seeded records are illustrative.',
          style: TextStyle(color: Colors.black54))
    ]);
  }

  Widget posPage() {
    final visible = products
        .where((p) =>
            (category == 'All' || p['category'] == category) &&
            numVal(p['price']) > 0)
        .toList();
    final categories = [
      'All',
      ...{for (final p in products) p['category'].toString()}
    ];
    return Column(children: [
      Row(children: [
        const Text('Menu catalogue',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const Spacer(),
        DropdownButton<String>(
            value: category,
            items: categories
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) => setState(() => category = v ?? 'All'))
      ]),
      Expanded(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            flex: 3,
            child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 1.6,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10),
                itemCount: visible.length,
                itemBuilder: (c, i) {
                  final p = visible[i];
                  return InkWell(
                      onTap: () => setState(
                          () => cart[p['id']] = (cart[p['id']] ?? 0) + 1),
                      child: Card(
                          color: Colors.white,
                          child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.local_cafe,
                                        color: Color(0xFF80563E)),
                                    const SizedBox(height: 5),
                                    Text(
                                        '${p['name']}${p['variant'] == '' ? '' : ' • ${p['variant']}'}',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis),
                                    Text(
                                        '₹${numVal(p['price']).toStringAsFixed(0)}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16))
                                  ]))));
                })),
        const SizedBox(width: 12),
        Expanded(
            flex: 2,
            child: panel(
                'Current order',
                Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (cart.isEmpty)
                        const Padding(
                            padding: EdgeInsets.all(20),
                            child:
                                Text('Tap a product to add it to the order.')),
                      ...cart.entries.map((e) {
                        final p = products.firstWhere((x) => x['id'] == e.key);
                        return ListTile(
                            dense: true,
                            title: Text(p['name']),
                            subtitle: Text(
                                '₹${numVal(p['price']).toStringAsFixed(0)} × ${e.value}'),
                            trailing:
                                Row(mainAxisSize: MainAxisSize.min, children: [
                              IconButton(
                                  onPressed: () => setState(() => e.value == 1
                                      ? cart.remove(e.key)
                                      : cart[e.key] = e.value - 1),
                                  icon:
                                      const Icon(Icons.remove_circle_outline)),
                              IconButton(
                                  onPressed: () =>
                                      setState(() => cart[e.key] = e.value + 1),
                                  icon: const Icon(Icons.add_circle_outline))
                            ]));
                      }),
                      const Divider(),
                      Text(
                          'Total (menu prices GST-inclusive): ₹${cartTotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                          initialValue: payment,
                          decoration: const InputDecoration(
                              labelText: 'Payment method'),
                          items: ['Cash', 'UPI', 'Card', 'Split']
                              .map((x) =>
                                  DropdownMenuItem(value: x, child: Text(x)))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => payment = v ?? 'UPI')),
                      const SizedBox(height: 10),
                      FilledButton.icon(
                          onPressed: cart.isEmpty ? null : completeSale,
                          icon: const Icon(Icons.check),
                          label: const Text('Complete demo sale')),
                      TextButton(
                          onPressed: () => setState(() => cart.clear()),
                          child: const Text('Clear order'))
                    ])))
      ]))
    ]);
  }

  Future<void> completeSale() async {
    try {
      final items = cart.entries
          .map((e) => {'productId': e.key, 'quantity': e.value})
          .toList();
      final result =
          await postApi('/sales', {'items': items, 'paymentMethod': payment});
      setState(() => cart.clear());
      await refresh();
      toast(
          'Sale #${result['saleId']} completed • ₹${numVal(result['total']).toStringAsFixed(2)}');
    } catch (e) {
      toast('Sale failed: $e');
    }
  }

  Widget inventoryPage() {
    final inv = (dashboard['inventory'] as List? ?? []);
    return panel(
        'Stock levels • sample recipe quantities',
        Column(
            children: inv
                .map((x) => ListTile(
                    leading: Icon(
                        numVal(x['quantity']) <= numVal(x['reorder_level'])
                            ? Icons.warning_amber
                            : Icons.inventory_2,
                        color:
                            numVal(x['quantity']) <= numVal(x['reorder_level'])
                                ? Colors.red
                                : Colors.green),
                    title: Text(x['name']),
                    subtitle: Text(
                        'Reorder level: ${x['reorder_level']} ${x['unit']}'),
                    trailing: Text('${x['quantity']} ${x['unit']}',
                        style: const TextStyle(fontWeight: FontWeight.bold))))
                .toList()));
  }

  Widget purchasesPage() {
    return ListView(children: [
      Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
              onPressed: addPurchase,
              icon: const Icon(Icons.add),
              label: const Text('Record purchase'))),
      const SizedBox(height: 10),
      panel(
          'Purchase register',
          Column(
              children: purchases
                  .map((p) => ListTile(
                      title: Text('${p['item_name']} • ${p['supplier_name']}'),
                      subtitle: Text(
                          '${p['quantity']} ${p['unit']} • ${p['status']} • Invoice: ${p['invoice_status']}'),
                      trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('₹${numVal(p['total']).toStringAsFixed(2)}'),
                            if (p['invoice_status'] != 'paid')
                              TextButton(
                                  onPressed: () => payPurchase(p),
                                  child: const Text('Mark paid'))
                          ])))
                  .toList()))
    ]);
  }

  Future<void> addPurchase() async {
    if (suppliers.isEmpty) return;
    int supplierId = suppliers.first['id'];
    int inventoryId = 1;
    String item = 'Arabica Coffee Beans';
    String unit = 'g';
    double qty = 1000, cost = 0.8;
    bool receive = true;
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, setD) => AlertDialog(
                    title: const Text('Record sample purchase'),
                    content: SizedBox(
                        width: 360,
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          DropdownButtonFormField<int>(
                              initialValue: supplierId,
                              decoration:
                                  const InputDecoration(labelText: 'Supplier'),
                              items: suppliers
                                  .map<DropdownMenuItem<int>>((s) =>
                                      DropdownMenuItem(
                                          value: s['id'] as int,
                                          child: Text(s['name'])))
                                  .toList(),
                              onChanged: (v) =>
                                  setD(() => supplierId = v ?? supplierId)),
                          DropdownButtonFormField<int>(
                              initialValue: inventoryId,
                              decoration: const InputDecoration(
                                  labelText: 'Inventory item'),
                              items: (dashboard['inventory'] as List)
                                  .map<DropdownMenuItem<int>>((x) =>
                                      DropdownMenuItem(
                                          value: x['id'] as int,
                                          child: Text(x['name'])))
                                  .toList(),
                              onChanged: (v) {
                                setD(() => inventoryId = v ?? 1);
                                final x = (dashboard['inventory'] as List)
                                    .firstWhere((x) => x['id'] == inventoryId);
                                item = x['name'];
                                unit = x['unit'];
                                cost = numVal(x['unit_cost']);
                              }),
                          const SizedBox(height: 8),
                          const Text(
                              'Quantity and unit cost use the selected inventory item unit.'),
                          SwitchListTile(
                              value: receive,
                              title: const Text('Goods received now'),
                              onChanged: (v) => setD(() => receive = v))
                        ])),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel')),
                      FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Save'))
                    ])));
    if (ok != true) return;
    try {
      await postApi('/purchases', {
        'supplierId': supplierId,
        'itemName': item,
        'quantity': qty,
        'unit': unit,
        'unitCost': cost,
        'inventoryItemId': inventoryId,
        'receiveNow': receive
      });
      await refresh();
      toast('Purchase recorded. Demo quantity: $qty $unit.');
    } catch (e) {
      toast('Purchase failed: $e');
    }
  }

  Future<void> payPurchase(dynamic p) async {
    try {
      final due = numVal(p['total']) - numVal(p['paid']);
      await postApi('/purchases/${p['id']}/pay',
          {'amount': due, 'paymentMethod': 'Bank'});
      await refresh();
      toast('Supplier payment recorded.');
    } catch (e) {
      toast('Payment failed: $e');
    }
  }

  Widget suppliersPage() => panel(
      'Suppliers',
      Column(
          children: suppliers
              .map((s) => ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.store)),
                  title: Text(s['name']),
                  subtitle: Text('Contact: ${s['phone']}')))
              .toList()));
  Widget reportsPage() {
    final inv = (dashboard['inventory'] as List? ?? []);
    final purchasesDue = numVal(dashboard['unpaidInvoices']);
    return ListView(children: [
      Wrap(spacing: 12, runSpacing: 12, children: [
        metric(
            'Recorded sales',
            '₹${numVal(dashboard['sales']).toStringAsFixed(2)}',
            Icons.point_of_sale),
        metric(
            'Completed orders', '${dashboard['orders'] ?? 0}', Icons.receipt),
        metric('Items needing reorder', '${dashboard['lowStock'] ?? 0}',
            Icons.warning),
        metric('Outstanding purchase value',
            '₹${purchasesDue.toStringAsFixed(2)}', Icons.receipt_long),
      ]),
      const SizedBox(height: 16),
      panel(
          'Inventory summary',
          Column(
              children: inv
                  .map((x) => ListTile(
                      title: Text(x['name']),
                      trailing: Text('${x['quantity']} ${x['unit']}')))
                  .toList())),
      const Padding(
          padding: EdgeInsets.all(12),
          child: Text(
              'Demo reports are operational summaries, not a verified profit-and-loss or GST report.'))
    ]);
  }

  Widget metric(String title, String value, IconData icon,
          {Color color = const Color(0xFF6D4935)}) =>
      SizedBox(
          width: 220,
          child: Card(
              color: Colors.white,
              child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(icon, color: color),
                        const SizedBox(height: 10),
                        Text(title,
                            style: const TextStyle(color: Colors.black54)),
                        const SizedBox(height: 5),
                        Text(value,
                            style: const TextStyle(
                                fontSize: 23, fontWeight: FontWeight.bold))
                      ]))));
  Widget panel(String title, Widget child) => Card(
      color: Colors.white,
      child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const Divider(),
            child
          ])));
  double numVal(dynamic x) => double.tryParse(x?.toString() ?? '') ?? 0;
}

import 'package:flutter/material.dart';
import 'package:trek_bikes_app/cart_api.dart';
import 'package:trek_bikes_app/checkout_page.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  Cart? cart;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadCart();
  }

  Future<void> _loadCart() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final res = await CartApi.get();
      if (mounted) {
        setState(() {
          cart = res;
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = 'Không thể tải giỏ hàng: $e';
          loading = false;
        });
      }
    }
  }

  Future<void> _updateQuantity(int cartItemId, int newQuantity) async {
    try {
      Cart res;
      if (newQuantity <= 0) {
        res = await CartApi.remove(cartItemId);
      } else {
        res = await CartApi.setQuantity(cartItemId, newQuantity);
      }
      if (mounted) setState(() => cart = res);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi cập nhật: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Giỏ hàng của bạn')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(error!),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _loadCart,
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                )
              : (cart == null || cart!.items.isEmpty)
                  ? const Center(child: Text('Giỏ hàng đang trống.'))
                  : Column(
                      children: [
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: _loadCart,
                            child: ListView.separated(
                              itemCount: cart!.items.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final item = cart!.items[index];
                                return ListTile(
                                  title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text('${item.unitPrice.toStringAsFixed(0)} đ'),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.remove_circle_outline),
                                        onPressed: () => _updateQuantity(item.cartItemId, item.quantity - 1),
                                      ),
                                      Text(
                                        '${item.quantity}',
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.add_circle_outline),
                                        onPressed: () => _updateQuantity(item.cartItemId, item.quantity + 1),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                                        onPressed: () => _updateQuantity(item.cartItemId, 0),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            boxShadow: const [
                              BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2)),
                            ],
                          ),
                          child: SafeArea(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('Tổng tiền:'),
                                    Text(
                                      '${cart!.totalAmount.toStringAsFixed(0)} đ',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.deepOrange,
                                      ),
                                    ),
                                  ],
                                ),
                                FilledButton(
                                  onPressed: () async {
                                    final placed = await Navigator.push<bool>(
                                      context,
                                      MaterialPageRoute(builder: (_) => const CheckoutPage()),
                                    );
                                    if (placed == true && mounted) {
                                      Navigator.pop(context, true);
                                    }
                                  },
                                  child: const Text('Thanh toán'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
    );
  }
}


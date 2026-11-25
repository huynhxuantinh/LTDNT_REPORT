import 'package:flutter/material.dart';
import 'package:trek_bikes_app/cart_api.dart';
import 'package:trek_bikes_app/money_format.dart';
import 'package:trek_bikes_app/checkout_page.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key, this.loadCart, this.setQuantity, this.removeItem});
  final Future<Cart> Function()? loadCart;
  final Future<Cart> Function(int id, int quantity)? setQuantity;
  final Future<Cart> Function(int id)? removeItem;

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  Cart? cart;
  bool loading = true;
  String? error;
  final Set<int> updatingItems = {};

  @override
  void initState() {
    super.initState();
    cartSyncRevision.addListener(_refreshAfterSync);
    _loadCart();
  }

  @override
  void dispose() {
    cartSyncRevision.removeListener(_refreshAfterSync);
    super.dispose();
  }

  void _refreshAfterSync() {
    if (mounted && !loading) _loadCart();
  }

  Future<void> _loadCart() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final res = await (widget.loadCart ?? CartApi.get)();
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
    if (newQuantity < 1 || updatingItems.contains(cartItemId)) return;
    setState(() => updatingItems.add(cartItemId));
    try {
      final res = await (widget.setQuantity ?? CartApi.setQuantity)(
        cartItemId,
        newQuantity,
      );
      if (mounted) setState(() => cart = res);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lỗi cập nhật: $e')));
      }
    } finally {
      if (mounted) setState(() => updatingItems.remove(cartItemId));
    }
  }

  Future<void> _confirmRemove(CartItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa món khỏi giỏ?'),
        content: Text('Bạn muốn xóa ${item.name} khỏi giỏ hàng?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa món'),
          ),
        ],
      ),
    );
    if (confirmed != true ||
        !mounted ||
        updatingItems.contains(item.cartItemId))
      return;
    setState(() => updatingItems.add(item.cartItemId));
    try {
      final res = await (widget.removeItem ?? CartApi.remove)(item.cartItemId);
      if (mounted) setState(() => cart = res);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể xóa món. Vui lòng thử lại.')),
        );
    } finally {
      if (mounted) setState(() => updatingItems.remove(item.cartItemId));
    }
  }

  Future<void> _discardPending() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bỏ thay đổi chưa đồng bộ?'),
        content: const Text(
          'Các thay đổi giỏ hàng chưa đồng bộ trên máy sẽ bị bỏ. Giỏ trên máy chủ được giữ lại.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Quay lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Bỏ thay đổi'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => loading = true);
    try {
      final result = await CartApi.discardPendingChanges();
      if (mounted)
        setState(() {
          cart = result;
          loading = false;
        });
    } catch (_) {
      if (mounted) {
        setState(() => loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Không thể tải giỏ từ máy chủ. Hãy kiểm tra mạng và thử lại.',
            ),
          ),
        );
      }
    }
  }

  Widget _offlineBanner() => Padding(
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          cart?.syncIssue == null
              ? 'Giỏ đang lưu trên máy. Kết nối để đồng bộ và đặt hàng.'
              : 'Không thể đồng bộ: ${cart!.syncIssue}',
        ),
        Wrap(
          children: [
            TextButton(onPressed: _loadCart, child: const Text('Thử đồng bộ')),
            if (cart?.syncIssue != null)
              TextButton(
                onPressed: _discardPending,
                child: const Text('Bỏ thay đổi chưa đồng bộ'),
              ),
          ],
        ),
      ],
    ),
  );

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
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    cart?.isOffline == true
                        ? 'Giỏ hàng lưu trên máy đang trống. Hãy kết nối mạng để đồng bộ.'
                        : 'Giỏ hàng đang trống.',
                  ),
                  if (cart?.isOffline == true) _offlineBanner(),
                ],
              ),
            )
          : Column(
              children: [
                if (cart!.isOffline) _offlineBanner(),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadCart,
                    child: ListView.separated(
                      itemCount: cart!.items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = cart!.items[index];
                        return ListTile(
                          title: Text(
                            item.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text('${formatVnd(item.unitPrice)} đ'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Giảm số lượng',
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed:
                                    item.quantity <= 1 ||
                                        updatingItems.contains(item.cartItemId)
                                    ? null
                                    : () => _updateQuantity(
                                        item.cartItemId,
                                        item.quantity - 1,
                                      ),
                              ),
                              Text(
                                '${item.quantity}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Tăng số lượng',
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed:
                                    updatingItems.contains(item.cartItemId)
                                    ? null
                                    : () => _updateQuantity(
                                        item.cartItemId,
                                        item.quantity + 1,
                                      ),
                              ),
                              IconButton(
                                tooltip: 'Xóa món',
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                ),
                                onPressed:
                                    updatingItems.contains(item.cartItemId)
                                    ? null
                                    : () => _confirmRemove(item),
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
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 4,
                        offset: Offset(0, -2),
                      ),
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
                              '${formatVnd(cart!.totalAmount)} đ',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.deepOrange,
                              ),
                            ),
                          ],
                        ),
                        FilledButton(
                          onPressed: cart!.isOffline
                              ? null
                              : () async {
                                  final placed = await Navigator.push<bool>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const CheckoutPage(),
                                    ),
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

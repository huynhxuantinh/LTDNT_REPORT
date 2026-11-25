String orderStatusLabel(Object? status) => switch (status) {
  'Pending' => 'Chờ xác nhận',
  'Confirmed' => 'Đã xác nhận',
  'Preparing' => 'Đang chuẩn bị',
  'Delivering' => 'Đang giao',
  'Completed' => 'Hoàn thành',
  'Cancelled' => 'Đã hủy',
  _ => 'Không xác định',
};

String orderTypeLabel(Object? type) => switch (type) {
  'Delivery' => 'Giao hàng',
  'DineIn' => 'Ăn tại quán',
  'TakeAway' => 'Mang đi',
  _ => 'Không xác định',
};

String paymentStatusLabel(Object? status) => switch (status) {
  'Paid' => 'Đã thanh toán',
  'Unpaid' => 'Chưa thanh toán',
  _ => 'Không xác định',
};

String roleLabel(Object? role) => switch (role) {
  'Admin' => 'Quản trị viên',
  'Staff' => 'Nhân viên',
  'Member' => 'Khách hàng',
  _ => 'Không xác định',
};

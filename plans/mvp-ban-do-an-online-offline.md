# MVP — Ứng dụng bán đồ ăn Online và Offline

## Mục tiêu ưu tiên

Hoàn thành toàn bộ chức năng có điểm trong đề trước. Phần Staff, bàn ăn và bán
offline là tính năng mở rộng, triển khai sau khi luồng đặt món online đã ổn định.

## 1. Role và phân quyền

- `Member`: xem món, giỏ hàng, đặt đơn online, xem/tìm kiếm đơn của chính mình.
- `Staff`: tạo và xử lý đơn tại quán; không được gọi endpoint hoặc vào màn Admin.
- `Admin`: quản lý user/role, danh mục, món, đơn hàng, bàn ăn.
- Admin xem danh sách user, gán/đổi role, khóa/mở khóa tài khoản.
- API bắt buộc dùng `[Authorize(Roles = "Admin")]` hoặc role tương ứng; Flutter ẩn
  menu/màn hình không có quyền.

## 2. Chức năng bắt buộc — Online

### Tài khoản

- Đăng ký, đăng nhập JWT, đổi mật khẩu, logout.
- Quản lý Member và Role.

### Danh mục và món ăn (Admin)

- Hiển thị/thêm/sửa/xóa danh mục.
- Không cho xóa danh mục nếu còn món.
- Hiển thị món theo danh mục, có lọc category và phân trang.
- Thêm món kèm upload ảnh.
- Sửa món: upload ảnh mới phải xóa file ảnh cũ.
- Xóa món: xóa file ảnh kèm theo.
- Danh sách món có phân trang.

### Trang chủ (Member)

- Hiển thị danh mục.
- Hiển thị món mới nhất, có phân trang.
- Hiển thị món theo danh mục, có phân trang.
- Tìm kiếm món, có phân trang.
- Xem chi tiết món.
- Nút thêm giỏ hàng ở danh sách món và trang chi tiết.

### Giỏ hàng và đơn hàng

- Hiển thị badge số lượng ở icon giỏ.
- Xem giỏ, thêm/xóa món, tăng/giảm số lượng.
- Checkout đơn giao hàng: họ tên, SĐT, địa chỉ, ghi chú.
- MVP dùng COD/thanh toán tiền mặt; đơn mới có `PaymentStatus = Unpaid`, Staff/Admin
  xác nhận thu tiền để chuyển thành `Paid`.
- Member xem danh sách đơn và **chi tiết đơn**.
- Đơn `Delivery`: `Pending` → `Confirmed` → `Preparing` → `Delivering` → `Completed` hoặc `Cancelled`.
- Admin xem danh sách đơn và cập nhật trạng thái.

## 3. Bán offline tại quán (mở rộng sau phần bắt buộc)

- Staff tạo đơn `DineIn` hoặc `TakeAway`.
- `DineIn`: hiển thị bàn có sẵn, chỉ chọn bàn `Available`.
- Tạo đơn thì bàn chuyển `Occupied`; khi thanh toán hoặc đơn hoàn thành/hủy thì trở về `Available`.
- `DineIn`/`TakeAway`: `Pending` → `Confirmed` → `Preparing` → `Completed` hoặc `Cancelled`.
- Staff xác nhận thanh toán tiền mặt cho đơn offline.
- Admin quản lý bàn: số bàn, sức chứa, trạng thái.
- Bổ sung bảng `DiningTables`; `Orders.TableId` chỉ dùng cho `DineIn`.

## 4. Điểm cộng ưu tiên cao

- Upload ảnh danh mục: thêm/sửa/xóa ảnh.
- Xóa món có hai nhánh:
  - Chưa xuất hiện trong `OrderDetails`: xóa cứng bản ghi và file ảnh.
  - Đã xuất hiện trong `OrderDetails`: không xóa cứng, chuyển `IsAvailable = false` và giữ ảnh.
    API phía Member chỉ trả món có `IsAvailable = true`.
- Món liên quan: cùng danh mục, có phân trang.
- Member tìm kiếm đơn hàng.
- Admin tìm kiếm và lọc đơn theo ngày.
- Quên mật khẩu và xác thực email.

## 5. Điểm cộng làm cuối

- VietQR.
- VNPay sandbox.

## 6. Công nghệ

- Flutter/Dart: ứng dụng mobile.
- SQLite trên điện thoại: cache danh mục/món và giỏ hàng offline.
- ASP.NET Core 10 REST API: toàn bộ nghiệp vụ và phân quyền; giỏ hàng trên server là
  nguồn dữ liệu chính.
- SQL Server: cơ sở dữ liệu chính. SQLite chỉ cache/giữ giỏ tạm khi mất mạng và đồng
  bộ về API khi có mạng.

## 7. Database SQL Server

- `Roles`, `Users`
- `Categories`, `FoodItems`
- `DiningTables`
- `Carts`, `CartItems`
- `Orders`, `OrderDetails`
- `Payments`

`Orders` cần có `OrderType` (`Delivery`, `DineIn`, `TakeAway`), `TableId` (nullable,
chỉ dùng cho `DineIn`) và `PaymentStatus` (`Unpaid`, `Paid`, `Failed`, `Refunded`).

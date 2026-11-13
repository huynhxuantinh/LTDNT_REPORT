# Checklist đồ án: Ứng dụng đặt món và quản lý đơn hàng quán ăn

## 1. Công nghệ bắt buộc

- [ ] Flutter + Dart cho ứng dụng di động.
- [ ] SQLite trên điện thoại: cache dữ liệu, giỏ hàng offline và phiên cần thiết.
- [ ] REST API ASP.NET Core 10.
- [ ] SQL Server là cơ sở dữ liệu trung tâm.
- [ ] GitHub repository có nhánh `main` và `dev`.

## 2. Dữ liệu cần thiết

- [ ] Role: `Admin`, `Member`.
- [ ] User/Member: họ tên, email, mật khẩu mã hóa, role, trạng thái.
- [ ] Category: tên danh mục, ảnh/biểu tượng.
- [ ] FoodItem: tên món, giá, mô tả, ảnh, category, trạng thái còn bán.
- [ ] Cart/CartItem: người dùng, món ăn, số lượng, đơn giá.
- [ ] Order/OrderDetail: khách hàng, danh sách món, tổng tiền, địa chỉ/bàn, trạng thái đơn.
- [ ] Payment: phương thức, mã giao dịch, trạng thái thanh toán.

## 3. Chức năng bắt buộc

### Xác thực và phân quyền

- [ ] Đăng ký.
- [ ] Đăng nhập bằng JWT.
- [ ] Đổi mật khẩu.
- [ ] Đăng xuất.
- [ ] Admin quản lý Member.
- [ ] Admin quản lý Role.
- [ ] Phân quyền Member/Admin ở Flutter và API.

### Admin quản lý danh mục

- [ ] Xem danh sách danh mục.
- [ ] Thêm danh mục.
- [ ] Sửa danh mục.
- [ ] Xóa danh mục.
- [ ] Không cho xóa danh mục đang có món ăn.

### Admin quản lý món ăn

- [ ] Danh sách món có phân trang.
- [ ] Thêm món và upload ảnh.
- [ ] Sửa món; thay ảnh mới phải xóa ảnh cũ.
- [ ] Xóa món và xóa file ảnh đi kèm.
- [ ] Phân loại món theo danh mục.

### Khách hàng xem và đặt món

- [ ] Trang chủ hiển thị danh mục.
- [ ] Hiển thị món mới nhất có phân trang.
- [ ] Xem món theo danh mục có phân trang.
- [ ] Tìm kiếm món có phân trang.
- [ ] Xem chi tiết món.
- [ ] Nút thêm vào giỏ.
- [ ] Badge số lượng món trên icon giỏ.
- [ ] Xem giỏ hàng.
- [ ] Tăng/giảm số lượng món trong giỏ.
- [ ] Xóa món khỏi giỏ.
- [ ] Checkout tạo đơn hàng.
- [ ] Xem danh sách đơn hàng và chi tiết đơn của tôi.

### Admin quản lý đơn hàng

- [ ] Danh sách đơn hàng.
- [ ] Cập nhật trạng thái: Chờ xác nhận → Đang chế biến → Đang giao/Phục vụ → Hoàn thành hoặc Hủy.

## 4. Điểm cộng nên làm

- [ ] Upload ảnh danh mục khi thêm/sửa/xóa.
- [ ] Chặn xóa món đã xuất hiện trong OrderDetail.
- [ ] Sản phẩm/món liên quan.
- [ ] Tìm kiếm đơn hàng.
- [ ] Lọc đơn theo ngày.
- [ ] Xác thực email.
- [ ] Quên mật khẩu qua email.
- [ ] Thanh toán VietQR.
- [ ] Thanh toán VNPay sandbox.

## 5. Yêu cầu kỹ thuật không được bỏ qua

- [ ] Flutter gọi REST API cho đăng nhập, món ăn, danh mục, giỏ hàng, đơn hàng và quản trị; không thao tác trực tiếp SQL Server.
- [ ] Mật khẩu mã hóa BCrypt; không lưu mật khẩu gốc.
- [ ] API dùng JWT và kiểm tra role ở server.
- [ ] Upload ảnh kiểm tra định dạng/kích thước; dùng tên file UUID.
- [ ] Xóa ảnh vật lý khi xóa món hoặc đổi ảnh.
- [ ] API phân trang trả `page`, `pageSize`, `totalItems`, `totalPages`.
- [ ] Tạo đơn hàng bằng transaction: Order + OrderDetail + cập nhật giỏ.
- [ ] SQLite không thay thế SQL Server; chỉ phục vụ dữ liệu cục bộ/cache.
- [ ] Không đưa JWT secret, connection string, SMTP key, khóa thanh toán lên GitHub.

## 6. REST API tối thiểu

- [ ] `POST /api/auth/register`, `POST /api/auth/login`, `PUT /api/auth/change-password`, `POST /api/auth/logout`.
- [ ] `GET/POST/PUT/DELETE /api/categories`.
- [ ] `GET/POST/PUT/DELETE /api/foods`; hỗ trợ tìm kiếm, lọc category và phân trang.
- [ ] `GET/POST/PUT/DELETE /api/cart-items`.
- [ ] `POST /api/orders`, `GET /api/orders/my`, `GET /api/orders/{id}`.
- [ ] `GET /api/admin/orders`, `PUT /api/admin/orders/{id}/status`.
- [ ] `GET/PUT /api/admin/users`, `PUT /api/admin/users/{id}/role`.

## 7. Hạng mục nộp/bảo vệ

- [ ] Source Flutter + API + script SQL Server.
- [ ] README hướng dẫn chạy dự án.
- [ ] ERD database và sơ đồ kiến trúc.
- [ ] Danh sách API/request/response.
- [ ] Tài khoản demo Admin và Member.
- [ ] APK Android cài được.
- [ ] Video demo toàn bộ luồng chính.
- [ ] Báo cáo và slide bảo vệ.

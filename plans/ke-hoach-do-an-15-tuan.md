# Kế hoạch đồ án TrekBikes — 15 tuần

## Mục tiêu

Hoàn thiện ứng dụng bán xe đạp Flutter (Dart), dùng SQLite trên điện thoại,
REST API ASP.NET Core 10 và SQL Server. Có hai vai trò: `Admin` và `Member`.

## Nguyên tắc

- SQL Server là nguồn dữ liệu chính; SQLite chỉ lưu giỏ hàng offline, dữ liệu
  cache và phiên đăng nhập cần thiết.
- API bảo vệ bằng JWT, kiểm tra role ở cả API lẫn giao diện.
- Mỗi tuần phải có bản chạy được trên thiết bị Android và đẩy mã nguồn lên GitHub.
- Làm xong toàn bộ chức năng bắt buộc trước tuần 11; điểm cộng làm từ tuần 11.

## Lộ trình

| Tuần | Phạm vi và đầu ra |
| --- | --- |
| 1 | Chốt yêu cầu, use case, ERD, sơ đồ kiến trúc; tạo README, tài khoản demo Admin/Member. |
| 2 | Chuẩn hoá SQL Server: Users, Roles, Categories, Products, ProductImages, Carts, CartItems, Orders, OrderDetails; migration/seed data. Thiết lập Flutter SQLite (`sqflite`, `path`) và cấu hình môi trường. |
| 3 | API xác thực: đăng ký, đăng nhập JWT, đổi mật khẩu, logout/refresh token, phân quyền. Flutter: màn đăng ký/đăng nhập và lưu token an toàn. |
| 4 | API và màn Admin quản lý member/role; chặn route và API theo Admin/Member. |
| 5 | CRUD Category; chặn xóa khi còn Product; màn admin danh mục. |
| 6 | CRUD Product có upload/đổi/xóa ảnh trên server; phân trang; màn admin sản phẩm. |
| 7 | Trang chủ Flutter: category, sản phẩm mới, chi tiết, sản phẩm theo category, tìm kiếm và phân trang. |
| 8 | Hoàn thiện SQLite: cache danh mục/sản phẩm, giỏ hàng offline và đồng bộ giỏ khi đăng nhập. |
| 9 | Giỏ hàng: thêm, badge số lượng, hiển thị, sửa số lượng, xóa; API Cart/CartItem. |
| 10 | Checkout: tạo Order/OrderDetail theo transaction, giảm tồn kho nếu có; lịch sử và chi tiết đơn cho Member. |
| 11 | Admin quản lý đơn: danh sách, tìm kiếm, lọc ngày, cập nhật trạng thái; chặn xóa sản phẩm đã có trong OrderDetail. |
| 12 | Điểm cộng: email xác thực, quên mật khẩu qua email, sản phẩm liên quan. |
| 13 | Thanh toán: ưu tiên VietQR trước, sau đó VNPay sandbox; callback API phải xác minh chữ ký và cập nhật thanh toán idempotent. |
| 14 | Kiểm thử: API integration, test Flutter trọng yếu, kiểm tra quyền, upload/xóa ảnh, offline/online, phân trang và các lỗi biên. |
| 15 | Hoàn thiện UI, tài liệu báo cáo, ERD/API document, video demo, APK release và diễn tập bảo vệ. |

## Điểm cộng theo độ ưu tiên

1. Kiểm tra Product đã có OrderDetail trước khi xóa.
2. Tìm kiếm/lọc đơn theo ngày và sản phẩm liên quan.
3. Quên mật khẩu, xác thực email.
4. VietQR.
5. VNPay sandbox.
6. Đăng nhập Google; Facebook/Zalo chỉ làm khi các phần trên đã ổn định.

## Tiêu chí hoàn thành từng chức năng

- API có request/response rõ ràng và trả lỗi phù hợp.
- Giao diện xử lý loading, empty state, lỗi mạng và xác nhận trước thao tác xóa.
- Chức năng Admin bị từ chối khi gọi API bằng token Member.
- File ảnh được xóa cùng bản ghi, và ảnh cũ được xóa khi cập nhật thành công ảnh mới.
- Mọi danh sách yêu cầu phân trang đều có `page`, `pageSize`, `totalItems`, `totalPages`.

## Rủi ro cần tránh

- Không lưu toàn bộ dữ liệu nghiệp vụ chỉ trong SQLite; phải chứng minh SQL Server và REST API hoạt động.
- Không tin role từ Flutter: API phải kiểm tra `[Authorize(Roles = "Admin")]`.
- Không bắt đầu cổng thanh toán trước khi hoàn thành checkout chuẩn.
- Không commit connection string, JWT secret, SMTP password hoặc khóa thanh toán vào GitHub.

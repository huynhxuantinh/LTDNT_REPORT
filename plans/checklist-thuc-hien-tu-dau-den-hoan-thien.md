# Checklist thực hiện từ đầu đến hoàn thiện

> Đề tài: Ứng dụng bán đồ ăn Online và Offline cho quán ăn.
>
> Quy ước: SQL Server là dữ liệu chính qua REST API; SQLite chỉ chạy trong Flutter
> để cache/giỏ hàng tạm khi mất mạng. Không để Flutter truy cập SQL Server trực tiếp.

## Giai đoạn 0 — Chốt phạm vi và chuẩn bị

- [x] Chốt đề tài bán đồ ăn Online/Offline.
- [x] Chốt role: `Member`, `Staff`, `Admin`.
- [x] Xác nhận Flutter/Dart là công nghệ bắt buộc theo đề bài.
- [x] Tạo GitHub repo, nhánh `main` và `dev`.
- [x] Lưu code tham khảo ở `reference/`, không đưa lên repo public.
- [x] Viết MVP, checklist rubric và kế hoạch thực hiện.
- [ ] Vẽ use case theo 3 role.
- [ ] Vẽ ERD cuối cùng.
- [ ] Vẽ sơ đồ kiến trúc Flutter → REST API → SQL Server; Flutter → SQLite.
- [ ] Chốt quy tắc trạng thái đơn và trạng thái bàn.
- [x] Tạo tài khoản demo: Admin, Staff, Member.

## Giai đoạn 1 — Database SQL Server

### Bảng và ràng buộc

- [x] Tạo `Roles`, `Users`, `RefreshTokens`, token email/quên mật khẩu.
- [x] Tạo `Categories`, `FoodItems`.
- [x] Xác nhận schema: `Categories.ImageUrl`; `FoodItems.ImageUrl`, `IsAvailable`, `CreatedAt`; `Users.IsActive`.
- [x] Tạo `Carts`, `CartItems`.
- [x] Tạo `Orders`, `OrderDetails`, `Payments`, `OrderStatuses`.
- [x] Tạo `DiningTables`: số bàn, sức chứa, trạng thái `Available`/`Occupied`.
- [x] Thêm `Orders.TableId` nullable và FK đến `DiningTables`.
- [x] Cập nhật entity/mapping EF Core đúng toàn bộ schema mới.
- [x] Có `Orders.OrderType`: `Delivery`, `DineIn`, `TakeAway`.
- [x] Có `Orders.PaymentStatus`: `Unpaid`, `Paid`, `Failed`, `Refunded`.
- [x] Unique email, unique tên danh mục, unique món theo danh mục.
- [x] FK chặn xóa category khi còn món.
- [x] FK chặn xóa món khi đã có `OrderDetails`.
- [x] Thêm index cho danh mục/món, tìm kiếm và danh sách đơn.

### Seed và chạy database

- [x] Seed role `Member`, `Admin`, `Staff`.
- [x] Seed trạng thái đơn, danh mục, món, user demo, cart/order/payment demo.
- [x] Seed bàn ăn demo.
- [x] Chạy lại toàn bộ migration trên database trống và kiểm tra đủ bảng/dữ liệu.

## Giai đoạn 2 — REST API nền tảng

- [x] Tạo ASP.NET Core 10 project, EF Core SQL Server và JWT.
- [x] Cấu hình secret/connection string qua file local hoặc environment; không commit secret.
- [x] Viết unit test API.
- [x] Đăng ký: mặc định gán role Member, mật khẩu BCrypt.
- [x] Login JWT + refresh token hash trong SQL Server.
- [x] Đổi mật khẩu và thu hồi refresh token cũ.
- [x] Logout và thu hồi refresh token.
- [x] Thêm endpoint refresh access token.
- [x] Thêm rate limit cho register/login.
- [x] Chuẩn hóa response lỗi và phân trang: `page`, `pageSize`, `totalItems`, `totalPages`.
- [x] Test API với SQL Server thật cho toàn bộ endpoint mới.

## Giai đoạn 3 — User, role và phân quyền

- [x] API Admin xem danh sách user có phân trang/tìm kiếm.
- [x] API Admin gán/đổi role Member/Staff/Admin.
- [x] API Admin khóa/mở khóa user.
- [x] `[Authorize(Roles = "Admin")]` cho API quản trị.
- [ ] `[Authorize(Roles = "Admin,Staff")]` cho API xử lý đơn offline.
- [x] Member chỉ xem/sửa dữ liệu của chính mình.
- [x] Test Member gọi Admin API nhận `403`.
- [x] Test Staff gọi Admin API nhận `403`.
- [ ] Test Member A không thể đọc/sửa giỏ hoặc đơn hàng của Member B.
- [x] Flutter đọc role, ẩn menu và chặn route không đúng quyền.

## Giai đoạn 4 — Danh mục và món ăn (Admin)

### Category

- [x] API xem/thêm/sửa/xóa category.
- [x] Kiểm tra category còn món trước khi xóa, trả lỗi rõ ràng.
- [x] Flutter Admin quản lý category.

### Food item

- [x] API danh sách món phân trang, lọc theo category, tìm kiếm.
- [x] API thêm món và upload ảnh.
- [x] API sửa món; thay ảnh mới phải xóa ảnh cũ sau khi lưu thành công.
- [x] API xóa cứng món chưa có trong `OrderDetails`, đồng thời xóa file ảnh.
- [x] API ẩn món đã có trong `OrderDetails` bằng `IsAvailable = false`.
- [x] API Member chỉ trả món `IsAvailable = true`.
- [x] Flutter Admin quản lý món theo category, tìm kiếm và phân trang.
- [x] Test validation ảnh: kích thước, MIME type, extension, tên file UUID.

## Giai đoạn 5 — Flutter khách hàng và SQLite

### App cơ bản

- [x] Khởi tạo Flutter project và màn hình auth.
- [x] Flutter gọi API đăng ký/login/đổi mật khẩu/logout.
- [x] Lưu access/refresh token bằng secure storage.
- [x] Cấu hình URL API cho Android emulator (`10.0.2.2`) và máy thật (LAN/HTTPS).
- [x] Xử lý loading, lỗi mạng, empty state trên mọi màn.

### Member mua online

- [x] Trang chủ hiển thị category.
- [x] Hiển thị món mới nhất có phân trang.
- [x] Hiển thị món theo category có phân trang.
- [x] Tìm kiếm món có phân trang.
- [x] Trang chi tiết món.
- [x] Nút thêm giỏ ở danh sách và chi tiết.
- [x] Badge số lượng giỏ.
- [x] Hiển thị giỏ; thêm/xóa/tăng/giảm số lượng.
- [x] API Cart/CartItem là nguồn dữ liệu chính khi online.
- [x] Checkout `Delivery`: tên người nhận, SĐT, địa chỉ, ghi chú.
- [x] Tạo Order + OrderDetail bằng transaction; xóa/cập nhật giỏ sau khi đặt thành công.
- [x] Member xem danh sách đơn và xem chi tiết đơn.
- [x] COD/tiền mặt: đơn mới `Unpaid`, sau khi thu tiền chuyển `Paid`.

### SQLite trên điện thoại (làm sau luồng online)

- [x] Thêm `sqflite` và `path`.
- [x] Tạo database SQLite, version và migration cục bộ.
- [x] Cache category và món ăn có thời điểm cập nhật.
- [x] Tạo bảng giỏ hàng local cho offline.
- [x] Đồng bộ giỏ offline lên API sau khi đăng nhập/có mạng.
- [x] Không lưu mật khẩu hoặc token JWT trong SQLite.

## Giai đoạn 6 — Quản lý đơn hàng (Admin)

- [ ] Admin xem danh sách toàn bộ đơn có phân trang.
- [ ] Tìm kiếm theo mã đơn/tên/SĐT.
- [ ] Lọc theo ngày, trạng thái, loại đơn và thanh toán.
- [ ] Cập nhật trạng thái theo đúng luồng; không cho nhảy trạng thái sai.
- [ ] Lưu `UpdatedAt` và user thực hiện cập nhật trạng thái đơn.
- [ ] Xem chi tiết đơn và lịch sử thanh toán.

## Giai đoạn 7 — Điểm cộng nhanh

- [ ] Upload ảnh category đủ thêm/sửa/xóa.
- [ ] Món liên quan cùng category, có phân trang.
- [ ] Member tìm kiếm đơn hàng.
- [ ] Admin tìm kiếm và lọc đơn theo ngày.

## Giai đoạn 8 — Bán offline và bàn ăn

- [ ] Admin CRUD bàn ăn, không xóa bàn đang có đơn mở.
- [ ] Staff xem danh sách bàn, chỉ chọn bàn `Available` cho `DineIn`.
- [ ] Staff tạo đơn `DineIn`, thêm/sửa/xóa món.
- [ ] Khi tạo `DineIn`, bàn chuyển `Occupied` trong transaction.
- [ ] Staff tạo đơn `TakeAway`.
- [ ] Staff xác nhận thanh toán tiền mặt cho đơn offline.
- [ ] Khi thanh toán/hoàn thành/hủy DineIn, bàn trở lại `Available`.
- [ ] Luồng trạng thái Delivery: `Pending` → `Confirmed` → `Preparing` → `Delivering` → `Completed`/`Cancelled`.
- [ ] Luồng trạng thái DineIn/TakeAway: `Pending` → `Confirmed` → `Preparing` → `Completed`/`Cancelled`.
- [ ] Flutter Staff: màn chọn loại đơn, chọn bàn, tạo đơn và xử lý đơn.
- [ ] Test đồng thời: không cho hai Staff chọn cùng một bàn.

## Giai đoạn 9 — Điểm cộng nâng cao

- [ ] Xác thực email.
- [ ] Quên mật khẩu qua email.
- [ ] VietQR: tạo QR, lưu mã giao dịch, đối soát trạng thái thanh toán.
- [ ] VNPay sandbox: tạo URL thanh toán, xác thực chữ ký callback, xử lý callback idempotent.

## Giai đoạn 10 — Kiểm thử, hoàn thiện và bảo vệ

- [ ] Unit/integration test: auth, phân quyền, category, upload ảnh, phân trang, cart, checkout, table conflict.
- [ ] Flutter test các màn và luồng: auth, giỏ, checkout, Staff tạo DineIn.
- [ ] Test trên Android emulator và điện thoại thật.
- [ ] Kiểm tra SQLite offline → online sync.
- [ ] Kiểm tra không có secret/connection string/key thanh toán trong GitHub.
- [ ] Chạy build API và `flutter test` trước mỗi commit lớn.
- [ ] Hoàn thiện README: cài SQL, cấu hình API, chạy Flutter, account demo.
- [ ] Viết tài liệu API, ERD, use case, sơ đồ kiến trúc.
- [ ] Tạo APK release.
- [ ] Chuẩn bị data demo, video demo và slide bảo vệ.
- [ ] Push nhánh `dev`, kiểm tra diff rồi merge vào `main` khi sẵn sàng.

# Ứng dụng bán đồ ăn Online và Offline

Đồ án Flutter/Dart, SQLite trên điện thoại, ASP.NET Core 10 REST API và SQL Server.

- `src/FoodOrdering.Api`: REST API.
- `src/food_ordering_app`: ứng dụng Flutter.
- `database/migrations`: schema và dữ liệu SQL Server.
- `plans/checklist-thuc-hien-tu-dau-den-hoan-thien.md`: checklist thực hiện chính.

## Chuẩn bị

- Cài .NET SDK 10, Flutter SDK và Android SDK; chạy `flutter doctor` để kiểm tra.
- Cài SQL Server 2022 trở lên (có thể dùng SQL Server Express), SQL Server Management Studio (SSMS) hoặc `sqlcmd`.
- Các lệnh dưới đây chạy trong PowerShell tại thư mục gốc của repository.

## Tạo database SQL Server

Khởi động SQL Server và xác định tên instance trong SSMS. Với instance `.\SQLEXPRESS` và Windows Authentication, chạy lần lượt các script dưới đây **một lần trên database mới**:

```powershell
sqlcmd -S '.\SQLEXPRESS' -E -b -f 65001 -i database/migrations/001_initial_schema.sql
sqlcmd -S '.\SQLEXPRESS' -E -b -f 65001 -i database/migrations/002_seed_reference_data.sql
sqlcmd -S '.\SQLEXPRESS' -E -b -f 65001 -i database/migrations/003_add_dining_tables.sql
sqlcmd -S '.\SQLEXPRESS' -E -b -f 65001 -i database/migrations/004_seed_staff_and_dining_tables.sql
sqlcmd -S '.\SQLEXPRESS' -E -b -f 65001 -i database/migrations/006_order_status_history.sql
sqlcmd -S '.\SQLEXPRESS' -E -b -f 65001 -i database/migrations/007_pending_registrations.sql
sqlcmd -S '.\SQLEXPRESS' -E -b -f 65001 -i database/migrations/008_password_reset_code_attempts.sql
sqlcmd -S '.\SQLEXPRESS' -E -b -f 65001 -i database/migrations/009_registration_code_attempts.sql
sqlcmd -S '.\SQLEXPRESS' -E -b -f 65001 -i database/migrations/010_cart_sync_operations.sql
```

Thay tên instance nếu máy bạn khác. Dùng `-f 65001` để đọc dữ liệu tiếng Việt trong script seed bằng UTF-8. Có thể mở từng file trong SSMS và chạy theo thứ tự tương tự; kiểm tra kết quả từng script trước khi chạy tiếp. Script `001` và `006` không chạy lại trên database đã có bảng tương ứng.

Script `005_repair_unicode_seed_data.sql` chỉ dành cho database demo bị lỗi encoding; **không chạy tự động** vì nó ghi đè tên/mô tả món và dữ liệu khác. Sao lưu và xem kỹ nội dung trước khi sử dụng.

### SQLite và đồng bộ giỏ hàng

Flutter dùng SQLite trên thiết bị để lưu danh mục, các trang món và chi tiết món đã tải; khi mất mạng chỉ xem được dữ liệu từng tải trước đó. Giỏ được lưu riêng theo tài khoản, các thay đổi offline được xếp hàng và gửi qua API sau khi đăng nhập, khi mở lại ứng dụng hoặc khi ứng dụng đang mở và có mạng. Mỗi thay đổi có mã riêng để gửi lại không bị cộng trùng. Đặt hàng và thanh toán vẫn cần kết nối API. Nếu món không còn bán hoặc số lượng vượt giới hạn, màn giỏ hiển thị lỗi và cho phép bỏ thay đổi chưa đồng bộ sau khi xác nhận.

Với database đang dùng, chạy migration `010_cart_sync_operations.sql` trước khi khởi động lại API. Dữ liệu cũ trong bảng giỏ offline phiên bản 1 không có thông tin chủ sở hữu nên không được tự gán cho tài khoản nào.

## Cấu hình và chạy API

```powershell
Copy-Item src/FoodOrdering.Api/appsettings.Development.example.json src/FoodOrdering.Api/appsettings.Development.json
```

Mở file `appsettings.Development.json` vừa tạo, sửa `ConnectionStrings:FoodOrdering` theo SQL Server của bạn và thay `Jwt:Key` bằng chuỗi ngẫu nhiên có ít nhất 32 byte. File local này được `.gitignore` loại trừ; không đưa secret lên GitHub.

```powershell
cd src/FoodOrdering.Api
dotnet restore
dotnet watch run
```

API development mặc định nghe tại `http://localhost:5000`. Có thể kiểm tra `http://localhost:5000/api/categories`. Dừng API bằng `Ctrl+C`.

Tính năng email cần cấu hình SMTP local (`Smtp:Host`, `Port`, `User`, `Password`, `From`); không lưu mật khẩu trong file mẫu hoặc commit. Mailtrap Sandbox chỉ nhận email thử nghiệm trong inbox sandbox, không gửi tới hộp thư thật.

Email chứa nút xác thực hoặc đặt lại mật khẩu. Cấu hình `EmailLinks:BaseUrl` trong `appsettings.Development.json` thành địa chỉ API mà trình duyệt mở email truy cập được: `http://localhost:5000` nếu mở trên máy API, hoặc địa chỉ LAN của máy API nếu mở trên điện thoại cùng mạng (chạy API với `--urls http://0.0.0.0:5000`). Với môi trường thật cần URL HTTPS. Mã trong email cũng có thể nhập trực tiếp trong ứng dụng.

## Cấu hình VNPay Sandbox

1. Sửa `src/FoodOrdering.Api/appsettings.json`, mục `VNPay`: thay `TmnCode` và `HashSecret` bằng thông tin VNPay cấp; giữ `BaseUrl` là `https://sandbox.vnpayment.vn/paymentv2/vpcpay.html`.
2. Trên VNPay Sandbox Merchant Admin: https://sandbox.vnpayment.vn/merchantv2/ — điền **IPN URL** là `https://spectacle-surname-emphases.ngrok-free.dev/api/orders/vnpay-ipn`.
3. Chạy API ở cổng 5000, rồi mở PowerShell khác chạy: `ngrok http 5000`.
4. Nếu ngrok hiện domain khác, thay domain đó trong IPN URL ở VNPay và trong `ReturnUrl` tại mục `VNPay` của `appsettings.json`; đường dẫn Return URL là `/api/orders/vnpay-return`. Khởi động lại API sau khi sửa.

Không đưa `HashSecret` lên GitHub.

## Cấu hình và chạy Flutter

Từ thư mục gốc repository:

```powershell
cd src/food_ordering_app
Copy-Item .env.example .env
flutter pub get
flutter devices
```

Mở `.env` và chọn URL API phù hợp với thiết bị:

Copy `src/food_ordering_app/.env.example` thành `.env`, sau đó chọn một URL:

- Android emulator: `API_URL=http://10.0.2.2:5000`
- Điện thoại Android qua USB: đặt `API_URL=http://127.0.0.1:5000` và chạy `adb reverse tcp:5000 tcp:5000` khi điện thoại đã kết nối.
- Điện thoại thật cùng Wi-Fi: chạy API với `dotnet run --urls http://0.0.0.0:5000`, rồi đặt `API_URL=http://<IPv4-LAN-của-máy>:5000`. Điện thoại và máy tính cần liên lạc được qua mạng; firewall phải cho phép cổng 5000.
- Windows/Chrome chạy trên máy API: `API_URL=http://localhost:5000`.
- Production: dùng HTTPS, ví dụ `API_URL=https://api.example.com`.

Android đã được cấp quyền Internet. HTTP cleartext chỉ phục vụ phát triển LAN; bản phát hành dùng HTTPS.

```powershell
flutter run -d <device-id>
```

Lấy `<device-id>` từ `flutter devices`. Sau khi đổi `.env`, dừng và chạy lại ứng dụng để nạp cấu hình mới.

## Tài khoản demo

Sau khi chạy seed trên database mới:

| Vai trò | Email | Mật khẩu demo |
| --- | --- | --- |
| Admin | `admin@foodordering.local` | `Admin@123` |
| Staff | `staff@foodordering.local` | `Staff@123` |
| Member | `member@foodordering.local` | `Member@123` |

Chỉ dùng các tài khoản này cho môi trường demo, không dùng trong production.

## Kiểm thử

```powershell
dotnet test src/FoodOrdering.Api.Tests/FoodOrdering.Api.Tests.csproj
cd src/food_ordering_app
flutter test
```

SQLite phục vụ cache/offline trên điện thoại; đồng bộ offline chưa hoàn thiện. Xem checklist để biết các chức năng và kiểm thử còn lại.

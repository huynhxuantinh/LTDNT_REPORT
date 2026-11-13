# Ứng dụng bán đồ ăn Online và Offline

Đồ án Flutter/Dart, SQLite trên điện thoại, ASP.NET Core 10 REST API và SQL Server.

- `src/FoodOrdering.Api`: REST API.
- `src/food_ordering_app`: ứng dụng Flutter.
- `database/migrations`: schema và dữ liệu SQL Server.
- `plans/checklist-thuc-hien-tu-dau-den-hoan-thien.md`: checklist thực hiện chính.

## URL API Flutter

Copy `src/food_ordering_app/.env.example` thành `.env`, sau đó chọn một URL:

- Android emulator: `API_URL=http://10.0.2.2:5000`
- Điện thoại thật cùng Wi-Fi: chạy API với `dotnet run --urls http://0.0.0.0:5000`, rồi đặt `API_URL=http://<IPv4-LAN-của-máy>:5000`.
- Production: dùng HTTPS, ví dụ `API_URL=https://api.example.com`.

Android đã được cấp quyền Internet. HTTP cleartext chỉ phục vụ phát triển LAN; bản phát hành dùng HTTPS.

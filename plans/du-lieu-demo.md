# Dữ liệu demo

Sau khi chạy seed trong README trên database mới, có thể dùng:

- Ba tài khoản Admin, Staff và Member (thông tin đăng nhập trong README).
- Bốn danh mục và 15 món ăn; đủ để thử lọc, tìm kiếm và phân trang.
- Năm bàn `B01`–`B05` để tạo đơn tại quán.
- Đơn `DEMO-000001` thuộc Member: Delivery, Completed, Paid; hai dòng món với tổng 90.000 đồng. Giao dịch VietQR trong seed chỉ là dữ liệu giả, không phải thanh toán thật.

Trước khi bảo vệ, kiểm tra trên database đang dùng:

1. Đăng nhập từng tài khoản demo và kiểm tra tài khoản chưa bị khóa hoặc đổi mật khẩu.
2. Kiểm tra tên món tiếng Việt, hình ảnh, giá và danh mục hiển thị đúng. Seed hiện chưa có ảnh món; cần chuẩn bị ảnh và upload qua chức năng quản trị khi giao diện hỗ trợ.
3. Tạo thử một đơn Delivery chưa thanh toán và một đơn DineIn/TakeAway bằng ứng dụng khi các luồng đó đã được kiểm thử; kiểm tra trạng thái bàn và thanh toán sau thao tác.
4. Giữ một bàn `Available` để trình diễn tạo đơn tại quán. Không xóa hoặc đặt lại dữ liệu có sẵn chỉ để chuẩn bị demo.

Tham khảo lệnh khởi tạo database trong README. Không chạy script sửa encoding `005` trên dữ liệu có giá trị vì script có thể ghi đè dữ liệu.

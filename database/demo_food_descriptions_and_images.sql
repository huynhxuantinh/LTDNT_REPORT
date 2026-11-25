/* Dữ liệu minh họa cho các món seed. Chỉ bổ sung trường còn trống;
   không ghi đè mô tả hoặc ảnh đã có. Chạy bằng sqlcmd -f 65001. */
USE FoodOrderingDb;
GO

DECLARE @Demo TABLE (Name nvarchar(150), Description nvarchar(500), ImageUrl nvarchar(500));
INSERT INTO @Demo (Name, Description, ImageUrl) VALUES
(N'Cơm gà xối mỡ', N'Cơm ăn cùng gà chiên vàng giòn, dùng kèm rau và nước chấm.', N'/demo-foods/com-ga.jpg'),
(N'Bún bò Huế', N'Bún sợi to trong nước dùng đậm đà, ăn cùng thịt bò và rau.', NULL),
(N'Khoai tây chiên', N'Khoai tây chiên vàng giòn, thích hợp dùng ăn nhẹ hoặc ăn kèm.', NULL),
(N'Trà đào cam sả', N'Trà đào thơm dịu kết hợp vị cam và hương sả, dùng lạnh.', N'/demo-foods/tra-dao.jpg'),
(N'Bánh flan', N'Bánh flan mềm mịn với lớp caramel ngọt dịu.', NULL),
(N'Phở bò tái', N'Phở nước dùng thơm, bánh phở mềm ăn cùng thịt bò tái và rau thơm.', NULL),
(N'Cơm sườn nướng', N'Cơm ăn cùng sườn nướng thơm, dùng kèm rau và nước chấm.', NULL),
(N'Mì xào bò', N'Mì xào cùng thịt bò và rau, dùng nóng.', N'/demo-foods/mi-xao.jpg'),
(N'Gà viên chiên', N'Gà viên chiên vàng giòn, dùng kèm nước chấm.', NULL),
(N'Nem chua rán', N'Nem chua rán vàng giòn, ăn nhẹ cùng nước chấm.', NULL),
(N'Trà sữa trân châu', N'Trà sữa béo nhẹ kết hợp trân châu dai, dùng lạnh.', N'/demo-foods/tra-sua.jpg'),
(N'Cà phê sữa đá', N'Cà phê pha cùng sữa, thêm đá, vị đậm đà.', N'/demo-foods/ca-phe.jpg'),
(N'Nước cam', N'Nước cam có vị chua ngọt, dùng lạnh.', N'/demo-foods/nuoc-cam-local.jpg'),
(N'Chè khúc bạch', N'Chè khúc bạch mềm mát, dùng lạnh với nước đường thanh.', N'/demo-foods/che-khuc-bach.jpg'),
(N'Bánh tiramisu', N'Bánh tráng miệng mềm với hương cà phê và lớp kem.', N'/demo-foods/tiramisu.jpg');

UPDATE food
SET Description = CASE WHEN food.Description IS NULL OR LTRIM(RTRIM(food.Description)) = N'' THEN demo.Description ELSE food.Description END,
    ImageUrl = CASE WHEN food.ImageUrl IS NULL OR LTRIM(RTRIM(food.ImageUrl)) = N'' THEN demo.ImageUrl ELSE food.ImageUrl END,
    UpdatedAt = SYSUTCDATETIME()
FROM dbo.FoodItems AS food
JOIN @Demo AS demo ON food.Name = demo.Name
WHERE food.IsAvailable = 1
  AND ((food.Description IS NULL OR LTRIM(RTRIM(food.Description)) = N'')
    OR (demo.ImageUrl IS NOT NULL AND (food.ImageUrl IS NULL OR LTRIM(RTRIM(food.ImageUrl)) = N'')));

-- Lưu bản thu nhỏ của đúng ảnh seed cũ trên API để tránh lỗi tải ảnh ngoài.
-- Chỉ đổi các URL seed đã biết, không thay ảnh do người dùng tải lên.
DECLARE @Cached TABLE (OriginalUrl nvarchar(500), LocalUrl nvarchar(500));
INSERT INTO @Cached VALUES
(N'https://upload.wikimedia.org/wikipedia/commons/e/ee/B%C3%BAn_b%C3%B2_Hu%E1%BA%BF_minh28397.jpg', N'/demo-foods/bun-bo.jpg'),
(N'https://upload.wikimedia.org/wikipedia/commons/1/19/Cajun_fries_from_Popeyes_Louisiana_Kitchen%2C_Stratford%2C_Ontario%2C_2025-08-04.jpg', N'/demo-foods/khoai-tay.jpg'),
(N'https://upload.wikimedia.org/wikipedia/commons/4/43/Homemade_Flan.jpg', N'/demo-foods/banh-flan-local.jpg'),
(N'https://upload.wikimedia.org/wikipedia/commons/3/3d/Ph%E1%BB%9F_b%C3%B2_in_a_German_restaurant_02.jpg', N'/demo-foods/pho-bo.jpg'),
(N'https://upload.wikimedia.org/wikipedia/commons/3/3c/C%C6%A1m_s%C6%B0%E1%BB%9Dn_n%C6%B0%E1%BB%9Bng.jpg', N'/demo-foods/com-suon.jpg'),
(N'https://upload.wikimedia.org/wikipedia/commons/6/65/Chicken_nuggets_on_a_plate.jpg', N'/demo-foods/ga-vien.jpg'),
(N'https://upload.wikimedia.org/wikipedia/commons/2/26/Nem-chua-ran2.jpg', N'/demo-foods/nem-chua.jpg');
UPDATE food SET ImageUrl = cached.LocalUrl, UpdatedAt = SYSUTCDATETIME()
FROM dbo.FoodItems AS food JOIN @Cached AS cached ON food.ImageUrl = cached.OriginalUrl
WHERE food.IsAvailable = 1;
GO

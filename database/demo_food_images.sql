/* Ảnh minh họa từ Wikimedia Commons. Chỉ bổ sung cho món seed chưa có ảnh;
   không ghi đè ảnh người dùng đã upload. Dùng UTF-8 khi chạy file này. */
USE FoodOrderingDb;

UPDATE dbo.FoodItems SET ImageUrl = CASE Name
    WHEN N'Bún bò Huế' THEN N'https://upload.wikimedia.org/wikipedia/commons/e/ee/B%C3%BAn_b%C3%B2_Hu%E1%BA%BF_minh28397.jpg'
    WHEN N'Khoai tây chiên' THEN N'https://upload.wikimedia.org/wikipedia/commons/1/19/Cajun_fries_from_Popeyes_Louisiana_Kitchen%2C_Stratford%2C_Ontario%2C_2025-08-04.jpg'
    WHEN N'Bánh flan' THEN N'https://upload.wikimedia.org/wikipedia/commons/4/43/Homemade_Flan.jpg'
    WHEN N'Phở bò tái' THEN N'https://upload.wikimedia.org/wikipedia/commons/3/3d/Ph%E1%BB%9F_b%C3%B2_in_a_German_restaurant_02.jpg'
    WHEN N'Cơm sườn nướng' THEN N'https://upload.wikimedia.org/wikipedia/commons/3/3c/C%C6%A1m_s%C6%B0%E1%BB%9Dn_n%C6%B0%E1%BB%9Bng.jpg'
    WHEN N'Gà viên chiên' THEN N'https://upload.wikimedia.org/wikipedia/commons/6/65/Chicken_nuggets_on_a_plate.jpg'
    WHEN N'Nem chua rán' THEN N'https://upload.wikimedia.org/wikipedia/commons/2/26/Nem-chua-ran2.jpg'
    ELSE ImageUrl END
WHERE (ImageUrl IS NULL OR ImageUrl = N'')
  AND Name IN (N'Bún bò Huế', N'Khoai tây chiên', N'Bánh flan', N'Phở bò tái', N'Cơm sườn nướng', N'Gà viên chiên', N'Nem chua rán');

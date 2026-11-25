/* Map every seeded menu item to a locally hosted image under API wwwroot. */
USE FoodOrderingDb;
GO

UPDATE dbo.FoodItems
SET ImageUrl = CASE Name
    WHEN N'Cơm gà xối mỡ' THEN N'/demo-foods/com-ga-xoi-mo.jpg'
    WHEN N'Bún bò Huế' THEN N'/demo-foods/bun-bo-hue.jpg'
    WHEN N'Khoai tây chiên' THEN N'/demo-foods/khoai-tay-chien.jpg'
    WHEN N'Trà đào cam sả' THEN N'/demo-foods/tra-dao.jpg'
    WHEN N'Bánh flan' THEN N'/demo-foods/banh-flan.jpg'
    WHEN N'Phở bò tái' THEN N'/demo-foods/pho-bo-tai.jpg'
    WHEN N'Cơm sườn nướng' THEN N'/demo-foods/com-suon-nuong.jpg'
    WHEN N'Mì xào bò' THEN N'/demo-foods/mi-xao.jpg'
    WHEN N'Gà viên chiên' THEN N'/demo-foods/ga-vien-chien.jpg'
    WHEN N'Nem chua rán' THEN N'/demo-foods/nem-chua-ran.jpg'
    WHEN N'Trà sữa trân châu' THEN N'/demo-foods/tra-sua.jpg'
    WHEN N'Cà phê sữa đá' THEN N'/demo-foods/ca-phe-sua-da.jpg'
    WHEN N'Nước cam' THEN N'/demo-foods/nuoc-cam.jpg'
    WHEN N'Chè khúc bạch' THEN N'/demo-foods/che-khuc-bach.jpg'
    WHEN N'Bánh tiramisu' THEN N'/demo-foods/tiramisu.jpg'
    ELSE ImageUrl
END
WHERE Name IN (
    N'Cơm gà xối mỡ', N'Bún bò Huế', N'Khoai tây chiên', N'Trà đào cam sả', N'Bánh flan',
    N'Phở bò tái', N'Cơm sườn nướng', N'Mì xào bò', N'Gà viên chiên', N'Nem chua rán',
    N'Trà sữa trân châu', N'Cà phê sữa đá', N'Nước cam', N'Chè khúc bạch', N'Bánh tiramisu'
);
GO

SELECT Name, ImageUrl
FROM dbo.FoodItems
WHERE ImageUrl LIKE N'/demo-foods/%'
ORDER BY Name;
GO

/*
  Repairs demo data that was imported with a non-UTF-8 SQL client.
  NCHAR is intentionally used so this script is safe with every SQL client encoding.
*/
USE FoodOrderingDb;
GO

UPDATE dbo.Categories
SET Name = CASE CategoryId
    WHEN 1 THEN N'M' + NCHAR(243) + N'n ch' + NCHAR(237) + N'nh'
    WHEN 2 THEN N'M' + NCHAR(243) + N'n ' + NCHAR(259) + N'n nh' + NCHAR(7865)
    WHEN 3 THEN NCHAR(272) + NCHAR(7891) + N' u' + NCHAR(7889) + N'ng'
    WHEN 4 THEN N'Tr' + NCHAR(225) + N'ng mi' + NCHAR(7879) + N'ng'
    ELSE Name
END,
Description = NULL
WHERE CategoryId BETWEEN 1 AND 4;
GO

UPDATE dbo.FoodItems
SET Name = CASE FoodItemId
    WHEN 1 THEN N'C' + NCHAR(417) + N'm g' + NCHAR(224) + N' x' + NCHAR(7889) + N'i m' + NCHAR(7905)
    WHEN 2 THEN N'B' + NCHAR(250) + N'n b' + NCHAR(242) + N' Hu' + NCHAR(7871)
    WHEN 3 THEN N'Khoai t' + NCHAR(226) + N'y chi' + NCHAR(234) + N'n'
    WHEN 4 THEN N'Tr' + NCHAR(224) + N' ' + NCHAR(273) + NCHAR(224) + N'o cam s' + NCHAR(7843)
    WHEN 5 THEN N'B' + NCHAR(225) + N'nh flan'
    WHEN 6 THEN N'Ph' + NCHAR(7903) + N' b' + NCHAR(242) + N' t' + NCHAR(225) + N'i'
    WHEN 7 THEN N'C' + NCHAR(417) + N'm s' + NCHAR(432) + NCHAR(7901) + N'n n' + NCHAR(432) + NCHAR(7899) + N'ng'
    WHEN 8 THEN N'M' + NCHAR(236) + N' x' + NCHAR(224) + N'o b' + NCHAR(242)
    WHEN 9 THEN N'G' + NCHAR(224) + N' vi' + NCHAR(234) + N'n chi' + NCHAR(234) + N'n'
    WHEN 10 THEN N'Nem chua r' + NCHAR(225) + N'n'
    WHEN 11 THEN N'Tr' + NCHAR(224) + N' s' + NCHAR(7919) + N'a tr' + NCHAR(226) + N'n ch' + NCHAR(226) + N'u'
    WHEN 12 THEN N'C' + NCHAR(224) + N' ph' + NCHAR(234) + N' s' + NCHAR(7919) + N'a ' + NCHAR(273) + NCHAR(225)
    WHEN 13 THEN N'N' + NCHAR(432) + NCHAR(7899) + N'c cam'
    WHEN 14 THEN N'Ch' + NCHAR(232) + N' kh' + NCHAR(250) + N'c b' + NCHAR(7841) + N'ch'
    WHEN 15 THEN N'B' + NCHAR(225) + N'nh tiramisu'
    ELSE Name
END,
Description = NULL;
GO

UPDATE detail
SET FoodNameSnapshot = food.Name
FROM dbo.OrderDetails detail
INNER JOIN dbo.FoodItems food ON food.FoodItemId = detail.FoodItemId;
GO

UPDATE dbo.Users
SET FullName = CASE Email
    WHEN N'admin@foodordering.local' THEN N'Admin demo'
    WHEN N'member@foodordering.local' THEN N'Member demo'
    WHEN N'staff@foodordering.local' THEN N'Staff demo'
    ELSE FullName
END
WHERE Email IN (N'admin@foodordering.local', N'member@foodordering.local', N'staff@foodordering.local');
GO

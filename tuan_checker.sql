Select * from inbound -- INBOUND BY SHOP CODE
Where shop_code like '1049'
and inbound.input_taras_defect = 0 order by id desc;




SELECT * FROM defect d -- DEFECT BY SHOP CODE
INNER JOIN inbound i ON d.purchase_order_num = i.purchase_order_num
WHERE i.shop_code = '1049' ORDER BY d.id DESC;


SELECT * FROM defect d  -- DEFECT BY BARCODE
where barcode = 8887049434551



select * from defect -- defect by style code1 
where style_code = "PW1-26480096-1"
order by id desc




select * from item_list-- item list by style code
where style_code = "PM1-85110464"

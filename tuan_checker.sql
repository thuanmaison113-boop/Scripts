Select * from inbound -- INBOUND BY SHOP CODE
Where shop_code like '1143'
and inbound.input_taras_defect = 0 order by id desc;




SELECT * FROM defect d -- DEFECT BY SHOP CODE
INNER JOIN inbound i ON d.purchase_order_num = i.purchase_order_num
WHERE i.shop_code = '1150' ORDER BY d.id DESC;


SELECT * FROM defect d  -- DEFECT BY BARCODE
where barcode = 8887049434551



select * from defect -- defect by style code1 
where style_code = "CK1-70381205"
order by id desc




select * from item_list-- item list by style code
where style_code = "CK1-70381205"

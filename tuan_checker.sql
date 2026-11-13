Select * from inbound -- INBOUND BY SHOP CODE
Where shop_code like '5802'
and inbound.input_taras_defect = 0 order by id desc;




SELECT * FROM defect d -- DEFECT BY SHOP CODE
INNER JOIN inbound i ON d.purchase_order_num = i.purchase_order_num
WHERE i.shop_code = '1150' ORDER BY d.id DESC;




select * from defect -- defect by style code1 
where style_code = "PW1-66480127"
order by id desc




select * from item_list-- item list by style code
where style_code = "CK2-30671820"

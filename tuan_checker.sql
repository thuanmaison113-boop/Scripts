-- inbound by shop_code 
Select * from inbound
Where shop_code like '1150'
and inbound.input_taras_defect = 0 order by id desc;



-- defect by shop_code
SELECT * FROM defect d
INNER JOIN inbound i ON d.purchase_order_num = i.purchase_order_num
WHERE i.shop_code = '1150' ORDER BY d.id DESC;



-- defect by style code1
select * from defect 
where style_code = "CK1-71650021"
order by id desc



-- item list by style code
select * from item_list
where style_code = "CK2-30671820"

UPDATE defect
SET
    shop_name = (SELECT i.shop_name FROM inbound i WHERE i.purchase_order_num = defect.purchase_order_num),
    item_full_name = (SELECT il.item_full_name FROM item_list il WHERE il.variant  = defect.artical ),
    style_code = (SELECT il.style_code FROM item_list il WHERE il.variant = defect.artical),
    barcode = (SELECT il.barcode FROM item_list il WHERE il.variant = defect.artical ),
    brand_name = (SELECT i.brand_name FROM inbound i WHERE i.purchase_order_num = defect.purchase_order_num)
WHERE 
shop_name IS NULL;
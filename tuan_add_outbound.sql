SELECT
box_qty,
post_date,
delivery_date,
shop_code,
product_qty,
order_qty,
stock_transfer_order_num,
delivery_order_num,
transfer_order_num,
note,
one_off_event,
checklist,
id
FROM outbound ORDER BY id DESC LIMIT 1;
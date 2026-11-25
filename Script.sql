SELECT
	o.id,
    o.post_date,
    o.order_date,
    o.delivery_date,
    o.brand_name,
    o.region,
    o.shop_code,
    o.shop_name,
    o.product_qty,
	o.paper_bag_qty,
    o.stock_transfer_order_num,
    o.delivery_order_num,
    o.note,
    o.box_qty,
    o.order_qty
FROM outbound o
WHERE o.post_date = (
    SELECT MAX(post_date)
    FROM outbound
)
ORDER BY shop_code ASC;



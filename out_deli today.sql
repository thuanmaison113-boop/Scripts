SELECT
	id,
	delivery_date as ngày_yêu_cầu_giao,
	post_date as ngày_post,
	checklist,
	brand_name as nhãn,
	shop_code as mã_shop,
    shop_name as tên_shop,
    region as vùng,
    stock_transfer_order_num as số_PO,
    delivery_order_num as số_DO,
    transfer_order_num,
    note,
    box_qty,
    product_qty,
    paper_bag_qty,
    passed_qc_qty,
    failed_qc_qty,
    order_qty as SL_order,
    one_off_event
    FROM outbound
	WHERE delivery_date = date('now')
	ORDER BY shop_code ASC;
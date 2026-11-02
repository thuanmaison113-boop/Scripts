SELECT
id,
current_action AS action,
brand_name AS brand,
shop_name AS tên_shop,
input_type,
CONCAT(box_qty, '-', input_standard, '-', input_taras_defect, '-', input_paper_bag) AS box_hh_taras_tg,
put_away_bin AS bin,
transfer_order_quality_issue AS TO_QI,
substandard_qty AS QI_Qty,
good_receipt_date,
delivery_order_num AS DO,
purchase_order_num
FROM inbound
WHERE action = 'post'

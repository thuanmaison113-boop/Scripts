SELECT
i.id,
i.shop_code,
i.shop_name,
i.brand_name,
region,
box_qty,
NULLIF(input_standard, 0) as D111,
NULLIF(input_taras_defect, 0) as D116,
NULLIF(input_paper_bag, 0) as túi_giấy,
NULLIF(input_visual_merchandising, 0) as VMR,
input_type,
purchase_order_num,
delivery_order_num,
good_issue_date,
transfer_order_num,
put_away_bin,
transfer_order_quality_issue,
substandard_qty,
arrival_date,
good_receipt_date,
i.note
FROM inbound i
LEFT JOIN "shop" s ON i.shop_code = s.shop_code
WHERE good_receipt_date =
    (SELECT MAX(good_receipt_date)
     FROM inbound i2);
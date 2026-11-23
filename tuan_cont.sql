SELECT
id,
shop_code,
note,
CASE 
    WHEN brand_name = 'Charles & Keith' THEN 'CK'
    ELSE brand_name
END AS brand,
box_qty as box,
input_standard,
input_paper_bag AS tg,
input_visual_merchandising as vmr,
input_type AS Loại,
purchase_order_num AS PO,
delivery_order_num,
good_issue_date,
current_action,
good_receipt_date,
arrival_date AS Arrival
FROM inbound
WHERE region = 'CONT'
ORDER BY id DESC;
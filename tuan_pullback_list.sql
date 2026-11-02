SELECT
id,
brand_name AS brand,
shop_code as code,
shop_name AS shop,
current_action AS action,
good_receipt_date as GRdate,
put_away_bin AS Bin,
input_type AS loại,
box_qty,
input_standard,
input_paper_bag,
input_taras_defect,
transfer_order_quality_issue AS TO_QI,
substandard_qty AS QI_Qty,
purchase_order_num AS STO,
delivery_order_num AS DO,
shop_name AS shop,
good_issue_date AS send_date,
arrival_date
FROM inbound  
WHERE current_action IS NULL AND region <> 'CONT'
AND purchase_order_num IN (




);
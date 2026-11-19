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
transfer_order_shortage AS TO_lost,
shortage_qty AS lost_qty,
purchase_order_num AS STO,
delivery_order_num AS DO,
shop_name AS shop,
good_issue_date AS send_date,
arrival_date
FROM inbound  
WHERE current_action IS NULL AND region <> 'CONT'
AND purchase_order_num IN (
4700534362,
4700534363,
4700534369,
4700534370,
4700534371,
4700534372,
4700534373,
4700534374,
4700534375,
4700536906,
4700536922,
4700536912,
4700536913,
4700537416


);


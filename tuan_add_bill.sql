SELECT
id,
brand_name,
shop_code AS code,
shop_name AS tên_shop,
box_qty AS số_thùng,
input_standard,
input_taras_defect,
input_paper_bag,
arrival_date AS Arrival,
way_bill,
input_type AS loại,
note,
purchase_order_num AS PO,
delivery_order_num AS DO,
good_issue_date AS send_date
FROM inbound
WHERE current_action IS NULL AND region <> 'CONT';
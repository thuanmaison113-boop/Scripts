SELECT
shop_code,
purchase_order_num,
delivery_order_num,
good_issue_date,
input_standard,
input_taras_defect,
input_paper_bag,
note,
arrival_date,
input_type,
id
FROM inbound 
ORDER BY id DESC LIMIT 1;






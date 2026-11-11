CREATE VIEW vw_check_one_off_event_wrong AS
SELECT 'outbound' AS tbl, one_off_event, COUNT(*) AS lines
FROM outbound
WHERE one_off_event IS NOT NULL
  AND one_off_event NOT IN (SELECT event_code FROM one_off_event_type)
GROUP BY one_off_event
UNION ALL
SELECT 'inbound', one_off_event, COUNT(*)
FROM inbound
WHERE one_off_event IS NOT NULL
  AND one_off_event NOT IN (SELECT event_code FROM one_off_event_type)
GROUP BY one_off_event;


CREATE VIEW vw_check_inbound_expected_arrival_unresolved AS
SELECT activity, shop_region, brand_name, COUNT(*) AS rows_unscheduled
FROM vw_pbi_inbound_expected_arrival
WHERE arrival_date IS NULL
  AND arrival_date_status = 'Unscheduled'
GROUP BY activity, shop_region, brand_name
ORDER BY rows_unscheduled DESC;


CREATE VIEW vw_check_plan_closed_day AS
 SELECT p.source, p.plan_type, p.brand_code, p.delivery_date, SUM(p.qty) AS qty_dropped
 FROM vw_pbi_plan_final_all p
 JOIN date_tb dt ON dt.Date = p.delivery_date
 WHERE p.delivery_date >= DATE('now')
   AND (dt.Weekend <> 'Weekday'
        OR EXISTS (SELECT 1 FROM date_exception de
                   WHERE p.delivery_date BETWEEN de.start_date AND de.end_date))
 GROUP BY p.source, p.plan_type, p.brand_code, p.delivery_date;

CREATE VIEW vw_check_item_40_not_in_zsta AS
SELECT e.*
FROM item_export e
LEFT JOIN item_zsta z
    ON CAST(e.Variant AS TEXT) = CAST(z.variant AS TEXT)
WHERE substr(CAST(e.Variant AS TEXT), 1, 2) = '40'
  AND z.variant IS NULL;

CREATE VIEW vw_check_shop_code_not_in_shop_table AS
SELECT i.shop_code
FROM inbound i
WHERE NOT EXISTS ( SELECT 1 FROM shop s WHERE s.shop_code = i.shop_code)
UNION ALL
SELECT o.shop_code
FROM outbound o
WHERE NOT EXISTS ( SELECT 1 FROM shop s WHERE s.shop_code = o.shop_code);


CREATE VIEW vw_check_shop_code_not_in_shop_groupx AS
SELECT s.shop_code,
s.shop_name 
FROM shop s
WHERE NOT EXISTS (
    SELECT 1
    FROM outbound_groupx og
    WHERE og.shop_code = s.shop_code
) AND shop_type NOT IN ("warehouse","GENERAL","ecom");

CREATE VIEW vw_check_dup_DO_outbound AS
SELECT 
    delivery_order_num,
    COUNT(*) AS duplicate_count
FROM outbound
WHERE delivery_order_num IS NOT NULL
  AND delivery_order_num <> ''
GROUP BY delivery_order_num
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;


CREATE VIEW vw_check_dup_PO_inbound AS
SELECT 
    purchase_order_num,
    COUNT(*) AS duplicate_count
FROM inbound
WHERE purchase_order_num IS NOT NULL
  AND purchase_order_num <> ''
GROUP BY purchase_order_num
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;

CREATE VIEW vw_check_connection_all_table AS
SELECT "table", parent, COUNT(*) AS bad_rows
FROM pragma_foreign_key_check
GROUP BY "table", parent ORDER BY bad_rows DESC;
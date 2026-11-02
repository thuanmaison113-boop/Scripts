CREATE VIEW vw_NXT_total_outbound_tiki AS
SELECT
strftime('%Y-%m', post_date) AS year_month,
brand_name,
SUM(product_qty + paper_bag_qty) AS total_outbound
FROM outbound
WHERE post_date IS NOT NULL AND shop_code LIKE '%99M2%'
GROUP BY year_month, brand_name
ORDER BY year_month, brand_name;

CREATE VIEW vw_NXT_cyclecount_last_month AS
SELECT
*
FROM cyclecount
WHERE document_date >= date('now', 'start of month', '-1 month')
  AND document_date < date('now', 'start of month');

CREATE VIEW vw_NXT_stocktaking_last_month AS
SELECT
*
FROM stocktaking
WHERE document_date >= date('now', 'start of month', '-1 month')
  AND document_date < date('now', 'start of month');

CREATE VIEW vw_NXT_job_last_month AS
SELECT
id,
note as tên_job,
brand_name as nhãn,
box_qty as số_thùng,
NULLIF(input_standard, 0) as D111,
NULLIF(input_paper_bag, 0) as túi_giấy,
NULLIF(input_visual_merchandising, 0) as VMR,
input_type as Loại,
purchase_order_num as PO,
delivery_order_num as số_post,
good_issue_date as GI_date,
NULLIF(substandard_qty, 0) as QI_Qty,
arrival_date as Arrival_date,
good_receipt_date as GR_date
FROM inbound
WHERE region = 'CONT'
  AND good_issue_date >= date('now', 'start of month', '-1 month')
  AND good_issue_date < date('now', 'start of month');

CREATE VIEW vw_NXT_last_month_outbound_summary AS
WITH outbound_summary AS (
SELECT
    brand_name,
    SUM(CASE WHEN main_vendor = 'D111' THEN product_qty ELSE 0 END) AS D111,
    SUM(CASE WHEN main_vendor = 'D116' THEN product_qty ELSE 0 END) AS D116,
    SUM(paper_bag_qty) AS paperbag,
    SUM(CASE WHEN main_vendor = 'D111' THEN product_qty ELSE 0 END) +
    SUM(CASE WHEN main_vendor = 'D116' THEN product_qty ELSE 0 END) +
    SUM(paper_bag_qty) AS total
FROM outbound
WHERE strftime('%Y-%m', post_date) = strftime('%Y-%m', DATE('now', 'start of month', '-1 month'))
GROUP BY brand_name
)
SELECT * FROM outbound_summary
UNION ALL
SELECT
    'TOTAL',
    SUM(D111),
    SUM(D116),
    SUM(paperbag),
    SUM(total)
FROM outbound_summary;

CREATE VIEW vw_NXT_last_month_inbound_cont_only AS
WITH inbound_raw AS (
    SELECT
        region,
        brand_name,
        input_standard,
        input_visual_merchandising,
        input_taras_defect,
        input_paper_bag
    FROM inbound
    WHERE strftime('%Y-%m', good_issue_date) = strftime('%Y-%m', DATE('now', 'start of month', '-1 month'))
),
inbound_summary AS (
    SELECT
        brand_name,
        -- CONT region
        SUM(CASE WHEN region = 'CONT' THEN input_standard ELSE 0 END) AS CONT_standard,
        SUM(CASE WHEN region = 'CONT' THEN input_visual_merchandising ELSE 0 END) AS CONT_visual,
        SUM(CASE WHEN region = 'CONT' THEN input_paper_bag ELSE 0 END) AS CONT_paperbag
    FROM inbound_raw
    GROUP BY brand_name
)
SELECT * 
FROM inbound_summary
UNION ALL
SELECT
    'TOTAL' AS brand_name,
    SUM(CONT_standard) AS CONT_standard,
    SUM(CONT_visual) AS CONT_visual,
    SUM(CONT_paperbag) AS CONT_paperbag
FROM inbound_summary;

CREATE VIEW vw_NXT_cont_summary_by_date_brand AS
SELECT
    good_issue_date,
    brand_name,
    SUM(NULLIF(input_standard, 0)) AS total_D111,
    SUM(NULLIF(input_paper_bag, 0)) AS total_tui_giay,
    SUM(NULLIF(input_visual_merchandising, 0)) AS total_VMR
FROM inbound
WHERE region = 'CONT'
  AND good_issue_date >= date('now', 'start of month', '-1 month')
  AND good_issue_date < date('now', 'start of month')
GROUP BY good_issue_date, brand_name
ORDER BY good_issue_date, brand_name;

CREATE VIEW vw_NXT_outbound_shop_last_month AS
SELECT
    shop_code,
    SUM(product_qty + paper_bag_qty) AS total
FROM outbound
WHERE strftime('%Y-%m', post_date) = strftime('%Y-%m', DATE('now', 'start of month', '-1 month')) AND brand_name = "Charles & Keith"
GROUP BY shop_code
ORDER BY shop_code;

CREATE VIEW vw_NXT_last_month_inbound_summary AS
SELECT
        brand_name,
        SUM(CASE WHEN region != 'CONT' THEN input_standard ELSE 0 END) AS D111_standard,
        SUM(CASE WHEN region != 'CONT' THEN input_visual_merchandising ELSE 0 END) AS D111_visual,
        SUM(CASE WHEN region != 'CONT' THEN input_taras_defect ELSE 0 END) AS D116,
        SUM(CASE WHEN region != 'CONT' THEN input_paper_bag ELSE 0 END) AS D111_paperbag,
        SUM(input_standard + input_visual_merchandising + input_taras_defect + input_paper_bag) AS total
FROM inbound
WHERE strftime('%Y-%m', good_issue_date) = strftime('%Y-%m', DATE('now', 'start of month', '-1 month')) AND region != 'CONT'
GROUP BY brand_name

CREATE VIEW vw_NXT_inbound_shop_last_month AS
SELECT
    shop_code,
    SUM(input_standard + input_taras_defect + input_paper_bag + input_visual_merchandising) AS total
FROM inbound
WHERE strftime('%Y-%m', good_issue_date) = strftime('%Y-%m', DATE('now', 'start of month', '-1 month')) AND brand_name = "Charles & Keith" AND region <> "CONT"
GROUP BY shop_code
ORDER BY shop_code;

CREATE VIEW vw_NXT_multi_4000_last_month AS
SELECT
post_date,
product_qty,
paper_bag_qty,
stock_transfer_order_num
FROM outbound
WHERE brand_name = 'Multibrand' AND strftime('%Y-%m', post_date) = strftime('%Y-%m', DATE('now', 'start of month', '-1 month'));


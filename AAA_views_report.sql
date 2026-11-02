CREATE VIEW vw_report_outbound_last_month AS
SELECT
post_date as ngày_post,
main_vendor as site_xuất,
brand_name as nhãn,
shop_name as tên_shop,
product_qty as hàng_hóa,
paper_bag_qty as túi_giấy,
note,
order_qty,
note2
FROM outbound
WHERE post_date >= date('now', 'start of month', '-1 month')
  AND post_date < date('now', 'start of month');

CREATE VIEW vw_report_defect_aggregation_by_ref AS
SELECT 
    i.style_code,
    m.material,
    d.defect_type,
    COUNT(*) AS issue_count
FROM 
    defect d
JOIN 
    item_list i	 ON d.barcode = i.barcode
JOIN 
    item_material m ON d.barcode = m.barcode
GROUP BY 
    i.style_code, m.material, d.defect_type 
ORDER BY 
    issue_count DESC;

CREATE VIEW vw_report_inbound_aggregation_by_brand AS
SELECT
    brand_name,
    SUM(input_standard) AS total_input_standard,
    ROUND(AVG(input_standard), 2) AS avg_input_standard
FROM inbound
WHERE input_standard IS NOT NULL
GROUP BY brand_name
ORDER BY total_input_standard DESC;

CREATE VIEW vw_report_inbound_CONT_percent_of_total AS
SELECT
    shop_code,
    input_standard  AS total_scan,
    ROUND((input_standard  * 100) / SUM(input_standard ) OVER (), 0) AS percent_of_total
FROM 
    inbound
WHERE 
    shop_code LIKE '%CONT%'
GROUP BY shop_code;

CREATE VIEW vw_report_defect_rate_by_shop AS
SELECT
    i.shop_name,
    b.brand_name AS brand,
    p.province_name,
    COALESCE(SUM(d.defect_qty), 0) AS total_defect_qty,
    COALESCE(SUM(i.input_standard), 0) AS total_received_qty,
    ROUND(100.0 * SUM(d.defect_qty) / NULLIF(SUM(i.input_standard), 0), 3) AS defect_rate
FROM defect d
INNER JOIN inbound i ON d.purchase_order_num = i.purchase_order_num
INNER JOIN shop s ON i.shop_code = s.shop_code
INNER JOIN brand b ON s.brand = b.brand_code
INNER JOIN province p ON s.province_id = p.id
WHERE p.region != 'CONT'
  AND i.shop_name NOT IN ('KHO D111', 'ECOM QUẬN 8', 'KHO ECOM THỦ ĐỨC')
GROUP BY i.shop_name, b.brand_name, p.province_name
HAVING defect_rate IS NOT NULL;

CREATE VIEW vw_report_inbound_aggregation AS
SELECT
  brand_name,
  COUNT(*) AS total_rows,
  COUNT(CASE WHEN input_standard > 10 THEN 1 END) AS over_10_input,
  COUNT(CASE WHEN status = 'complete' THEN 1 END) AS complete_status_count,
  COUNT(CASE WHEN input_standard BETWEEN 5 AND 10 THEN 1 END) AS mid_input,
  COUNT(CASE WHEN good_receipt_date IS NOT NULL THEN 1 END) AS with_gr_date
FROM inbound
GROUP BY brand_name;

CREATE VIEW vw_report_outbound_disparity_last_month AS
SELECT
post_date,
brand_name,
shop_code,
product_qty,
paper_bag_qty,
order_qty,
       (COALESCE(product_qty, 0) + COALESCE(paper_bag_qty, 0) - COALESCE(order_qty, 0)) AS disparity,
note
FROM outbound
WHERE strftime('%Y-%m', post_date) = strftime('%Y-%m', DATE('now', '-1 month'))
  AND COALESCE(product_qty, 0) + COALESCE(paper_bag_qty, 0) <> COALESCE(order_qty, 0) AND note != 'chênh lệch pullback';

CREATE VIEW vw_report_outbound_disparity_percent_last_month AS
WITH monthly_totals AS (
    SELECT 
        brand_name,
        SUM(COALESCE(product_qty, 0) + COALESCE(paper_bag_qty, 0)) AS total_product_paper
    FROM outbound
    WHERE strftime('%Y-%m', post_date) = strftime('%Y-%m', DATE('now', '-1 month'))
    GROUP BY brand_name
),
disparity_totals AS (
    SELECT 
        brand_name,
        SUM(COALESCE(product_qty, 0) + COALESCE(paper_bag_qty, 0) - COALESCE(order_qty, 0)) AS total_disparity
    FROM outbound
    WHERE strftime('%Y-%m', post_date) = strftime('%Y-%m', DATE('now', '-1 month'))
      AND COALESCE(product_qty, 0) + COALESCE(paper_bag_qty, 0) <> COALESCE(order_qty, 0) AND note != 'chênh lệch pullback'
    GROUP BY brand_name
)
SELECT 
    m.brand_name,
    m.total_product_paper,
    COALESCE(d.total_disparity, 0) AS total_disparity,
    ROUND(
        100.0 * COALESCE(d.total_disparity, 0) / NULLIF(m.total_product_paper, 0),
        2
    ) AS disparity_percent
FROM monthly_totals m
LEFT JOIN disparity_totals d ON m.brand_name = d.brand_name
ORDER BY m.brand_name;

CREATE VIEW vw_report_inbound_last5dayGI AS
SELECT delivery_order_num as DO_num
FROM inbound
WHERE DATE(good_issue_date) >= DATE('now', '-5 days')
  AND region <> 'CONT';

CREATE VIEW vw_report_daily_diff_in_out_last_date AS
SELECT 
    brand,
    MAX(date) AS date,
    SUM(D111_in - D111_out) AS D111_balance,
    SUM(D116_in - D116_out) AS D116_balance,
    SUM(paperbag_in - paperbag_out) AS paperbag_balance
FROM (
    SELECT 
        i.good_receipt_date AS date, 
        b.brand_name AS brand, 
        SUM(i.input_standard + i.input_visual_merchandising) AS D111_in,
        0 AS D111_out,
        SUM(i.input_taras_defect) AS D116_in, 
        0 AS D116_out,
        SUM(i.input_paper_bag) AS paperbag_in,
        0 AS paperbag_out
    FROM inbound i
    LEFT JOIN "shop" s ON i.shop_code = s.shop_code
    LEFT JOIN brand b ON s.brand = b.brand_code
    WHERE i.good_receipt_date = (SELECT MAX(good_receipt_date) FROM inbound)
    GROUP BY b.brand_name
    UNION ALL
    SELECT 
        o.post_date AS date, 
        b.brand_name AS brand, 
        0 AS D111_in,
        SUM(CASE WHEN o.main_vendor = 'D111' THEN o.product_qty ELSE 0 END) AS D111_out,
        0 AS D116_in,
        SUM(CASE WHEN o.main_vendor = 'D116' THEN o.product_qty ELSE 0 END) AS D116_out,
        0 AS paperbag_in,
        SUM(o.paper_bag_qty) AS paperbag_out
    FROM outbound o
    LEFT JOIN "shop" s ON o.shop_code = s.shop_code
    LEFT JOIN brand b ON s.brand = b.brand_code
    WHERE o.post_date = (SELECT MAX(post_date) FROM outbound)
    GROUP BY b.brand_name
) AS combined
GROUP BY brand;


CREATE VIEW outbound_compare_2025_2026_CK AS
SELECT
    strftime('%m',delivery_date ) AS month,
    SUM(CASE WHEN strftime('%Y', delivery_date) = '2025'
             THEN product_qty ELSE 0 END) AS qty_2025,
    SUM(CASE WHEN strftime('%Y', delivery_date) = '2026'
             THEN product_qty ELSE 0 END) AS qty_2026
FROM outbound
WHERE brand_name = 'Charles & Keith'
  AND strftime('%Y', delivery_date) IN ('2025', '2026')
GROUP BY month
ORDER BY month;

CREATE VIEW inbound_compare_2025_2026_CK AS
SELECT
    strftime('%m', arrival_date) AS month,
    SUM(CASE
        WHEN strftime('%Y', arrival_date) = '2025'
        THEN input_standard + input_taras_defect ELSE 0 END) AS qty_2025,
    SUM(CASE
        WHEN strftime('%Y', arrival_date) = '2026'
        THEN input_standard + input_taras_defect ELSE 0 END) AS qty_2026
FROM inbound
WHERE brand_name = 'Charles & Keith'
    AND region <> 'CONT'
    AND strftime('%Y', arrival_date) IN ('2025', '2026')
GROUP BY month
ORDER BY month;

CREATE VIEW check_dupSTO_outbound AS
SELECT stock_transfer_order_num,
    COUNT(*) AS duplicate_count
FROM outbound GROUP BY stock_transfer_order_num HAVING COUNT(*) > 1;


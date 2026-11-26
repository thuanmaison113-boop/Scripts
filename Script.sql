-- Move groupx (handover group) from outbound_groupx into shop (you 2026-11-26 11:24: G1 keep name groupx, G2 default 100,
-- G3 drop the old table, G4 one DB per site). Tested on the DB copy of 2026-11-25 (06_DB_COPY) by Claude.
-- Run in DBeaver on the live DB as one script. After it runs, delete this file (= deployed).

BEGIN;

-- 1. new column in shop: every shop starts at 100, then the 379 shops of outbound_groupx get their own group
ALTER TABLE shop ADD COLUMN groupx TEXT DEFAULT '100';
UPDATE shop SET groupx = (SELECT g.groupx FROM outbound_groupx g WHERE g.shop_code = shop.shop_code)
WHERE shop_code IN (SELECT shop_code FROM outbound_groupx WHERE groupx IS NOT NULL AND TRIM(groupx) <> '');

-- 2. the 4 views read s.groupx (same output column groupx; join to outbound_groupx removed)
-- data_tool_outbound_deli_today
DROP VIEW "data_tool_outbound_deli_today";
CREATE VIEW data_tool_outbound_deli_today AS
SELECT
    o.shop_code,
    o.shop_name,
    o.delivery_order_num AS do_num,
    o.note,
    o.box_qty,
    s.groupx,
    CASE WHEN s.carrier IS NULL OR TRIM(s.carrier) IN ('', '-') THEN 'other' ELSE s.carrier END AS carrier_code
FROM outbound AS o

LEFT JOIN "shop" AS s
    ON o.shop_code = s.shop_code
WHERE o.delivery_date = DATE('now')
ORDER BY s.groupx, o.shop_name ASC;

-- data_tool_outbound_include_today
DROP VIEW "data_tool_outbound_include_today";
CREATE VIEW data_tool_outbound_include_today AS
SELECT
    i.shop_code,
    s.shop_name,
    i.note AS do_num,
    i.item_name AS note,
    i.box_qty AS box_qty,
    s.groupx,
    CASE WHEN s.carrier IS NULL OR TRIM(s.carrier) IN ('', '-') THEN 'other' ELSE s.carrier END AS carrier_code
FROM outbound_include AS i

LEFT JOIN "shop" AS s
    ON i.shop_code = s.shop_code
WHERE i.dely_date = DATE('now')
ORDER BY s.groupx, i.shop_code, s.shop_name ASC;

-- AAA_outbound_province_bill_expect_date
DROP VIEW "AAA_outbound_province_bill_expect_date";
CREATE VIEW AAA_outbound_province_bill_expect_date AS
WITH wd AS (            -- working days: Mon–Sat, minus date_exception
    SELECT d.Date, ROW_NUMBER() OVER (ORDER BY d.Date) AS wd_no
    FROM date_tb d
    WHERE d.Date BETWEEN DATE('now') AND DATE('now', '+60 days')
      AND d.Weekend = 'Weekday'
      AND NOT EXISTS (SELECT 1 FROM date_exception e
                      WHERE d.Date BETWEEN e.start_date AND e.end_date)
),
t AS (
    SELECT
        o.shop_code, o.shop_name, b.brand_name,
        o.delivery_order_num AS do_num, o.note, o.box_qty,
        s.groupx, s.lead_time_day,
        c.name AS carrier_name, c.tracking_url, c.contact_name, c.contact_phone
    FROM outbound o
    LEFT JOIN "shop" s          ON o.shop_code = s.shop_code
    LEFT JOIN brand b           ON s.brand = b.brand_code
    LEFT JOIN province p        ON s.province_id = p.province_id
    LEFT JOIN carrier c         ON s.carrier = c.carrier_code
    WHERE o.delivery_date = DATE('now')
      AND p.region = 'province'
    UNION ALL
    SELECT
        i.shop_code, s.shop_name, b.brand_name,
        i.note AS do_num, i.item_name AS note, i.box_qty,
        s.groupx, s.lead_time_day,
        c.name, c.tracking_url, c.contact_name, c.contact_phone
    FROM outbound_include i
    LEFT JOIN "shop" s          ON i.shop_code = s.shop_code
    LEFT JOIN brand b           ON s.brand = b.brand_code
    LEFT JOIN province p        ON s.province_id = p.province_id
    LEFT JOIN carrier c         ON s.carrier = c.carrier_code
    WHERE i.dely_date = DATE('now')
      AND p.region = 'province'
    UNION ALL
    SELECT
        p1.to_shop, s.shop_name, b.brand_name,
        '-', 'zLCNB', SUM(p1.box_qty),
        s.groupx, s.lead_time_day,
        c.name, c.tracking_url, c.contact_name, c.contact_phone
    FROM pullback p1
    LEFT JOIN "shop" s          ON p1.to_shop = s.shop_code
    LEFT JOIN brand b           ON s.brand = b.brand_code
    LEFT JOIN province p        ON s.province_id = p.province_id
    LEFT JOIN carrier c         ON s.carrier = c.carrier_code
    WHERE p1.pullback_date = DATE('now')
      AND p1.to_shop NOT LIKE '%' || (SELECT main_site FROM site_info) || '%'
      AND p1.to_shop NOT LIKE '%' || IFNULL((SELECT taras_site FROM site_info), '~') || '%'
      AND p.region = 'province'
    GROUP BY p1.to_shop, s.shop_name, b.brand_name, s.groupx, s.lead_time_day,
             c.name, c.tracking_url, c.contact_name, c.contact_phone
),
agg AS (
    SELECT
        shop_code,
        MAX(shop_name)                  AS shop_name,
        MAX(brand_name)                 AS brand_name,
        SUM(box_qty)                    AS box_qty,
        COALESCE(MAX(lead_time_day), 0) AS lead_time_day,
        MAX(carrier_name)               AS carrier_name,
        MAX(tracking_url)               AS tracking_url,
        MAX(contact_name)               AS contact_name,
        MAX(contact_phone)              AS contact_phone,
        MAX(groupx)                     AS groupx
    FROM t
    GROUP BY shop_code
)
SELECT
    a.shop_code                         AS mã_shop,
    a.shop_name                         AS tên_shop,
    a.brand_name                        AS brand_name,
    a.box_qty                           AS số_thùng,
    '-'                                 AS bill_vận_chuyển,
    (SELECT w.Date FROM wd w
     WHERE w.wd_no = (SELECT MIN(wd_no) FROM wd) + a.lead_time_day)
                                        AS ngày_giao_hàng_dự_kiến,
    a.carrier_name                      AS Đơn_vị_vận_chuyển,
    a.tracking_url                      AS tracking_url,
    a.contact_name                      AS contact_name,
    a.contact_phone                     AS contact_phone
FROM agg a
ORDER BY a.groupx, a.shop_name;

-- data_tool_pullback_today
DROP VIEW "data_tool_pullback_today";
CREATE VIEW data_tool_pullback_today AS
SELECT
    p.to_shop AS shop_code,
    s.shop_name,
    '-' AS do_num,
    'zLCNB' AS note,
    SUM(p.box_qty) AS box_qty,
    s.groupx,
    CASE WHEN s.carrier IS NULL OR TRIM(s.carrier) IN ('', '-') THEN 'other' ELSE s.carrier END AS carrier_code
FROM pullback AS p
LEFT JOIN "shop" AS s
    ON p.to_shop = s.shop_code
WHERE p.pullback_date = DATE('now')
  AND p.to_shop NOT LIKE '%' || (SELECT main_site FROM site_info) || '%'
  AND p.to_shop NOT LIKE '%' || IFNULL((SELECT taras_site FROM site_info), '~') || '%'
GROUP BY p.to_shop, s.shop_name, s.groupx, s.carrier
ORDER BY s.groupx, p.to_shop, s.shop_name ASC;

-- 3. the check view, the trigger and the old table go (G2: every shop has a group now; G3: no backup table)
DROP VIEW "vw_check_shop_code_not_in_shop_groupx";
DROP TRIGGER "outbound_groupx_add_shop_name_brand";
DROP TABLE "outbound_groupx";

COMMIT;

-- Check (run after): 379 shops keep their old group, the rest are 100; the 4 views still run
SELECT groupx, COUNT(*) AS n_shops FROM shop GROUP BY groupx ORDER BY groupx;
SELECT COUNT(*) AS old_table_left FROM sqlite_master WHERE name IN ('outbound_groupx', 'outbound_groupx_add_shop_name_brand', 'vw_check_shop_code_not_in_shop_groupx');
SELECT 'data_tool_outbound_deli_today' AS view_name, COUNT(*) AS n_rows FROM "data_tool_outbound_deli_today";
SELECT 'data_tool_outbound_include_today' AS view_name, COUNT(*) AS n_rows FROM "data_tool_outbound_include_today";
SELECT 'AAA_outbound_province_bill_expect_date' AS view_name, COUNT(*) AS n_rows FROM "AAA_outbound_province_bill_expect_date";
SELECT 'data_tool_pullback_today' AS view_name, COUNT(*) AS n_rows FROM "data_tool_pullback_today";

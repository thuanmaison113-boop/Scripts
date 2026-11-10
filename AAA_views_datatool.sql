CREATE VIEW data_tool_outbound_deli_today AS
SELECT 
    o.shop_code,
    o.shop_name,
    o.delivery_order_num as do_num,
    o.note,
    o.box_qty,
    g.groupx
FROM outbound AS o
LEFT JOIN outbound_groupx AS g
    ON o.shop_code = g.shop_code
WHERE o.delivery_date = DATE('now')
ORDER BY g.groupx, o.shop_name ASC;

CREATE VIEW data_tool_pullback_today AS
SELECT 
  p.to_shop as shop_code,
  s.shop_name,
  '-' as do_num,
  'zLCNB' AS note,
  SUM(p.box_qty) AS box_qty,
  g.groupx
FROM pullback AS p
LEFT JOIN outbound_groupx AS g
  ON p.to_shop = g.shop_code
LEFT JOIN "shop" AS s
  ON p.to_shop = s.shop_code
WHERE p.pullback_date = DATE('now')
  AND p.to_shop NOT LIKE '%D111%'
  AND p.to_shop NOT LIKE '%D116%'
GROUP BY p.to_shop, s.shop_name, g.groupx
ORDER BY g.groupx, p.to_shop, s.shop_name ASC;

CREATE VIEW data_tool_outbound_include_today AS
SELECT 
i.shop_code,
s.shop_name,
i.note as do_num,
i.item_name AS note,
i.box_qty as box_qty,
g.groupx
FROM outbound_include as i
LEFT JOIN outbound_groupx AS g
  ON i.shop_code = g.shop_code
LEFT JOIN "shop" AS s
  ON i.shop_code = s.shop_code
WHERE i.dely_date = DATE('now')
ORDER BY g.groupx, i.shop_code, s.shop_name ASC;

CREATE VIEW data_tool_inbound_online AS
SELECT
CASE 
    WHEN brand_name = 'Charles & Keith' THEN 'CK'
    ELSE brand_name
END AS brand,
shop_name AS name,
box_qty AS box,
input_standard AS product,
input_taras_defect AS taras,
input_paper_bag AS paper,
input_visual_merchandising AS vmr,
input_type AS Loai,
arrival_date,
inbound_code
FROM inbound
WHERE current_action IS NULL AND region <> 'CONT'
ORDER BY shop_name;

CREATE VIEW data_tool_outbound_report AS
SELECT
	id,
	delivery_date,
	post_date,
    CASE
    WHEN post_date IS NOT NULL THEN 'posted'
    ELSE 'post null'
    END AS "check",
	checklist,
	brand_name,
	shop_code,
    shop_name,
    region,
    stock_transfer_order_num as PO_num,
    delivery_order_num as DO_num,
    note as type,
    box_qty,
    NULLIF(product_qty, 0) as product_qty,
	NULLIF(paper_bag_qty, 0) as paper_qty,
    order_qty
    FROM outbound
	WHERE delivery_date = date('now')
	ORDER BY shop_code ASC;

CREATE VIEW data_tool_inbound_report AS
SELECT
shop_code,
shop_name,
brand_name,
region,
box_qty,
NULLIF(input_standard, 0) as product_qty,
NULLIF(input_taras_defect, 0) as taras_qty,
NULLIF(input_paper_bag, 0) as paper_qty,
NULLIF(input_visual_merchandising, 0) as vm_qty,
input_type,
status,
delivery_order_num as DO_num,
good_issue_date as GI_date,
arrival_date,
good_receipt_date as GR_date,
note
FROM inbound
WHERE good_receipt_date is null AND region <> 'CONT';

CREATE VIEW vw_zdata_item_40_not_in_zsta AS
SELECT e.*
FROM item_export e
LEFT JOIN item_zsta z
    ON CAST(e.Variant AS TEXT) = CAST(z.variant AS TEXT)
WHERE substr(CAST(e.Variant AS TEXT), 1, 2) = '40'
  AND z.variant IS NULL;

CREATE VIEW vw_zdata_item_list AS
SELECT
    e.id,
    e.Brand_name AS brand_name,
    e.Style_Code AS style_code,
    e.Variant AS variant,
    e.Base_Unit_of_Measure AS unit,
    e.Barcode AS barcode,
    e.Color_Description AS color,
    e.Size AS sizes,
    CAST(REPLACE(e.Full_Price, ',', '') AS REAL) AS full_price,
    CAST(REPLACE(e.Markdown_Price_1, ',', '') AS REAL) AS markdown_price,
    CASE
        WHEN substr(CAST(e.Variant AS TEXT), 1, 2) = '40'
            THEN z.type
        ELSE t.type
    END AS type,
    e.Style_Code || ' ; ' ||
    COALESCE(e.Color_Description, '-') || ' ; ' ||
    COALESCE(e.Size, '-') AS item_full_name,
    CASE
        WHEN substr(CAST(e.Variant AS TEXT), 1, 2) = '40'
            THEN z.type
        ELSE t.kind
    END AS kind
FROM item_export e
LEFT JOIN item_type t
    ON substr(CAST(e.Variant AS TEXT), 1, 2) = t.variant_prefix
    AND substr(CAST(e.Variant AS TEXT), 1, 2) <> '40'
LEFT JOIN item_zsta z
    ON CAST(e.Variant AS TEXT) = CAST(z.variant AS TEXT);

CREATE VIEW vw_zdata_count_item_by_brand AS
SELECT
	b.brand_code, 
	b.brand_name,
	COUNT(*) AS total_rows
FROM item_list i
JOIN brand b ON i.brand_name = b.brand_name
GROUP BY b.brand_code, b.brand_name;

CREATE VIEW vw_zdata_zsta_list AS
SELECT
i.barcode AS Barcode,
i.variant AS Variant,
i.type AS LOẠI
FROM item_zsta i;

CREATE VIEW data_tool_employee_list AS
SELECT
	id,
    employee_full_name,
    employee_code
FROM employee
WHERE end_date IS NULL AND main_site_code = 'D111' And is_direct_labor = 1;

CREATE VIEW data_tool_web_app_login AS
SELECT employee_code      AS username,
       employee_full_name AS display_name,
       phone_number
FROM employee
WHERE end_date IS NULL AND main_site_code = "D111"
  AND employee_code IS NOT NULL AND TRIM(employee_code) <> '';
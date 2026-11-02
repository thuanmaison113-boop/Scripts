CREATE VIEW AAA_inbound_last_gr_date AS
SELECT
i.shop_code,
i.shop_name,
i.brand_name,
region,
box_qty,
NULLIF(input_standard, 0) as D111,
NULLIF(input_taras_defect, 0) as D116,
NULLIF(input_paper_bag, 0) as túi_giấy,
NULLIF(input_visual_merchandising, 0) as VMR,
input_type,
purchase_order_num,
delivery_order_num,
good_issue_date,
transfer_order_num,
put_away_bin,
transfer_order_quality_issue,
substandard_qty,
arrival_date,
good_receipt_date,
i.note
FROM inbound i
LEFT JOIN "shop" s ON i.shop_code = s.shop_code
WHERE good_receipt_date =
    (SELECT MAX(good_receipt_date)
     FROM inbound i2);

CREATE VIEW AAA_outbound_last_post_date AS
SELECT
	o.id,
    o.post_date,
    o.order_date,
    o.delivery_date,
    o.brand_name,
    o.region,
    o.shop_code,
    o.shop_name,
    NULLIF(o.product_qty, 0) as hàng_hóa,
	NULLIF(o.paper_bag_qty, 0) as túi_giấy,
    o.stock_transfer_order_num,
    o.delivery_order_num,
    o.note,
    o.box_qty,
    o.order_qty
FROM outbound o
WHERE o.post_date = (
    SELECT MAX(post_date)
    FROM outbound
)
ORDER BY shop_code ASC;

CREATE VIEW AAA_daily_inbound_summary AS
SELECT 
    MAX(i.good_receipt_date) AS date,
    b.brand_name AS brand,
    SUM(i.input_standard + i.input_visual_merchandising) AS D111,
    SUM(i.input_taras_defect) AS D116,
    SUM(i.input_paper_bag) AS paperbag
FROM inbound i
LEFT JOIN shop s ON i.shop_code = s.shop_code
LEFT JOIN brand b ON s.brand = b.brand_code
WHERE i.good_receipt_date = (
    SELECT MAX(good_receipt_date)
    FROM inbound
)
GROUP BY b.brand_name, s.brand;

CREATE VIEW AAA_daily_outbound_summary AS
SELECT 
    MAX(o.post_date) AS date,
    b.brand_name AS brand,
    SUM(CASE WHEN o.main_vendor = 'D111' THEN o.product_qty ELSE 0 END) AS D111,
    SUM(CASE WHEN o.main_vendor = 'D116' THEN o.product_qty ELSE 0 END) AS D116,
    SUM(o.paper_bag_qty) AS paperbag
FROM outbound o
LEFT JOIN shop s ON o.shop_code = s.shop_code
LEFT JOIN brand b ON s.brand = b.brand_code
WHERE o.post_date = (
    SELECT MAX(post_date)
    FROM outbound
)
GROUP BY b.brand_name, s.brand;

CREATE VIEW AAA_outbound_post_null AS
SELECT
id,
post_date as ngày_post,
delivery_date as ngày_yêu_cầu_giao,
main_vendor as kho_xuất,
brand_name as nhãn,
region as khu_vực,
shop_code as mã_shop,
shop_name as tên_shop,
order_qty as số_lượng,
delivery_order_num as số_DO,
note
FROM outbound
WHERE post_date is null and main_vendor = 'D111'
ORDER BY shop_code;

CREATE VIEW AAA_cont_job AS
SELECT
id,
arrival_date as Arrival_date,
good_receipt_date as GR_date,
input_type as Loại,
note as tên_job,
CASE 
    WHEN brand_name = 'Charles & Keith' THEN 'CK'
    ELSE brand_name
END AS brand,
box_qty as thùng,
NULLIF(input_standard, 0) as hàng_hóa,
NULLIF(input_paper_bag, 0) as túi_giấy,
NULLIF(input_visual_merchandising, 0) as VMR,
purchase_order_num as PO
FROM inbound
WHERE region = 'CONT'
  AND note IN (
    SELECT note
    FROM inbound
    WHERE region = 'CONT'
    GROUP BY note
    ORDER BY MAX(arrival_date) DESC
  )
ORDER BY arrival_date DESC;

CREATE VIEW AAA_outbound_defect_taras AS
SELECT
id,
post_date as post,
main_vendor as sup,
order_date,
delivery_date,
shop_code as site,
box_qty as thùng,
product_qty as SL,
stock_transfer_order_num as PO,
delivery_order_num as DOs,
transfer_order_num as TOs,
note
FROM outbound
WHERE note LIKE '%defect%' AND post_date IS NULL
ORDER BY id DESC
LIMIT 10;

CREATE VIEW AAA_outbound_pending  AS
SELECT *
FROM outbound
WHERE product_qty = 0
  AND paper_bag_qty = 0
  AND delivery_date >= DATE('now', '-3 days');

CREATE VIEW AAA_Asset_stock_on_hand AS
SELECT
    item_name,
    SUM(CASE WHEN status = 'inbound' THEN quantity ELSE 0 END) AS total_inbound,
    SUM(CASE WHEN status = 'outbound' THEN quantity ELSE 0 END) AS total_outbound,
    SUM(CASE WHEN status = 'inbound' THEN quantity ELSE 0 END)
      - SUM(CASE WHEN status = 'outbound' THEN quantity ELSE 0 END) AS stock_in_hand
FROM inbound_visual_asset
GROUP BY item_name
HAVING 
    SUM(CASE WHEN status = 'inbound' THEN quantity ELSE 0 END)
    - SUM(CASE WHEN status = 'outbound' THEN quantity ELSE 0 END) > 0;

CREATE VIEW AAA_CONT_summary_month AS
SELECT
    strftime('%Y-%m', good_receipt_date) AS year_month,
    SUM(CASE WHEN sla_status = 'dat' THEN 1 ELSE 0 END) AS dat_count,
    SUM(CASE WHEN sla_status = 'khong_dat' THEN 1 ELSE 0 END) AS khong_dat_count,
    COUNT(*) AS total
FROM AAA_timeline_cont
GROUP BY strftime('%Y-%m', good_receipt_date)
ORDER BY year_month;

CREATE VIEW AAA_BOX_OUTBOUND AS
SELECT 
    o.shop_code,
    o.shop_name,
    o.region,
    SUM(o.order_qty) AS total_order_qty,
    SUM(o.box_qty) AS total_box_qty,
    SUM(CASE WHEN o.box_qty = 0 THEN 1 ELSE 0 END) AS pending_rows,
    IFNULL(pb.pullback_box_qty, 0) AS pullback_box_qty,
    SUM(o.box_qty) + IFNULL(pb.pullback_box_qty, 0)  AS total_box
FROM outbound o
LEFT JOIN (
    SELECT 
        to_shop,
        SUM(box_qty) AS pullback_box_qty
    FROM pullback
    WHERE pullback_date = DATE('now')
    GROUP BY to_shop
) pb
    ON pb.to_shop = o.shop_code
WHERE o.delivery_date = DATE('now')
  AND o.paper_bag_qty = 0
GROUP BY o.shop_code, o.shop_name;

CREATE VIEW AAA_employee_on_work AS
SELECT
	id,
    employee_code,
    employee_full_name,
    employee_short_name
FROM employee
WHERE end_date IS NULL
  AND employee_code NOT IN (
      SELECT employee_code
      FROM employee_leave
      WHERE DATE('now', '+7 hours') BETWEEN start_date AND end_date
  );

CREATE VIEW AAA_employee_overtime_today AS
SELECT 
id,
employee_full_name AS tên_NV,
start_time AS giờ_bắt_đầu,
end_time AS giờ_kết_thúc,
overtime_hours AS tổng_giờ,
reason AS công_việc
FROM employee_overtime
WHERE overtime_date = date('now');

CREATE VIEW AAA_PULLBACK_summary_month AS
SELECT
    v.month,
    SUM(CASE WHEN v.timeline_status = 'dat' THEN 1 ELSE 0 END) AS dat_count,
    SUM(CASE WHEN v.timeline_status = 'khong_dat' THEN 1 ELSE 0 END) AS khong_dat_count,
    COUNT(*) AS total_records,
    SUM(v.input_standard) AS hang_hoa,
    SUM(v.input_paper_bag) AS tui_giay
FROM AAA_timeline_pullback v
GROUP BY v.month;

CREATE VIEW AAA_timeline_cont AS
WITH grouped AS (
    SELECT
        note,
        strftime('%Y', good_receipt_date) AS yr,
        SUM(input_standard) AS qty_sum
    FROM inbound
    WHERE region = 'CONT'
    GROUP BY note, yr
),
base AS (
    SELECT
        i.*,
        g.qty_sum,

        CAST(
            julianday(i.good_receipt_date) -
            julianday(i.arrival_date)
            AS REAL
        ) AS ngay_xu_ly,

        CASE
            WHEN g.qty_sum < 12000 THEN 3
            ELSE 3 +
                (
                    CAST(
                        (g.qty_sum - 12000 + 4999) / 5000
                        AS INTEGER
                    ) * 1.5
                )
        END AS sla_days
    FROM inbound i
    JOIN grouped g
        ON i.note = g.note
       AND strftime('%Y', i.good_receipt_date) = g.yr
    WHERE i.region = 'CONT'
),
sunday_check AS (
    SELECT
        b.*,
        CASE
            WHEN EXISTS (
                SELECT 1
                FROM date_tb d
                WHERE d.Date BETWEEN b.arrival_date
                                 AND date(
                                     b.arrival_date,
                                     '+' || CAST(b.sla_days AS INTEGER) || ' day'
                                 )
                  AND d.Day_Of_Week_Number = 7
            )
            THEN 1
            ELSE 0
        END AS sunday_bonus
    FROM base b
)
SELECT
    *,
    sla_days + sunday_bonus AS sla_final,
    CASE
        WHEN ngay_xu_ly <= sla_days + sunday_bonus
            THEN 'dat'
        ELSE 'khong_dat'
    END AS sla_status
FROM sunday_check;

CREATE VIEW AAA_timeline_pullback AS
SELECT
    i.shop_name,
    i.box_qty || '-' || 
    i.input_standard || '-' || 
    i.input_taras_defect || '-' || 
    i.input_paper_bag
    AS box_hh_taras_tg,
    i.input_standard,
    i.input_paper_bag,
    CAST(
        julianday(date(i.good_receipt_date)) 
        - julianday(date(i.arrival_date))
        AS INTEGER
    ) AS so_ngay_xu_ly,
    i.delivery_order_num AS DO_num,
    i.good_issue_date || '>' ||
    i.arrival_date || '>' ||
    i.good_receipt_date
    AS process_date,
    strftime('%Y-%m', i.good_issue_date) AS month,
    CASE
        WHEN i.arrival_date IS NULL 
          OR i.good_receipt_date IS NULL
            THEN NULL
        WHEN julianday(date(i.good_receipt_date)) >
             julianday(
                CASE
                    WHEN d.Day_Of_Week_Number = 7
                        THEN date(i.arrival_date, '+8 day')
                    ELSE date(i.arrival_date, '+7 day')
                END
             )
            THEN 'khong_dat'
        ELSE 'dat'
    END AS timeline_status
FROM inbound i
LEFT JOIN date_tb d
    ON d.Date = date(i.arrival_date, '+7 day')
WHERE i.region <> 'CONT';

CREATE VIEW AAA_OUTBOUND_TIKI_LAST10 AS
SELECT *
FROM outbound
WHERE shop_name = 'KHO ECOM THỦ ĐỨC'
AND box_qty > 0
ORDER BY id DESC
LIMIT 10;

CREATE VIEW AAA_defect_pending AS
SELECT
d.id,
d.results,
d.purchase_order_num AS PO,
d.shop_name AS tên_shop,
d.defect_qty AS số_lượng,
d.barcode,
d.artical,
d.item_full_name AS tên_sản_phẩm,
d.defect_type AS lỗi,
d.solution AS hướng_xử_lý,
d.note,
d.checklist 
FROM defect d
WHERE d.results IS NULL 
ORDER BY d.id DESC;

CREATE VIEW AAA_Delidate_NULL  AS
SELECT *
FROM outbound
WHERE delivery_date is NULL AND main_vendor <> 'D116';

CREATE VIEW AAA_inbound_pending AS
SELECT
id,
shop_code,
shop_name,
brand_name,
region,
box_qty as box,
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

CREATE VIEW AAA_LUC666 AS
SELECT *
FROM (
    SELECT *
    FROM outbound
    ORDER BY id DESC
    LIMIT 500
   
) t
ORDER BY id ASC;

CREATE VIEW AAA_outbound_deli_today AS
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
    transfer_order_num as TO_num,
    note as type,
    note2,
    box_qty,
    NULLIF(product_qty, 0) as product_qty,
	NULLIF(paper_bag_qty, 0) as paper_qty,
    order_qty
    FROM outbound
	WHERE delivery_date = date('now')
	ORDER BY shop_code ASC;

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
        g.groupx, s.lead_time_day,
        c.name AS carrier_name, c.tracking_url, c.contact_name, c.contact_phone
    FROM outbound o
    LEFT JOIN outbound_groupx g ON o.shop_code = g.shop_code
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
        g.groupx, s.lead_time_day,
        c.name, c.tracking_url, c.contact_name, c.contact_phone
    FROM outbound_include i
    LEFT JOIN outbound_groupx g ON i.shop_code = g.shop_code
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
        g.groupx, s.lead_time_day,
        c.name, c.tracking_url, c.contact_name, c.contact_phone
    FROM pullback p1
    LEFT JOIN outbound_groupx g ON p1.to_shop = g.shop_code
    LEFT JOIN "shop" s          ON p1.to_shop = s.shop_code
    LEFT JOIN brand b           ON s.brand = b.brand_code
    LEFT JOIN province p        ON s.province_id = p.province_id
    LEFT JOIN carrier c         ON s.carrier = c.carrier_code
    WHERE p1.pullback_date = DATE('now')
      AND p1.to_shop NOT LIKE '%D111%'
      AND p1.to_shop NOT LIKE '%D116%'
      AND p.region = 'province'
    GROUP BY p1.to_shop, s.shop_name, b.brand_name, g.groupx, s.lead_time_day,
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

CREATE VIEW AAA_way_bill_last_month  AS
SELECT
a.id,
a.shop_code,
a.shop_name,
a.brand_name,
a.region,
sum(a.box_qty) as box_qty,
s.carrier,
a.arrival_date,
a.way_bill
FROM inbound a
LEFT JOIN "shop" s ON a.shop_code = s.shop_code
WHERE strftime('%Y-%m', arrival_date  ) = strftime('%Y-%m', DATE('now', 'start of month', '-1 month')) AND region != 'CONT' AND region = 'province'
GROUP BY
a.way_bill,
a.shop_code,
a.shop_name,
a.brand_name,
a.region,
s.carrier,
a.arrival_date;





















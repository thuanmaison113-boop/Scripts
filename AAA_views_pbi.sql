
CREATE VIEW vw_pbi_cont_job AS
WITH std AS (
    SELECT
        MAX(CASE WHEN TRIM(standard_code) = 'inbound_container_staff_required'
                 THEN CAST(standard_value AS REAL) END) AS staff_per_job,
        MAX(CASE WHEN LOWER(standard_code) LIKE '%20ft%handling%'
                 THEN CAST(standard_value AS REAL) END) AS days_20,
        MAX(CASE WHEN LOWER(standard_code) LIKE '%40ft%handling%'
                 THEN CAST(standard_value AS REAL) END) AS days_40
    FROM standard
),
containers AS (
    SELECT DISTINCT
        TRIM(note)                      AS job,
        DATE(arrival_date)              AS arrival_date,
        TRIM(input_type)                AS container,
        substr(TRIM(input_type), 1, 2)  AS cont_size
    FROM inbound
    WHERE arrival_date IS NOT NULL
      AND (TRIM(input_type) LIKE '20-%' OR TRIM(input_type) LIKE '40-%')
)
SELECT
    c.job,
    c.arrival_date,
    c.job || ' | ' || c.arrival_date                               AS job_key,
    SUM(c.cont_size = '20')                                        AS cont_20_qty,
    SUM(c.cont_size = '40')                                        AS cont_40_qty,
    SUM(c.cont_size = '20') * s.days_20
      + SUM(c.cont_size = '40') * s.days_40                        AS handling_days,
    s.staff_per_job                                                AS staff_required,
    (SUM(c.cont_size = '20') * s.days_20
      + SUM(c.cont_size = '40') * s.days_40) * s.staff_per_job     AS hc_days
FROM containers c
CROSS JOIN std s
GROUP BY c.job, c.arrival_date, s.days_20, s.days_40, s.staff_per_job;

CREATE VIEW vw_pbi_cont_job_daily AS
WITH RECURSIVE cal(job_key, job, handling_days, hc, d, n) AS (
    SELECT job_key, job, handling_days, staff_required, arrival_date, 0
    FROM vw_pbi_cont_job
    WHERE handling_days > 0
    UNION ALL
    SELECT job_key, job, handling_days, hc, DATE(d, '+1 day'), n + 1
    FROM cal
    WHERE n < handling_days * 2 + 14
),
working AS (
    SELECT
        job_key, job, handling_days, hc, d AS work_date,
        ROW_NUMBER() OVER (PARTITION BY job_key ORDER BY d) AS day_no
    FROM cal
    WHERE strftime('%w', d) <> '0'
      AND NOT EXISTS (
          SELECT 1 FROM date_exception de
          WHERE cal.d BETWEEN DATE(de.start_date) AND DATE(de.end_date)
      )
)
SELECT job_key, job, work_date, day_no, handling_days, hc
FROM working
WHERE day_no <= handling_days;

CREATE VIEW vw_pbi_daily_workload AS
WITH wd AS (
    SELECT d.Date, ROW_NUMBER() OVER (ORDER BY d.Date) AS wd_no
    FROM date_tb d
    WHERE d.Date BETWEEN DATE('now','-90 days') AND DATE('now','+365 days')  -- only the window needed (speed)
      AND d.Weekend = 'Weekday'
      AND NOT EXISTS (SELECT 1 FROM date_exception e
                      WHERE d.Date BETWEEN e.start_date AND e.end_date)
),
std AS (
    SELECT COALESCE(MAX(CASE WHEN standard_code = 'outbound_max_pick_days'
                             THEN standard_value END), 3) AS max_pick_days
    FROM standard
),
ob AS (
    SELECT o.id, o.brand_name, o.product_qty AS qty,
        (SELECT MIN(wd_no) FROM wd WHERE wd.Date >= COALESCE(o.order_date, o.delivery_date)) AS start_no,
        (SELECT MAX(wd_no) FROM wd WHERE wd.Date <= o.delivery_date)                         AS end_no
    FROM outbound o
    WHERE o.delivery_date >= DATE('now') AND COALESCE(o.product_qty, 0) > 0
),
ob_win AS (
    SELECT id, brand_name, qty, end_no,
           MAX(MIN(start_no, end_no), end_no - (SELECT max_pick_days FROM std) + 1) AS start_no
    FROM ob
    WHERE end_no IS NOT NULL
),
offs(k) AS (              -- 0 .. max_pick_days-1
    SELECT 0
    UNION ALL
    SELECT k + 1 FROM offs WHERE k + 1 < (SELECT max_pick_days FROM std)
),
ob_days AS (              -- one row per order per pick day (equality join, no range scan)
    SELECT w.id, w.brand_name, w.qty, d.Date AS work_date,
           o.k + 1                     AS rn,
           w.end_no - w.start_no + 1   AS cnt
    FROM ob_win w
    JOIN offs o ON o.k <= w.end_no - w.start_no
    JOIN wd   d ON d.wd_no = w.start_no + o.k
),
src AS (
    SELECT workload_date AS work_date, brand_name, 'Pullback' AS activity,
           arrival_date_status AS status, workload_qty AS qty
    FROM vw_pbi_inbound_expected_arrival
    WHERE workload_date IS NOT NULL
    UNION ALL
    SELECT work_date, brand_name, 'Outbound', 'Order',
           qty / cnt + CASE WHEN rn <= qty % cnt THEN 1 ELSE 0 END
    FROM ob_days
)
SELECT work_date, brand_name, activity, status, SUM(qty) AS qty
FROM src
WHERE work_date >= DATE('now')   -- forward-looking only
GROUP BY work_date, brand_name, activity, status
HAVING SUM(qty) <> 0;

CREATE VIEW vw_pbi_soh_capacity_base AS
SELECT
    s.barcode,
    s.brand,
    s.site,
    s.unrestricted,
    it.type AS item_type
FROM (
    SELECT barcode, brand, site, unrestricted FROM soh_main WHERE brand <> ''
    UNION ALL
    SELECT barcode, brand, site, unrestricted FROM soh_taras WHERE brand <> ''
) s
LEFT JOIN item_list il ON s.barcode = il.barcode
LEFT JOIN item_type it ON il.type = it.type
WHERE it.type IS NULL OR it.type <> 'túi giấy';

CREATE VIEW vw_pbi_soh_combined AS
SELECT 'Main' AS site, article_number, article_type, brand,
       article_name, barcode, color, size,
       unrestricted, snapshot_date
FROM soh_main WHERE brand <> ''
UNION ALL
SELECT 'Taras' AS site, article_number, article_type, brand,
       article_name, barcode, color, size,
       unrestricted, snapshot_date
FROM soh_taras WHERE brand <> '';

CREATE VIEW vw_pbi_inbound_expected_arrival AS
WITH wd AS (
    SELECT d.Date, d.Day_Of_Week_Number,
           ROW_NUMBER() OVER (ORDER BY d.Date) AS wd_no
    FROM date_tb d
    WHERE d.Date BETWEEN DATE('now','-90 days') AND DATE('now','+365 days')
      AND d.Weekend = 'Weekday'
      AND NOT EXISTS (SELECT 1 FROM date_exception e
                      WHERE d.Date BETWEEN e.start_date AND e.end_date)
),
base AS (
    SELECT i.*, s.lead_time_day, p.region AS shop_region, b.brand_code,
        COALESCE(i.arrival_date, i.good_receipt_date) AS actual_date,
        CASE WHEN i.arrival_date IS NULL AND i.good_receipt_date IS NULL
              AND i.good_issue_date IS NOT NULL
             THEN (SELECT MIN(wd_no) FROM wd WHERE wd.Date >= i.good_issue_date)
        END AS start_wd_no
    FROM inbound i
    LEFT JOIN shop     s ON s.shop_code   = i.shop_code
    LEFT JOIN province p ON p.province_id = s.province_id
    LEFT JOIN brand    b ON b.brand_name  = i.brand_name
    WHERE COALESCE(i.region, '') <> 'CONT'
      AND (COALESCE(i.arrival_date, i.good_receipt_date) IS NULL
           OR COALESCE(i.arrival_date, i.good_receipt_date) >= DATE('now'))
),
calc AS (
    SELECT base.*,
        CASE
            WHEN start_wd_no IS NULL THEN NULL
            WHEN shop_region = 'City' THEN COALESCE(
                (SELECT MIN(w.Date) FROM wd w
                 JOIN plan_transaction_frequency f
                   ON f.brand_code = base.brand_code AND f.plan_type = 'pullback'
                  AND f.day_of_week = w.Day_Of_Week_Number
                 WHERE w.wd_no >= base.start_wd_no),
                (SELECT Date FROM wd WHERE wd_no = base.start_wd_no))
            WHEN shop_region = 'province' THEN
                (SELECT Date FROM wd WHERE wd_no = base.start_wd_no + COALESCE(base.lead_time_day, 0))
        END AS expected_arrival_date
    FROM base
)
SELECT calc.*,
    CASE WHEN actual_date IS NOT NULL             THEN actual_date
         WHEN expected_arrival_date < DATE('now') THEN DATE('now')
         ELSE expected_arrival_date END           AS workload_date,
    CASE WHEN actual_date IS NOT NULL             THEN 'Actual'
         WHEN expected_arrival_date < DATE('now') THEN 'Overdue'
         WHEN expected_arrival_date IS NOT NULL   THEN 'Expected'
         ELSE 'Unscheduled' END                   AS arrival_date_status,
    'Pullback'                                    AS activity,  -- kept for existing consumers
    COALESCE(input_standard,0) + COALESCE(input_taras_defect,0)
      + COALESCE(input_visual_merchandising,0)    AS workload_qty
FROM calc;

CREATE VIEW vw_pbi_cont_plan AS
SELECT
    b.brand_code,
    i.brand_name,
    'cont' AS plan_type,
    CAST(strftime('%m', i.arrival_date) AS INTEGER) AS plan_month,
    CAST(strftime('%Y', i.arrival_date) AS INTEGER) AS plan_year,
    i.arrival_date AS delivery_date,
    (
        COALESCE(i.input_standard, 0)
        + COALESCE(i.input_taras_defect, 0)
        + COALESCE(i.input_visual_merchandising, 0)
    ) AS qty,
    'EXIM' AS source,
    i.note
FROM inbound i
LEFT JOIN brand b
    ON b.brand_name = i.brand_name
WHERE i.region = 'CONT'
  AND i.arrival_date IS NOT NULL;

CREATE VIEW vw_pbi_plan_final_all AS
SELECT *
FROM vw_pbi_plan_final
UNION ALL
SELECT
    brand_code,
    brand_name,
    plan_type,
    plan_month,
    plan_year,
    delivery_date,
    qty,
    source,
    note
FROM vw_pbi_cont_plan;

CREATE VIEW vw_pbi_soh_projected AS
WITH baseline AS (
    SELECT b.brand_code, b.brand_name, SUM(s.unrestricted) AS current_soh
    FROM vw_pbi_soh_capacity_base s
    JOIN item_list il ON s.barcode = il.barcode
    JOIN brand b ON il.brand_name = b.brand_name
    WHERE b.is_active = 1
    GROUP BY b.brand_code, b.brand_name
),
dates AS (
    SELECT dt.Date AS delivery_date
    FROM date_tb dt
    WHERE dt.Date >= DATE('now')
      AND dt.Date <= DATE(
          'now',
          '+' || (
              SELECT CAST(standard_value AS INTEGER)
              FROM standard
              WHERE standard_code = 'soh_projected_x_day'
              LIMIT 1
          ) || ' days'
      )
      AND dt.Weekend = 'Weekday'
      AND NOT EXISTS (
          SELECT 1
          FROM date_exception de
          WHERE dt.Date BETWEEN de.start_date AND de.end_date
      )
),
flow AS (
    SELECT
        b.brand_code,
        d.delivery_date,
        COALESCE(SUM(CASE WHEN p.plan_type IN ('cont','pullback') THEN p.qty ELSE 0 END),0) AS inbound_qty,
        COALESCE(SUM(CASE WHEN p.plan_type = 'outbound' THEN p.qty ELSE 0 END),0) AS outbound_qty
    FROM baseline b
    CROSS JOIN dates d
    LEFT JOIN vw_pbi_plan_final_all p
        ON p.brand_code = b.brand_code
       AND p.delivery_date = d.delivery_date
    GROUP BY b.brand_code, d.delivery_date
),
grid AS (
    SELECT
        b.brand_code,
        b.brand_name,
        f.delivery_date,
        b.current_soh,
        f.inbound_qty,
        f.outbound_qty
    FROM baseline b
    JOIN flow f ON f.brand_code = b.brand_code
)
SELECT
    brand_code,
    brand_name,
    delivery_date,
    current_soh
        + COALESCE(SUM(inbound_qty - outbound_qty) OVER (
            PARTITION BY brand_code
            ORDER BY delivery_date
            ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
        ), 0) AS projected_soh
FROM grid
ORDER BY brand_code, delivery_date;

CREATE VIEW vw_pbi_plan_daily AS
WITH counted AS (
  SELECT *,
    ROW_NUMBER() OVER (PARTITION BY id, plan_month, plan_year ORDER BY delivery_date) AS rn,
    COUNT(*) OVER (PARTITION BY id, plan_month, plan_year) AS cnt
  FROM vw_pbi_plan_delivery_dates
)
SELECT
  id, brand_code, brand_name, plan_type, plan_month, plan_year, plan_qty,
  delivery_date, cnt AS delivery_days_in_month,
  (plan_qty / cnt) + CASE WHEN rn <= (plan_qty % cnt) THEN 1 ELSE 0 END AS calc_qty
FROM counted;

CREATE VIEW vw_pbi_plan_final AS
WITH detail_with_period AS (
  SELECT
    d.*,
    dt.Month_Number_Of_Year AS plan_month,
    dt.Year AS plan_year
  FROM plan_mer_detail d
  JOIN date_tb dt ON dt.Date = d.delivery_date
),
detail_sum AS (
  SELECT brand_code, plan_type, plan_month, plan_year, SUM(qty) AS detail_total
  FROM detail_with_period
  GROUP BY brand_code, plan_type, plan_month, plan_year
),
calc_remaining AS (
  SELECT
    pd.*,
    COALESCE(ds.detail_total, 0) AS detail_total,
    MAX(pd.plan_qty - COALESCE(ds.detail_total, 0), 0) AS qty_left   -- never negative
  FROM vw_pbi_plan_daily pd
  LEFT JOIN detail_sum ds
    ON ds.brand_code = pd.brand_code AND ds.plan_type = pd.plan_type
    AND ds.plan_month = pd.plan_month AND ds.plan_year = pd.plan_year
  WHERE NOT EXISTS (
    SELECT 1 FROM plan_mer_detail d
    WHERE d.brand_code = pd.brand_code AND d.plan_type = pd.plan_type
    AND d.delivery_date = pd.delivery_date
  )
),
recounted AS (
  SELECT *,
    ROW_NUMBER() OVER (PARTITION BY brand_code, plan_type, plan_month, plan_year ORDER BY delivery_date) AS rn,
    COUNT(*) OVER (PARTITION BY brand_code, plan_type, plan_month, plan_year) AS cnt
  FROM calc_remaining
)
SELECT
  brand_code, brand_name, plan_type, plan_month, plan_year,
  delivery_date,
  CASE WHEN cnt = 0 THEN 0
       ELSE (qty_left / cnt) + CASE WHEN rn <= (qty_left % cnt) THEN 1 ELSE 0 END
  END AS qty,
  'calculated' AS source,
  NULL AS note
FROM recounted
UNION ALL
SELECT
  d.brand_code,
  b.brand_name,            
  d.plan_type, dp.plan_month, dp.plan_year,
  d.delivery_date,
  d.qty,
  d.source,
  d.note
FROM plan_mer_detail d
JOIN detail_with_period dp ON dp.id = d.id
LEFT JOIN brand b ON b.brand_code = d.brand_code;

CREATE VIEW vw_pbi_month_end_dates AS
SELECT
    Year AS year,
    Month_Number_Of_Year AS month_number,
    MAX(Date) AS month_end,
    MIN(Start_of_Month) AS month_start,
    MAX(Quarter) AS quarter,
    MAX(Month_Name) AS month_name,
    MAX(Month_Short) AS month_short,
    Year || '-' || substr('00' || Month_Number_Of_Year, -2) AS year_month
FROM date_tb
WHERE Date <= DATE('now')
GROUP BY Year, Month_Number_Of_Year;

CREATE VIEW vw_pbi_employee_headcount_monthly AS
SELECT
    dm.month_end, dm.year, dm.month_number, dm.year_month, dm.quarter, dm.month_name,
    e.employee_code,
    e.employee_full_name,
    e.gender,
    e.employee_role,
    e.is_direct_labor,
    CASE WHEN e.is_direct_labor = 1 THEN 'Direct Labor' ELSE 'Indirect Labor' END AS labor_type,
    e.main_site_code,
    e.start_date,
    e.end_date,
    CAST((julianday(dm.month_end) - julianday(e.start_date)) / 30 AS INTEGER) AS tenure_months
FROM vw_pbi_month_end_dates dm
JOIN employee e
    ON e.start_date <= dm.month_end
   AND (e.end_date IS NULL OR e.end_date >= dm.month_end);

CREATE VIEW vw_pbi_employee_leave_detail AS
SELECT
    el.id AS leave_id,
    el.employee_code,
    e.employee_full_name,
    e.gender,
    e.employee_role,
    e.is_direct_labor,
    CASE WHEN e.is_direct_labor = 1 THEN 'Direct Labor' ELSE 'Indirect Labor' END AS labor_type,
    e.main_site_code,
    el.leave_type,
    el.start_date,
    el.end_date,
    el.total_day,
    dt.Year AS leave_year,
    dt.Month_Number_Of_Year AS leave_month_number,
    dm.year_month AS leave_year_month
FROM employee_leave el
JOIN employee e ON e.employee_code = el.employee_code
JOIN date_tb dt ON dt.Date = el.start_date
JOIN vw_pbi_month_end_dates dm ON dm.year = dt.Year AND dm.month_number = dt.Month_Number_Of_Year;

CREATE VIEW vw_pbi_plan_delivery_dates AS
SELECT DISTINCT
  p.id, p.brand_code, p.brand_name, p.plan_type,
  p.plan_month, p.plan_year, p.plan_qty,
  dt.Date AS delivery_date
FROM plan_mer_overall p
JOIN plan_transaction_frequency f
  ON f.brand_code = p.brand_code AND f.plan_type = p.plan_type
JOIN date_tb dt
  ON dt.Year = p.plan_year
  AND dt.Month_Number_Of_Year = p.plan_month
  AND dt.Day_Of_Week_Number = f.day_of_week
WHERE NOT EXISTS (
    SELECT 1 FROM date_exception de
    WHERE dt.Date >= de.start_date AND dt.Date <= de.end_date
);

CREATE VIEW vw_check_plan_closed_day AS
 SELECT p.source, p.plan_type, p.brand_code, p.delivery_date, SUM(p.qty) AS qty_dropped
 FROM vw_pbi_plan_final_all p
 JOIN date_tb dt ON dt.Date = p.delivery_date
 WHERE p.delivery_date >= DATE('now')
   AND (dt.Weekend <> 'Weekday'
        OR EXISTS (SELECT 1 FROM date_exception de
                   WHERE p.delivery_date BETWEEN de.start_date AND de.end_date))
 GROUP BY p.source, p.plan_type, p.brand_code, p.delivery_date;


CREATE VIEW vw_inbound_expected_arrival_unresolved AS
SELECT activity, shop_region, brand_name, COUNT(*) AS rows_unscheduled
FROM vw_pbi_inbound_expected_arrival
WHERE arrival_date IS NULL
  AND arrival_date_status = 'Unscheduled'
GROUP BY activity, shop_region, brand_name
ORDER BY rows_unscheduled DESC;

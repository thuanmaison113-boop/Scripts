VACUUM;
ANALYZE;
PRAGMA freelist_count;

PRAGMA legacy_alter_table = ON;
PRAGMA foreign_keys = OFF;
PRAGMA foreign_keys = ON;
PRAGMA foreign_keys;
PRAGMA foreign_key_check;
PRAGMA integrity_check;
PRAGMA foreign_key_list('item_zsta');
CREATE UNIQUE INDEX IF NOT EXISTS idx_inbound_purchase_order_num_unique ON inbound(purchase_order_num);

DELETE FROM item_export WHERE id NOT IN ( SELECT MAX(id) FROM item_export GROUP BY barcode) AND barcode IN ( SELECT barcode FROM item_export GROUP BY barcode HAVING COUNT(*) > 1 );
DELETE FROM item_list;
DELETE FROM sqlite_sequence WHERE name = 'item_list';
INSERT INTO item_list SELECT * FROM vw_zdata_item_list;


DELETE FROM soh_main;
DELETE FROM soh_taras;
DELETE FROM sqlite_sequence WHERE name = 'soh_main';
DELETE FROM sqlite_sequence WHERE name = 'soh_taras';



UPDATE soh_main SET unrestricted = REPLACE(unrestricted, ',', '') WHERE unrestricted LIKE '%,%';
UPDATE soh_taras SET unrestricted = REPLACE(unrestricted, ',', '') WHERE unrestricted LIKE '%,%';
DELETE FROM soh_main  WHERE COALESCE(barcode, '') = '' AND COALESCE(article_number, '') = '';
DELETE FROM soh_taras WHERE COALESCE(barcode, '') = '' AND COALESCE(article_number, '') = '';


UPDATE outbound SET one_off_event = LOWER(TRIM(one_off_event)) WHERE one_off_event IS NOT NULL AND one_off_event <> LOWER(TRIM(one_off_event));
UPDATE inbound SET one_off_event = LOWER(TRIM(one_off_event)) WHERE one_off_event IS NOT NULL AND one_off_event <> LOWER(TRIM(one_off_event));



INSERT INTO inbound_new SELECT * FROM inbound;

-- GET COLUMN LIST HORIZONTALLY
SELECT GROUP_CONCAT(name, ', ') AS column_list FROM PRAGMA_TABLE_INFO('brand');

-- GET COLUMN LIST VERTICALLY 
SELECT name || ',' AS column_name_with_comma FROM PRAGMA_TABLE_INFO('inbound');

-------------------thêm dòng ảo để cân bằng báo cáo ngày
INSERT INTO inbound (shop_code, good_issue_date,status,arrival_date,current_action, good_receipt_date) VALUES ('TEMP','2026-10-13', 'complete', '2026-10-13', 'confirm','2026-10-13');
INSERT INTO outbound (shop_code, post_date) VALUES ('TEMP', '2026-04-04');


UPDATE item_material SET material = REPLACE(material, 'Thành phần: ', '') WHERE material LIKE '%Thành phần: %';
UPDATE item_material SET material = REPLACE(material, 'Thành phần chính', 'chính') WHERE material LIKE '%Thành phần%';
UPDATE item_material SET material = REPLACE(material, 'Lớp lót', 'lót') WHERE material LIKE '%Lớp lót%';
UPDATE item_material SET material = REPLACE(material, 'Lớp đế', 'đế') WHERE material LIKE '%Lớp đế%';
UPDATE item_material SET material = 'Da Tổng Hợp' WHERE material = 'Da Tổng Hợp (chính)';
DELETE FROM item_material WHERE material = 'Theo thông tin trên bao bì' OR material is null OR barcode like '%+12';

-- DELETE row have lower id in item_material
DELETE FROM item_material WHERE id NOT IN ( SELECT MAX(id) FROM item_material GROUP BY barcode ) AND barcode IN ( SELECT barcode FROM item_material GROUP BY barcode HAVING COUNT(*) > 1 );

-------------------Check inbound integrity
SELECT id, shop_code, shop_name AS recorded_shop_name,
       (SELECT s.shop_name FROM shop s WHERE s.shop_code = i.shop_code) AS correct_shop_name,
       brand_name AS recorded_brand_name,
       (SELECT b.brand_name FROM brand b 
        JOIN shop s ON s.brand = b.brand_code 
        WHERE s.shop_code = i.shop_code) AS correct_brand_name,
       region AS recorded_region,
       (SELECT p.region FROM province p 
        JOIN shop s ON s.province_id = p.province_id 
        WHERE s.shop_code = i.shop_code) AS correct_region
FROM inbound i
WHERE shop_name != (SELECT s.shop_name FROM shop s WHERE s.shop_code = i.shop_code)
   OR brand_name != (SELECT b.brand_name FROM brand b 
                     JOIN shop s ON s.brand = b.brand_code 
                     WHERE s.shop_code = i.shop_code)
   OR region != (SELECT p.region FROM province p 
                 JOIN shop s ON s.province_id = p.province_id 
                 WHERE s.shop_code = i.shop_code);

-------------------Update inbound integrity
UPDATE inbound
SET 
    shop_name = (SELECT s.shop_name FROM shop s WHERE s.shop_code = inbound.shop_code),
    brand_name = (SELECT b.brand_name FROM brand b 
                  JOIN shop s ON s.brand = b.brand_code 
                  WHERE s.shop_code = inbound.shop_code),
    region = (SELECT p.region FROM province p 
              JOIN shop s ON s.province_id = p.province_id 
              WHERE s.shop_code = inbound.shop_code)
WHERE shop_code IN (
    SELECT s.shop_code FROM shop s
);

-------------------Check outbound integrity
SELECT id, shop_code, shop_name AS recorded_shop_name,
       (SELECT s.shop_name FROM shop s WHERE s.shop_code = o.shop_code) AS correct_shop_name,
       brand_name AS recorded_brand_name,
       (SELECT b.brand_name FROM brand b 
        JOIN shop s ON s.brand = b.brand_code 
        WHERE s.shop_code = o.shop_code) AS correct_brand_name,
       region AS recorded_region,
       (SELECT p.region FROM province p 
        JOIN shop s ON s.province_id = p.province_id 
        WHERE s.shop_code = o.shop_code) AS correct_region
FROM outbound o
WHERE shop_name != (SELECT s.shop_name FROM shop s WHERE s.shop_code = o.shop_code)
   OR brand_name != (SELECT b.brand_name FROM brand b 
                     JOIN shop s ON s.brand = b.brand_code 
                     WHERE s.shop_code = o.shop_code)
   OR region != (SELECT p.region FROM province p 
                 JOIN shop s ON s.province_id = p.province_id 
                 WHERE s.shop_code = o.shop_code);

-------------------Update outbound integrity
UPDATE outbound
SET 
    shop_name = (SELECT s.shop_name FROM shop s WHERE s.shop_code = outbound.shop_code),
    brand_name = (SELECT b.brand_name FROM brand b 
                  JOIN shop s ON s.brand = b.brand_code 
                  WHERE s.shop_code = outbound.shop_code),
    region = (SELECT p.region FROM province p 
              JOIN shop s ON s.province_id = p.province_id 
              WHERE s.shop_code = outbound.shop_code)
WHERE shop_code IN (SELECT shop_code FROM shop);

-------------------Check defect integrity
SELECT id, purchase_order_num, barcode,
       shop_name AS recorded_shop_name,
       (SELECT i.shop_name FROM inbound i WHERE i.purchase_order_num = d.purchase_order_num) AS correct_shop_name,
       item_full_name AS recorded_item_name,
       (SELECT il.item_full_name FROM item_list il WHERE il.barcode = d.barcode) AS correct_item_name,
       style_code AS recorded_style_code,
       (SELECT il.style_code FROM item_list il WHERE il.barcode = d.barcode) AS correct_style_code
FROM defect d
WHERE shop_name != (SELECT i.shop_name FROM inbound i WHERE i.purchase_order_num = d.purchase_order_num)
   OR item_full_name != (SELECT il.item_full_name FROM item_list il WHERE il.barcode = d.barcode)
   OR style_code != (SELECT il.style_code FROM item_list il WHERE il.barcode = d.barcode);

-------------------Update defect integrity
UPDATE defect
SET
    shop_name = (SELECT i.shop_name FROM inbound i WHERE i.purchase_order_num = defect.purchase_order_num),
    item_full_name = (SELECT il.item_full_name FROM item_list il WHERE il.barcode = defect.barcode),
    style_code = (SELECT il.style_code FROM item_list il WHERE il.barcode = defect.barcode)
WHERE 
    EXISTS (SELECT 1 FROM inbound i WHERE i.purchase_order_num = defect.purchase_order_num)
    OR EXISTS (SELECT 1 FROM item_list il WHERE il.barcode = defect.barcode);

-------------------check wrong status for inbound table
SELECT 
    id,
    status AS current_status,
    CASE
        WHEN current_action = 'confirm' THEN 'complete'
        WHEN (arrival_date IS NULL OR arrival_date = '') 
             AND (current_action IS NULL OR current_action = '') THEN 'Pending'
        ELSE 'process'
    END AS expected_status
FROM inbound
WHERE status <> CASE
        WHEN current_action = 'confirm' THEN 'complete'
        WHEN (arrival_date IS NULL OR arrival_date = '') 
             AND (current_action IS NULL OR current_action = '') THEN 'Pending'
        ELSE 'process'
    END;

-------------------Update inbound status
UPDATE inbound
SET status =
    CASE
        WHEN current_action = 'confirm' THEN 'complete'
        WHEN (arrival_date IS NULL OR arrival_date = '') 
             AND (current_action IS NULL OR current_action = '') THEN 'Pending'
        ELSE 'process'
    END
WHERE status IS NOT
    CASE
        WHEN current_action = 'confirm' THEN 'complete'
        WHEN (arrival_date IS NULL OR arrival_date = '') 
             AND (current_action IS NULL OR current_action = '') THEN 'Pending'
        ELSE 'process'
    END;


-- alter table statement
ALTER TABLE carrier_zone_hcm RENAME COLUMN "description" TO district;
ALTER TABLE shop DROP COLUMN pullback_schedule;
ALTER TABLE shop ADD COLUMN pullback_schedule INTEGER DEFAULT 0 CHECK (pullback_schedule IN (0, 1));

-- export sample data
SELECT 'SELECT * FROM (SELECT * FROM "' || name || '" ORDER BY id DESC LIMIT 500) ORDER BY id;'
FROM sqlite_master WHERE type = 'table'  AND name NOT LIKE 'sqlite_%';



-- fix shop_new problem
PRAGMA foreign_keys = OFF;
PRAGMA legacy_alter_table = ON;
ALTER TABLE pullback RENAME TO pullback_old;
CREATE TABLE "pullback" (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    pullback_date DATE NOT NULL CHECK (strftime('%Y-%m-%d', pullback_date) = pullback_date),
    from_shop TEXT NOT NULL,
    to_shop TEXT NOT NULL,
    box_qty INTEGER DEFAULT 0 CHECK (box_qty >= 0),
    product INTEGER DEFAULT 0 CHECK (product >= 0),
    paper_bag INTEGER DEFAULT 0 CHECK (paper_bag >= 0),
    note TEXT DEFAULT '-',
    FOREIGN KEY (from_shop) REFERENCES shop(shop_code)
        ON UPDATE CASCADE,
    FOREIGN KEY (to_shop) REFERENCES shop(shop_code)
        ON UPDATE CASCADE,
    FOREIGN KEY (pullback_date) REFERENCES date_tb(Date)
);
INSERT INTO pullback (id, pullback_date, from_shop, to_shop, box_qty, product, paper_bag, note)
SELECT id, pullback_date, from_shop, to_shop, box_qty, product, paper_bag, note FROM pullback_old;
UPDATE sqlite_sequence SET seq = (SELECT seq FROM sqlite_sequence WHERE name = 'pullback_old')
WHERE name = 'pullback' AND (SELECT seq FROM sqlite_sequence WHERE name = 'pullback_old') > seq;
DROP TABLE pullback_old;


-- check bad row connect
SELECT "table", parent, COUNT(*) AS bad_rows
FROM pragma_foreign_key_check
WHERE "table" IN ('pullback', 'outbound_include', 'outbound_groupx')
GROUP BY "table", parent;
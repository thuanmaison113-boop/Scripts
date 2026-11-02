CREATE TABLE inbound (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    shop_code TEXT NOT NULL,
    shop_name TEXT,
	brand_name TEXT,
    region TEXT,
    box_qty INTEGER DEFAULT 0 CHECK (box_qty >= 0),
    input_standard INTEGER DEFAULT 0 CHECK (input_standard >= 0),
    input_taras_defect INTEGER DEFAULT 0 CHECK (input_taras_defect >= 0),
    input_paper_bag INTEGER DEFAULT 0 CHECK (input_paper_bag >= 0),
    input_visual_merchandising INTEGER DEFAULT 0 CHECK (input_visual_merchandising >= 0),
    input_type TEXT DEFAULT '-',
    status TEXT DEFAULT 'Pending',
    purchase_order_num TEXT DEFAULT '-',
    delivery_order_num TEXT DEFAULT '-',
	good_issue_date DATE CHECK (good_issue_date IS NULL OR strftime('%Y-%m-%d', good_issue_date) = good_issue_date),
    transfer_order_num TEXT DEFAULT '-',
    put_away_bin TEXT DEFAULT '-',
    transfer_order_quality_issue TEXT DEFAULT '-',
    substandard_qty INTEGER DEFAULT 0 CHECK (substandard_qty >= 0),   
    arrival_date DATE CHECK (arrival_date IS NULL OR strftime('%Y-%m-%d', arrival_date) = arrival_date),
    current_action TEXT CHECK (current_action IN ('post', 'confirm') OR current_action IS NULL),
    good_receipt_date DATE CHECK (good_receipt_date IS NULL OR strftime('%Y-%m-%d', good_receipt_date) = good_receipt_date),
    note TEXT DEFAULT '-',
    inbound_code TEXT,
    way_bill TEXT DEFAULT '-',
    checklist TEXT DEFAULT 0,
    FOREIGN KEY (shop_code) REFERENCES shop(shop_code)
        ON UPDATE CASCADE,
    FOREIGN KEY (good_issue_date) REFERENCES date_tb(Date),
    FOREIGN KEY (arrival_date) REFERENCES date_tb(Date),
    FOREIGN KEY (good_receipt_date) REFERENCES date_tb(Date)
);
CREATE INDEX idx_inbound_shop_code ON inbound(shop_code);
CREATE UNIQUE INDEX IF NOT EXISTS idx_inbound_purchase_order_num_unique ON inbound(purchase_order_num);
CREATE INDEX idx_inbound_current_action ON inbound(current_action);
CREATE INDEX idx_inbound_gr_date        ON inbound(good_receipt_date);
CREATE INDEX idx_inbound_gi_date        ON inbound(good_issue_date);
CREATE INDEX idx_inbound_region_arrival ON inbound(region, arrival_date);
CREATE INDEX idx_inbound_arrival_date   ON inbound(arrival_date);
CREATE TRIGGER inbound_add_infos
AFTER INSERT ON inbound
FOR EACH ROW
BEGIN
    UPDATE inbound
    SET 
        shop_name = (SELECT s.shop_name FROM shop s WHERE s.shop_code = NEW.shop_code),
        brand_name = (SELECT b.brand_name FROM shop s INNER JOIN brand b ON s.brand = b.brand_code WHERE s.shop_code = NEW.shop_code),
        region = (SELECT p.region FROM shop s INNER JOIN province p ON s.province_id = p.id WHERE s.shop_code = NEW.shop_code),
        inbound_code = 
        CASE
            WHEN SUBSTR(NEW.purchase_order_num, 1, 2) = '47' THEN 'I-' || NEW.delivery_order_num || '-001'
            WHEN SUBSTR(NEW.purchase_order_num, 1, 2) = '45' THEN 'O-00' || NEW.delivery_order_num || '-001'
            ELSE '-'
        END
    WHERE rowid = NEW.rowid;
END;
CREATE TRIGGER inbound_change_status
AFTER UPDATE OF current_action, arrival_date ON inbound
FOR EACH ROW
WHEN NEW.current_action IS NOT OLD.current_action OR NEW.arrival_date IS NOT OLD.arrival_date
BEGIN
    UPDATE inbound 
    SET status = 
        CASE
            WHEN NEW.current_action = 'confirm' THEN 'complete'
            WHEN (NEW.arrival_date IS NULL OR NEW.arrival_date = '') AND 
                 (NEW.current_action IS NULL OR NEW.current_action = '') THEN 'Pending'
            ELSE 'process'
        END
    WHERE rowid = NEW.rowid;
END;
CREATE TRIGGER inbound_add_defect_row
AFTER UPDATE OF substandard_qty ON inbound
FOR EACH ROW
WHEN COALESCE(OLD.substandard_qty, 0) = 0
     AND NEW.substandard_qty > 0
BEGIN
    INSERT INTO defect (purchase_order_num, defect_qty)
    SELECT NEW.purchase_order_num, 1
    FROM support_numbers
    WHERE n <= NEW.substandard_qty;
END;

CREATE TABLE outbound (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    post_date DATE CHECK (post_date IS NULL OR strftime('%Y-%m-%d', post_date) = post_date),
    order_date DATE DEFAULT (DATE('now')) CHECK (strftime('%Y-%m-%d', order_date) = order_date),
    delivery_date DATE DEFAULT (DATE('now')) CHECK (strftime('%Y-%m-%d', delivery_date) = delivery_date),
    main_vendor TEXT DEFAULT 'D111',
    brand_name TEXT,
    region TEXT,
    shop_code TEXT NOT NULL,
    shop_name TEXT,
    product_qty INTEGER DEFAULT 0 CHECK (product_qty >= 0),
    paper_bag_qty INTEGER DEFAULT 0 CHECK (paper_bag_qty >= 0),
    stock_transfer_order_num TEXT DEFAULT '-',
    delivery_order_num TEXT DEFAULT '-',
    note TEXT DEFAULT '-',
    box_qty INTEGER DEFAULT 0 CHECK (box_qty >= 0),
    order_qty INTEGER DEFAULT 0 CHECK (order_qty >= 0),
    transfer_order_num TEXT DEFAULT '-',
    passed_qc_qty INTEGER DEFAULT 0,
    failed_qc_qty INTEGER DEFAULT 0,
    note2 TEXT DEFAULT '-',
    checklist TEXT DEFAULT 0,
    FOREIGN KEY (shop_code) REFERENCES shop(shop_code)
        --ON DELETE CASCADE
        ON UPDATE CASCADE,
    FOREIGN KEY (post_date) REFERENCES date_tb(Date),
    FOREIGN KEY (order_date) REFERENCES date_tb(Date),
    FOREIGN KEY (delivery_date) REFERENCES date_tb(Date)
);
CREATE INDEX idx_outbound_post_date ON outbound(post_date);
CREATE INDEX idx_outbound_delivery_date ON outbound(delivery_date);
CREATE INDEX idx_outbound_stock_tranfer_oder_num ON outbound(stock_transfer_order_num);
CREATE INDEX idx_outbound_shop_code ON outbound(shop_code);
CREATE INDEX idx_outbound_transfer_order_num ON outbound(transfer_order_num);
CREATE UNIQUE INDEX IF NOT EXISTS idx_outbound_delivery_order_num_unique ON outbound(delivery_order_num);
CREATE TRIGGER outbound_add_shop_brand_region
AFTER INSERT ON outbound
FOR EACH ROW
BEGIN
    UPDATE outbound
    SET 
        shop_name = (SELECT s.shop_name FROM shop s WHERE s.shop_code = NEW.shop_code),
        brand_name = (SELECT b.brand_name FROM shop s INNER JOIN brand b ON s.brand = b.brand_code WHERE s.shop_code = NEW.shop_code),
        region = (SELECT p.region FROM shop s INNER JOIN province p ON s.province_id = p.id WHERE s.shop_code = NEW.shop_code)
    WHERE rowid = NEW.rowid;
END;



CREATE TABLE a_diary (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    diary_date DATE DEFAULT (DATE('now')) CHECK (strftime('%Y-%m-%d', diary_date) = diary_date),
    content TEXT DEFAULT '-',
    box INTEGER DEFAULT 0 CHECK (box >= 0),
    qty INTEGER DEFAULT 0 CHECK (qty >= 0),
    shop TEXT DEFAULT '-',
    location TEXT DEFAULT '-',
    note TEXT DEFAULT '-',
    status TEXT DEFAULT '-'
);

CREATE TABLE shop (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    shop_code TEXT UNIQUE NOT NULL,
    brand TEXT NOT NULL DEFAULT '-',
    shop_name TEXT DEFAULT '-',
    status TEXT DEFAULT '-',
    carrier TEXT DEFAULT '-',
   	shop_type TEXT DEFAULT '-',
    pickup_time TEXT CHECK (pickup_time GLOB '[0-2][0-9]:[0-5][0-9]' AND CAST(substr(pickup_time, 1, 2) AS INTEGER) <= 23 ) DEFAULT '00:00',
    delivery_time TEXT CHECK (delivery_time GLOB '[0-2][0-9]:[0-5][0-9]' AND CAST(substr(delivery_time, 1, 2) AS INTEGER) <= 23 ) DEFAULT '00:00',
    lead_time_day INTEGER DEFAULT 0,
    mail_address TEXT DEFAULT '-',
    shop_address TEXT DEFAULT '-',
    phone_number TEXT DEFAULT '-',
    latitude TEXT DEFAULT 0,
    longitude TEXT DEFAULT 0,
    province_id INTEGER DEFAULT 0 NOT NULL CHECK (province_id >= 0),
    note TEXT DEFAULT '-',
    checklist TEXT DEFAULT 0,
    cost_center TEXT DEFAULT '-',
    shop_name_nxt TEXT DEFAULT '-',
    district TEXT DEFAULT '-',
    default_box_pullback INTEGER DEFAULT 0 CHECK (default_box_pullback >= 0),
    pullback_schedule INTEGER DEFAULT 1 CHECK (pullback_schedule IN (0, 1)),
    
    FOREIGN KEY (brand) REFERENCES brand(brand_code)
        ON UPDATE CASCADE,
    FOREIGN KEY (province_id) REFERENCES province(province_id)
        ON UPDATE CASCADE,
    FOREIGN KEY (carrier) REFERENCES carrier(carrier_code)
); 
CREATE INDEX idx_shop_shop_name ON shop(shop_name);
CREATE INDEX idx_shop_shop_code ON shop(shop_code);

CREATE TABLE carrier (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    carrier_code TEXT UNIQUE,
    name TEXT DEFAULT '-',
    tracking_url TEXT DEFAULT '-',
    contact_name TEXT DEFAULT '-',
    contact_phone TEXT DEFAULT '-'
);

CREATE TABLE carrier_service (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    carrier_id TEXT,
    transport_mode TEXT,
    description TEXT,
    FOREIGN KEY (carrier_id) REFERENCES carrier(carrier_code)
);

CREATE TABLE pullback (
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
CREATE INDEX idx_pullback_date_shop ON pullback(pullback_date, to_shop);



CREATE TABLE defect (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    results TEXT,
    purchase_order_num TEXT NOT NULL,
    shop_name TEXT,
    defect_qty INTEGER CHECK (defect_qty >= 0),
    barcode TEXT,
    artical TEXT,
    item_full_name TEXT,
    defect_type TEXT DEFAULT '-',
    solution TEXT DEFAULT '-',
    note TEXT DEFAULT '-',
    style_code TEXT,
    checklist TEXT DEFAULT '-',
    brand_name TEXT DEFAULT '-',
    FOREIGN KEY (purchase_order_num) REFERENCES inbound(purchase_order_num)
        ON UPDATE CASCADE,
    FOREIGN KEY (barcode) REFERENCES item_list(barcode)
        ON UPDATE CASCADE
    FOREIGN KEY (artical) REFERENCES item_list(variant)
        ON UPDATE CASCADE
);
CREATE INDEX idx_defect_purchase_order_num ON defect(purchase_order_num);
CREATE INDEX idx_defect_style_code ON defect(style_code);
CREATE TRIGGER defect_after_insert_barcode
AFTER INSERT ON defect
FOR EACH ROW
WHEN NEW.barcode IS NOT NULL
BEGIN
    UPDATE defect
    SET
        shop_name = (SELECT i.shop_name FROM inbound i WHERE i.purchase_order_num = NEW.purchase_order_num),
        brand_name = (SELECT i.brand_name FROM inbound i WHERE i.purchase_order_num = NEW.purchase_order_num),
        artical = (SELECT il.variant FROM item_list il WHERE il.barcode = NEW.barcode),
        item_full_name = (SELECT il.item_full_name FROM item_list il WHERE il.barcode = NEW.barcode),
        style_code = (SELECT il.style_code FROM item_list il WHERE il.barcode = NEW.barcode)
    WHERE rowid = NEW.rowid;
END;
CREATE TRIGGER defect_after_insert_artical
AFTER INSERT ON defect
FOR EACH ROW
WHEN NEW.artical IS NOT NULL
BEGIN
    UPDATE defect
    SET
        shop_name = (SELECT i.shop_name FROM inbound i WHERE i.purchase_order_num = NEW.purchase_order_num),
        brand_name = (SELECT i.brand_name FROM inbound i WHERE i.purchase_order_num = NEW.purchase_order_num),
        barcode = (SELECT il.barcode FROM item_list il WHERE il.variant = NEW.artical ),
        item_full_name = (SELECT il.item_full_name FROM item_list il WHERE il.variant = NEW.artical),
        style_code = (SELECT il.style_code FROM item_list il WHERE il.variant = NEW.artical)
    WHERE rowid = NEW.rowid;
END;




CREATE TABLE province (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    province_id INTEGER UNIQUE NOT NULL,
	region TEXT NOT NULL,
	province_name TEXT UNIQUE NOT NULL,
	area TEXT NOT NULL
);

CREATE TABLE item_list (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    brand_name TEXT NOT NULL,
    style_code TEXT DEFAULT '-',
    variant TEXT NOT NULL,
    unit TEXT DEFAULT '-',
    barcode TEXT UNIQUE NOT NULL,
    color TEXT DEFAULT '-',
    sizes TEXT DEFAULT '-',
    full_price INTEGER CHECK (full_price >= 0),
    markdown_price INTEGER CHECK (markdown_price >= 0),
    type TEXT,
    item_full_name TEXT,
    kind TEXT,
    FOREIGN KEY (brand_name) REFERENCES brand(brand_name)
        --ON DELETE CASCADE
        ON UPDATE CASCADE,
    FOREIGN KEY (type) REFERENCES item_type(type)
        --ON DELETE CASCADE
        ON UPDATE CASCADE
);
CREATE INDEX idx_item_list_barcode ON item_list(barcode);
CREATE INDEX idx_item_list_variant ON item_list(variant);
CREATE INDEX idx_item_list_style_code ON item_list(style_code);

CREATE TABLE item_type (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
	type TEXT,
	kind TEXT,
	variant_prefix Text
);

CREATE TABLE carrier_area (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    carrier TEXT,
	area_code TEXT,
	province_name TEXT,
	province_id TEXT,
	FOREIGN KEY (carrier) REFERENCES carrier(carrier_code),
	FOREIGN KEY (province_id) REFERENCES province(province_id)
);

CREATE TABLE carrier_zone_hcm (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    carrier TEXT,
	zone_id TEXT,
	district TEXT,
	FOREIGN KEY (carrier) REFERENCES carrier(carrier_code)
);

CREATE TABLE carrier_vehicle (
	id INTEGER PRIMARY KEY AUTOINCREMENT,
    vehicle_code TEXT UNIQUE,
    vehicle_name TEXT,
    max_box_qty TEXT,
	capacity_factor INTEGER
);

CREATE TABLE carrier_zone_hcm_pricing (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    carrier TEXT,
    zone_id TEXT,
    vehicle_type TEXT,
    base_price INTEGER,
    extra_same_area INTEGER,
    extra_other_area INTEGER,
    loading_fee INTEGER,
    FOREIGN KEY (carrier) REFERENCES carrier(carrier_code) ON UPDATE CASCADE,
    FOREIGN KEY (zone_id) REFERENCES carrier_zone_hcm(zone_id) ON UPDATE CASCADE,
    FOREIGN KEY (vehicle_type) REFERENCES carrier_vehicle(vehicle_code) ON UPDATE CASCADE
);

CREATE TABLE carrier_price (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    carrier TEXT,
    area TEXT,
   	tranport_type TEXT,
	weight_step_kg TEXT,
	price INTEGER DEFAULT 0,
	FOREIGN KEY (carrier) REFERENCES carrier(carrier_code)
);

CREATE TABLE carrier_lead_time (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    carrier TEXT,
    tranport_type TEXT NOT NULL,
	area TEXT NOT NULL,
	lead_time TEXT NOT NULL,
    FOREIGN KEY (carrier) REFERENCES carrier(carrier_code)
);

CREATE TABLE date_tb (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    Date DATE NOT NULL UNIQUE,
    Day_Of_Month INTEGER NOT NULL CHECK (Day_Of_Month BETWEEN 1 AND 31),
    Month_Number_Of_Year INTEGER NOT NULL CHECK (Month_Number_Of_Year BETWEEN 1 AND 12),
    Year INTEGER NOT NULL,
    Day_Of_Week_Number INTEGER NOT NULL CHECK (Day_Of_Week_Number BETWEEN 1 AND 7),
    Month_Name TEXT NOT NULL,
    Day_Name TEXT NOT NULL,
    Start_of_Week DATE NOT NULL,
    Start_of_Month DATE NOT NULL,
    Start_of_Quarter DATE NOT NULL,
    Start_of_Year DATE NOT NULL,
    Quarter INTEGER,
    Weekend TEXT,
    Month_Short TEXT
);

CREATE TABLE brand (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    brand_code TEXT UNIQUE NOT NULL,
    brand_name TEXT NOT NULL DEFAULT '-',
    storage_location TEXT NOT NULL DEFAULT '-',
    is_active INTEGER NOT NULL DEFAULT 0,
	is_reportable INTEGER NOT NULL DEFAULT 0,
	note TEXT DEFAULT '-',
	capacity_factor INTEGER DEFAULT 0
)

CREATE TABLE item_material (
	id INTEGER PRIMARY KEY AUTOINCREMENT,
    barcode TEXT,
    material TEXT DEFAULT '-',
    FOREIGN KEY (barcode) REFERENCES item_list(barcode)
);



CREATE TABLE cyclecount (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    site TEXT NOT NULL,
    storage_type TEXT,
	brand_code TEXT,
	brand_name TEXT,
    cyclecount_num TEXT,	
    cyclecount_qty INTEGER DEFAULT 0,
    scan_qty INTEGER DEFAULT 0,
    different INTEGER DEFAULT 0,
    document_date DATE DEFAULT (DATE('now')),
    status TEXT DEFAULT 'process',
    results TEXT  DEFAULT '-',
    location TEXT  DEFAULT '-',
    note TEXT DEFAULT '-',
    FOREIGN KEY (brand_code) REFERENCES brand(brand_code)
        --ON DELETE CASCADE
        ON UPDATE CASCADE,
    FOREIGN KEY (document_date) REFERENCES date_tb(Date)
);
CREATE TRIGGER cyclecount_add_brand_name
AFTER INSERT ON cyclecount
FOR EACH ROW
BEGIN
    UPDATE cyclecount
    SET brand_name = (
        SELECT brand_name
        FROM brand
        WHERE brand.brand_code = NEW.brand_code
    )
    WHERE id = NEW.id;
END;
CREATE TRIGGER cyclecount_calc_difference
AFTER UPDATE ON cyclecount
FOR EACH ROW
BEGIN
    UPDATE cyclecount
    SET different = NEW.scan_qty - NEW.cyclecount_qty
    WHERE id = NEW.id;
END;


CREATE TABLE stocktaking (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    site TEXT NOT NULL,
    storage_type TEXT,
	brand_code TEXT,
	brand_name TEXT,
    stocktaking_num TEXT,	
    stocktaking_qty INTEGER DEFAULT 0,
    scan_qty INTEGER DEFAULT 0,
    different INTEGER DEFAULT 0,
    document_date DATE CHECK (document_date IS NULL OR strftime('%Y-%m-%d', document_date) = document_date),
    status TEXT DEFAULT 'process',
    results TEXT  DEFAULT '-',
    location TEXT  DEFAULT '-',
    note TEXT DEFAULT '-',
    FOREIGN KEY (brand_code) REFERENCES brand(brand_code)
        --ON DELETE CASCADE
        ON UPDATE CASCADE,
    FOREIGN KEY (document_date) REFERENCES date_tb(Date)
);
CREATE TRIGGER stocktaking_add_brand_name
AFTER INSERT ON stocktaking
FOR EACH ROW
BEGIN
   UPDATE stocktaking
    SET brand_name = (
        SELECT brand_name
        FROM brand
        WHERE brand.brand_code = stocktaking.brand_code
    )
    WHERE id = NEW.id;
END;
CREATE TRIGGER stocktaking_calc_difference
AFTER UPDATE ON stocktaking
FOR EACH ROW
BEGIN
    UPDATE stocktaking
    SET different = NEW.scan_qty - NEW.stocktaking_qty
    WHERE id = NEW.id;
END;

CREATE TABLE a_bin_temp (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    bin TEXT NOT NULL DEFAULT '-',
    section TEXT,
	description TEXT DEFAULT '-',
	qty INTEGER DEFAULT 0,
    note TEXT DEFAULT '-'
);

CREATE TABLE item_paper_bag (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    brand_name TEXT,
    style_code TEXT,
    variant TEXT,
    barcode TEXT NOT NULL,
    color TEXT DEFAULT '-',
    size TEXT DEFAULT '-',
    qty_per_box INTEGER DEFAULT 0,
    FOREIGN KEY (barcode) REFERENCES item_list(barcode)
        ON UPDATE CASCADE
);

CREATE TABLE item_ecom_bag (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    barcode TEXT NOT NULL,
    artical TEXT,
    description TEXT DEFAULT '-',
    en_name TEXT DEFAULT '-',
    vn_name TEXT DEFAULT '-',
    size TEXT DEFAULT '-',
    length TEXT DEFAULT '-',
    width TEXT DEFAULT '-',
    height TEXT DEFAULT '-',
    price TEXT DEFAULT '-',
    info TEXT DEFAULT '-',
    note TEXT DEFAULT '-',
    checklist TEXT DEFAULT '-',
    FOREIGN KEY (barcode) REFERENCES item_list(barcode)
        ON UPDATE CASCADE
);



CREATE TABLE outbound_groupx (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    shop_code TEXT NOT NULL,
    brand TEXT,
    shop_name TEXT,
	groupx TEXT,
    FOREIGN KEY (shop_code) REFERENCES shop(shop_code)
);
CREATE INDEX idx_groupx_shop_code   ON outbound_groupx(shop_code);



CREATE TABLE outbound_include (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    dely_date DATE DEFAULT (DATE('now')),
    shop_code TEXT,
    shop_name TEXT,
    box_qty INTEGER DEFAULT 0,
    item_name TEXT DEFAULT '-',
    note TEXT DEFAULT '-',
    FOREIGN KEY (shop_code) REFERENCES shop(shop_code)
        ON UPDATE CASCADE,
    FOREIGN KEY (dely_date) REFERENCES date_tb(Date)
);
CREATE INDEX idx_out_include_date   ON outbound_include(dely_date);
CREATE TRIGGER outbound_include_add_shop_name
AFTER INSERT ON outbound_include
FOR EACH ROW
BEGIN
    UPDATE outbound_include
    SET 
        shop_name = (SELECT s.shop_name FROM shop s WHERE s.shop_code = NEW.shop_code)
    WHERE rowid = NEW.rowid;
END;



CREATE TABLE inbound_visual_asset (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    item_name TEXT DEFAULT '-',
    qty_box INTEGER DEFAULT 0,
    quantity INTEGER DEFAULT 0,
    status TEXT CHECK (status IN ('inbound', 'outbound')),
    note TEXT DEFAULT '-',
    check_date DATE DEFAULT (DATE('now')) CHECK (strftime('%Y-%m-%d', check_date) = check_date),
    FOREIGN KEY (check_date) REFERENCES date_tb(Date)
);

CREATE TABLE employee (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    employee_code TEXT UNIQUE,
    employee_full_name TEXT DEFAULT '-',
    employee_short_name TEXT DEFAULT '-',
    user_SAP TEXT UNIQUE,
    gender TEXT CHECK (gender IN ('Male', 'Female', 'Other')) DEFAULT 'Male',
    phone_number TEXT DEFAULT '-',
    employee_role TEXT DEFAULT '-',
    is_direct_labor INTEGER DEFAULT 1 CHECK (is_direct_labor IN (0, 1)),
    start_date DATE CHECK (start_date IS NULL OR strftime('%Y-%m-%d', start_date) = start_date),
    end_date DATE CHECK (end_date IS NULL OR strftime('%Y-%m-%d', end_date) = end_date),
    birth_year INTEGER DEFAULT 0,
    hometow TEXT DEFAULT "-",
    main_site_code TEXT DEFAULT 'D111',
    motorbike_plate TEXT DEFAULT '-',
    motorbike_card_no TEXT DEFAULT '-',
    note TEXT DEFAULT '-',
    resignation_reason TEXT DEFAULT '-',
    FOREIGN KEY (start_date) REFERENCES date_tb(Date),
    FOREIGN KEY (end_date) REFERENCES date_tb(Date)
);

CREATE TABLE outbound_disparity (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    disparity_date DATE DEFAULT (DATE('now'))
        CHECK (disparity_date IS NULL OR strftime('%Y-%m-%d', disparity_date) = disparity_date),
    user_SAP TEXT DEFAULT '-',
    employee_short_name TEXT DEFAULT '-',
    delivery_order_num TEXT,
    barcode TEXT NOT NULL,
    item_full_name TEXT DEFAULT '-',
    TO_num INTEGER DEFAULT 0,
    pick_num INTEGER DEFAULT 0,
    pack_num INTEGER DEFAULT 0,
    note TEXT DEFAULT '-',
    FOREIGN KEY (barcode) REFERENCES item_list(barcode),
    FOREIGN KEY (user_SAP) REFERENCES employee(user_SAP),
    FOREIGN KEY (disparity_date) REFERENCES date_tb(Date),
    FOREIGN KEY (delivery_order_num) REFERENCES outbound(delivery_order_num)
);
CREATE TRIGGER outbound_disparity_insert
AFTER INSERT ON outbound_disparity
FOR EACH ROW
BEGIN
    UPDATE outbound_disparity
    SET employee_short_name = (
        SELECT e.employee_short_name 
        FROM employee e 
        WHERE e.user_SAP = NEW.user_SAP
    )
    WHERE rowid = NEW.rowid;
END;




CREATE TABLE inbound_ecom (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    barcode TEXT NOT NULL,
    qty INTEGER CHECK (qty >= 0),
    artical TEXT,
    purchase_order_num TEXT,
    en_name TEXT DEFAULT '-',
    vn_name TEXT DEFAULT '-',
    note TEXT DEFAULT '-',
    FOREIGN KEY (barcode) REFERENCES item_list(barcode)
    ON UPDATE CASCADE,
    FOREIGN KEY (purchase_order_num) REFERENCES inbound(purchase_order_num)
    ON UPDATE CASCADE
);
CREATE TRIGGER inbound_ecom_add_info
AFTER INSERT ON inbound_ecom
FOR EACH ROW
BEGIN
    UPDATE inbound_ecom
    SET 
    	artical = (SELECT e.artical FROM item_ecom_bag e WHERE e.barcode = NEW.barcode),
        en_name = (SELECT e.en_name FROM item_ecom_bag e WHERE e.barcode = NEW.barcode),
        vn_name = (SELECT e.vn_name FROM item_ecom_bag e WHERE e.barcode = NEW.barcode)
    WHERE rowid = NEW.rowid;
END;

CREATE TABLE a_documentation (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    type TEXT,
    name TEXT NOT NULL UNIQUE,
	description TEXT
);

CREATE TABLE cyclecount (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    site TEXT NOT NULL,
    storage_type TEXT,
	brand_code TEXT,
	brand_name TEXT,
    cyclecount_num TEXT,	
    cyclecount_qty INTEGER DEFAULT 0,
    scan_qty INTEGER DEFAULT 0,
    different INTEGER DEFAULT 0,
    document_date DATE DEFAULT (DATE('now')),
    status TEXT DEFAULT 'process',
    results TEXT  DEFAULT '-',
    location TEXT  DEFAULT '-',
    note TEXT DEFAULT '-',
    FOREIGN KEY (brand_code) REFERENCES brand(brand_code)
        --ON DELETE CASCADE
        ON UPDATE CASCADE,
    FOREIGN KEY (document_date) REFERENCES date_tb(Date)
);

CREATE TABLE a_tcode (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    type TEXT DEFAULT '-',
    t_code TEXT UNIQUE,
	description TEXT DEFAULT '-'
);

CREATE TABLE a_reminder (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    note TEXT NOT NULL,
    created_at DATE DEFAULT (DATE('now')) CHECK (strftime('%Y-%m-%d', created_at) = created_at)
);

CREATE TABLE standard (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ware_house_code TEXT DEFAULT "-",
    standard_code TEXT DEFAULT "-",
	standard_value INTEGER CHECK (standard_value >= 0) DEFAULT 0,
	standard_unit TEXT DEFAULT "-",
	category TEXT DEFAULT "-"
);

CREATE TABLE pda_devices (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    device_code TEXT DEFAULT '-',
    serial_number TEXT DEFAULT '-',
    phone_number TEXT UNIQUE,
    brand TEXT DEFAULT '-',
    model TEXT DEFAULT '-',
    location TEXT DEFAULT 'D111',
    assigned_to TEXT DEFAULT '-',
    assigned_user_name TEXT DEFAULT '-',
    note TEXT DEFAULT '-',
    FOREIGN KEY (assigned_to) REFERENCES employee(employee_code)
);
CREATE TRIGGER pda_devices_insert
AFTER INSERT ON pda_devices
FOR EACH ROW
BEGIN
    UPDATE pda_devices
    SET assigned_user_name = (
        SELECT e.employee_short_name 
        FROM employee e 
        WHERE e.user_SAP = NEW.assigned_to
    )
    WHERE rowid = NEW.rowid;
END;
CREATE TRIGGER pda_devices_update
AFTER UPDATE OF assigned_to ON pda_devices
FOR EACH ROW
BEGIN
    UPDATE pda_devices
    SET assigned_user_name = (
        SELECT e.employee_short_name
        FROM employee e
        WHERE e.user_SAP = NEW.assigned_to
    )
    WHERE rowid = NEW.rowid;
END;


CREATE TABLE soh_main (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
	article_number TEXT DEFAULT '-',
	article_type TEXT DEFAULT '-',
	brand TEXT DEFAULT '-',
	site TEXT DEFAULT '-',
	storage_location TEXT DEFAULT '-',
	article_name TEXT DEFAULT '-',
	category TEXT DEFAULT '-',
	barcode TEXT DEFAULT '-',
	old_article TEXT DEFAULT '-',
	season TEXT DEFAULT '-',
	color TEXT DEFAULT '-',
	size TEXT DEFAULT '-',
	unrestricted INTEGER DEFAULT 0,
	blocked TEXT DEFAULT '-',
	batch TEXT DEFAULT '-',
	note TEXT DEFAULT '-',
	snapshot_date DATE DEFAULT (DATE('now')),
    FOREIGN KEY (brand) REFERENCES brand(brand_code),
    FOREIGN KEY (barcode) REFERENCES item_list(barcode)
);

CREATE TABLE soh_taras (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
	article_number TEXT DEFAULT '-',
	article_type TEXT DEFAULT '-',
	brand TEXT DEFAULT '-',
	site TEXT DEFAULT '-',
	storage_location TEXT DEFAULT '-',
	article_name TEXT DEFAULT '-',
	category TEXT DEFAULT '-',
	barcode TEXT DEFAULT '-',
	old_article TEXT DEFAULT '-',
	season TEXT DEFAULT '-',
	color TEXT DEFAULT '-',
	size TEXT DEFAULT '-',
	unrestricted INTEGER DEFAULT 0,
	blocked TEXT DEFAULT '-',
	batch TEXT DEFAULT '-',
	note TEXT DEFAULT '-',
	snapshot_date DATE DEFAULT (DATE('now')),
	FOREIGN KEY (brand) REFERENCES brand(brand_code),
    FOREIGN KEY (barcode) REFERENCES item_list(barcode)
);

CREATE TABLE plan_mer_overall (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    brand_code TEXT NOT NULL DEFAULT '-',
	brand_name TEXT NOT NULL DEFAULT '-',
	plan_type TEXT CHECK (plan_type IN ('outbound', 'pullback', 'cont') OR plan_type IS NULL),
	plan_month INTEGER DEFAULT 0 CHECK (plan_month >= 0),
	plan_year INTEGER DEFAULT 2020 CHECK (plan_year >= 2020),
	plan_qty INTEGER DEFAULT 0 CHECK (plan_qty >= 0),
	FOREIGN KEY (brand_code) REFERENCES brand(brand_code)
);
CREATE TRIGGER plan_mer_overall_add_brand_name
AFTER INSERT ON plan_mer_overall
FOR EACH ROW
BEGIN
    UPDATE plan_mer_overall
    SET 
        brand_name = (SELECT b.brand_name FROM brand b WHERE b.brand_code = NEW.brand_code)
       	WHERE rowid = NEW.rowid;
END;




CREATE TABLE plan_transaction_frequency (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    brand_code TEXT NOT NULL,
	brand_name TEXT,
	plan_type TEXT CHECK (plan_type IN ('outbound', 'pullback', 'cont') OR plan_type IS NULL),
    day_of_week INTEGER DEFAULT 0 CHECK (day_of_week >= 0),
    orders_per_week INTEGER DEFAULT 0 CHECK (orders_per_week >= 0),
    FOREIGN KEY (brand_code) REFERENCES brand(brand_code)
);
CREATE TRIGGER plan_transaction_frequency_add_brand_name
AFTER INSERT ON plan_transaction_frequency
FOR EACH ROW
BEGIN
    UPDATE plan_transaction_frequency
    SET 
        brand_name = (SELECT b.brand_name FROM brand b WHERE b.brand_code = NEW.brand_code)
       	WHERE rowid = NEW.rowid;
END;



CREATE TABLE plan_mer_detail (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  brand_code    TEXT NOT NULL,
  plan_type     TEXT CHECK (plan_type IN ('outbound', 'pullback', 'cont') OR plan_type IS NULL),
  delivery_date DATE CHECK (delivery_date IS NULL OR strftime('%Y-%m-%d', delivery_date) = delivery_date),
  qty           INTEGER DEFAULT 0 CHECK (qty >= 0),
  source        TEXT NOT NULL DEFAULT 'manual',
  note          TEXT DEFAULT '-',
  created_at    TEXT NOT NULL DEFAULT (DATE('now')),
  UNIQUE (brand_code, plan_type, delivery_date, qty, note),
  FOREIGN KEY (brand_code) REFERENCES brand(brand_code)
);

CREATE TABLE employee_leave (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    employee_code TEXT NOT NULL,
    employee_full_name TEXT DEFAULT '-',
    leave_type TEXT DEFAULT 'sick',
    start_date DATE CHECK (start_date IS NULL OR strftime('%Y-%m-%d', start_date) = start_date),
    end_date DATE CHECK (end_date IS NULL OR strftime('%Y-%m-%d', end_date) = end_date),
    total_day INTEGER,
    note TEXT DEFAULT '-',
    FOREIGN KEY (employee_code) REFERENCES employee(employee_code) ON UPDATE CASCADE,
  	CHECK (end_date >= start_date),
  	CHECK (total_day > 0)
);
CREATE TRIGGER employee_leave_add_name
AFTER INSERT ON employee_leave
FOR EACH ROW
BEGIN
    UPDATE employee_leave
    SET 
        employee_full_name = (SELECT b.employee_full_name FROM employee b WHERE b.employee_code = NEW.employee_code)
       	WHERE rowid = NEW.rowid;
END;
CREATE TRIGGER employee_leave_calc_total_day
AFTER INSERT ON employee_leave
FOR EACH ROW
WHEN NEW.start_date IS NOT NULL
 AND NEW.end_date IS NOT NULL
BEGIN
    UPDATE employee_leave
    SET total_day = (
        SELECT COUNT(*)
        FROM (
            WITH RECURSIVE dates(d) AS (
                SELECT NEW.start_date
                UNION ALL
                SELECT date(d, '+1 day')
                FROM dates
                WHERE d < NEW.end_date
            )
            SELECT d
            FROM dates
            WHERE strftime('%w', d) <> '0'
        )
    )
    WHERE id = NEW.id;
END;
CREATE TRIGGER employee_leave_calc_total_day_update
AFTER UPDATE OF start_date, end_date ON employee_leave
FOR EACH ROW
WHEN NEW.start_date IS NOT NULL
 AND NEW.end_date IS NOT NULL
BEGIN
    UPDATE employee_leave
    SET total_day = (
        SELECT COUNT(*)
        FROM (
            WITH RECURSIVE dates(d) AS (
                SELECT NEW.start_date
                UNION ALL
                SELECT date(d, '+1 day')
                FROM dates
                WHERE d < NEW.end_date
            )
            SELECT d
            FROM dates
            WHERE strftime('%w', d) <> '0'
        )
    )
    WHERE id = NEW.id;
END;
CREATE TRIGGER employee_overtime_cal_overtime_hours
AFTER INSERT ON employee_overtime
FOR EACH ROW
BEGIN
    UPDATE employee_overtime
    SET overtime_hours =
        ROUND(
            (
                CASE
                    WHEN end_time >= start_time THEN
                        (
                            (CAST(substr(end_time, 1, 2) AS INTEGER) * 60 +
                             CAST(substr(end_time, 4, 2) AS INTEGER))
                            -
                            (CAST(substr(start_time, 1, 2) AS INTEGER) * 60 +
                             CAST(substr(start_time, 4, 2) AS INTEGER))
                        )
                    ELSE
                        (
                            (CAST(substr(end_time, 1, 2) AS INTEGER) * 60 +
                             CAST(substr(end_time, 4, 2) AS INTEGER))
                            + 1440
                            -
                            (CAST(substr(start_time, 1, 2) AS INTEGER) * 60 +
                             CAST(substr(start_time, 4, 2) AS INTEGER))
                        )
                END
            ) / 60.0,
            2
        )
    WHERE id = NEW.id;
END;
CREATE TRIGGER employee_overtime_cal_overtime_hours_update
AFTER UPDATE OF start_time, end_time ON employee_overtime
FOR EACH ROW
WHEN NEW.start_time IS NOT OLD.start_time OR NEW.end_time IS NOT OLD.end_time
BEGIN
    UPDATE employee_overtime 
    SET overtime_hours = 
        ROUND(
            (
                CASE
                    WHEN end_time >= start_time THEN
                        (
                            (CAST(substr(end_time, 1, 2) AS INTEGER) * 60 +
                             CAST(substr(end_time, 4, 2) AS INTEGER))
                            -
                            (CAST(substr(start_time, 1, 2) AS INTEGER) * 60 +
                             CAST(substr(start_time, 4, 2) AS INTEGER))
                        )
                    ELSE
                        (
                            (CAST(substr(end_time, 1, 2) AS INTEGER) * 60 +
                             CAST(substr(end_time, 4, 2) AS INTEGER))
                            + 1440
                            -
                            (CAST(substr(start_time, 1, 2) AS INTEGER) * 60 +
                             CAST(substr(start_time, 4, 2) AS INTEGER))
                        )
                END
            ) / 60.0,
            2
        )
    WHERE rowid = NEW.rowid;
END;



CREATE TABLE date_exception (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    start_date DATE NOT NULL CHECK (strftime('%Y-%m-%d', start_date) = start_date),
    end_date DATE NOT NULL CHECK (strftime('%Y-%m-%d', end_date) = end_date),
    off_type TEXT DEFAULT 'holiday',
    description TEXT DEFAULT '-',
    note TEXT DEFAULT '-',
    CHECK (end_date >= start_date)
);

CREATE TABLE soh_701_702 (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    document_date DATE DEFAULT (DATE('now')) CHECK (document_date IS NULL OR strftime('%Y-%m-%d', document_date ) = document_date ),
    document_type TEXT DEFAULT "cyclecount",
    document_num TEXT DEFAULT "DCCL",
    site TEXT NOT NULL DEFAULT 'D111',
	brand_code TEXT NOT NULL  DEFAULT '-',
    movement_type TEXT DEFAULT '701' NOT NULL CHECK (movement_type IN ('701', '702')),
	barcode TEXT DEFAULT '-',
    article TEXT DEFAULT '-',
	style_code TEXT DEFAULT '-',
	size TEXT DEFAULT '-',
	color TEXT DEFAULT '-',
    soh_system INTEGER DEFAULT 0,
    soh_physical INTEGER DEFAULT 0,
	disparity INTEGER DEFAULT 0,
	full_price INTEGER DEFAULT 0,
    note TEXT DEFAULT '-',
    FOREIGN KEY (brand_code) REFERENCES brand(brand_code) ON UPDATE CASCADE,
    FOREIGN KEY (barcode) REFERENCES item_list(barcode) ON UPDATE CASCADE,
    FOREIGN KEY (document_date) REFERENCES date_tb(Date),
    FOREIGN KEY (document_num) REFERENCES stocktaking(stocktaking_num)
);
CREATE TRIGGER soh_701_702_add_artical_stylesizecolor
AFTER INSERT ON soh_701_702
FOR EACH ROW
WHEN NEW.barcode IS NOT NULL AND NEW.barcode != '-'
BEGIN
    UPDATE soh_701_702
    SET
        article = (SELECT il.variant FROM item_list il WHERE il.barcode = NEW.barcode),
        style_code = (SELECT il.style_code FROM item_list il WHERE il.barcode = NEW.barcode),
        size = (SELECT il.sizes FROM item_list il WHERE il.barcode = NEW.barcode),
        color = (SELECT il.color FROM item_list il WHERE il.barcode = NEW.barcode),
        full_price = (SELECT il.full_price FROM item_list il WHERE il.barcode = NEW.barcode)
    WHERE rowid = NEW.rowid;
END;
CREATE TRIGGER soh_701_702_calc_disparity
AFTER INSERT ON soh_701_702
FOR EACH ROW
BEGIN
    UPDATE soh_701_702
    SET
        disparity = NEW.soh_physical - NEW.soh_system
    WHERE rowid = NEW.rowid;
END;



CREATE TABLE employee_overtime (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    overtime_date DATE DEFAULT (DATE('now')) CHECK (overtime_date IS NULL OR strftime('%Y-%m-%d', overtime_date) = overtime_date),
	site TEXT DEFAULT 'D111',
    employee_code TEXT NOT NULL,
    employee_full_name TEXT DEFAULT '-',
    start_time TEXT DEFAULT '00:00',
    end_time TEXT DEFAULT '00:00',
    overtime_hours REAL NOT NULL DEFAULT 0 CHECK (overtime_hours >= 0),
    overtime_rate REAL DEFAULT 1.5 CHECK (overtime_rate >= 0),
    reason TEXT DEFAULT '-',
    note TEXT DEFAULT '-',
    FOREIGN KEY (employee_code) REFERENCES employee(employee_code) ON UPDATE CASCADE,
    FOREIGN KEY (overtime_date) REFERENCES date_tb(Date)
);
CREATE TRIGGER employee_overtime_add_name
AFTER INSERT ON employee_overtime
FOR EACH ROW
BEGIN
    UPDATE employee_overtime
    SET employee_full_name = (
        SELECT employee_full_name
        FROM employee
        WHERE employee_code = NEW.employee_code
    )
    WHERE id = NEW.id;
END;





CREATE TABLE carrier_claim (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    event_date DATE NOT NULL DEFAULT (DATE('now')),
    carier TEXT DEFAULT "-",
    type TEXT DEFAULT "-",
	description TEXT,
	FOREIGN KEY (carier) REFERENCES carrier(carrier_code),
	FOREIGN KEY (event_date) REFERENCES date_tb(Date)
);

CREATE TABLE item_consignment (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    date_received DATE DEFAULT (DATE('now')) CHECK (date_received IS NULL OR strftime('%Y-%m-%d', date_received) = date_received),
    consignt_type TEXT DEFAULT 'renovation',
    shop_code TEXT DEFAULT '-',
    shop_name TEXT,
    good_name TEXT DEFAULT '-',
    quantity INTEGER DEFAULT 0 CHECK (quantity >= 0),
    note1 TEXT DEFAULT '-',
    storage_location TEXT DEFAULT '-',
    date_returned DATE CHECK (date_returned IS NULL OR strftime('%Y-%m-%d', date_returned) = date_returned),
    note2 TEXT DEFAULT '-',
    checklist TEXT DEFAULT 0,
    FOREIGN KEY (shop_code) REFERENCES shop(shop_code) ON UPDATE CASCADE,
    FOREIGN KEY (date_received) REFERENCES date_tb(Date),
    FOREIGN KEY (date_returned) REFERENCES date_tb(Date)
);
CREATE TRIGGER item_consignment_add_shop_name
AFTER INSERT ON item_consignment
FOR EACH ROW
BEGIN
    UPDATE item_consignment
    SET 
        shop_name = (SELECT s.shop_name FROM "shop" s WHERE s.shop_code = NEW.shop_code)
    WHERE rowid = NEW.rowid;
END;

CREATE TABLE asset_master (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    asset_name TEXT DEFAULT '-',
    asset_type TEXT DEFAULT '-',
    asset_qty INTEGER DEFAULT 0 CHECK (asset_qty >= 0),  
    status TEXT DEFAULT 'in_use',
    note TEXT DEFAULT '-',
    condition TEXT DEFAULT 'good',
    location TEXT DEFAULT 'D111',
    last_check_date DATE CHECK (last_check_date IS NULL OR strftime('%Y-%m-%d', last_check_date) = last_check_date),
    FOREIGN KEY (last_check_date) REFERENCES date_tb(Date)
);

CREATE TABLE capacity_observation (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    observation_date DATE DEFAULT (DATE('now')),
    estimated_fill_pct REAL,
    soh_at_observation INTEGER,
    note TEXT DEFAULT '-'
);

CREATE TABLE item_checker (
    barcode TEXT,
    variant TEXT,
    item_full_name TEXT,
    full_price INTEGER,
    markdown_price INTEGER,
    type TEXT,
    unit TEXT,
    brand_name TEXT,
    style_code TEXT,
    sizes TEXT,
    color TEXT,
	note TEXT DEFAULT '-',
	id INTEGER PRIMARY KEY AUTOINCREMENT
);
CREATE TRIGGER item_checker_after_insert_variant
AFTER INSERT ON item_checker
FOR EACH ROW
WHEN NEW.variant IS NOT NULL
BEGIN
    UPDATE item_checker
    SET
        barcode = (SELECT il.barcode FROM item_list il WHERE il.variant = NEW.variant),
        item_full_name = (SELECT il.item_full_name FROM item_list il WHERE il.variant = NEW.variant),
        full_price = (SELECT il.full_price FROM item_list il WHERE il.variant = NEW.variant),
        markdown_price = (SELECT il.markdown_price FROM item_list il WHERE il.variant = NEW.variant),
        type = (SELECT il.type FROM item_list il WHERE il.variant = NEW.variant),
        unit = (SELECT il.unit FROM item_list il WHERE il.variant = NEW.variant),
        brand_name = (SELECT il.brand_name FROM item_list il WHERE il.variant = NEW.variant),
        style_code = (SELECT il.style_code FROM item_list il WHERE il.variant = NEW.variant),
        sizes = (SELECT il.sizes FROM item_list il WHERE il.variant = NEW.variant),
        color = (SELECT il.color FROM item_list il WHERE il.variant = NEW.variant)
    WHERE rowid = NEW.rowid;
END;
CREATE TRIGGER item_checker_after_insert_barcode
AFTER INSERT ON item_checker
FOR EACH ROW
WHEN NEW.barcode IS NOT NULL
BEGIN
    UPDATE item_checker
    SET
        variant = (SELECT il.variant FROM item_list il WHERE il.barcode = NEW.barcode),
        item_full_name = (SELECT il.item_full_name FROM item_list il WHERE il.barcode = NEW.barcode),
        full_price = (SELECT il.full_price FROM item_list il WHERE il.barcode = NEW.barcode),
        markdown_price = (SELECT il.markdown_price FROM item_list il WHERE il.barcode = NEW.barcode),
        type = (SELECT il.type FROM item_list il WHERE il.barcode = NEW.barcode),
        unit = (SELECT il.unit FROM item_list il WHERE il.barcode = NEW.barcode),
        brand_name = (SELECT il.brand_name FROM item_list il WHERE il.barcode = NEW.barcode),
        style_code = (SELECT il.style_code FROM item_list il WHERE il.barcode = NEW.barcode),
        sizes = (SELECT il.sizes FROM item_list il WHERE il.barcode = NEW.barcode),
        color = (SELECT il.color FROM item_list il WHERE il.barcode = NEW.barcode)
    WHERE rowid = NEW.rowid;
END;




CREATE TABLE item_zsta (
	id INTEGER PRIMARY KEY AUTOINCREMENT,
    barcode TEXT UNIQUE,
    variant TEXT UNIQUE,
    type TEXT,
    FOREIGN KEY (barcode) REFERENCES item_list(barcode),
    FOREIGN KEY (variant) REFERENCES item_list(variant),
    FOREIGN KEY (type) REFERENCES item_type(type)
);

CREATE TABLE item_export (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    Brand TEXT,
    Brand_name TEXT,
    Article_Type TEXT,
    Article_Category TEXT,
    Style_Code TEXT,
    Generic_Article TEXT,
    Variant TEXT,
    Base_Unit_of_Measure TEXT,
    English_Name TEXT,
    Vietnamese_Name TEXT,
    Barcode TEXT,
    Color TEXT,
    Color_Description TEXT,
    Size TEXT,
    Itemcode TEXT,
    Department TEXT,
    Department_Name TEXT,
    Merchandise_Category TEXT,
    Category_Description TEXT,
    Season TEXT,
    Year TEXT,
    Detail TEXT,
    Collection TEXT,
    Description_1 TEXT,
    Description_2 TEXT,
    FOB_Price TEXT,
    Cur1 TEXT,
    Principal_Price TEXT,
    Cur2 TEXT,
    Full_Price TEXT,
    Cur3 TEXT,
    Valid_From1 TEXT,
    Markdown_Price_1 TEXT,
    Cur4 TEXT,
    Valid_From2 TEXT,
    Valid_To1 TEXT,
    Markdown_Price_2 TEXT,
    Cur6 TEXT,
    Valid_From3 TEXT,
    Valid_To2 TEXT,
    Fashion_Grade TEXT,
    Generic_Name TEXT,
    Country TEXT,
    Original_Price TEXT,
    Tax_classific TEXT,
    snapshot_datetime TEXT NOT NULL DEFAULT (datetime('now', '+7 hours'))
);

CREATE TABLE brand_section (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    brand_code TEXT UNIQUE,
    brand_name TEXT DEFAULT '-',
    frefix TEXT DEFAULT '-',
	multi_type TEXT DEFAULT '-',
	shoe TEXT DEFAULT '-',
	bag TEXT DEFAULT '-',
	wallet TEXT DEFAULT '-',
	vmr TEXT DEFAULT '-',
	sandal TEXT DEFAULT '-',
	uniform TEXT DEFAULT '-',
	gwp TEXT DEFAULT '-',
	paper_bag TEXT DEFAULT '-',
	clothes TEXT DEFAULT '-',
	strap TEXT DEFAULT '-',
	note TEXT DEFAULT '-',
    FOREIGN KEY (brand_code) REFERENCES brand(brand_code)
        ON UPDATE CASCADE
);
CREATE TRIGGER brand_section_insert_brand_name
AFTER INSERT ON brand_section
FOR EACH ROW
BEGIN
    UPDATE brand_section
    SET 
        brand_name = (SELECT b.brand_name FROM "brand" b WHERE b.brand_code = NEW.brand_code)
    WHERE rowid = NEW.rowid;
END;



CREATE TABLE contact (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    brand_code TEXT DEFAULT '-',
    brand_name TEXT DEFAULT '-',
	department TEXT DEFAULT '-',
	name TEXT DEFAULT '-',
	title TEXT DEFAULT '-',
	responsibility TEXT DEFAULT '-',
	email TEXT DEFAULT '-',
	phone TEXT DEFAULT '-',
	note DEFAULT '-',
    FOREIGN KEY (brand_code) REFERENCES brand(brand_code)
        ON UPDATE CASCADE
);
CREATE TRIGGER contact_add_brand_name
AFTER INSERT ON contact
FOR EACH ROW
BEGIN
    UPDATE contact
    SET 
        brand_name = (SELECT b.brand_name FROM "brand" b WHERE b.brand_code = NEW.brand_code)
    WHERE rowid = NEW.rowid;
END;


CREATE TABLE web_users ( 
    id INTEGER PRIMARY KEY AUTOINCREMENT, 
    username TEXT NOT NULL UNIQUE, 
    password TEXT NOT NULL, 
    display_name TEXT 
);

CREATE TABLE web_users_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT,
    executed_at TEXT DEFAULT CURRENT_TIMESTAMP,
    sql_text TEXT,
    sql_type TEXT,
    status TEXT,
    query_ms REAL,
    affected_rows INTEGER,
    returned_rows INTEGER,
    client_ip TEXT,
    error_message TEXT
);

CREATE TABLE shop_name_checker (
    shop_code TEXT,
    shop_name TEXT DEFAULT '-',
    shop_name_nxt TEXT DEFAULT '-',
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    FOREIGN KEY (shop_code) REFERENCES shop(shop_code)
);
CREATE TRIGGER shop_name_checker_insert_shop_name
AFTER INSERT ON shop_name_checker
FOR EACH ROW
BEGIN
    UPDATE shop_name_checker
    SET 
    	shop_name = (SELECT s.shop_name FROM "shop" s WHERE s.shop_code = NEW.shop_code),
        shop_name_nxt = (SELECT s.shop_name_nxt FROM "shop" s WHERE s.shop_code = NEW.shop_code)
    WHERE rowid = NEW.rowid;
END;



CREATE TABLE item_borrow (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    borrow_date DATE DEFAULT (DATE('now')) CHECK (strftime('%Y-%m-%d', borrow_date) = borrow_date),
    brand_code TEXT DEFAULT '-',
    brand_name TEXT DEFAULT '-',
    team TEXT DEFAULT 'MKT',
	borrower TEXT DEFAULT '-',
    barcode TEXT DEFAULT '-',
    item_full_name TEXT DEFAULT '-',
    qty INTEGER DEFAULT 0,
    purpose TEXT DEFAULT '-',
    borrow_bin DEFAULT '-',
    return_status DEFAULT 'on loan',
    FOREIGN KEY (brand_code) REFERENCES brand(brand_code)
    FOREIGN KEY (barcode) REFERENCES item_list(barcode),
    FOREIGN KEY (borrow_date) REFERENCES date_tb(Date)
);
CREATE TRIGGER item_borrow_insert_info
AFTER INSERT ON item_borrow
FOR EACH ROW
WHEN NEW.barcode IS NOT NULL
BEGIN
    UPDATE item_borrow
    SET
        brand_name = (SELECT b.brand_name FROM brand b WHERE b.brand_code = NEW.brand_code),
        item_full_name = (SELECT il.item_full_name FROM item_list il WHERE il.barcode = NEW.barcode)
    WHERE rowid = NEW.rowid;
END;

CREATE TABLE web_edit_log (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                edited_at TEXT,
                username TEXT,
                client_ip TEXT,
                table_name TEXT NOT NULL,
                row_key TEXT NOT NULL,
                column_name TEXT NOT NULL,
                old_type TEXT,
                old_value TEXT,
                new_type TEXT,
                new_value TEXT
            );

-- phải có bảng này thì trigger inbound_add_defect_row mới chạy dc
CREATE TABLE IF NOT EXISTS support_numbers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    n INTEGER UNIQUE
);
INSERT OR IGNORE INTO support_numbers (n)
WITH RECURSIVE seq(n) AS (SELECT 1 UNION ALL SELECT n + 1 FROM seq WHERE n < 10000)
SELECT n FROM seq;
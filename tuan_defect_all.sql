SELECT
    d.id,
    d.results,
    d.purchase_order_num AS PO,
    d.shop_name,
    d.defect_qty,
    d.barcode,
    d.artical,
    d.item_full_name AS tên_sản_phẩm,
    d.defect_type AS lỗi,
    d.solution AS hướng_xử_lý,
    d.note,
    d.checklist,
    d.style_code,
    d.brand_name
FROM defect d
WHERE d.results IS NULL
ORDER BY d.id DESC;
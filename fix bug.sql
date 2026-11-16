WM11109
WM11122
WM11108
WM11112
WM11102
WM11111
WM11113
WM11120
WM11121
WM11110
WM11104
WM11115
WM11101
WM11106
WM11107
WM11114
WM11116

mã nhân viên có trong disparity nhưng ko có trong employee


# DB clean-up — bad rows still open (v02)

_2026-11-11 · from `PRAGMA foreign_key_check` on the DB copy refreshed 2026-11-11 20:20 (schema dump 20:39). Total 410 rows, integrity_check = ok._
_Replaces `fk_cleanup_manual_list_v01.md` (2026-11-10, 572 rows). Task: T-68 (parked)._

## Summary

| # | Table → links to | Rows | Status |
|---|---|---|---|
| 1 | outbound_groupx → shop | 2 | Quick fix: `ONR` → `ONS` |
| 2 | pda_devices → employee | 1 | Quick fix: '-' → NULL (new since 2026-11-10) |
| 3 | outbound_disparity → outbound | 16 | By hand |
| 4 | outbound_disparity → item_list | 2 | By hand (same rows as #3: ids 181, 637) |
| 5 | defect → item_list | 7 | By hand |
| 6 | defect → inbound | 1 | By hand |
| 7 | item_zsta → item_list | 2 (1 row) | Decide: add item to item_list or delete row |
| 8 | outbound_disparity → employee | 335 | **Decision needed** (store WM logins in employee, or drop the link) |
| 9 | pullback → shop | 44 | Kept on purpose (decision 2026-11-10) |

Without #8 and #9: 31 rows to fix. Fixed since 2026-11-10: asset_master dates (20), SOH total rows, 108 pullback.to_shop rows, 8 groupx codes, 3 defect PO numbers.

## 1. outbound_groupx — code not in shop (2)

| id | shop_code now | shop_name | should be |
|---|---|---|---|
| 227 | ONR D119 | KHO NVL Q7 | ONS D119 |
| 243 | ONR 99M1 | ECOM QUẬN 8 | ONS 99M1 |

Fix: `UPDATE outbound_groupx SET shop_code = 'ONS ' || SUBSTR(shop_code, 5) WHERE shop_code LIKE 'ONR %';`

## 2. pda_devices — assigned_to not an employee (1)

| id | device_code | serial_number | location | assigned_to |
|---|---|---|---|---|
| 36 | 9101033 | 20248B1E71 | D111 | - |

Fix: `UPDATE pda_devices SET assigned_to = NULL WHERE assigned_to = '-';` (or the real employee code if the device is assigned)

## 3–4. outbound_disparity — DO not in outbound (16) / barcode not in item_list (2)

| id | disparity_date | delivery_order_num | barcode | note |
|---|---|---|---|---|
| 104 | 2025-07-10 | 80178030 | 8887049321233 | - |
| 105 | 2025-07-10 | 80178030 | 8887049321240 | - |
| 106 | 2025-07-10 | 80178030 | 8887049321257 | - |
| 132 | 2025-08-16 | 80182434 | 1004698124641 | - |
| 134 | 2025-08-19 | 80182440 | 1004670310208 | - |
| 135 | 2025-08-19 | 80182440 | 1004915512213 | - |
| 136 | 2025-08-19 | 80182440 | 1005079741211 | - |
| 137 | 2025-08-19 | 80182446 | 1004828808649 | - |
| 138 | 2025-08-19 | 80182446 | 1004893406030 | - |
| 139 | 2025-08-20 | 80182453 | 1004437617212 | - |
| 140 | 2025-08-20 | 80182453 | 1004955530215 | - |
| 141 | 2025-08-20 | 80182453 | 1005097518208 | - |
| 181 | 2025-11-04 | 8019044 | 8887049366889 | - |
| 637 | 2026-06-25 | 8887049533117 | PM2-46320078, Dark Taupe Saffiano, M | - |
| 665 | 2026-07-07 | 80223900 | 8887049254562 | - |
| 666 | 2026-07-07 | 80223900 | 8887049376110 | - |

- Id 181: DO `8019044` is one digit short → find the real DO.
- Id 637: barcode in the DO column and item name in the barcode column (columns swapped).
- Others: DOs not (yet) in outbound → check if the DO exists in SAP / was imported.

## 5. defect — barcode not in item_list (7)

| id | barcode | purchase_order_num | item_full_name |
|---|---|---|---|
| 3002 | 100176598001 | 4700194371 |  |
| 3003 | 100176746001 | 4700194371 |  |
| 5355 | 4099685087815 | 4500118786 |  |
| 5736 | 100121869004 | 4700276386 |  |
| 6999 | 8809964582018 | 4500142923 |  |
| 7983 | 8809964612746 | 4700345958 |  |
| 7988 | 8809964620154 | 4700346584 |  |

- Ids 3002, 3003, 5736: article numbers (100…) typed instead of barcodes → replace with the barcode.
- Others: barcodes not in item_list (old articles?) → add to item_list or correct.

## 6. defect — PO not in inbound (1)

| id | purchase_order_num | barcode | item_full_name | note |
|---|---|---|---|---|
| 10402 | 4500211791 | 8887049295053 | CK2-20151510 ; Wineberry Red ; S | 4700474868 |

PO 4500211791 is not in inbound → correct PO or leave a note why.

## 7. item_zsta — not in item_list (1 row, 2 checks)

| id | barcode | variant | type |
|---|---|---|---|
| 1061 | 5453000000029 | 400001366001 | vmr |

VMR item → add to item_list, or delete the item_zsta row if it is not needed.

## 8. outbound_disparity.user_SAP — decision needed (335)

SAP logins `WM111xx` are not in `employee.user_SAP` (that column holds MS employee codes). Match by name from outbound_disparity:

| SAP login | name in disparity | rows | employee match |
|---|---|---|---|
| WM11101 | Hoàng> | 7 | MS58064 |
| WM11102 | Tuấn | 5 | MS57674,MS60175 |
| WM11104 | Khiêm | 5 | MS55959 |
| WM11106 | Ngân | 1 | MS60995 |
| WM11107 | Sang | 3 | MS54678 |
| WM11108 | Tấn< | 46 | MS60280 |
| WM11109 | Thắng | 61 | **none** |
| WM11110 | Vũ | 12 | MS53945 |
| WM11111 | Gởi | 29 | MS55740 |
| WM11112 | Tấn> | 35 | MS58379 |
| WM11113 | Khoa | 27 | MS56296 |
| WM11114 | Tường | 5 | MS61810,MS63169 |
| WM11115 | Toàn | 20 | MS60002 |
| WM11116 | Nguyên | 5 | MS61865 |
| WM11120 | Bảo | 40 | MS57491 |
| WM11121 | Trung > | 6 | MS58283 |
| WM11122 | Dương | 28 | MS58284,MS3 |

Options: (a) store the WM login in employee (13 clear matches; WM11102, WM11114, WM11122 have 2 matches, WM11109 has none), or (b) drop the foreign key (table rebuild, like the shop_new fix).

## 9. pullback.to_shop — kept on purpose (44)

| to_shop | rows |
|---|---|
| D111-TUIGIAY | 29 |
|  | 6 |
| D111-BT | 3 |
| D116-TARAS | 2 |
| D116 - TARAS | 1 |
| D111-AEON BT  | 1 |
| D111- AEON BÌNH TÂN | 1 |
| D111 - Tuigiay | 1 |

Kept as is (decision 2026-11-10). Editing these rows with `foreign_keys = ON` will be refused. The 6 empty ones have no destination at all.

## Other check

- `vw_check_one_off_event` is not in the DB copy (T-66). Create it again, or note its new name.






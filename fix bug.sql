find which table and view do not exist in table document;





There are two gaps in coverage, neither from this fix:
3 open shops are in provinces with no Nhất Tín area: Quảng Ninh (2) and Lai Châu (1).
Two of them use VinTrans, so this is fine as long as VinTrans keeps serving them.
The third Quảng Ninh shop has no carrier set ('-').

carrier_lead_time and carrier_price include areas G, H and I, but no province in carrier_area is mapped to them yet.




-- hỏi lại biểu phí cho quận 12 này
INSERT INTO carrier_zone_hcm (carier, zone_id, district) VALUES ('nhattin', 'KV1', 'Q12');





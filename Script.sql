select *
from defect
where note = 4500186662

select *
from outbound o 
where stock_transfer_order_num = 4500186662

80193095


select *
from inbound
where shop_code = 1139 and input_taras_defect = 1
order by id desc
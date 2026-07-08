with labevents as (select
    itemid,
    count(*)                                                as n_rows,
    round(avg(valuenum), 2)                                 as mean_val,
    round(min(valuenum), 2)                                 as min_val,
    round(max(valuenum), 2)                                 as max_val,
    round(approx_quantiles(valuenum, 100)[offset(25)], 2)   as p25,
    round(approx_quantiles(valuenum, 100)[offset(75)], 2)   as p75

from `physionet-data.mimiciv_3_1_hosp.labevents`
where itemid in (50882,
                50885,
                53089,
                52546,
                50912,
                50852,
                50855,
                51640,
                51222,
                51237,
                51675,
                53154,
                50954,
                53189,
                50971,
                52610,
                50983,
                52623,
                52647,
                51006,
                51756,
                51301,
                51755)
group by itemid),
intermediate as (select s.*, l.label, l.fluid, l.category
from labevents s join `physionet-data.mimiciv_3_1_hosp.d_labitems` l
on s.itemid = l.itemid
order by n_rows desc),
markers as (
    select marker from
    unnest(array['creatinine',
            'urea',
            'white blood',
            'hemoglobin',
            'platelet',
            'sodium',
            'potassium',
            'bicarbonate',
            'lactate',
            'bilirubin',
            'inr']) as marker
            )
select m.marker,
       i.*
from markers m
join intermediate i
on lower(i.label) like concat("%",m.marker, "%") 
order by m.marker

with markers as (
    select marker from unnest([
        'creatinine', 'urea', 'white blood', 'hemoglobin', 'hematocrit',
        'platelet', 'sodium', 'potassium', 'chloride', 'bicarbonate',
        'glucose', 'calcium', 'magnesium', 'phosphate',
        'lactate', 'ph', 'po2', 'pco2', 'base excess',
        'bilirubin', 'ast', 'alt', 'alkaline phosphatase', 'albumin',
        'inr', 'pt', 'ptt', 'troponin'
    ]) as marker
)
select
    m.marker,
    l.itemid,
    l.label,
    l.fluid,
    l.category
from markers m
join `physionet-data.mimiciv_3_1_hosp.d_labitems` l
  on regexp_contains(lower(l.label), concat(r'\b', m.marker, r'\b'))
where l.fluid = 'Blood'
order by m.marker, l.category, l.label;
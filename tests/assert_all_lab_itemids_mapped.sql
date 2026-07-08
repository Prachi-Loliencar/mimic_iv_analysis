-- Fails if stg_hosp__labevents ever contains an itemid not covered by the
-- concept CASE mapping in int_labs_first_24h. Keep this list in sync with
-- that CASE statement (see docs/exploration/concept_reference.md).
select distinct itemid
from {{ ref('stg_hosp__labevents') }}
where itemid not in (
    50862, 50863, 50861, 50878, 50802, 50882, 50885, 50893, 50902, 50912,
    50931, 51221, 51222, 51237, 50813, 50960, 50818, 50820, 50970, 51265,
    50821, 50971, 51274, 51275, 50983, 51003, 51006, 51301
)

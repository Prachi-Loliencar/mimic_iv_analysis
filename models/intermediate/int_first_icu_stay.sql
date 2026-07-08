-- 14 stays have null outtime/los (open or incomplete stays in the source);
-- excluded here because los is required for the cohort spine and downstream
-- time window features.

with source as (
    select * from {{ ref("stg_icu__icustays") }}
    where los is not null and los >= 1
),

ranked as (
    select
        *,
        row_number() over (
            partition by subject_id
            order by intime asc
        ) as stay_num
    from source
)

select
    subject_id,
    hadm_id,
    stay_id,
    first_careunit,
    last_careunit,
    intime,
    outtime,
    los
from ranked
where stay_num = 1

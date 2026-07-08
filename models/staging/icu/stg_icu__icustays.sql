with source as (
    select * from {{ source("mimic_icu","icustays") }}
),

renamed as (
    select
        stay_id,
        hadm_id,
        subject_id,
        first_careunit,
        last_careunit,
        cast(intime as timestamp) as intime,
        cast(outtime as timestamp) as outtime,
        cast(los as float64) as los
    from source
)

select * from renamed

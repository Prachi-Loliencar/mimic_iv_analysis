
with source as (select * from {{ source("mimic_hosp","patients") }}),

renamed as (
    select 
        subject_id,
        gender,
        cast(anchor_age as integer) as anchor_age,
        cast(anchor_year as integer) as anchor_year,
        anchor_year_group,
        cast(dod as date) as dod
    from source
)

select * from renamed
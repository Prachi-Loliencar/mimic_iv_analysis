{{ config(
    materialized='table',
    partition_by={'field': 'charttime', 'data_type': 'timestamp', 'granularity': 'month'},
    cluster_by=['subject_id', 'itemid']
) }}

with source as (select * from {{ source("mimic_hosp","labevents") }}),

renamed as (
    select
        labevent_id,
        subject_id,
        hadm_id,
        specimen_id,
        itemid,
        cast(charttime as timestamp) as charttime,
        valuenum,
        valueuom,
        ref_range_lower,
        ref_range_upper,
        priority
    from source
    where itemid in (
        -- renal
        50912, 51006,
        -- hematology CBC
        51222, 51221, 51301, 51265,
        -- coagulation
        51237, 51274, 51275,
        -- electrolytes & metabolic
        50983, 50971, 50902, 50882, 50931, 50893, 50960, 50970,
        -- acid-base & oxygenation
        50813, 50820, 50821, 50818, 50802,
        -- liver
        50885, 50878, 50861, 50863, 50862,
        -- cardiac
        51003
    )
)

select * from renamed

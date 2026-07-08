{{ config(
    materialized='table',
    partition_by={'field': 'charttime', 'data_type': 'timestamp', 'granularity': 'month'},
    cluster_by=['stay_id', 'itemid']
) }}

with source as (select * from {{ source("mimic_icu","chartevents") }}),

renamed as (
    select
        stay_id,
        cast(charttime as timestamp) as charttime,
        itemid,
        valuenum,
        valueuom
    from source
    where itemid in (
        220045, 220050, 220051, 220052, 220179, 220180,
        220181,
        225312,
        220210,
        224690,
        220277,
        223761,
        223762,
        220739,
        223900,
        223901
    )
)

select * from renamed

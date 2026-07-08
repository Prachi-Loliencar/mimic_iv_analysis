with source as (
    select * from {{ source("mimic_hosp","d_labitems") }}
),

renamed as (
    select itemid,
           label,
           fluid,
           category
        from source
)

select * from renamed
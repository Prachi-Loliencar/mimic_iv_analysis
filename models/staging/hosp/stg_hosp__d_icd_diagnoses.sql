with source as (select * from {{ source("mimic_hosp","d_icd_diagnoses") }}),

renamed as (
    select icd_code,
           icd_version,
           long_title
           from source
    )

select * from renamed
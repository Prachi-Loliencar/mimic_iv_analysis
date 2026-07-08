with source as (
    select * from {{ source("mimic_hosp","diagnoses_icd") }}
),

renamed as (
    select 
        subject_id,
        hadm_id,
        seq_num,
        icd_code,
        icd_version
    from source
)

select * from renamed

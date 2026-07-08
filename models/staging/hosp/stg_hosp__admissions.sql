with source as (select * from {{ source("mimic_hosp","admissions") }}),

renamed as (
    select
        subject_id,
        hadm_id,
        cast(admittime as timestamp) as admittime,
        cast(dischtime as timestamp) as dischtime,
        cast(deathtime as timestamp) as deathtime,
        admission_type,
        admission_location,
        discharge_location,
        edregtime,
        edouttime,
        insurance,
        race,
        marital_status,
        cast(hospital_expire_flag as integer) as hospital_expire_flag
    from source
)

select * from renamed

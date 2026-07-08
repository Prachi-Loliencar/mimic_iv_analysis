with source as (select * from {{ source("mimic_icu", "d_items") }}),
renamed as (
    select
        itemid,
        label,
        linksto,
        category,
        unitname,
        param_type,
        lownormalvalue,
        highnormalvalue 
        from source
)
select * from renamed

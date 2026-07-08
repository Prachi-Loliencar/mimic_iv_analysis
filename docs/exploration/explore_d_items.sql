select
        itemid,
        label,
        linksto,
        category,
        unitname,
        param_type,
        lownormalvalue as low_normal_value,
        highnormalvalue as low_normal_value
        from `physionet-data.mimiciv_3_1_icu.d_items`
where itemid in (220045, 220050, 220051, 220052, 220179, 220180,
                 220181, 225312, 220210, 224690, 220277, 223761, 223762,220739, 223900, 223901)
order by itemid

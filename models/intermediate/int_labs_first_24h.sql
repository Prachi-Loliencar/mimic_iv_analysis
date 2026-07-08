-- First-24h lab feature aggregates, one row per (stay_id, concept).
-- Per-analyte plausibility bounds in bounded_vals are sourced verbatim from
-- MIT-LCP mimic-code (chemistry.sql, enzyme.sql, coagulation.sql,
-- complete_blood_count.sql, bg.sql, cardiac_marker.sql). Three deviations
-- flagged in-line: pO2 > 0, base_excess in [-50, 50], wbc <= 1000.
-- See docs/concept_reference.md for the full filter table and rationale.

with labevents as (select * from {{ ref('stg_hosp__labevents') }}),

icustays as (select * from {{ ref('int_first_icu_stay') }}),

merged as (
    select
        i.hadm_id,
        i.stay_id,
        i.intime,
        l.itemid,
        l.charttime,
        l.valuenum
    from icustays as i inner join labevents as l
        on i.hadm_id = l.hadm_id
    where
        l.charttime < timestamp_add(i.intime, interval 24 hour)
        and l.charttime >= i.intime
        and l.valuenum is not null
),

items_named as (
    select
        stay_id,
        valuenum,
        case itemid
            when 50862 then 'albumin'
            when 50863 then 'alp'
            when 50861 then 'alt'
            when 50878 then 'ast'
            when 50802 then 'base_excess'
            when 50882 then 'bicarbonate'
            when 50885 then 'bilirubin'
            when 50893 then 'calcium'
            when 50902 then 'chloride'
            when 50912 then 'creatinine'
            when 50931 then 'glucose'
            when 51221 then 'hematocrit'
            when 51222 then 'hemoglobin'
            when 51237 then 'inr'
            when 50813 then 'lactate'
            when 50960 then 'magnesium'
            when 50818 then 'pco2'
            when 50820 then 'ph'
            when 50970 then 'phosphate'
            when 51265 then 'platelet'
            when 50821 then 'po2'
            when 50971 then 'potassium'
            when 51274 then 'pt'
            when 51275 then 'ptt'
            when 50983 then 'sodium'
            when 51003 then 'troponin'
            when 51006 then 'urea'
            when 51301 then 'wbc'
        end as concept
    from merged),

bounded_vals as (
    select 
        stay_id,
        concept,
        case 
             when concept = 'albumin' and valuenum > 0 and valuenum <= 10 then valuenum 
             when concept = 'alp' and valuenum > 0 then valuenum
             when concept = 'alt' and valuenum > 0 then valuenum 
             when concept = 'ast' and valuenum > 0 then valuenum
             when concept = 'base_excess' and valuenum >= -50 and valuenum <= 50 then valuenum --base_excess in [-50, 50] deviates from MIT-LCP,
             when concept = 'bicarbonate' and valuenum > 0 and valuenum <= 10000 then valuenum
             when concept = 'bilirubin' and valuenum > 0 then valuenum
             when concept = 'calcium' and valuenum > 0 and valuenum <= 10000 then valuenum
             when concept = 'chloride' and valuenum > 0 and valuenum <= 10000 then valuenum
             when concept = 'creatinine' and valuenum > 0 and valuenum <= 150 then valuenum
             when concept = 'glucose' and valuenum > 0 and valuenum <= 10000 then valuenum
             when concept = 'hematocrit' and valuenum > 0 then valuenum
             when concept = 'hemoglobin' and valuenum > 0 then valuenum
             when concept = 'lactate' and valuenum <= 10000 then valuenum
             when concept = 'magnesium' and valuenum > 0 then valuenum
             when concept = 'phosphate' and valuenum > 0 then valuenum
             when concept = 'platelet' and valuenum > 0 then valuenum
             when concept = 'po2' and valuenum > 0 then valuenum          -- pO2 > 0 deviates from MIT-LCP
             when concept = 'potassium' and valuenum > 0 and valuenum <= 30 then valuenum
             when concept = 'sodium' and valuenum > 0 and valuenum <= 200 then valuenum
             when concept = 'urea' and valuenum > 0 and valuenum <= 300 then valuenum
             when concept = 'wbc' and valuenum > 0 and valuenum <= 1000 then valuenum -- wbc <= 1000 deviates from MIT-LCP
             when concept in ('inr', 'ph', 'pco2', 'pt', 'ptt', 'troponin') then valuenum
             end as valuenum
             from items_named),



aggregates as (
    select
        stay_id,
        concept,
        count(valuenum) as n_measurements,
        avg(valuenum) as valuenum_mean,
        stddev_samp(valuenum) as valuenum_std,
        approx_quantiles(valuenum, 4) as quantile_array
    from bounded_vals
    where valuenum is not null
    group by stay_id, concept
)

select
    stay_id,
    concept,
    n_measurements,
    valuenum_mean,
    valuenum_std,
    quantile_array[safe_offset(0)] as valuenum_min,
    quantile_array[safe_offset(1)] as valuenum_q1,
    quantile_array[safe_offset(2)] as valuenum_median,
    quantile_array[safe_offset(3)] as valuenum_q3,
    quantile_array[safe_offset(4)] as valuenum_max
from aggregates
    

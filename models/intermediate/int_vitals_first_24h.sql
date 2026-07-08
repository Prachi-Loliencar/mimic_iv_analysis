-- First-24h vital feature aggregates, one row per (stay_id, concept).
-- Per-itemid plausibility bounds in bounded_vals are sourced verbatim from
-- MIT-LCP mimic-code vitalsign.sql (no deviations). Temperature °F is
-- filtered on the raw Fahrenheit scale in bounded_vals *before* conversion
-- to °C in combine_temps; reversing the order would let Fahrenheit data-entry
-- errors slip through (e.g. 950 -> 510 °C).
-- See docs/concept_reference.md for the full filter table, coalescing
-- rationale, and MIT-LCP citations.

with chartevents as (select * from {{ ref('stg_icu__chartevents') }}),

icu_stay as (select * from {{ ref('int_first_icu_stay') }}),

merged as (
    select
        i.stay_id,
        c.itemid,
        c.charttime,
        c.valuenum,
        i.intime
    from icu_stay as i inner join chartevents as c on i.stay_id = c.stay_id
    where
        c.charttime < timestamp_add(i.intime, interval 24 hour)
        and c.charttime >= i.intime
        and c.valuenum is not null
),


named_concepts as ( 
    select
    stay_id,
    valuenum,
    case 
        when itemid in (220052, 225312) then 'art_bp_mean'
        when itemid in (220210, 224690) then 'resp_rate'
        when itemid = 223761 then 'temp_f' 
        when itemid = 223762 then 'temp_c'
        when itemid = 220045 then 'heart_rate'
        when itemid = 220050 then 'art_bp_sys'
        when itemid = 220051 then 'art_bp_dia'
        when itemid = 220179 then 'nibp_sys'
        when itemid = 220180 then 'nibp_dia'
        when itemid = 220181 then 'nibp_mean'
        when itemid = 220277 then 'spo2'
        when itemid = 220739 then 'gcs_eye'
        when itemid = 223900 then 'gcs_verbal'
        when itemid = 223901 then 'gcs_motor'
    end as concept
    from merged
),

bounded_vals as (
    select 
    stay_id,
    concept,
    case 
        when concept = 'heart_rate' and valuenum > 0 and valuenum < 300 then valuenum
        when concept = 'art_bp_sys' and valuenum > 0 and valuenum < 400 then valuenum
        when concept = 'art_bp_dia' and valuenum > 0 and valuenum < 300 then valuenum
        when concept = 'art_bp_mean' and valuenum > 0 and valuenum < 300 then valuenum
        when concept = 'nibp_sys' and valuenum > 0 and valuenum < 400 then valuenum
        when concept = 'nibp_dia' and valuenum > 0 and valuenum < 300 then valuenum
        when concept = 'nibp_mean' and valuenum > 0 and valuenum < 300 then valuenum
        when concept = 'resp_rate' and valuenum > 0 and valuenum < 70 then valuenum
        when concept = 'spo2' and valuenum > 0 and valuenum <= 100 then valuenum
        when concept = 'temp_f' and valuenum > 70 and valuenum < 120 then valuenum
        when concept = 'temp_c' and valuenum > 10 and valuenum < 50 then valuenum
        when concept in ('gcs_eye', 'gcs_verbal', 'gcs_motor') then valuenum
    end as valuenum
    from named_concepts
),

combine_temps as (
    select 
    stay_id,
    case 
        when concept = 'temp_f' then (valuenum-32)*5/9 else valuenum
    end as valuenum,
    case
        when concept = 'temp_f' then 'temp_c' else concept
    end as concept 
    from bounded_vals
),

aggregates as (
    select
        stay_id,
        concept,
        count(valuenum) as n_measurements,
        avg(valuenum) as valuenum_mean,
        stddev_samp(valuenum) as valuenum_std,
        approx_quantiles(valuenum, 4) as quantile_array
    from combine_temps
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

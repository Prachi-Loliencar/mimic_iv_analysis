{% set stats = ['mean', 'std', 'min', 'q1', 'median', 'q3', 'max'] %}

{% set lab_concepts = [
    'albumin', 'alp', 'alt', 'ast', 'base_excess', 'bicarbonate',
    'bilirubin', 'calcium', 'chloride', 'creatinine', 'glucose',
    'hematocrit', 'hemoglobin', 'inr', 'lactate', 'magnesium',
    'pco2', 'ph', 'phosphate', 'platelet', 'po2', 'potassium',
    'pt', 'ptt', 'sodium', 'troponin', 'urea', 'wbc'
] %}

{% set vital_concepts = [
    'heart_rate', 'art_bp_sys', 'art_bp_dia', 'art_bp_mean', 'nibp_sys', 
    'nibp_dia', 'nibp_mean', 'resp_rate', 'spo2', 'temp_c', 'gcs_eye',
        'gcs_verbal', 'gcs_motor'
] %}


with first_icu_stays as (select * from {{ ref("int_first_icu_stay") }}),

admissions as (select * from {{ ref("stg_hosp__admissions") }}),

patients as (select * from {{ ref("stg_hosp__patients") }}),

vitals as (select * from {{ ref("int_vitals_first_24h") }}),

labs as (select * from {{ ref("int_labs_first_24h") }}),

age_computed as (
    select
        -- identifiers carried forward
        f.subject_id,
        f.hadm_id,
        f.stay_id,
        -- stay attributes needed downstream
        f.intime,
        f.first_careunit,
        f.last_careunit,
        -- patient attributes needed downstream
        p.gender,
        p.anchor_year,
        p.dod,
        -- newly computed here
        date_diff(date(f.intime), date(p.anchor_year, 1, 1), year)
        + p.anchor_age
            as age_at_intime
    from first_icu_stays as f
    inner join patients as p on f.subject_id = p.subject_id
),

cohort_spine as (
select
    -- carried from age_computed
    ac.subject_id,
    ac.hadm_id,
    ac.stay_id,
    ac.intime,
    ac.first_careunit,
    ac.last_careunit,
    ac.gender,
    ac.anchor_year,
    ac.dod,
    ac.age_at_intime,
    -- newly joined in from admissions
    a.dischtime,
    a.admission_type,
    a.admission_location,
    a.discharge_location,
    a.marital_status,
    a.race,
    a.insurance,
    a.hospital_expire_flag
from age_computed as ac
inner join
    admissions as a
    on ac.hadm_id = a.hadm_id and ac.subject_id = a.subject_id
where ac.age_at_intime >= 18
),

outcomes_cte as (
select
-- identifiers/foreign keys
subject_id,
hadm_id,
stay_id,
-- demographics
gender,
age_at_intime,
anchor_year,
marital_status,
race,
insurance,
-- hospital stay information
intime,
dischtime,
admission_type,
admission_location,
discharge_location,
first_careunit,
last_careunit,
-- outcome information
dod,
hospital_expire_flag = 1 as died_in_hospital,
date_diff(dod, date(intime), day) <= 30 as died_within_30d,
date_diff(dod, date(intime), day) <= 365 as died_within_1y
from cohort_spine
),

vitals_pivoted as (
select
stay_id
{% for concept in vital_concepts %}
    {% for stat in stats %}
        , max(
            case when concept = '{{ concept }}' then valuenum_{{ stat }} end
        )
            as {{ concept }}_{{ stat }},
    {% endfor %}
    , max(case when concept = '{{ concept }}' then n_measurements end)
        as {{ concept }}_n_measurements
{% endfor %}
from vitals
group by stay_id
),

labs_pivoted as (
select
stay_id
{% for concept in lab_concepts %}
    {% for stat in stats %}
        max(
            case when concept = '{{ concept }}' then valuenum_{{ stat }} end
        )
            as {{ concept }}_{{ stat }},
    {% endfor %}
    , max(case when concept = '{{ concept }}' then n_measurements end)
        as {{ concept }}_n_measurements
{% endfor %}
from labs
group by stay_id
),

final_merge as (
select *
from outcomes_cte
left join vitals_pivoted on outcomes_cte.stay_id = vitals_pivoted.stay_id
left join labs_pivoted using (stay_id)
)

select * from final_merge

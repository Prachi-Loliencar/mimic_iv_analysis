-- Care-unit case mix: how much of the dashboard's Mortality Rate Index is explained by admission type?
-- Query 1 output: docs/exploration/careunit_case_mix.csv
-- Query 2 (crude vs. admission-type-adjusted index) can be reproduced from that CSV alone.
-- "Planned" admissions = ELECTIVE + SURGICAL SAME DAY ADMISSION.


-- Query 1: mortality by care unit x admission type, with each type's share of the unit's stays
select
    first_careunit,
    admission_type,
    count(*)                                                        as n_stays,
    countif(died_in_hospital)                                       as deaths,
    round(safe_divide(countif(died_in_hospital), count(*)), 4)      as mortality_rate,
    round(count(*) / sum(count(*)) over (partition by first_careunit), 4) as share_of_unit
from `mimic-iv-2026.dbt_prachi.mart_icu_cohort`
group by first_careunit, admission_type
order by first_careunit, n_stays desc;


-- Query 2: crude index vs. admission-type-adjusted index (indirect standardization) per care unit
with cohort as (
    select
        first_careunit,
        coalesce(admission_type, 'UNKNOWN') as admission_type,
        died_in_hospital
    from `mimic-iv-2026.dbt_prachi.mart_icu_cohort`
),

overall as (
    select avg(cast(died_in_hospital as int64)) as cohort_rate
    from cohort
),

type_rates as (
    -- cohort-wide mortality for each admission type
    select
        admission_type,
        avg(cast(died_in_hospital as int64)) as type_rate
    from cohort
    group by admission_type
),

by_unit as (
    select
        c.first_careunit,
        count(*)                                     as n_stays,
        countif(c.died_in_hospital)                  as observed_deaths,
        sum(t.type_rate)                             as expected_deaths,
        avg(if(c.admission_type in ('ELECTIVE', 'SURGICAL SAME DAY ADMISSION'), 1, 0)) as pct_planned
    from cohort c
    join type_rates t using (admission_type)
    group by c.first_careunit
)

select
    first_careunit,
    n_stays,
    n_stays >= 900                                                as shown_on_dashboard,
    round(pct_planned, 3)                                         as pct_planned,
    observed_deaths,
    round(expected_deaths, 1)                                     as expected_deaths,
    round(observed_deaths / n_stays, 4)                           as crude_rate,
    round(observed_deaths / n_stays / o.cohort_rate, 2)           as crude_index,     -- matches the dashboard
    round(expected_deaths / n_stays / o.cohort_rate, 2)           as expected_index,  -- index predicted by admission-type mix alone
    round(safe_divide(observed_deaths, expected_deaths), 2)       as adjusted_index   -- standardized mortality ratio
from by_unit
cross join overall o
order by crude_index;

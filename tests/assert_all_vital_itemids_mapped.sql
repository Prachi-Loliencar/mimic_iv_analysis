-- Fails if stg_icu__chartevents ever contains an itemid not covered by the
-- concept CASE mapping in int_vitals_first_24h. Keep this list in sync with
-- that CASE statement (see docs/exploration/concept_reference.md).
select distinct itemid
from {{ ref('stg_icu__chartevents') }}
where itemid not in (
    220052, 225312, 220210, 224690, 223761, 223762, 220045,
    220050, 220051, 220179, 220180, 220181, 220277,
    220739, 223900, 223901
)

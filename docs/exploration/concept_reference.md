# Concept reference

> Canonical record of the analytical concepts flowing through this pipeline: which itemids are filtered into each staging model, how those itemids map onto clinical concepts in the intermediate layer, and what plausibility bounds are applied before aggregation. The itemid filter can be found in `models/staging/hosp/stg_hosp__labevents.sql` and `models/staging/icu/stg_icu__chartevents.sql`; the concept mapping and plausibility bounds are in `models/intermediate/int_labs_first_24h.sql` and `models/intermediate/int_vitals_first_24h.sql`. The reasoning behind all of it is detailed here.

Two panels, labs (`stg_hosp__labevents`) and vitals (`stg_icu__chartevents`), are documented in parallel. The former was sourced using a bottom-up regex candidate discovery, while the latter uses top-down concept sourcing from the MIT-LCP `mimic-code` reference implementation for vitals. Both use MIT-LCP-derived plausibility filters at the intermediate layer, following the "reject data-entry errors, preserve extreme-but-real physiology" philosophy explained below. Cross-cutting materialization, cost, and tooling notes are presented at the end.

## Plausibility filter philosophy

Plausibility bounds are applied at the **intermediate layer**, not staging, keeping staging a faithful representation of source since value sanitization is a feature-engineering decision.

The bounds themselves follow the MIT-LCP `mimic-code` convention: **reject values consistent with data-entry errors (negatives, absurd magnitudes like glucose = 23,200 or creatinine = 808), preserve extreme-but-real physiology.** Tight clinical bounds would throw away real prognostic signal; for example, a creatinine of 50 mg/dL in dialysis-dependent renal failure or a lactate of 25 mmol/L in septic shock is not noise, it is exactly the kind of severity the mortality model needs to see. MIT-LCP's bounds on `chemistry.sql` (creatinine ≤ 150, glucose ≤ 10,000, sodium ≤ 200) reflect this.

**MIT-LCP is inconsistent across concept files in how strictly it filters.** `chemistry.sql` and `bg.sql` apply per-analyte bounds; `enzyme.sql` and `complete_blood_count.sql` apply only a global `valuenum > 0`; `coagulation.sql` and `cardiac_marker.sql` apply no filters beyond `NOT NULL`. Where MIT-LCP publishes a filter for a given itemid, this pipeline adopts it verbatim. Where MIT-LCP applies only the global `> 0` rule, we do the same. Where MIT-LCP applies nothing but the pipeline's own `d_labitems` exploration surfaced physically impossible values (negative pO2, base excess of -414, WBC of 12,500), we add a minimal defensible filter and flag it as an explicit **deviation from MIT-LCP**. The deviations are documented per-analyte below.

Citation for the MIT-LCP concept files, used throughout this document:

> Johnson AEW, Stone DJ, Celi LA, Pollard TJ. The MIMIC Code Repository: enabling reproducibility in critical care research. *Journal of the American Medical Informatics Association* 25(1):32–39, 2018.
> Repository: <https://github.com/MIT-LCP/mimic-code> (MIT License).

---

## Labs `stg_hosp__labevents`

### Scope

ICU labs panel for the mortality cohort. Markers are anchored in the SOFA / APACHE II / SAPS II severity scores plus standard ICU bloodwork. Population is adult first-ICU-stay patients with stays ≥ 24 hours.

**Final panel size:** 28 itemids, one canonical itemid per analyte.

### Selection methodology

Two-pass exploration:

1. **Pass 1 — `d_labitems` candidate discovery.** Word-boundary regex match (`REGEXP_CONTAINS` with `\b...\b`) against `label`, filtered to `fluid = 'Blood'`. Produces the catalog of candidate itemids per marker. SQL: `docs/exploration/find_item_id_for_lab_concept.sql`. Output: `docs/exploration/find_item_id_for_lab_concept.csv`.

2. **Pass 2 — `labevents` row counts and value distributions.** Aggregate the candidate itemids surfaced in Pass 1, then join back to `d_labitems` for labels. Canonical itemid per analyte = the one with row counts in the millions; 52xxx/53xxx low-volume secondary feeds are dropped. Value distributions (mean, p25, p75) cross-check against clinical reference ranges to confirm the right analyte. SQL: `docs/exploration/explore_d_labitems.sql`. Output: `docs/exploration/explore_d_labitems.csv`.

The "high-volume canonical itemid" rule reflects routine-care measurement where an analyte drawn on a daily metabolic panel for every ICU patient will accumulate millions of rows across the MIMIC-IV cohort, while event-driven or alternative-feed itemids land in the hundreds or low thousands.

### Final panel

#### Renal

| itemid | label | category | n_rows | notes |
|---|---|---|---|---|
| 50912 | Creatinine | Chemistry | 4,319,091 | |
| 51006 | Urea Nitrogen | Chemistry | 4,202,807 | BUN |

#### Hematology — CBC

| itemid | label | category | n_rows | notes |
|---|---|---|---|---|
| 51222 | Hemoglobin | Hematology | 4,181,121 | |
| 51221 | Hematocrit | Hematology | 4,331,615 | |
| 51301 | White Blood Cells | Hematology | 4,157,284 | |
| 51265 | Platelet Count | Hematology | 4,214,048 | |

#### Hematology — Coagulation

| itemid | label | category | n_rows | notes |
|---|---|---|---|---|
| 51237 | INR(PT) | Hematology | 1,783,315 | Filed under INR; clinically interpreted standardized ratio |
| 51274 | PT | Hematology | 1,782,642 | Raw prothrombin time |
| 51275 | PTT | Hematology | 1,637,800 | |

#### Electrolytes & metabolic

| itemid | label | category | n_rows | notes |
|---|---|---|---|---|
| 50983 | Sodium | Chemistry | 4,111,289 | |
| 50971 | Potassium | Chemistry | 4,149,507 | |
| 50902 | Chloride | Chemistry | 4,055,101 | Needed for anion-gap calculation |
| 50882 | Bicarbonate | Chemistry | 3,934,240 | |
| 50931 | Glucose | Chemistry | 3,621,769 | |
| 50893 | Calcium, Total | Chemistry | 2,969,588 | Total Ca; ionized Ca (50808) deliberately excluded |
| 50960 | Magnesium | Chemistry | 2,933,221 | |
| 50970 | Phosphate | Chemistry | 2,814,319 | |

#### Acid–base & oxygenation (Blood Gas)

| itemid | label | category | n_rows | notes |
|---|---|---|---|---|
| 50813 | Lactate | Blood Gas | 670,016 | Perfusion / sepsis marker |
| 50820 | pH | Blood Gas | 754,141 | |
| 50821 | pO2 | Blood Gas | 698,483 | For PaO2/FiO2 ratio (SOFA respiratory) |
| 50818 | pCO2 | Blood Gas | 698,217 | |
| 50802 | Base Excess | Blood Gas | 698,337 | |

#### Liver

| itemid | label | category | n_rows | notes |
|---|---|---|---|---|
| 50885 | Bilirubin, Total | Chemistry | 1,605,452 | SOFA liver component |
| 50878 | Asparate Aminotransferase (AST) | Chemistry | 1,793,910 | |
| 50861 | Alanine Aminotransferase (ALT) | Chemistry | 1,826,612 | |
| 50863 | Alkaline Phosphatase | Chemistry | 1,602,599 | |
| 50862 | Albumin | Chemistry | 1,032,456 | Strong mortality predictor |

#### Cardiac

| itemid | label | category | n_rows | notes |
|---|---|---|---|---|
| 51003 | Troponin T | Chemistry | 459,872 | Event-driven; lower coverage than routine labs |

### Notable exclusions

#### Wrong-analyte collisions (caught at Pass 1)

| itemid | label | why excluded |
|---|---|---|
| 50852 | % Hemoglobin A1c | Glycemic control marker, not anemia hemoglobin. Substring collision on "hemoglobin". |
| 50954 | Lactate Dehydrogenase (LD) | Cell-turnover/hemolysis marker, not tissue-perfusion lactate. Substring collision on "lactate". |

#### Low-volume secondary feeds (caught at Pass 2)

52xxx/53xxx itemids with matching labels but row counts in the hundreds/low thousands relative to the canonical itemid:

- Creatinine: 52546
- Urea Nitrogen: 52647
- Sodium: 52623
- Potassium: 52610
- Chloride: 52535
- Glucose: 52569
- Bilirubin, Total: 53089
- Albumin: 53085, 53138
- Alkaline Phosphatase: 53086
- PT: 52921
- PTT: 52923
- Lactate (Blood Gas duplicate): 52442
- Hemoglobin: 51640
- WBC: 51755, 51756

Full row counts in `docs/exploration/explore_d_labitems.csv`.

#### Deliberate category exclusions

- **Blood Gas electrolytes** (Na, K, Cl, glucose from gas analyzer). Excluded in favor of Chemistry due to higher precision, broader coverage (routine BMP vs. event-driven gas), and because it matches the reference values used by published severity scores.
- **Ionized Calcium** (50808, Blood Gas). Excluded; Total Calcium (50893) selected as the simpler v1 pick.

### Plausibility filters

Applied at the intermediate layer (`int_labs_first_24h`), not staging. Bounds are sourced from the corresponding MIT-LCP `mimic-code` concept file for each analyte category and adopted verbatim; the "reject data-entry errors, preserve extreme-but-real physiology" philosophy is discussed at the [top of this document](#plausibility-filter-philosophy).

#### Quick reference

Filter per itemid, sorted alphabetically by concept name (matches the `CASE` order in `int_labs_first_24h`). "None" = only the `NOT NULL` exclusion (already applied at the intermediate join). Deviations from MIT-LCP are flagged in **bold**.

| itemid | concept | filter to apply | MIT-LCP filter (source) | reason if different |
|---|---|---|---|---|
| 50862 | `albumin` | `valuenum > 0 AND valuenum <= 10` | same (chemistry.sql) | — |
| 50863 | `alp` | `valuenum > 0` | same (enzyme.sql global) | — |
| 50861 | `alt` | `valuenum > 0` | same (enzyme.sql global) | — |
| 50878 | `ast` | `valuenum > 0` | same (enzyme.sql global) | — |
| 50802 | `base_excess` | `valuenum >= -50 AND valuenum <= 50` | none (bg.sql) | **Deviation:** observed min -414 (impossible; physiological range ~±30) |
| 50882 | `bicarbonate` | `valuenum > 0 AND valuenum <= 10000` | same (chemistry.sql) | — |
| 50885 | `bilirubin` | `valuenum > 0` | same (enzyme.sql global) | — |
| 50893 | `calcium` | `valuenum > 0 AND valuenum <= 10000` | same (chemistry.sql) | — |
| 50902 | `chloride` | `valuenum > 0 AND valuenum <= 10000` | same (chemistry.sql) | — |
| 50912 | `creatinine` | `valuenum > 0 AND valuenum <= 150` | same (chemistry.sql) | — |
| 50931 | `glucose` | `valuenum > 0 AND valuenum <= 10000` | same (chemistry.sql) | — |
| 51221 | `hematocrit` | `valuenum > 0` | same (complete_blood_count.sql global) | — |
| 51222 | `hemoglobin` | `valuenum > 0` | same (complete_blood_count.sql global) | — |
| 51237 | `inr` | none | none (coagulation.sql) | — |
| 50813 | `lactate` | `valuenum <= 10000` | same (bg.sql) | — |
| 50960 | `magnesium` | `valuenum > 0` | not published for this itemid | Adopted global `> 0` rule from enzyme / CBC files as default; not covered by chemistry.sql |
| 50818 | `pco2` | none | none (bg.sql) | — |
| 50820 | `ph` | none | none (bg.sql) | — |
| 50970 | `phosphate` | `valuenum > 0` | not published for this itemid | Same as magnesium |
| 51265 | `platelet` | `valuenum > 0` | same (complete_blood_count.sql global) | — |
| 50821 | `po2` | `valuenum > 0` | none (bg.sql) | **Deviation:** observed min -32 (impossible; partial pressure cannot be negative) |
| 50971 | `potassium` | `valuenum > 0 AND valuenum <= 30` | same (chemistry.sql) | — |
| 51274 | `pt` | none | none (coagulation.sql) | — |
| 51275 | `ptt` | none | none (coagulation.sql) | — |
| 50983 | `sodium` | `valuenum > 0 AND valuenum <= 200` | same (chemistry.sql) | — |
| 51003 | `troponin` | none | none (cardiac_marker.sql) | — |
| 51006 | `urea` | `valuenum > 0 AND valuenum <= 300` | same (chemistry.sql) | — |
| 51301 | `wbc` | `valuenum > 0 AND valuenum <= 1000` | `valuenum > 0` (complete_blood_count.sql global) | **Deviation:** observed max 12,500 (impossible; physiological max ~500 in extreme leukemia) |

Three deviations from MIT-LCP total (pO2, base excess, WBC — see table above for rationale). Filters are sourced from MIT-LCP's `chemistry.sql`, `enzyme.sql`, `coagulation.sql`, `complete_blood_count.sql`, `bg.sql`, and `cardiac_marker.sql` (all in [`mimic-iv/concepts_postgres/measurement/`](https://github.com/MIT-LCP/mimic-code/tree/main/mimic-iv/concepts_postgres/measurement)).

#### Implementation status

Implemented. All 28 lab itemids are filtered in the `bounded_vals` CTE of `int_labs_first_24h`, matching the quick-reference table above verbatim.

### Column selection

Kept: `labevent_id`, `subject_id`, `hadm_id`, `specimen_id`, `itemid`, `charttime`, `storetime`, `valuenum`, `valueuom`, `ref_range_lower`, `ref_range_upper`, `priority`.

Dropped: `value` (raw string, redundant with `valuenum`), `flag` (source-system abnormality flag, regenerate downstream from `valuenum` vs. `ref_range_lower/upper` if needed), `comments` (free-text, sparse, not used in cohort analysis).

`priority` kept deliberately: distinguishes `STAT` from `ROUTINE` orders, an independent predictive signal.

---

## Vitals — `stg_icu__chartevents`

### Scope

Standard ICU vital-signs panel: hemodynamics (heart rate, arterial and non-invasive blood pressures), respiration (rate, SpO2), temperature, and Glasgow Coma Scale (GCS) components. Panel is anchored in the same clinical severity scores that inform the labs panel (SOFA / APACHE II/III / SAPS II/III / OASIS), and mirrors the itemid set used by MIT-LCP's canonical MIMIC-IV derived concepts.

**Final panel size:** 16 itemids across 13 clinical concepts (Fahrenheit + Celsius temperature coalesced; two arterial-BP-mean itemids coalesced; two respiratory-rate itemids coalesced).

### Selection methodology

Different from the labs approach: rather than a bottom-up two-pass exploration, the vitals panel was sourced top-down from the [MIT-LCP `mimic-code` repository](https://github.com/MIT-LCP/mimic-code) — the community-standard reference implementation for MIMIC-IV derived concepts, maintained by the group that produced the dataset itself.

- **Hemodynamics, respiration, temperature.** Sourced from [`mimic-iv/concepts_postgres/measurement/vitalsign.sql`](https://github.com/MIT-LCP/mimic-code/blob/main/mimic-iv/concepts_postgres/measurement/vitalsign.sql).
- **GCS components.** Sourced from [`mimic-iv/concepts_postgres/measurement/gcs.sql`](https://github.com/MIT-LCP/mimic-code/blob/main/mimic-iv/concepts_postgres/measurement/gcs.sql).
- **Validation against `d_items`.** Sourced itemids were validated against `mimiciv_3_1_icu.d_items` for label, category, unit, and `param_type` before hard-coding into staging. SQL: `docs/exploration/explore_d_items.sql`. Output: `docs/exploration/explore_d_items.csv`.

**MetaVision-only.** All selected itemids are in the MetaVision 220xxx–225xxx range. MIMIC-IV's ICU capture is MetaVision-only — the CareVue itemids that appear in some MIMIC-III literature (e.g. HR `211`, GCS-Verbal `723`, GCS-Motor `454`, GCS-Eyes `184`) are not present in MIMIC-IV and require no coalescing.

### Final panel

#### Hemodynamics

| itemid | label | category | unit | notes |
|---|---|---|---|---|
| 220045 | Heart Rate | Routine Vital Signs | bpm | |
| 220050 | Arterial Blood Pressure systolic | Routine Vital Signs | mmHg | Primary invasive ART sys |
| 220051 | Arterial Blood Pressure diastolic | Routine Vital Signs | mmHg | Primary invasive ART dia |
| 220052 | Arterial Blood Pressure mean | Routine Vital Signs | mmHg | Primary invasive ART mean; coalesced with 225312 |
| 220179 | Non Invasive Blood Pressure systolic | Routine Vital Signs | mmHg | |
| 220180 | Non Invasive Blood Pressure diastolic | Routine Vital Signs | mmHg | |
| 220181 | Non Invasive Blood Pressure mean | Routine Vital Signs | mmHg | |
| 225312 | ART BP Mean | Routine Vital Signs | mmHg | Alternate invasive ART mean; coalesced with 220052 |

#### Respiration

| itemid | label | category | unit | notes |
|---|---|---|---|---|
| 220210 | Respiratory Rate | Respiratory | insp/min | Primary spontaneous rate |
| 224690 | Respiratory Rate (Total) | Respiratory | insp/min | Ventilator-derived total rate; coalesced with 220210 |
| 220277 | O2 saturation pulseoxymetry (SpO2) | Respiratory | % | Peripheral pulse oximetry |

#### Temperature

| itemid | label | category | unit | notes |
|---|---|---|---|---|
| 223761 | Temperature Fahrenheit | Routine Vital Signs | °F | Converted to °C at intermediate before aggregation |
| 223762 | Temperature Celsius | Routine Vital Signs | °C | |

#### Neurological (GCS)

| itemid | label | category | unit | notes |
|---|---|---|---|---|
| 220739 | GCS - Eye Opening | Neurological | (score) | 1–4 |
| 223900 | GCS - Verbal Response | Neurological | (score) | 1–5; see ETT note below |
| 223901 | GCS - Motor Response | Neurological | (score) | 1–6 |

`param_type = Text` on the three GCS itemids describes the caregiver's *entry* mechanism (selecting a categorical label), not what is stored — the clinical system stores both the text label and its corresponding numeric score. Coverage verified: `valuenum` is populated for 100% of rows on all three GCS itemids.

### Coalescing (deferred to intermediate)

Three coalesce operations happen in `int_vitals_first_24h`, not staging:

- **Temperature.** 223761 (°F) is converted to °C via `(valuenum − 32) × 5/9`, then combined with 223762 (°C) under a single `temp_c` concept. Conversion happens on raw values *before* aggregation.
- **Arterial BP mean.** 220052 (primary MetaVision) and 225312 (alternate) coalesced to a single `art_bp_mean` concept. MIT-LCP's `vitalsign.sql` groups these with NIBP mean (220181) as `mbp`; this project keeps NIBP mean separate since invasive-vs-noninvasive is prognostically meaningful.
- **Respiratory rate.** 220210 (primary) and 224690 (Total, ventilator-derived) coalesced to a single `resp_rate` concept, matching `vitalsign.sql`'s treatment.

### Notable exclusions

Departures from MIT-LCP's `vitalsign.sql`:

- **Glucose** (chartevents itemids `225664`, `220621`, `226537`). MIT-LCP includes these in `vitalsign.sql`; this project sources glucose from `labevents` (`50931`) instead, for broader coverage and higher precision.
- **ART BP Systolic/Diastolic alt** (`225309`, `225310`). MetaVision alternates to the primary invasive ART sys/dia; excluded from v1 for simplicity.
- **CareVue vitals** (e.g. `211` HR, `442` NIBP sys, `723` GCS-Verbal). MIMIC-III-only itemids, not present in MIMIC-IV; no coalescing required.

### Plausibility filters

Applied at the intermediate layer (`int_vitals_first_24h`), not staging. All bounds are sourced verbatim from [`mimic-iv/concepts_postgres/measurement/vitalsign.sql`](https://github.com/MIT-LCP/mimic-code/blob/main/mimic-iv/concepts_postgres/measurement/vitalsign.sql).

#### Quick reference

Filter per itemid, grouped by category (hemodynamics → respiration → temperature → GCS). "None" = only the `NOT NULL` exclusion (already applied at the intermediate join).

| itemid | concept | filter to apply | MIT-LCP filter (source) | reason if different |
|---|---|---|---|---|
| 220045 | `heart_rate` | `valuenum > 0 AND valuenum < 300` | same (vitalsign.sql) | — |
| 220050 | `art_bp_sys` | `valuenum > 0 AND valuenum < 400` | same (vitalsign.sql, SBP group) | — |
| 220051 | `art_bp_dia` | `valuenum > 0 AND valuenum < 300` | same (vitalsign.sql, DBP group) | — |
| 220052 | `art_bp_mean` | `valuenum > 0 AND valuenum < 300` | same (vitalsign.sql, MBP group) | — |
| 220179 | `nibp_sys` | `valuenum > 0 AND valuenum < 400` | same (vitalsign.sql, SBP group) | — |
| 220180 | `nibp_dia` | `valuenum > 0 AND valuenum < 300` | same (vitalsign.sql, DBP group) | — |
| 220181 | `nibp_mean` | `valuenum > 0 AND valuenum < 300` | same (vitalsign.sql, MBP group) | — |
| 225312 | `art_bp_mean` (coalesced with 220052) | `valuenum > 0 AND valuenum < 300` | same (vitalsign.sql, MBP group) | — |
| 220210 | `resp_rate` | `valuenum > 0 AND valuenum < 70` | same (vitalsign.sql) | — |
| 224690 | `resp_rate` (coalesced with 220210) | `valuenum > 0 AND valuenum < 70` | same (vitalsign.sql) | — |
| 220277 | `spo2` | `valuenum > 0 AND valuenum <= 100` | same (vitalsign.sql) | — |
| 223761 | `temp_c` (from Fahrenheit) | `valuenum > 70 AND valuenum < 120` on raw °F, then `(valuenum − 32) × 5/9` | same (vitalsign.sql) | Order matters: filter first, convert second |
| 223762 | `temp_c` (direct Celsius) | `valuenum > 10 AND valuenum < 50` | same (vitalsign.sql) | — |
| 220739 | `gcs_eye` | none | none (vitalsign.sql / gcs.sql) | Ordinal scale enforced by source-capture semantics |
| 223900 | `gcs_verbal` | none | none (vitalsign.sql / gcs.sql) | Same |
| 223901 | `gcs_motor` | none | none (vitalsign.sql / gcs.sql) | Same |

Zero deviations from MIT-LCP — the entire vitals panel adopts `vitalsign.sql` verbatim.

Note: temperature filtering order is load-bearing — the filter must run against the raw °F `valuenum` before the `(valuenum − 32) × 5/9` conversion, matching MIT-LCP's own pattern in `vitalsign.sql`, otherwise Fahrenheit data-entry errors can convert into a plausible-looking °C value.

#### Implementation status

Implemented. `int_vitals_first_24h` applies all 16 filters in `bounded_vals`, matching the quick-reference table above verbatim, with temperature filtered in the correct order (raw °F bounded first, then converted).

### Column selection

Kept: `stay_id`, `charttime`, `itemid`, `valuenum`, `valueuom`.

Dropped:
- `value` (raw string) — verified safe to drop via coverage check on the three GCS itemids (220739, 223900, 223901, the only itemids in the panel flagged `param_type = Text`), which have `valuenum` populated in 100% of rows (2.2M+ each). Caveat: this conclusion is itemid-list-specific — re-run the coverage check before assuming `value` is droppable if the panel is extended. Note: MIT-LCP's `gcs.sql` uses `value = 'No Response-ETT'` to reassign `valuenum` → 0 for intubated patients; dropping `value` means the raw stored valuenum is used instead of this reassignment.
- `storetime` — rarely used downstream; dropped here for cost savings given `chartevents`' much larger row count relative to `stg_hosp__labevents`.

---

## References

**Peer-reviewed citation for the MIT-LCP `mimic-code` repository:**

> Johnson AEW, Stone DJ, Celi LA, Pollard TJ. The MIMIC Code Repository: enabling reproducibility in critical care research. *Journal of the American Medical Informatics Association* 25(1):32–39, 2018. [DOI: 10.1093/jamia/ocx084](https://doi.org/10.1093/jamia/ocx084)

**Peer-reviewed citation for the MIMIC-IV dataset:**

> Johnson AEW, Bulgarelli L, Shen L, et al. MIMIC-IV, a freely accessible electronic health record dataset. *Scientific Data* 10, 1 (2023).

**Repository and specific concept files consulted:**

- MIT-LCP `mimic-code` repository (MIT License): <https://github.com/MIT-LCP/mimic-code>
- [`concepts_postgres/measurement/vitalsign.sql`](https://github.com/MIT-LCP/mimic-code/blob/main/mimic-iv/concepts_postgres/measurement/vitalsign.sql) — reference vitals pivot (hemodynamics, respiration, temperature, glucose)
- [`concepts_postgres/measurement/gcs.sql`](https://github.com/MIT-LCP/mimic-code/blob/main/mimic-iv/concepts_postgres/measurement/gcs.sql) — GCS component pivot with ETT special-case handling
- [`concepts_postgres/measurement/chemistry.sql`](https://github.com/MIT-LCP/mimic-code/blob/main/mimic-iv/concepts_postgres/measurement/chemistry.sql) — chemistry labs pivot with plausibility filters
- [`concepts_postgres/measurement/enzyme.sql`](https://github.com/MIT-LCP/mimic-code/blob/main/mimic-iv/concepts_postgres/measurement/enzyme.sql) — liver enzymes pivot (AST, ALT, ALP, bilirubin)
- [`concepts_postgres/measurement/coagulation.sql`](https://github.com/MIT-LCP/mimic-code/blob/main/mimic-iv/concepts_postgres/measurement/coagulation.sql) — coagulation markers pivot (INR, PT, PTT)
- [`concepts_postgres/measurement/complete_blood_count.sql`](https://github.com/MIT-LCP/mimic-code/blob/main/mimic-iv/concepts_postgres/measurement/complete_blood_count.sql) — CBC pivot (hemoglobin, hematocrit, WBC, platelet)
- [`concepts_postgres/measurement/bg.sql`](https://github.com/MIT-LCP/mimic-code/blob/main/mimic-iv/concepts_postgres/measurement/bg.sql) — blood gas pivot (lactate, pH, pO2, pCO2, base excess)
- [`concepts_postgres/measurement/cardiac_marker.sql`](https://github.com/MIT-LCP/mimic-code/blob/main/mimic-iv/concepts_postgres/measurement/cardiac_marker.sql) — cardiac markers pivot (troponin)

Each intermediate-layer plausibility filter in this project is sourced from the corresponding file above and adopted verbatim, with citation in the model header comment.

{# Approximate quartile k (1, 2 or 3) of col.
   BigQuery: same approx_quantiles call as before, so full-data quartiles are unchanged.
   Snowflake: approx_percentile (t-digest), so values can differ slightly between warehouses. #}
{% macro approx_quartile(col, k) %}
  {{ return(adapter.dispatch('approx_quartile')(col, k)) }}
{% endmacro %}

{% macro bigquery__approx_quartile(col, k) %}
  approx_quantiles({{ col }}, 4)[safe_offset({{ k }})]
{% endmacro %}

{% macro snowflake__approx_quartile(col, k) %}
  approx_percentile({{ col }}, {{ k / 4 }})
{% endmacro %}

{% macro default__approx_quartile(col, k) %}
  percentile_cont({{ k / 4 }}) within group (order by {{ col }})
{% endmacro %}

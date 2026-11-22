{# Add n hours to a timestamp column, keeping the TIMESTAMP type.
   dbt.dateadd is not used here: on BigQuery it casts to DATETIME, and
   comparing a TIMESTAMP (charttime) with a DATETIME fails on BigQuery. #}
{% macro add_hours(ts, n) %}
  {{ return(adapter.dispatch('add_hours')(ts, n)) }}
{% endmacro %}

{% macro bigquery__add_hours(ts, n) %}
  timestamp_add({{ ts }}, interval {{ n }} hour)
{% endmacro %}

{% macro default__add_hours(ts, n) %}
  dateadd(hour, {{ n }}, {{ ts }})
{% endmacro %}

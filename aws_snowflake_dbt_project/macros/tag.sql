{% macro tag(column) %}
    CASE
    WHEN price_per_night < 100 THEN 'LOW'
    WHEN price_per_night >= 100 AND price_per_night < 200 THEN 'MEDIUM'
    ELSE 'HIGH'
    END AS price_per_night_tag
{% endmacro %}
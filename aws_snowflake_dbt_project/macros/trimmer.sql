{% macro trimmer(column, node) %}
    {{ col_name | trim | upper }}
{% endmacro %}
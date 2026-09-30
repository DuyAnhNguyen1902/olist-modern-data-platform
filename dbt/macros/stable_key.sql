{% macro stable_key(sql_expression) -%}
    (
        ('x' || substr(md5(coalesce(cast({{ sql_expression }} as text), '_dbt_null_')), 1, 15))
        ::bit(60)::bigint
    )
{%- endmacro %}

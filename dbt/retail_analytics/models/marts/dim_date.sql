-- Date dimension covering the full Olist order date range
with date_spine as (
    select
        unnest(
            generate_series(
                date '2016-09-01',
                date '2018-10-01',
                interval '1 day'
            )
        )::date as date_day
),

final as (
    select
        date_day,
        extract(year  from date_day)::int  as year,
        extract(month from date_day)::int  as month_num,
        strftime(date_day, '%B')           as month_name,
        extract(quarter from date_day)::int as quarter,
        extract(dow from date_day)::int    as day_of_week,
        strftime(date_day, '%A')           as day_name,
        date_trunc('month', date_day)::date as month_start,
        case when extract(dow from date_day) in (0, 6)
             then true else false end       as is_weekend

    from date_spine
)

select * from final
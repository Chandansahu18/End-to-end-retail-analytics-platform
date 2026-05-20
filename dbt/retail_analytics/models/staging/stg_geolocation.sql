-- Aggregate to one lat/long per zip — raw has ~52 entries per zip
with source as (
    select * from {{ source('raw', 'geolocation') }}
),

aggregated as (
    select
        lpad(cast(geolocation_zip_code_prefix as varchar), 5, '0') as zip_code_prefix,
        round(avg(geolocation_lat), 6) as latitude,
        round(avg(geolocation_lng), 6) as longitude

    from source
    group by geolocation_zip_code_prefix
)

select * from aggregated
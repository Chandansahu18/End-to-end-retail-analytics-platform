with source as (
    select * from {{ source('raw', 'events') }}
),

cleaned as (
    select
        visitorid as visitor_id,
        lower(trim(event)) as event_type,
        itemid as item_id,
        cast(event_datetime as timestamp) as event_datetime,
        cast(event_datetime as date) as event_date

    from source
)

select * from cleaned
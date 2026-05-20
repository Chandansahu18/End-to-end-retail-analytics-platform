with source as (
    select * from {{ source('raw', 'order_reviews') }}
),

cleaned as (
    select
        review_id,
        order_id,
        review_score,
        review_comment_message,
        cast(review_answer_timestamp as timestamp) as review_answer_timestamp

        -- review_comment_title excluded — 88% null, not used in analysis
        -- review_creation_date excluded — internal Olist ops timestamp

    from source
)

select * from cleaned
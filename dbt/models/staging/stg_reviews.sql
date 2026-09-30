select
    trim(review_id) as review_id,
    trim(order_id) as order_id,
    nullif(review_score, '')::smallint as review_score,
    nullif(trim(review_comment_title), '') as review_comment_title,
    nullif(trim(review_comment_message), '') as review_comment_message,
    nullif(review_creation_date, '')::timestamp as review_creation_date,
    nullif(review_answer_timestamp, '')::timestamp as review_answer_timestamp,
    coalesce(source_updated_at, loaded_at) as record_updated_at
from {{ source('raw', 'reviews') }}

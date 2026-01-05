CREATE TABLE iceberg_namespace_properties (
    catalog_name VARCHAR(255) NOT NULL,
    namespace VARCHAR(255) NOT NULL,
    property_key VARCHAR(5500),
    property_value VARCHAR(5500),
    PRIMARY KEY (catalog_name, namespace, property_key)
);

CREATE TABLE iceberg_tables (
    catalog_name VARCHAR(255) NOT NULL,
    table_namespace VARCHAR(255) NOT NULL,
    table_name VARCHAR(255) NOT NULL,
    metadata_location VARCHAR(5500),
    previous_metadata_location VARCHAR(5500),
    PRIMARY KEY (catalog_name, table_namespace, table_name)
);

CREATE TABLE public.trn_customers (
  customer_id integer,
  customer_name varchar,
  country varchar,
  created_at timestamp
);

CREATE TABLE public.trn_orders (
  order_id integer,
  customer_id integer,
  order_ts timestamp,
  total_amount decimal(10,2)
);

CREATE TABLE public.trn_events (
  event_id bigint,
  user_id integer,
  event_time timestamp,
  event_name varchar
);

INSERT INTO public.trn_customers (customer_id, customer_name, country, created_at)
SELECT
  x AS customer_id,
  CONCAT('Customer ', CAST(x AS varchar)) AS customer_name,
  CASE (x % 6)
    WHEN 0 THEN 'DE'
    WHEN 1 THEN 'NL'
    WHEN 2 THEN 'FR'
    WHEN 3 THEN 'PL'
    WHEN 4 THEN 'ES'
    ELSE 'IT'
  END AS country,
  current_timestamp - INTERVAL '1' DAY * CAST(random() * 365 AS integer) AS created_at
FROM generate_series(1, 200) AS t(x);

INSERT INTO public.trn_orders (order_id, customer_id, order_ts, total_amount)
WITH c AS (
  SELECT customer_id, row_number() OVER (ORDER BY customer_id) AS rn
  FROM public.trn_customers
),
cnt AS (SELECT MAX(rn) AS n FROM c)
SELECT
  x AS order_id,
  c.customer_id,
  current_timestamp
    - INTERVAL '1' DAY * CAST(random() * 180 AS integer)
    - INTERVAL '1' MINUTE * CAST(random() * 1440 AS integer) AS order_ts,
  round( (10 + random() * 490)::numeric, 2 ) AS total_amount
FROM generate_series(1, 1000) AS t(x)
CROSS JOIN cnt
JOIN c ON c.rn = ((x - 1) % cnt.n) + 1;

INSERT INTO public.trn_events (event_id, user_id, event_time, event_name)
WITH o AS (
  SELECT
    order_id,
    customer_id AS user_id,
    order_ts,
    row_number() OVER (ORDER BY order_id) AS rn
  FROM public.trn_orders
),
funnel AS (
  SELECT CAST(rn*100+1 AS bigint), user_id,
         order_ts - INTERVAL '1' HOUR * CAST(1 + random()*48 AS integer), 'visit'
  FROM o
  UNION ALL
  SELECT CAST(rn*100+2 AS bigint), user_id,
         order_ts - INTERVAL '1' HOUR * CAST(1 + random()*24 AS integer), 'add_to_cart'
  FROM o WHERE rn % 5 != 0
  UNION ALL
  SELECT CAST(rn*100+3 AS bigint), user_id,
         order_ts + INTERVAL '1' HOUR * CAST(random()*12 AS integer), 'purchase'
  FROM o WHERE rn % 3 != 0
),
noise AS (
  SELECT
    CAST(1000000 + x AS bigint) AS event_id,
    1 + CAST(random() * 200 AS integer) AS user_id,
    current_timestamp - INTERVAL '1' DAY * CAST(random() * 30 AS integer)
                     - INTERVAL '1' MINUTE * CAST(random() * 1440 AS integer) AS event_time,
    'visit' AS event_name
  FROM generate_series(1, 3000) AS t(x)
)
SELECT * FROM funnel
UNION ALL
SELECT * FROM noise;

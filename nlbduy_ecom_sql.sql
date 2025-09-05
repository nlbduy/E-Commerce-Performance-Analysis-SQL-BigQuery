-- Query 1
SELECT  
      FORMAT_DATE('%Y%m', PARSE_DATE('%Y%m%d',date)) AS month
      , SUM(totals.visits) AS visits
      , SUM(totals.pageviews) AS pageviews
      , SUM(totals.transactions) AS transactions
FROM `bigquery-public-data.google_analytics_sample.ga_sessions_2017*`
WHERE _TABLE_SUFFIX BETWEEN '0101' AND '0331'
GROUP BY month
ORDER BY month ASC;

-- Query 2
WITH
prep AS( -- calculate total visit and total bounces by source
  SELECT  
        trafficSource.source AS source
        , COUNT(totals.visits) AS total_visits
        , COUNT(totals.bounces) AS total_no_of_bounces
  FROM `bigquery-public-data.google_analytics_sample.ga_sessions_201707*` -- filter data 07/2017
  GROUP BY trafficSource.source
)

SELECT -- calculate bounce_rate
      source
      , total_visits
      , total_no_of_bounces
      , ROUND(SAFE_DIVIDE(100*total_no_of_bounces,total_visits),3) AS bounce_rate
FROM prep
ORDER BY total_visits DESC;

-- Query 3
WITH
raw_data AS( -- prepare a base table with essential fields and preliminary metrics
  SELECT 
        PARSE_DATE('%Y%m%d', date) AS date
        , trafficSource.source AS source
        , productRevenue AS revenue
  FROM `bigquery-public-data.google_analytics_sample.ga_sessions_201706*`,
  UNNEST (hits),
  UNNEST (product)
  WHERE productRevenue IS NOT NULL
)

, month_revenue AS( -- calculate total revenue per source by month
  SELECT
        'Month' AS time_type
        , FORMAT_DATE('%Y%m', date) AS time
        , source
        , SUM(revenue)/1000000 AS total_revenue
  FROM raw_data
  GROUP BY time, source
)

, week_revenue AS( -- calculate total revenue per source by week
  SELECT
        'Week' AS time_type
        , FORMAT_DATE('%Y%W', date) AS time
        , source
        , SUM(revenue)/1000000 AS total_revenue
  FROM raw_data
  GROUP BY time, source
)

SELECT
      time_type
      , time
      , source
      , total_revenue
FROM month_revenue
UNION ALL
SELECT
      time_type
      , time
      , source
      , total_revenue			
FROM week_revenue
ORDER BY time_type, total_revenue DESC;

-- Query 4
WITH
pageview_per_visitor AS( -- calculate total pageviews per visitor per month
  SELECT
      FORMAT_DATE('%Y%m', PARSE_DATE('%Y%m%d', date)) AS month
      , fullVisitorId AS visitor_id
      , SUM(totals.pageviews) AS total_pageview -- total pageviews (not duplicated) for the session before unnesting
  FROM `bigquery-public-data.google_analytics_sample.ga_sessions_2017*`
  WHERE _TABLE_SUFFIX BETWEEN '0601' AND '0731'
  GROUP BY month, visitor_id
)

, purchaser AS( -- get a list of all visitors who made a purchase
  SELECT
      fullVisitorId AS visitor_id
  FROM `bigquery-public-data.google_analytics_sample.ga_sessions_2017*`,
  UNNEST(hits),
  UNNEST(product)
  WHERE _TABLE_SUFFIX BETWEEN '0601' AND '0731'
      AND totals.transactions >= 1 -- has at least one transaction
      AND productRevenue IS NOT NULL -- generated revenue
  GROUP BY visitor_id -- deduplicate visitor IDs
)

SELECT -- if p2.visitor_id is NOT NULL: is a purchaser; ELSE: is a non-purchaser
      month
      , AVG(CASE WHEN p2.visitor_id IS NOT NULL THEN total_pageview END) AS avg_pageviews_purchase
      , AVG(CASE WHEN p2.visitor_id IS NULL THEN total_pageview END) AS avg_pageviews_non_purchase
FROM pageview_per_visitor AS p1
LEFT JOIN purchaser AS p2
  ON p1.visitor_id = p2.visitor_id
GROUP BY month
ORDER BY month;

-- Query 5
WITH
trans_per_visitor AS( -- list of visitors (including purchaser and non purchaser) in 7/2017
  SELECT
        FORMAT_DATE('%Y%m', PARSE_DATE('%Y%m%d', date)) AS month
        , fullVisitorId AS visitor_id
        , totals.transactions AS trans -- num of transactions for each visit of each visitor
  FROM `bigquery-public-data.google_analytics_sample.ga_sessions_201707*`
) 

, purchaser AS( -- get a list of visitors who made a purchase
  SELECT
        fullVisitorId AS visitor_id
  FROM `bigquery-public-data.google_analytics_sample.ga_sessions_201707*`,
  UNNEST(hits),
  UNNEST(product)
  WHERE totals.transactions >= 1 -- has at least 1 transaction
        AND productRevenue IS NOT NULL -- generated revenue 
  GROUP BY visitor_id --  deduplicate visitor IDs
)

SELECT 
      month
    , SUM(trans)/COUNT(DISTINCT p.visitor_id) AS Avg_total_transactions_per_purchaser
    -- avg = total num of trans/num of unique user
FROM trans_per_visitor AS t
INNER JOIN purchaser AS p
  ON  t.visitor_id = p.visitor_id
GROUP BY month;

-- Query 6
SELECT
      FORMAT_DATE('%Y%m', PARSE_DATE('%Y%m%d',date)) AS month
      , (SUM(product.productRevenue)/COUNT(DISTINCT visitId))/1000000 AS avg_revenue_per_visit
FROM `bigquery-public-data.google_analytics_sample.ga_sessions_201707*`,
UNNEST(hits) AS hits,
UNNEST(product) AS product
WHERE totals.transactions >= 1 -- has at least 1 transaction
      AND product.productRevenue IS NOT NULL -- generated revenue
GROUP BY month;

-- Query 7
WITH
raw_data AS(-- find visitors who purchased the "YouTube Men's Vintage Henley" product
  SELECT DISTINCT fullVisitorId AS visitor_id
  FROM `bigquery-public-data.google_analytics_sample.ga_sessions_201707*`,
	UNNEST(hits) AS hits,
  UNNEST(product) AS product
  WHERE totals.transactions >= 1 -- has at least 1 transaction
    AND product.productRevenue IS NOT NULL -- generated revenue
    AND product.v2ProductName = "YouTube Men's Vintage Henley"
)

SELECT -- get a list of other products purchased by the same visitors
      product.v2ProductName AS other_purchased_products
      , SUM(product.productQuantity) AS quantity
FROM `bigquery-public-data.google_analytics_sample.ga_sessions_201707*` AS t1,
UNNEST(hits) AS hits,
UNNEST(product) AS product
INNER JOIN raw_data AS t2
  ON t1.fullVisitorId = t2.visitor_id # the same visitors
WHERE totals.transactions >= 1 -- has at least 1 transaction
  AND product.productRevenue IS NOT NULL -- generated revenue
  AND product.v2ProductName <> "YouTube Men's Vintage Henley" -- buy other products rather than YouTube Men's Vintage Henley
GROUP BY other_purchased_products
ORDER BY quantity DESC;

-- Query 8
WITH
raw_data AS( -- prepare a base table with essential fields and preliminary metrics
  SELECT
        FORMAT_DATE('%Y%m', PARSE_DATE('%Y%m%d', date)) AS month
        , product.v2ProductName AS product_name
        , hits.eCommerceAction.action_type AS action_type
        , product.productRevenue AS product_revenue
  FROM `bigquery-public-data.google_analytics_sample.ga_sessions_2017*`,
  UNNEST(hits) hits,
  UNNEST(hits.product) product
  WHERE _TABLE_SUFFIX BETWEEN '0101' AND '0331'
)
, agg AS( 
-- count the number of products according to each action type by month
  SELECT
        month
        , COUNT(CASE WHEN action_type = '2' THEN product_name END) AS num_product_view 
        , COUNT(CASE WHEN action_type = '3' THEN product_name END) AS num_addtocart 
        , COUNT(CASE WHEN action_type = '6' AND product_revenue IS NOT NULL THEN product_name END) AS num_purchase
  FROM raw_data
  GROUP BY month
)
-- calculate the conversion rate
SELECT
      month
      , num_product_view
      , num_addtocart
      , num_purchase
      , ROUND(100*num_addtocart/num_product_view,2) AS add_to_cart_rate -- product-view to add-to-cart
      , ROUND(100*num_purchase/num_product_view,2) AS purchase_rate -- product-view to purchase
FROM agg
ORDER BY month;
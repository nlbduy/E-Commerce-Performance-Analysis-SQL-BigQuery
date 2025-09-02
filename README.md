# 🛒 E-Commerce Web Traffic & User Behavior Analysis with SQL on BigQuery
<img width="2000" height="1200" alt="Image" src="https://github.com/user-attachments/assets/5575e830-b858-412e-827d-6f777abe65b2" />

👤 Author: Nguyen Luu Bao Duy  
🛠️ Tool Used: SQL

# 📚 Table of Contents
- [📌 Project Overview](#project-overview)
- [📊 Dataset](#dataset)
- [🧩 Analysis Approach](#analysis-approach)
- [💡 Insights and Recommendations](#insights-and-recommendations)

# 📌 Project Overview

## 🎯 Project Objectives

This project uses the Google Analytics Sample Dataset (2017) available on BigQuery to explore E-Commerce performance and user behavior through SQL queries. The goal is to uncover actionable insights into traffic patterns, bounce rate, revenue trends, and purchasing behavior that can inform data-driven business decisions.

## ❓ Core Questions

The analysis focuses on key questions:

- How do visits, pageviews, and transactions change across different months?
- Which traffic sources generate the highest engagement and revenue?
- What is the average number of transactions per user and the average revenue per session?
- What differentiates purchasers from non-purchasers in terms of behavior?
- Which products are frequently purchased together?
- How do users progress along the funnel from product views to purchases?

## 👥 Target audience

- Marketing Team
- E-Commerce Team
- Analytics Team
- Business Strategy Team
- Customer Experience Team

# 📊 Dataset

## 🗂️ Source

- Dataset Name: Google Analytics Sample Dataset
- Hosted on: Google BigQuery Public Datasets
- Dataset ID: `bigquery-public-data.google_analytics_sample`
- Table Used: `ga_sessions_2017MMDD`

## 📝 Description

- Contains Google Analytics data for an E-Commerce website in 2017.
- Table Schema: [View more](https://support.google.com/analytics/answer/3437719?hl=en)
- Each record represents a **session** with details

## 🗓️ Time Frame

- The entire year of 2017 is available.
- This project specifically analyzes subsets of data from January to July 2017.

## ⚙️ Granularity

- Session-level data with nested structures (hits, products).
- Queries often involve unnesting to access pageview, transaction, or product-level details.

# 🧩 Analysis Approach

## 🔍 Monthly visits, pageviews, and transactions (Jan–Mar 2017)

This step is to measure the metrics: total visits, pageviews, and number of transactions. The result identifies the trends and month-over-month growth in overall site activity and sales performance across the first quarter.

📜 **Query**

``` sql
SELECT  
      FORMAT_DATE('%Y%m', PARSE_DATE('%Y%m%d',date)) AS month
      , SUM(totals.visits) AS visits
      , SUM(totals.pageviews) AS pageviews
      , SUM(totals.transactions) AS transactions
FROM `bigquery-public-data.google_analytics_sample.ga_sessions_2017*`
WHERE _TABLE_SUFFIX BETWEEN '0101' AND '0331'
GROUP BY month
ORDER BY month ASC;
```

✔️ **Result**

<img width="2000" height="714" alt="Image" src="https://github.com/user-attachments/assets/98b489d8-2d5a-4284-8113-a31378a703a9" />

## 🔍 Bounce rate per traffic source (Jul 2017)

This step is to evaluate user engagement quality by traffic source. The result indicates which sources hold higher engagements (lower bounce rate) and which drive worse interactions (higher bounce rate).

📜 **Query**

```sql
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
```

✔️ **Result**

<img width="2000" height="1300" alt="Image" src="https://github.com/user-attachments/assets/7c6ff0bb-5e9c-42d1-a133-cae31a300e20" />

## 🔍 Revenue by traffic source by week and month (Jun 2017)

This step is to understand the revenue contribution of each traffic source over time. The result pinpoints the most profitable sources for targeting and optimizing further strategies.

📜 **Query**

```sql
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
```

✔️ **Result**

<img width="2000" height="835" alt="Image" src="https://github.com/user-attachments/assets/3d884a85-28bf-4956-bdd3-dc28f71fff8e" />
<img width="2000" height="587" alt="Image" src="https://github.com/user-attachments/assets/18d79ddb-f8a7-4af0-ac9c-94bab19dd371" />

## 🔍 Average pageviews by purchaser type (Jun–Jul 2017)

This step is to compare engagement levels between purchasers and non-purchasers. The result helps assess whether purchasers tend to view more pages before converting than non-purchasers.

📜 **Query**
```sql
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
```

✔️ **Result**

<img width="2000" height="577" alt="Image" src="https://github.com/user-attachments/assets/ef41349c-5b52-4d1f-af7f-8b81d6683e61" />

## 🔍 Average number of transactions per purchaser (Jul 2017)

This step is to measure purchasing intensity and customer loyalty. The result helps the business understand customer purchasing behaviors and evaluate the performance of marketing strategies.

📜 **Query**

```sql
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
```

✔️ **Result**

<img width="2000" height="487" alt="Image" src="https://github.com/user-attachments/assets/64bcc2bb-1938-446b-8582-efd89df879f2" />

## 🔍 Average revenue per session for purchasers (Jul 2017)

This step is to assess the value of a purchasing session. The result provides a benchmark to evaluate the marketing effectiveness when deploying any strategies to increase the quality of each session.

📜 **Query**

```sql
SELECT
      FORMAT_DATE('%Y%m', PARSE_DATE('%Y%m%d',date)) AS month
      , (SUM(product.productRevenue)/COUNT(DISTINCT visitId))/1000000 AS avg_revenue_per_visit
FROM `bigquery-public-data.google_analytics_sample.ga_sessions_201707*`,
UNNEST(hits) AS hits,
UNNEST(product) AS product
WHERE totals.transactions >= 1 -- has at least 1 transaction
      AND product.productRevenue IS NOT NULL -- generated revenue
GROUP BY month;
```

✔️ **Result**

<img width="2000" height="485" alt="Image" src="https://github.com/user-attachments/assets/ad348407-862f-4a98-a666-46ff2b04d247" />

## 🔍 Product affinity analysis for a specific item (Jul 2017)

This step is to identify other products that are bought alongside the product of interest - *YouTube Men’s Vintage Henley.* The result provides a list of products that could be used to support product bundling or recommendation strategies.

📜 **Query**

```sql
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
```

✔️ **Result**

<img width="2000" height="1050" alt="Image" src="https://github.com/user-attachments/assets/2ac27d5d-87bf-427a-a20a-828a2eb2928b" />

## 🔍 Funnel cohort from product-view → add-to-cart → purchase (Jan–Mar 2017)

This step is to build a cohort map to track the user journey and measure conversion efficiency across funnel stages. The result reveals bottlenecks where users drop off.

📜 **Query**

```sql
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
```

✔️ **Result**

<img width="2000" height="390" alt="Image" src="https://github.com/user-attachments/assets/5542487a-949c-4daf-8fee-1cafe59c32fa" />

# 💡 Insights and Recommendations

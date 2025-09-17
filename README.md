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

**Visits** & **Pageviews**: Visits slightly **dropped in February** (-3.9%) and then **rebounded in March** (+12%). Similarly, Pageviews **declined in February** (-9.4%) before **increasing in March** (+11.2%).

**Transactions**: Transactions **remained stable** in January and February, then **spiked in March** (+35.5% vs. February).


## 🔍 Traffic Drivers and Bounce Rate per traffic source (Jul 2017)

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

**Google** and **Direct** were the **top traffic drivers** in July 2017, with bounce rates at 51.6% and 43.3% respectively.

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

In June 2017, **Direct traffic was the dominant revenue channel** ($97K monthly), far exceeding Google ($18.8K) and DFA ($8.9K). Weekly trends confirmed direct traffic as the consistent top performer, with Google as a secondary contributor and other sources showing negligible revenue.

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

**Purchasers engaged far more deeply than non-purchasers**, averaging 32 to 37 pageviews per session compared to only about 4 among non-purchasers.

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

- The average number of transactions per purchaser was **1.11** in July 2017. This indicates that most customers made only **one purchase during the month**, with only a small fraction making multiple purchases. The relatively low figure suggests that **purchasing intensity and customer loyalty are weak**, as customers are not frequently returning within the same period.

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

The **average revenue per session for purchasers** means that **each visit by a purchaser generates about 156 in revenue on average**, which is a relatively **strong monetization per session**. Compared to the earlier metric (average transactions per purchaser = **1.11**), we see that while customers are **not purchasing frequently**, they do tend to **spend a significant amount when they do purchase**.

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

Purchasers of the **YouTube Men’s Vintage Henley** frequently paired it with related **apparel** (tees, hoodies) as well as **lifestyle items** (sunglasses and lip balm).

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
      , ROUND(100*num_addtocart/num_product_view,2) AS view_to_cart_rate -- product-view to add-to-cart
      , ROUND(100*num_purchase/num_addtocart,2) AS cart_to_purchase_rate -- add-to-cart to puchase
      , ROUND(100*num_purchase/num_product_view,2) AS view_to_purchase_rate -- product-view to purchase
FROM agg
ORDER BY month;
```

✔️ **Result**

<img width="2000" height="385" alt="Image" src="https://github.com/user-attachments/assets/32412915-7dcc-4e81-8971-48cae7228d33" />

<img width="2000" height="849" alt="Image" src="https://github.com/user-attachments/assets/524d1fd1-0126-4bcb-b59b-921d0e8c7dcd" />

**Conversion uplift**: Despite a slight dip in **cart_to_purchase_rate** in February, both **view_to_cart_rate** and **view_to_purchase_rate** rates increased, showing better funnel efficiency.

**March momentum**: March stands out with the highest **view_to_cart_rate** (37.3%) and **view_to_purchase_rate** (12.6%), suggesting either effective campaigns, promotions, or improved UX during checkout.

**Bottleneck shift**: In January and February, the major drop-off happened at the checkout stage (**add-to-cart → purchase**). By March, the drop-off shrank, showing that checkout completion rate had improved.


# 💡 Key Insights and Recommendations

## 🌟 Key Insights

- **Traffic vs. Conversions**: Traffic volume stayed relatively stable, but conversions spiked in March - suggesting campaigns, promotions, or seasonal effects as key drivers.
- **Channel Performance**: Direct traffic is the dominant and most reliable revenue channel, while Google provides a larger volume of visits but weaker monetization.
- **Customer Behavior**: Purchasers engage far more deeply than non-purchasers, but repeat purchase intensity remains low, which indicates that loyalty is weak.
- **Revenue Dynamics**: Strong revenue per purchaser session shows customers spend big when they buy, but long-term growth depends more on increasing frequency than basket size.
- **Funnel Efficiency**: Conversion funnel improved across Q1, with cart abandonment shrinking in March - a critical uplift for revenue growth.
- **Product Affinity**: Henley shirts link strongly with apparel and lifestyle items, with hints of gifting or couples’ purchases.

## 🚀 Recommendations

1. **Channel Optimization**
	- Prioritize investments in Direct and Google channels, given their strong revenue contribution and high traffic volume.
	- Improve underperforming but promising channels by enhancing content relevance, refining targeting, and optimizing page load speed to reduce bounce rates.
	- Reassess or phase out channels with consistently low traffic, high bounce rates, and minimal revenue impact.
2. **Boost Repeat Purchases & Loyalty**
	- Current revenue per session is strong, but the low purchase frequency indicates over-reliance on new customer acquisition.
	- To drive sustainable growth, develop strategies to increase repeat purchases and nurture a loyal customer base.
	- Potential approaches:
		+ Launch personalized retention campaigns (e.g., email/SMS remarketing).
		+ Introduce loyalty programs or rewards to incentivize return purchases.
		+ Offer subscription models for key product categories.
3. **Product Cross-Sell & Upsell**
	- Identify purchasing patterns across high-performing products to design cross-sell and upsell strategies.
	- Create bundles, combo offers, or add-on recommendations to increase average order value (AOV).
4. **Strengthen Checkout Flow**
	- Build on the positive momentum from March by further streamlining the checkout process.
	- Key improvements: enable guest checkout, reduce the number of steps, and optimize for mobile.





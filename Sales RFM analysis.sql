select * from dbo.sales_data_sample

-- -----------------------------------Exploring Data----------------------------------------
-- checking unique values in our table

-- In STATUS column,  we've 6 distinct values (Resolved, On Hold, Cancelled, Shipped, Disputed, In Process)
select distinct status 
from sales_data_sample;

-- In Year_Id column, we've 3 years (2003, 2004, 2005)
select distinct YEAR_ID 
from sales_data_sample;

-- In ProductLine column, we've 7 disticy values (Trains, Motorcycles, Ships, Trucks and Buses, Vintage Cars, Classic Cars, Planes)
select distinct PRODUCTLINE 
from sales_data_sample;

-- In country column, we've 19 countries
select distinct COUNTRY 
from sales_data_sample;

-- In DealSize column, 3 distinct values (small, medium, large)
select distinct DEALSIZE 
from sales_data_sample;

-- In Territory column, 4 distinct values (EMEA, APAC, Japan, NA)
select distinct TERRITORY 
from sales_data_sample;

-- ------------------------------------------------------------------------------------------
-- -----------------------------------Sales Analysis-----------------------------------------

-- 1. Which Product has the most Revenue? --> Classic Cars
select
	PRODUCTLINE, 
	ROUND(SUM(sales), 2) as revenue
from 
	sales_data_sample
group by 
	PRODUCTLINE
order by 
	revenue DESC;



-- 2. In which year did they make their most sales?  --> 2004 was the year with the most revenue = 4,724,162.59
select
	YEAR_ID, 
	ROUND(SUM(sales), 2) as revenue
from 
	sales_data_sample
group by 
	YEAR_ID
order by 
	revenue DESC;



-- 3. Why is there a drop down in the revenue in 2005? --> they operated just for 5 months
select
	MONTH_ID, 
	ROUND(SUM(sales), 2) as revenue
from 
	sales_data_sample
where 
	YEAR_ID = '2005'
group by 
	MONTH_ID
order by 
	MONTH_ID;



-- 4. which dealsize made the most revenue?  --> medium
select 
	DEALSIZE,
	ROUND(SUM(sales), 2) as revenue
from 
	sales_data_sample
group by 
	DEALSIZE
order by 
	revenue DESC;



-- 5. what was the best month for sales in each month in a specific year? and how many orders were purchased?
--> NOVEMBER is their best month followed by OCTOBER in 2003 and 2004
select
	MONTH_ID,
	SUM(sales) as revenue,
	COUNT(ORDERNUMBER) as frequency
from 
	sales_data_sample
where 
	YEAR_ID = '2005'
group by 
	MONTH_ID
order by 
	revenue desc;



-- 6. what product did they sell in NOVEMBER? --> In NOVEMBER, classic cars were their top productline and was purchased 104 times
select
	MONTH_ID,
	PRODUCTLINE,
	SUM(sales) as revenue,
	COUNT(ORDERNUMBER) as frequency
from 
	sales_data_sample
where 
	YEAR_ID = '2004' and MONTH_ID = '11'
group by 
	MONTH_ID, PRODUCTLINE 
order by 3 desc;


-- 7. which country generated the most sales?  --> USA has the most revenue with 3,627,982.83
select 
	country,
	ROUND(SUM(sales),2) as revenue
from 
	sales_data_sample
group by country
order by 2 desc


-- 8. what are the top 3 products that customers in USA have purchased?  -> classic cars, vintage cars, and motorcycles
select 
	TOP 3 PRODUCTLINE,
	ROUND(SUM(sales),2) as revenue
from 
	sales_data_sample
where country = 'USA'
group by PRODUCTLINE
order by 2 desc



-- --------------------------------------------------------------------------------------
-- ----------------------------- RFM Analysis -------------------------------------------

-- 9. Who are our best customers? --using temp table, CTEs, nested queries, IQR
DROP TABLE IF EXISTS #rfm
;with rfm as
(
	select
		CUSTOMERNAME,
		SUM(sales) as Monetary,
		AVG(sales) as AvgMonetary,
		count(ORDERNUMBER) as frequency,
		max(ORDERDATE) as last_order_date, -- startDate
		(select max(ORDERDATE) from sales_data_sample) as max_order_date, -- endDate
		DATEDIFF(DD, max(ORDERDATE), (select max(ORDERDATE) from sales_data_sample)) as recency 
	from 
		sales_data_sample
	group by 
		CUSTOMERNAME
),
rfm_IQR AS
(
	select 
		r.*,
		NTILE(4) over(order by recency desc) r_score, -- the closer to 4 the better
		NTILE(4) over(order by frequency) f_score,
		NTILE(4) over(order by Monetary) m_score
	from rfm as r
)
select 
	*,
	r_score *100 + f_score *10 + m_score as rfm_score
into #rfm
from rfm_IQR


-- ----------------------------------------------------------------------------------------
-- -------------------------- Customer Segmentation ---------------------------------------

select 
	CUSTOMERNAME, r_score, f_score, m_score, rfm_score,
	CASE
	WHEN r_score = 4 AND f_score = 4 AND m_score = 4 THEN 'Best customer'
    WHEN r_score = 4 AND f_score >= 3 AND m_score >=3 THEN 'Loyal customer'
    WHEN r_score >= 3 AND f_score <= 3 AND m_score <= 3 THEN 'Active customer'
    WHEN r_score >= 3 AND f_score >= 2 AND m_score >= 2 THEN 'Potential churner'
    WHEN r_score < 3 AND f_score >= 3 AND m_score >= 3 THEN 'Needs attention'
    WHEN r_score < 3 AND (f_score < 3 or m_score < 3) THEN 'Slipping away'
	WHEN r_score <= 2 AND (f_score <= 2 or m_score <= 2) THEN 'At risk'
	WHEN r_score = 1 AND (f_score = 1 or m_score = 1) THEN 'Lost custmer'
  END AS customer_segment
from #rfm


-- 10. which 2 products are often sold together?
select 
	distinct ORDERNUMBER,
	STUFF(
		(select ', ' + productcode
		from sales_data_sample as p1
		where ORDERNUMBER in
			(select ORDERNUMBER
			from (
				select ORDERNUMBER,count(*) rn
				from sales_data_sample
				where STATUS = 'Shipped'
				group by ORDERNUMBER) as t1
			where rn = 2) -- change this if we want to see more than 2 products purchased together
		and p1.ORDERNUMBER = P2.ORDERNUMBER
		for xml path ('')) 
		, 1, 1, '') as productcodes
from sales_data_sample as p2
order by productcodes desc



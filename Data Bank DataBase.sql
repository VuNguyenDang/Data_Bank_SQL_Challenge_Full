-- These Query are in MySQL languague.

/*
Data Bank Challenge
There is a new innovation in the financial industry called Neo-Banks: new aged digital only banks without physical branches.

Danny thought that there should be some sort of intersection between these new age banks, cryptocurrency and the data world…so he decides to launch a new initiative - Data Bank!

Data Bank runs just like any other digital bank - but it isn’t only for banking activities, they also have the world’s most secure distributed data storage platform!

Customers are allocated cloud data storage limits which are directly linked to how much money they have in their accounts. There are a few interesting caveats that go with this business model, and this is where the Data Bank team need your help!

The management team at Data Bank want to increase their total customer base - but also need some help tracking just how much data storage their customers will need.

This case study is all about calculating metrics, growth and helping the business analyse their data in a smart way to better forecast and plan for their future developments!
*/


			-- CHALLENGE A. CUSTOMER NODES EXPLORATION --

---- Question 1: How many unique nodes are there on the Data Bank system?
select
	count(distinct node_id) as num_of_nodes
from customer_nodes

---- Question 2: What is the number of nodes per region?
select
	r.region_name
	, count(distinct n.node_id) as num_of_node_per_region
from customer_nodes as n
join
	regions as r
    on r.region_id = n.region_id
group by
	r.region_name
order by
	region_name asc

---- Question 3: How many customers are allocated to each region?
select
	r.region_name
	, count(distinct n.customer_id) as num_of_cus_per_region
from customer_nodes as n
join
	regions as r
    on r.region_id = n.region_id
group by
	r.region_name
order by
	region_name asc

---- Question 4: How many days on average are customers reallocated to a different node?

--- For each customer
select 
	customer_id
	, avg(datediff(end_date,start_date)+1) as Avg_Day_to_Reallocate
from 
	customer_nodes
where
	left(end_date,4) != 9999
group by 
	customer_id

--- For all customers
select 

	 avg(datediff(end_date,start_date)+1) as Avg_Day_to_Reallocate
from 
	customer_nodes
where
	left(end_date,4) != 9999

---- Question 5: What is the median, 80th and 95th percentile for this same reallocation days metric for each region?
with X as
(
select 
	customer_id
	, avg(datediff(end_date,start_date)+1) as Avg_Day_to_Reallocate
from 
	customer_nodes
where
	left(end_date,4) != 9999
group by 
	customer_id
  ),
Y as
 (
select
	*
   , round(
     	percent_rank()
     	over( order by Avg_Day_to_Reallocate)
     , 2) as quantile
from X
  )
select
	max(Avg_Day_to_Reallocate) as Avg_Day
    , quantile
from Y
where
	quantile in (0.50,0.80,0.95)
group by
	quantile


		-- CHALLENGE B. CUSTOMER TRANSACTIONS --

---- Question 1: What is the unique count and total amount for each transaction type?
select 
	txn_type as transaction_type
    , count(txn_type) as counts
    , sum(txn_amount) as total_amount
from 
	customer_transactions
group by 
	txn_type

---- Question 2: What is the average total historical deposit counts and amounts for all customers?

with X as
(
select 
	count(*)*1.0   as count_deposit
    , sum(txn_amount)*1.0 as amount_deposit

from 
	customer_transactions
where
	txn_type = 'deposit'
)
select
	count_deposit / (select count(distinct customer_id) from customer_transactions) as avg_count_deposit
    , amount_deposit / (select count(distinct customer_id) from customer_transactions) as avg_sum_deposit
from X

---- Question 3: For each month - how many Data Bank customers make more than 1 deposit and either 1 purchase or 1 withdrawal in a single month?
with X as
(
select
	month(txn_date) as Months
	, count(distinct customer_id) as num_of_cus_non_deposit
from 
	customer_transactions
where
	txn_type in ('withdrawal','purchase')
group by
	month(txn_date)
having 
	count(distinct txn_type) = 2
),
Y as
(select
	month(txn_date) as Months
	, count(distinct customer_id) as total_num_cus
from 
	customer_transactions
group by
	month(txn_date)
)
select
	Y.Months
	, Y.total_num_cus - X.num_of_cus_non_deposit as Num_of_cus_deposit
from X
	right join Y
	on X.Months = Y.Months

---- Question 4: What is the closing balance for each customer at the end of the month?
with X as
(
select
	customer_id
	, month(txn_date) as Months
	, Year(txn_date) as Years
	, (case
		when txn_type = 'deposit' then txn_amount
		else - txn_amount 
		end ) as change_in_account_balance
from 
	customer_transactions
),
Y as
(
select
	customer_id
	, Months
    , Years
    , sum(change_in_account_balance) change_month
from 
	X
group by 
	customer_id
    , Months
    , Years
)
select
	customer_id
    , Months
    , Years
    , sum(change_month) over( partition by customer_id order by Years, Months) as balance_closing
from
	Y

---- Question 5: What is the percentage of customers who increase their closing balance by more than 5%?

with X as
(
select
	customer_id
	, month(txn_date) as Months
	, Year(txn_date) as Years
	, (case
		when txn_type = 'deposit' then txn_amount
		else - txn_amount 
		end ) as change_in_account_balance
from 
	customer_transactions
),
Y as
(
select
	customer_id
	, Months
    , Years
    , sum(change_in_account_balance) change_month
from 
	X
group by 
	customer_id
    , Months
    , Years
),
Z as
(select
	customer_id
    , Months
    , Years
    , sum(change_month) over( partition by customer_id order by Years, Months) as balance_closing
from
	Y
), 
T as
(select
	customer_id
	, balance_closing
	, (lead(balance_closing,1) over (partition by customer_id order by Years, Months) - balance_closing)*1.0/balance_closing as growth_percent
from 
	Z
where 
	balance_closing > 0)
select
	concat(format(count(distinct customer_id)*100.0 / (select count (distinct customer_id) from customer_transactions),2),' %') as percentage_increasing
from 
	T
where 
	growth_percent > 0.05
	and balance_closing > 0


		-- CHALLENGE C. DATA ALLOCATION CHALLENGE --

/*To test out a few different hypotheses - the Data Bank team wants to run an experiment where different groups of customers would be allocated data using 3 different options:

Option 1: data is allocated based off the amount of money at the end of the previous month
Option 2: data is allocated on the average amount of money kept in the account in the previous 30 days
Option 3: data is updated real-time
For this multi-part challenge question - you have been requested to generate the following data elements to help the Data Bank team estimate how much data will need to be provisioned for each option:

running customer balance column that includes the impact each transaction
customer balance at the end of each month
minimum, average and maximum values of the running balance for each customer
Using all of the data available - how much data would have been required for each option on a monthly basis?
*/

---- Option 1: data is allocated based off the amount of money at the end of the previous month

--> customer balance at the end of each month
with X as
(
select
	customer_id
	, month(txn_date) as Months
	, Year(txn_date) as Years
	, (case
		when txn_type = 'deposit' then txn_amount
		else - txn_amount 
		end ) as change_in_account_balance
from 
	customer_transactions
),
Y as
(
select
	customer_id
	, Months
    , Years
    , sum(change_in_account_balance) change_month
from 
	X
group by 
	customer_id
    , Months
    , Years
)
select
	customer_id
    , Months
    , Years
    , sum(change_month) over( partition by customer_id order by Years, Months) as balance_closing
from
	Y

---- Option 2: data is allocated on the average amount of money kept in the account in the previous 30 days

--> minimum, average and maximum values of the running balance for each customer

with X as
(
select
	customer_id
	, month(txn_date) as Months
	, Year(txn_date) as Years
	, (case
		when txn_type = 'deposit' then txn_amount
		else - txn_amount 
		end ) as change_in_account_balance
from 
	customer_transactions
),
Y as
(
select
	customer_id
	, Months
    , Years
    , sum(change_in_account_balance) change_month
from 
	X
group by 
	customer_id
    , Months
    , Years
), T as
(select
	customer_id
    , Months
    , Years
    , sum(change_month) over( partition by customer_id order by Years, Months) as balance_closing
from
	Y)
select
	customer_id
	, Months
	, Years
	, max(balance_closing) as max_balance
	, min(balance_closing) as min_balance
	, avg(balance_closing) as avg_balance
from 
	T
group by
	customer_id
	, Months
	, Years
---- Option 3: data is update real-time

--> running customer balance column that includes the impact each transaction

with X as
(
select
	customer_id
	, txn_date
	, (case
		when txn_type = 'deposit' then txn_amount
		else - txn_amount 
		end ) as change_in_account_balance
from 
	customer_transactions
)
select
	customer_id
	, txn_date
	, sum(change_in_account_balance) over (partition by customer_id order by txn_date) as balance_closing_real_time
from 
	X
order by 
	customer_id
	, txn_date

			-- D. EXTRA CHALLENGE --
/*Data Bank wants to try another option which is a bit more difficult to implement - they want to calculate data growth using an interest calculation, just like in a traditional savings account you might have with a bank.

If the annual interest rate is set at 6% and the Data Bank team wants to reward its customers by increasing their data allocation based off the interest calculated on a daily basis at the end of each day, how much data would be required for this option on a monthly basis?
*/

with X as
(
select
	customer_id
	, txn_date
	, lead(txn_date,1) over (partition by customer_id)
	, (case					-- Calculate change in account balance (+ or -)
		when txn_type = 'deposit' then txn_amount
		else - txn_amount 
		end ) as change_in_account_balance     
	, datediff(curdate(), txn_date) + 1 as num_of_days -- Calculate num of days from transaction day to the current date
from 
	customer_transactions
)
select
	customer_id
	, txn_date
	, sum(change_in_account_balance*0.06*num_of_days/365) over (partition by customer_id order by txn_date) as balance_closing_real_time 
	--- Sum of change in account order by txn_date is balance closing at real time
from 
	X
order by 
	customer_id
	, txn_date

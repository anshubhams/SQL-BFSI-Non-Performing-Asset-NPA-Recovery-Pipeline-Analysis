-- 0. Create the Master Loan Portfolio Table
CREATE TABLE loan_portfolio (
    Borrower_ID VARCHAR(50),
    Age INT,
    Gender VARCHAR(20),
    Employment_Type VARCHAR(50),
    Monthly_Income INT,
    Num_Dependents INT,
    Loan_ID VARCHAR(50) PRIMARY KEY,
    Loan_Amount INT,
    Loan_Tenure INT,
    Interest_Rate NUMERIC(5,2),
    Loan_Type VARCHAR(50),
    Collateral_Value NUMERIC(15,2),
    Outstanding_Loan_Amount NUMERIC(15,2),
    Monthly_EMI NUMERIC(12,2),
    Payment_History VARCHAR(50),
    Num_Missed_Payments INT,
    Days_Past_Due INT,
    Recovery_Status VARCHAR(50),
    Collection_Attempts INT,
    Collection_Method VARCHAR(50),
    Legal_Action_Taken VARCHAR(10)
);

-- 0.1 Create the interaction logs table
CREATE TABLE interaction_logs (
    Interaction_ID VARCHAR(50) PRIMARY KEY,
    Loan_ID VARCHAR(50),
    Agent_ID VARCHAR(20),
    Interaction_Date DATE,
    Call_Status VARCHAR(50),
    Amount_Recovered NUMERIC(12,2)
	);
	
-- 0.2 CRUCIAL: Tell PostgreSQL to read MM/DD/YYYY dates for this session
SET datestyle = 'MDY';

COPY interaction_logs 
FROM 'D:\Downloads\PROJECTS\Smart Loan Recovery System Dataset\Recovery Agent Interaction Logs.csv' 
DELIMITER ',' 
CSV HEADER;

-- 0.3 Verifying the data upload:
SELECT 'loan_portfolio' AS table_name, COUNT(*) FROM loan_portfolio
UNION ALL
SELECT 'interaction_logs' AS table_name, COUNT(*) FROM interaction_logs;

-- 1. Portfolio Health Overview (Descriptive Analytics)
-- How many loans are currently active/stuck?
-- What is the total sanctioned amount vs. what is actually left to be recovered (Outstanding_Loan_Amount)?
-- How deep is the payment delay on average (Days_Past_Due)?
select
	loan_type,
	count(loan_id) as total_loans,
	sum(loan_amount) as total_sanctioned_amount,
	sum(outstanding_loan_amount) as total_outstanding_balance,
	round(avg(days_past_due),1) as avg_days_past_due
from loan_portfolio
group by loan_type
order by total_outstanding_balance desc;

-- 2. Regulatory Risk Segmentation (The SMA & NPA Buckets)
-- classify delinquent loans into standard Indian banking risk buckets 
-- (SMA-0: 1-30 DPD, SMA-1: 31-60 DPD, SMA-2: 61-90 DPD, NPA: 90+ DPD) and 
-- calculate the count and total & average outstanding amount for each bucket?
select 
	case
		when days_past_due = 0 then 'Standard (Current)'
		when days_past_due between 1 and 30 then 'SMA-0 (1-30 DPD)'
		when days_past_due between 31 and 60 then 'SMA-1 (31-60 DPD)'
		when days_past_due between 61 and 90 then 'SMA-2 (31-90 DPD)'
		else 'NPA (90+ DPD)'
	end as regulatory_risk_bucket,
	count(loan_id),
	sum(outstanding_loan_amount) as total_outstanding_amount,
	round(avg(outstanding_loan_amount), 2) as avg_ticket_size
from loan_portfolio
group by 1
order by 1 asc;

-- 3. Agent Productivity Benchmark (Operational Efficiency)
-- Who has recoverd the highest loan amounts?
-- What is their actual recovery yield efficiency rate? 
-- (Total Recovered divided by the Total Outstanding of the loans they touched)
select
	agent_id,
	count(distinct il.loan_id) as Unique_Loans_Handled,
	count(interaction_id) as Total_Contacts_Attempts,
	sum(il.amount_recovered) as Total_Amount_Recovered,
	round(sum(il.amount_recovered * 100) / nullif(sum(lp.outstanding_loan_amount), 0), 2) as Recovery_Effiency_Pct
from interaction_logs il join loan_portfolio lp on lp.loan_id = il.loan_id
group by il.agent_id
order by 4 desc;

-- 4. Call Efficiency Analytics (Behavioral Analytics): 
-- What percentage of calls result in an actual collection vs. a "Promise to Pay" OR 
-- a non-response ("Busy"/"Switch Off")?
select
	count(interaction_id) as Total_Calls_Made,
	-- calls that were actually successfull with their %:
	count(case when amount_recovered > 0 then 1 end) as Successfull_Collections,
	round(count(case when amount_recovered > 0 then 1 end) * 100 / count(interaction_id), 2) as Conversion_Pct,	
	-- calls where borrower promised to pay later with their %:
	count(case when call_status = 'Promise to Pay' then 1 end) as Promises_Logged,
	round(count(case when call_status = 'Promise to Pay' then 1 end) * 100 / count(interaction_id), 2) as Promise_Rate_Pct,
	-- Non responsive calls with their %:
	count(case when call_status in ('Busy','Switch Off') then 1 end) as Lost_Contacts, 
	round(count(case when call_status in ('Busy','Switch Off') then 1 end) * 100 / count(interaction_id), 2) as Lost_Contacts_Pct
from interaction_logs;

-- 4. Analysing Call Efficiency by using CTEs:
with CallMetrics as (
    -- Calculate raw counts in a single pass
    select 
        count(interaction_id) as total_calls_made,
        count(case when amount_recovered > 0 then 1 end) as successful_collections,
        count(case when call_status = 'Promise to Pay' then 1 end) as promises_logged,
        count(case when call_status in ('Busy', 'Switch Off') then 1 end) as lost_contacts
    from interaction_logs
)
	-- Step 2: Calculate percentages cleanly on top of the aggregated numbers
select 
    total_calls_made,
    successful_collections,
    ROUND((successful_collections * 100.0) / total_calls_made, 2) as conversion_rate_pct,
    promises_logged,
    ROUND((promises_logged * 100.0) / total_calls_made, 2) as promise_rate_pct,
    lost_contacts,
    ROUND((lost_contacts * 100.0) / total_calls_made, 2) as non_response_rate_pct
from CallMetrics;

-- 5. High-Value Risk Prioritization (Operational Strategy): 
-- For accounts currently marked as 'NPA' (>90 DPD) that have a collateral value, 
-- what is our "Collateral Coverage Ratio" (Collateral Value / Outstanding Amount)? 
-- Find the top 10 accounts where the bank has the highest safety net.
select
	loan_id,
	borrower_id,
	loan_type,
	collateral_value,
	days_past_due,
	recovery_status,
	-- Finding Collateral Coverage Ratio
	round((collateral_value/nullif(outstanding_loan_amount, 0)),2) as Collateral_Coverage_Ratio
from loan_portfolio
where days_past_due > 90 and collateral_value > 0
order by 7 desc 
limit 10;

-- 6. Agent Workload and Touchpoint Frequency (Resource Allocation): 
-- Calculate a running total of contact attempts made by agents over time 
-- for each loan to identify if we are over-contacting certain customers while ignoring others.
select
	loan_id,
	agent_id
	interaction_date,
	call_status,
	amount_recovered,
	count(interaction_id) over(
	partition by loan_id order by interaction_date asc, interaction_id asc) as Cumulative_contact_count
from interaction_logs
order by loan_id, cumulative_contact_count;

-- 7. Contact Quality Leaderboard (Advanced Ranking): 
-- Rank our top 3 recovery agents within each loan type 
-- based on the total amount they recovered.
with Agent_Performance as (
	select
		lp.loan_type,
		il.agent_id,
		sum(il.amount_recovered) as total_amt_recovered,
		-- ranking agents within each specific loan type:
		dense_rank() over(
			partition by lp.loan_type order by sum(il.amount_recovered)
			) as agent_rank
	from interaction_logs il
	join loan_portfolio lp on il.loan_id = lp.loan_id
	group by lp.loan_type, il.agent_id
	)
select
	loan_type,
	agent_id,
	total_amt_recovered,
	agent_rank
from Agent_Performance
where agent_rank <= 3
order by loan_type, agent_rank;

-- 8. The "Hopeless" Account Flag (Strategic Intelligence): 
-- Identify loans where the customer has missed more than 3 payments AND 
-- the collection agent has called them more than 5 times, 
-- but the Amount_Recovered is still 0. These need to be flagged for immediate legal action.
with Combined_Summary as (
	select
		lp.loan_id,
		lp.borrower_id,
		lp.num_missed_payments,
		lp.outstanding_loan_amount,
		count(il.interaction_id) as total_calls_made,
		sum(il.amount_recovered) as total_amount_recovered
	from loan_portfolio lp
	join interaction_logs il on lp.loan_id = il.loan_id
	group by lp.loan_id, lp.borrower_id, lp.num_missed_payments, lp.outstanding_loan_amount
	)
select 
	loan_id,
	borrower_id,
	num_missed_payments,
	outstanding_loan_amount,
	total_calls_made
from Combined_summary
where num_missed_payments > 3 and total_calls_made > 5 and total_amount_recovered = 0
order by outstanding_loan_amount desc;

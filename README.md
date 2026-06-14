# SQL-BFSI-Non-Performing-Asset-NPA-Recovery-Pipeline-Analysis
This repository contains a full-stack financial data analytics architecture designed to evaluate credit risk, manage delinquency pipelines, and optimize collection operations for a retail banking loan portfolio.

Moving beyond standard prediction models, this project designs operational business intelligence pipelines to classify distressed assets according to standard regulatory thresholds and identify critical process leakage within a 2,500-row collection transaction database.

## 🛠️ Data Architecture & Relational Schema
The analytics warehouse is self-hosted on **PostgreSQL** utilizing two primary relational tables:
1. **`loan_portfolio`**: Master dimension containing structural borrowing attributes, outstanding fields, credit risk status, and structural collateral evaluations.
2. **`interaction_logs`**: Transactional table logging discrete field calling metrics, historical agent timelines, contact success flags, and fractional cash yields.

---

## 📈 Core Business Insights & Analytical Framework

### 1. Portfolio Health Overview
**Business Intent:** Assessing systemic exposure concentrations across consumer loan silos.
SELECT loan_type, COUNT(loan_id), SUM(outstanding_loan_amount)... **-- See full code in queries.sql**
Output Verification:
q1.png

# E-Commerce Database Normalization & Data Quality Analysis

**Technologies:** MySQL, SQL, Relational Database Design, Data Cleaning

## Overview

This project demonstrates the transformation of an e-commerce transaction dataset into a normalized relational database using MySQL.

The project focuses on identifying data quality issues, reducing data redundancy, organizing records into related tables, and generating a consolidated reporting view.

## Project Results

| Metric | Result |
|---|---:|
| Original transaction records | 46 |
| Customer records | 44 |
| Product records | 11 |
| Retained order records | 42 |
| Orders in filtered report | 40 |

The initial audit identified missing or invalid values in timestamps, customer information, product information, and pricing.

## Database Design

The database separates the original transaction data into three relational tables.

**Customers**
- `customer_id` — Primary key
- `customer_name`
- `customer_email`
- `customer_city`

**Products**
- `product_id` — Primary key
- `product_name`
- `category_name`
- `unit_price`

**Orders**
- `order_id` — Primary key
- `order_timestamp`
- `customer_id` — Foreign key
- `product_id` — Foreign key
- `quantity`
- `review_rating`

Each order references a customer and a product through foreign keys.

## Implementation

### 1. Data Quality Audit

Analyzed the original 46 transaction records using SQL aggregate functions and conditional expressions.

Identified missing timestamps, customer contact information, product details, and invalid pricing values.

### 2. Data Cleaning

Applied SQL functions including `TRIM()`, `NULLIF()`, `COALESCE()`, and `STR_TO_DATE()` to standardize data and convert timestamps.

### 3. Database Normalization

Separated customer, product, and transaction information into relational tables to reduce repeated attributes.

Established primary and foreign key relationships between the tables.

### 4. Data Validation

Excluded orders with missing timestamps or unresolved customer/product references.

Retained 42 orders in the normalized database.

### 5. Reporting

Created the `v_orders_3nf_report` SQL view to combine information from the normalized tables.

The view calculates transaction totals using:

`unit_price * quantity`

The final exported report filters for transactions with positive order amounts, returning 40 records.

## SQL Skills Demonstrated

- Data profiling and quality auditing
- Conditional expressions and aggregate functions
- Data cleaning and type conversion
- Relational schema design
- Primary and foreign key relationships
- Multi-table joins
- SQL views and calculated fields

## Repository Contents

- `ecomdb.sql` — Database creation, transformation, validation, and reporting SQL
- `ShowStartingTable.csv` — Original transaction dataset
- `ReportOfRecords.csv` — Data quality audit results
- `customerTable.csv` — Customer table export
- `productsTable.csv` — Product table export
- `ordersTable.csv` — Orders table export
- `orders_3nf_view.csv` — Filtered reporting view export

## Future Improvements

- Add an entity-relationship diagram.
- Create a reproducible database initialization script.
- Add automated data integrity tests.
- Strengthen uniqueness and nullability constraints.

## Author

Steven Harrington

[GitHub](https://github.com/Steven-Harrington)

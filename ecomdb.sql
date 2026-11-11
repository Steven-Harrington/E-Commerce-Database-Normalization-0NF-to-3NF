-- E-Commerce Database Normalization: 0NF to 3NF
-- MySQL project: data audit, normalization, and reporting
-- Prerequisite: import the source data into raw_orders_1nf before running.
-- IF NOT EXISTS prevents table-creation errors when tables already exist.
-- Note: rerunning INSERT statements may still duplicate data or cause key conflicts.

-- SECTION 1: Database setup and source data inspection
CREATE DATABASE IF NOT EXISTS ecomdb;
USE ecomdb;

-- Disable safe-update restrictions and foreign key checks for this assignment workflow.
SET SQL_SAFE_UPDATES = 0;
SET FOREIGN_KEY_CHECKS = 0;

-- Inspect the imported source table.
SELECT * FROM raw_orders_1nf;
DESCRIBE raw_orders_1nf;
-- SECTION 2: Audit missing and invalid source values

-- Count valid and missing values for each source field.
SELECT 
    COUNT(*) AS total_records,
    COUNT(order_id) AS valid_ids,
    count(*) - count(order_id) AS missing_ids,
    SUM(CASE WHEN order_timestamp IS NOT NULL AND TRIM(order_timestamp) != '' THEN 1 ELSE 0 END) AS valid_order_timestamps,
    SUM(CASE WHEN order_timestamp IS NULL OR TRIM(order_timestamp) = '' THEN 1 ELSE 0 END) AS missing_timestamps,
    SUM(CASE WHEN customer_name IS NOT NULL AND TRIM(customer_name) != '' THEN 1 ELSE 0 END) AS valid_customers,
    SUM(CASE WHEN customer_name IS NULL OR TRIM(customer_name) = '' THEN 1 ELSE 0 END) AS missing_customers,
    SUM(CASE WHEN customer_email IS NOT NULL AND TRIM(customer_email) != '' THEN 1 ELSE 0 END) AS valid_emails,
    SUM(CASE WHEN customer_email IS NULL OR TRIM(customer_email) = '' THEN 1 ELSE 0 END) AS missing_emails,
    SUM(CASE WHEN customer_city IS NOT NULL AND TRIM(customer_city) != '' THEN 1 ELSE 0 END) AS valid_cities,
    SUM(CASE WHEN customer_city IS NULL OR TRIM(customer_city) = '' THEN 1 ELSE 0 END) AS missing_cities,
    SUM(CASE WHEN product_name IS NOT NULL AND TRIM(product_name) != '' THEN 1 ELSE 0 END) AS valid_products,
    SUM(CASE WHEN product_name IS NULL OR TRIM(product_name) = '' THEN 1 ELSE 0 END) AS missing_products,
    SUM(CASE WHEN category_name IS NOT NULL AND TRIM(category_name) != '' THEN 1 ELSE 0 END) AS valid_categories,
    SUM(CASE WHEN category_name IS NULL OR TRIM(category_name) = '' THEN 1 ELSE 0 END) AS missing_categories,
    SUM(CASE WHEN unit_price IS NOT NULL AND unit_price != 0 THEN 1 ELSE 0 END) AS valid_prices,
    SUM(CASE WHEN unit_price IS NULL OR unit_price = 0 THEN 1 ELSE 0 END) AS missing_prices,
    COUNT(quantity) AS valid_quantities,
    count(*) - count(quantity) AS missing_quantities,
    COUNT(review_rating) AS valid_ratings,
    count(*) - count(review_rating) AS missing_ratings
FROM raw_orders_1nf;
-- SECTION 3: Create customer, product, and order tables

-- Create the customer lookup table.
CREATE TABLE IF NOT EXISTS customers (
	customer_id INT AUTO_INCREMENT PRIMARY KEY,
	customer_name VARCHAR(125),
    customer_email VARCHAR(125),
    customer_city VARCHAR(125)
);

-- Insert distinct combinations of customer name, email, and city.
-- Different combinations are treated as separate customer records.
INSERT IGNORE INTO  customers(customer_name,customer_email,customer_city)
SELECT DISTINCT customer_name, customer_email, COALESCE(NULLIF(TRIM(customer_city), ''), 'Unknown')
FROM raw_orders_1nf
WHERE customer_name IS NOT NULL AND TRIM(customer_name) != '';

-- Inspect the customer table.
DESCRIBE customers;
SELECT * FROM customers;

-- Create the product lookup table.
CREATE TABLE IF NOT EXISTS products (
	product_id INT AUTO_INCREMENT PRIMARY KEY,
	product_name VARCHAR(125),
    category_name VARCHAR(125),
    unit_price DOUBLE
);

-- Insert distinct product combinations, including zero-priced products.
INSERT IGNORE INTO  products(product_name,category_name,unit_price)
SELECT DISTINCT product_name, COALESCE(NULLIF(TRIM(category_name), ''), 'General'), unit_price
FROM raw_orders_1nf
WHERE product_name IS NOT NULL AND TRIM(product_name) != '';

-- Inspect the product table.
DESCRIBE products;
SELECT * FROM products;

-- Create the orders table with foreign keys to customers and products.
CREATE TABLE IF NOT EXISTS orders (
    order_id INT PRIMARY KEY,
    order_timestamp DATETIME,
    customer_id INT,
    product_id INT,
    quantity INT,
    review_rating INT,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);

DESCRIBE orders;
SELECT * FROM orders;

-- SECTION 4: Populate orders and validate relationships
-- Match raw orders to customer and product records using joins.
INSERT INTO orders (
    order_id,
    order_timestamp, 
    customer_id, 
    product_id, 
    quantity, 
    review_rating
)
SELECT 
    r.order_id,
	STR_TO_DATE(NULLIF(TRIM(r.order_timestamp), ''),'%c/%e/%y %H:%i'),
    c.customer_id,
    p.product_id,
    r.quantity,
    r.review_rating
FROM raw_orders_1nf r
LEFT JOIN customers c
    ON r.customer_name = c.customer_name
    AND COALESCE(NULLIF(TRIM(r.customer_email), ''), 'Unknown')
        = COALESCE(NULLIF(TRIM(c.customer_email), ''), 'Unknown')
    AND COALESCE(NULLIF(TRIM(r.customer_city), ''), 'Unknown')
        = COALESCE(NULLIF(TRIM(c.customer_city), ''), 'Unknown')
LEFT JOIN products p 
    ON r.product_name = p.product_name
    AND COALESCE(NULLIF(TRIM(r.category_name), ''), 'General')
        = COALESCE(NULLIF(TRIM(p.category_name), ''), 'General')
    AND r.unit_price <=> p.unit_price;
    
SELECT * FROM orders;

-- Remove orders missing a valid timestamp or a customer/product reference.
DELETE FROM orders
WHERE order_timestamp IS NULL
   OR customer_id IS NULL
   OR product_id IS NULL;

-- Check whether any order references an ID absent from its lookup table.
SELECT *
FROM orders
WHERE customer_id NOT IN (
    SELECT customer_id
    FROM customers
)
OR product_id NOT IN (
    SELECT product_id
    FROM products
);

-- Assignment validation step: remove orders with invalid lookup references, if any.
DELETE
FROM orders
WHERE customer_id NOT IN (
    SELECT customer_id
    FROM customers
) OR product_id NOT IN (
	SELECT product_id
    FROM products);

-- Restore the settings changed during setup.
SET SQL_SAFE_UPDATES = 1;
SET FOREIGN_KEY_CHECKS = 1;

-- SECTION 5: Create the normalized reporting view
CREATE OR REPLACE VIEW v_orders_3nf_report AS
SELECT 
    o.order_id AS ORDER_ID,
    o.order_timestamp AS ORDER_TIMESTAMP,
    c.customer_name AS CUSTOMER_NAME,
     COALESCE(NULLIF(TRIM(c.customer_email), ''), 'Unspecified') AS EMAIL,
     COALESCE(NULLIF(TRIM(c.customer_city), ''), 'Unknown') AS CITY,
    p.product_name AS PRODUCT_NAME,
     COALESCE(NULLIF(TRIM(p.category_name), ''), 'General') AS CATEGORY,
    p.unit_price AS UNIT_PRICE,
    o.quantity AS QUANTITY,
    o.review_rating AS RATING,
    p.unit_price * o.quantity AS total_order_amount
FROM orders o
INNER JOIN customers c ON o.customer_id = c.customer_id
INNER JOIN products p ON o.product_id = p.product_id;

-- Show positive-value orders only; zero-priced orders remain in the orders table.
SELECT * FROM v_orders_3nf_report
WHERE total_order_amount > 0
ORDER BY ORDER_TIMESTAMP DESC;

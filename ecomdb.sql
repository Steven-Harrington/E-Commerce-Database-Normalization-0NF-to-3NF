#Challenge 1
CREATE DATABASE IF NOT EXISTS ecomdb;
USE ecomdb;

#turns off safety checks
SET SQL_SAFE_UPDATES = 0;
SET FOREIGN_KEY_CHECKS = 0;

#added these here to see what our table look like
SELECT * FROM raw_orders_1nf;
DESCRIBE raw_orders_1nf;
#Challenge 2

#give the total count and then the valid and missing for specific columns
#It specified only a few columns, but I wanted to be safe so I did all the columns
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
#Challenge 3

#made the customer table
CREATE TABLE customers (
	customer_id INT AUTO_INCREMENT PRIMARY KEY,
	customer_name VARCHAR(125),
    customer_email VARCHAR(125),
    customer_city VARCHAR(125)
);

#Inserts unqiue combinations into customers table
#For example each different Rachel Green combo is added
INSERT IGNORE INTO  customers(customer_name,customer_email,customer_city)
SELECT DISTINCT customer_name, customer_email, COALESCE(NULLIF(TRIM(customer_city), ''), 'Unknown')
FROM raw_orders_1nf
WHERE customer_name IS NOT NULL AND TRIM(customer_name) != '';

#added to see what table looks like
DESCRIBE customers;
SELECT * FROM customers;

#made the products table
CREATE TABLE products (
	product_id INT AUTO_INCREMENT PRIMARY KEY,
	product_name VARCHAR(125),
    category_name VARCHAR(125),
    unit_price DOUBLE
);

#Inserts unique product combinations, including products with zero prices
INSERT IGNORE INTO  products(product_name,category_name,unit_price)
SELECT DISTINCT product_name, COALESCE(NULLIF(TRIM(category_name), ''), 'General'), unit_price
FROM raw_orders_1nf
WHERE product_name IS NOT NULL AND TRIM(product_name) != '';

#give us an idea of the products table
DESCRIBE products;
SELECT * FROM products;

#makes an orders fact table
CREATE TABLE orders (
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

#challenge 4
#connects the lookup tables to the fact table
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

#deletes rows which have null values
DELETE FROM orders
WHERE order_timestamp IS NULL
   OR customer_id IS NULL
   OR product_id IS NULL;

#checks to see if we have values to delete, we don't
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

#Deletes them anyways for assignment
DELETE
FROM orders
WHERE customer_id NOT IN (
    SELECT customer_id
    FROM customers
) OR product_id NOT IN (
	SELECT product_id
    FROM products);

#turn safety checks back on
SET SQL_SAFE_UPDATES = 1;
SET FOREIGN_KEY_CHECKS = 1;

#challenge 5;
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

#there were two sections that had a unit_price of 0
#as the condition wasn't specified, I just made sure everything at least was above 0
SELECT * FROM v_orders_3nf_report
WHERE total_order_amount > 0
ORDER BY ORDER_TIMESTAMP DESC;

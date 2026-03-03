/* Objetos a serem utilizadas
 * 
 * Tabelas
 * 	- customer_tratada
 * 	- sellers_tratada
 * 	- geolocation_tratada
 *  - leads_closed
 * 	- leads_qualified
 * 
 * Views
 *  - vw_orders (Fato)
 *  - vw_products
 *  - vw_leads
 *  
 */



-- VIEW ORDERS


CREATE VIEW vw_orders AS

WITH payment_summary AS (
    SELECT 
        order_id,
        SUM(payment_value) AS total_payment_value,
        MAX(payment_type) AS main_payment_type,
        MAX(payment_installments) AS total_installments
    FROM order_payments
    GROUP BY order_id
),
item_summary AS (
    SELECT
        order_id,
        SUM(price) AS total_items_value,
        SUM(freight_value) AS total_freight_value
    FROM order_items
    GROUP BY order_id
),
review_summary AS (
    SELECT
        order_id,
        AVG(review_score) AS avg_review_score,
        MAX(review_creation_date) AS last_review_date,
        MAX(review_answer_timestamp) AS last_answer_date,
        MAX(review_comment_message) AS last_comment  -- usa o mais recente disponível
    FROM order_reviews
    GROUP BY order_id
)
SELECT
    o.order_id,
    o.customer_id,
    o.order_status,
    DATE(o.order_purchase_timestamp) AS dt_pedido,
    DATE(o.order_approved_at) AS dt_aprovacao_pagamento,
    DATE(o.order_delivered_carrier_date) AS dt_coleta_transportadora,
    DATE(o.order_delivered_customer_date) AS dt_entrega_cliente,
    DATE(o.order_estimated_delivery_date) AS dt_prevista_entrega,
    CASE
        WHEN o.order_status IN ('unavailable', 'canceled') THEN 'Unavailable'
        WHEN (
            (o.order_delivered_customer_date IS NULL AND DATE(o.order_estimated_delivery_date) < DATE('2018-10-17'))
            OR DATE(o.order_delivered_customer_date) > DATE(o.order_estimated_delivery_date)
        ) THEN 'Overdue'
        ELSE 'On time'
    END AS status,
    
    -- Itens do pedido
    oi.product_id,
    oi.seller_id,
    oi.shipping_limit_date,
    oi.price,
    oi.freight_value,
    
    -- Totais agregados (repetidos corretamente por item) 
    isummary.total_items_value AS vlr_total_itens, -- Possivelmente vamos remover
    isummary.total_freight_value AS vlr_total_frete, -- Possivelmente vamos remover
    (isummary.total_items_value + isummary.total_freight_value) AS vlr_total_pedido_itens, -- Possivelmente vamos remover
    ps.total_payment_value AS vlr_total_pago, -- Possivelmente vamos remover
    ps.main_payment_type AS payment_type,
    ps.total_installments AS payment_installments,
    
    -- Avaliações (agregadas)
    DATE(rv.last_review_date) AS dt_criacao_avaliacao,
    rv.avg_review_score AS review_score_medio,
    rv.last_comment AS review_comment_message,
    DATE(rv.last_answer_date) AS dt_resposta_avaliacao

FROM orders o
JOIN order_items oi 
    ON o.order_id = oi.order_id
LEFT JOIN item_summary isummary 
    ON o.order_id = isummary.order_id
LEFT JOIN payment_summary ps 
    ON o.order_id = ps.order_id
LEFT JOIN review_summary rv 
    ON o.order_id = rv.order_id;



	
-- TABLE GEOLOCATION TRATADA
	
CREATE TEMP TABLE new_geolocation_one AS
SELECT  DISTINCT geolocation_zip_code_prefix, geolocation_lat,
        geolocation_lng, geolocation_city,
        geolocation_state
FROM geolocation
ORDER BY geolocation_zip_code_prefix ; 

CREATE TEMP TABLE real_geolocation AS
SELECT      geolocation_zip_code_prefix,
            geolocation_lat,
            geolocation_lng,
            REPLACE
            (REPLACE
            (REPLACE
            (REPLACE
            (REPLACE
            (REPLACE
            (REPLACE
            (REPLACE
            (REPLACE
            (REPLACE
            (REPLACE
            (REPLACE
            (REPLACE
            (REPLACE
            (REPLACE
            (REPLACE
            (REPLACE
            (REPLACE(geolocation_city, '...a', 'a'),
            '´', ''),
            '4o.', 'quarto'),
            '4º', 'quarto'),
            'á', 'a'),
            'â', 'a'),
            'ã', 'a'),
            'à', 'a'),
            'ç', 'c'),
            'é', 'e'),
            'ê', 'e'),
            'í', 'i'),
            'ó', 'o'),
            'ô', 'o'),
            'õ', 'o'),
            'ú', 'u'),
            '''', ''),
            '-', ' ') AS geolocation_city,
            geolocation_state       
from new_geolocation_one
ORDER BY geolocation_city;


CREATE TABLE geolocation_real AS 
SELECT      geolocation_zip_code_prefix, geolocation_lat, geolocation_lng,
	    REPLACE
            (REPLACE
            (REPLACE
            (REPLACE
            (REPLACE
            (REPLACE
            (REPLACE
            (REPLACE
            (REPLACE
            (REPLACE
            (REPLACE
            (REPLACE
            (REPLACE
            (REPLACE (geolocation_city, 'antunes (igaratinga)', 'antunes'),
            'bacaxa (saquarema)   distrito', 'bacaxa'),
            'california da barra (barra do pirai)', 'california da barra'),
            'campo alegre de lourdes, bahia, brasil', 'campo alegre de lourdes'),
            'florian&oacute;polis', 'florianopolis'),
            'itabatan (mucuri)', 'itabatan'),
            'jacare (cabreuva)', 'jacare'),
            'monte gordo (camacari)   distrito', 'monte gordo'),
            'penedo (itatiaia)', 'penedo'),
            'praia grande (fundao)   distrito', 'praia grande'),
            'realeza (manhuacu)', 'realeza'),
            'rio de janeiro, rio de janeiro, brasil', 'rio de janeiro'),
            'tamoios (cabo frio)', 'tamoios'),
            '* cidade', 'cidade gaucha') AS geolocation_city,
            geolocation_state
FROM real_geolocation;  


DROP TABLE new_geolocation_one;

DROP TABLE real_geolocation;



UPDATE geolocation_real
SET geolocation_city = 'sao paulo'
WHERE geolocation_city = 'sp';

UPDATE geolocation_real
SET geolocation_city = 'rio de janeiro'
WHERE geolocation_city = 'rj';

UPDATE geolocation_real
SET geolocation_city = 'belo horizonte'
WHERE geolocation_city = 'bh';

UPDATE geolocation_real
SET geolocation_city = 'franca'
WHERE geolocation_zip_code_prefix = 14407;

UPDATE geolocation_real
SET geolocation_city = 'guarulhos'
WHERE geolocation_zip_code_prefix = 7174;

UPDATE geolocation_real
SET geolocation_city = 'lavras'
WHERE geolocation_zip_code_prefix = 37200;

UPDATE geolocation_real
SET geolocation_city = 'limeira do oeste'
WHERE geolocation_zip_code_prefix = 38295;

UPDATE geolocation_real
SET geolocation_city = 'arraial dajuda'
WHERE 	geolocation_state = 'BA' AND
        geolocation_city LIKE '%arraial d%';


UPDATE geolocation_real
SET geolocation_city = 'jacarei'
WHERE geolocation_city LIKE 'jacare%'
        AND geolocation_state = 'SP';

UPDATE geolocation_real
SET geolocation_city = 'santa barbara doeste'
WHERE geolocation_state = 'SP' AND
        geolocation_city LIKE '%santa barbara d%';

UPDATE geolocation_real
SET geolocation_city = 'sao paulo'
WHERE geolocation_state = 'SP' AND
        geolocation_city LIKE 'saopaulo';

UPDATE geolocation_real
SET geolocation_city = 'dias davila'
WHERE geolocation_city = 'dias d avila';


UPDATE geolocation_real
SET geolocation_city =  REPLACE
                        (REPLACE
                        (REPLACE
                        (REPLACE
                        (REPLACE
                        (REPLACE
                        (REPLACE(geolocation_city, 'd oeste', 'doeste'),
                        'd  oeste', 'doeste'),
                        'd  arco', 'darco'),
                        'd agua', 'dagua'),
                        'd alianca', 'dalianca'),
                        'd alho', 'dalho'),
                        'sao joao do pau d%26apos%3balho', 'sao joao do pau dalho');

UPDATE geolocation_real
SET geolocation_city = TRIM(geolocation_city); 

CREATE TEMP TABLE no_duplicates_geolocation AS 
SELECT  DISTINCT geolocation_zip_code_prefix, geolocation_lat,
        geolocation_lng, geolocation_city,
        geolocation_state
FROM geolocation_real
ORDER BY geolocation_zip_code_prefix; 

CREATE TABLE geolocation_tratada AS
SELECT *
FROM no_duplicates_geolocation

SELECT *
FROM geolocation_tratada

DROP TABLE no_duplicates_geolocation;

DROP TABLE geolocation_real



-- TABLE SELLERS TRATADA

CREATE TABLE sellers_real AS 
SELECT      seller_id, seller_zip_code_prefix,
            REPLACE
            (REPLACE
            (REPLACE
            (REPLACE
            (REPLACE
            (REPLACE
            (REPLACE
            (REPLACE
            (REPLACE
            (REPLACE
            (REPLACE
            (REPLACE
            (REPLACE
            (REPLACE
            (REPLACE
            (REPLACE
            (REPLACE
            (REPLACE
            (REPLACE
            (REPLACE
            (REPLACE
            (REPLACE
            (REPLACE
            (REPLACE
            (REPLACE (seller_city, 'andira-pr', 'andira'),
            'arraial d''ajuda (porto seguro)', 'arraial dajuda'),
            'auriflama/sp', 'auriflama'),
            'barbacena/ minas gerais', 'barbacena'),
            'carapicuiba / sao paulo', 'carapicuiba'),
            'cariacica / es', 'cariacica'),
            'jacarei / sao paulo', 'jacarei'),
            'lages - sc', 'lages'),
            'maua/sao paulo', 'maua'),
            'mogi das cruzes / sp', 'mogi das cruzes'),
            'novo hamburgo, rio grande do sul, brasil', 'novo hamburgo'),
            'pinhais/pr', 'pinhais'),
            'ribeirao preto / sao paulo', 'ribeirao preto'),
            'rio de janeiro / rio de janeiro', 'rio de janeiro'),
            'rio de janeiro \rio de janeiro', 'rio de janeiro'),
            'rio de janeiro, rio de janeiro, brasil', 'rio de janeiro'),
            'santa barbara d''oeste', 'santa barbara doeste'),
            'santo andre/sao paulo', 'santo andre'),
            'sao miguel d''oeste', 'sao miguel doeste'),
            'sao paulo - sp', 'sao paulo'),
            'sao paulo / sao paulo', 'sao paulo'),
            'sao sebastiao da grama/sp', 'sao sebastiao da grama'),
            'sbc/sp', 'sbcampo'),
            'sp / sp', 'sao paulo'),
            'vendas@creditparts.com.br', 'maringa') AS seller_city,
            seller_state
FROM sellers;  



UPDATE sellers_real
SET seller_city = 'sao paulo'
WHERE   seller_state = 'SP' AND 
        seller_city IN ('sao paulo sp', 'sp');

UPDATE sellers_real
SET seller_city = REPLACE(seller_city, 'd oeste', 'doeste');

UPDATE sellers_real
SET seller_city = 'rio de janeiro'
WHERE seller_city = 04482255; 


UPDATE sellers_real
SET seller_city = TRIM(seller_city);


CREATE TABLE sellers_tratada AS
SELECT * FROM sellers_real


SELECT * FROM sellers_tratada

DROP TABLE sellers_real


-- TABLE CUSTOMER TRATADA


CREATE TEMP TABLE real_customers AS 
SELECT  customer_id, customer_unique_id,
        customer_zip_code_prefix,
        REPLACE
        (REPLACE (customer_city, '-', ' '),
        '''', '') AS customer_city,
        customer_state
FROM customers;


CREATE TABLE customers_real AS 
SELECT  customer_id, customer_unique_id,
        customer_zip_code_prefix,
        REPLACE
        (REPLACE
        (REPLACE (customer_city, 'd oeste', 'doeste'),
        'd ajuda', 'dajuda'),
        'd avila', 'davila') AS customer_city,
        customer_state
FROM real_customers;


UPDATE customers_real
SET customer_city = TRIM(customer_city);


CREATE TABLE customers_tratada AS
SELECT * FROM customers_real

SELECT * FROM customers_tratada 

DROP TABLE customers_real

DROP TABLE real_customers


--  VIEW PRODUCT

CREATE VIEW vw_products AS
SELECT 
	p.product_id 
	, pcnt.product_category_name_english  AS category_name
FROM products p 
LEFT JOIN product_category_name_translation pcnt 
ON p.product_category_name = pcnt.product_category_name 

SELECT * FROM vw_products


-- VIEW LEADS

CREATE VIEW vw_leads AS 
SELECT  *
FROM leads_qualified lq 
LEFT JOIN leads_closed lc
ON lq.mql_id = lc.mql_id 

SELECT * FROM vw_leads

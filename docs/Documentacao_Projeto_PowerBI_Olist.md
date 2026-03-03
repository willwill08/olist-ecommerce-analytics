# 📊 Documentação do Projeto Power BI - Análise E-commerce Olist

## 📋 Visão Geral do Projeto

Este projeto Power BI foi desenvolvido para análise abrangente de dados de e-commerce da plataforma Olist, oferecendo insights estratégicos sobre vendas, clientes, vendedores e leads. O relatório apresenta uma visão 360° das operações comerciais, permitindo tomada de decisões baseada em dados para otimização de performance e crescimento do negócio.

### 🎯 Objetivos Principais
- **Análise de Performance de Vendas**: Monitoramento de receita, volume de pedidos e tendências temporais
- **Gestão de Clientes**: Compreensão do comportamento e distribuição geográfica dos clientes
- **Análise de Vendedores**: Avaliação de performance e distribuição regional dos sellers
- **Gestão de Leads**: Acompanhamento do funil de vendas e conversão de leads qualificados
- **Insights Operacionais**: Identificação de gargalos, oportunidades de melhoria e padrões de negócio

---

## 🗄️ Origem dos Dados

### Fonte Principal
- **SQL Server**: Banco de dados relacional contendo todas as tabelas transacionais e dimensionais
- **Estrutura Star Schema**: Modelo dimensional otimizado para análise com tabelas de fato e dimensões

### Tabelas Base
- **orders**: Pedidos e status de entrega
- **order_items**: Itens dos pedidos com preços e fretes
- **order_payments**: Informações de pagamento
- **order_reviews**: Avaliações dos clientes
- **customers**: Dados dos clientes
- **sellers**: Informações dos vendedores
- **products**: Catálogo de produtos
- **geolocation**: Dados geográficos
- **leads_qualified**: Leads qualificados
- **leads_closed**: Leads convertidos

---

## 🔧 Tratamento dos Dados

### 🎯 Objetivo: Consolidação de Dados de Pedidos
### 💡 Racional: Necessidade de agregar informações dispersas em múltiplas tabelas para criar uma visão unificada dos pedidos
### 🔍 Insight Esperado: Visão completa do ciclo de vida dos pedidos, incluindo valores, pagamentos, avaliações e status de entrega

```sql
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
        MAX(review_comment_message) AS last_comment
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
    
    -- Totais agregados
    isummary.total_items_value AS vlr_total_itens,
    isummary.total_freight_value AS vlr_total_freite,
    (isummary.total_items_value + isummary.total_freight_value) AS vlr_total_pedido_itens,
    ps.total_payment_value AS vlr_total_pago,
    ps.main_payment_type AS payment_type,
    ps.total_installments AS payment_installments,
    
    -- Avaliações agregadas
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
```

### 🎯 Objetivo: Padronização de Dados Geográficos
### 💡 Racional: Necessidade de normalizar nomes de cidades e estados para garantir consistência nas análises geográficas
### 🔍 Insight Esperado: Dados geográficos limpos e padronizados para análises precisas de distribuição regional

```sql
-- TABLE GEOLOCATION TRATADA
CREATE TEMP TABLE new_geolocation_one AS
SELECT  DISTINCT geolocation_zip_code_prefix, geolocation_lat,
        geolocation_lng, geolocation_city,
        geolocation_state
FROM geolocation
ORDER BY geolocation_zip_code_prefix; 

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

-- Continuação do tratamento com correções específicas de cidades
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

-- Correções específicas por CEP e padrões
UPDATE geolocation_real
SET geolocation_city = 'sao paulo'
WHERE geolocation_city = 'sp';

UPDATE geolocation_real
SET geolocation_city = 'rio de janeiro'
WHERE geolocation_city = 'rj';

UPDATE geolocation_real
SET geolocation_city = 'belo horizonte'
WHERE geolocation_city = 'bh';

-- Criação da tabela final tratada
CREATE TABLE geolocation_tratada AS
SELECT *
FROM no_duplicates_geolocation;
```

### 🎯 Objetivo: Normalização de Dados de Vendedores
### 💡 Racional: Padronização de informações de vendedores para análises consistentes de performance regional
### 🔍 Insight Esperado: Base de dados limpa de vendedores para análises de distribuição geográfica e performance

```sql
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

-- Correções específicas
UPDATE sellers_real
SET seller_city = 'sao paulo'
WHERE   seller_state = 'SP' AND 
        seller_city IN ('sao paulo sp', 'sp');

UPDATE sellers_real
SET seller_city = REPLACE(seller_city, 'd oeste', 'doeste');

-- Criação da tabela final
CREATE TABLE sellers_tratada AS
SELECT * FROM sellers_real;
```

### 🎯 Objetivo: Padronização de Dados de Clientes
### 💡 Racional: Normalização de informações de clientes para análises consistentes de comportamento e distribuição
### 🔍 Insight Esperado: Base de dados limpa de clientes para análises de segmentação e distribuição geográfica

```sql
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
SELECT * FROM customers_real;
```

### 🎯 Objetivo: Enriquecimento de Dados de Produtos
### 💡 Racional: Tradução de categorias de produtos para facilitar análises e relatórios em português
### 🔍 Insight Esperado: Catálogo de produtos com categorias em português para análises mais intuitivas

```sql
-- VIEW PRODUCT
CREATE VIEW vw_products AS
SELECT 
    p.product_id 
    , pcnt.product_category_name_english  AS category_name
FROM products p 
LEFT JOIN product_category_name_translation pcnt 
ON p.product_category_name = pcnt.product_category_name;
```

### 🎯 Objetivo: Consolidação de Dados de Leads
### 💡 Racional: Unificação de informações de leads qualificados e convertidos para análise do funil de vendas
### 🔍 Insight Esperado: Visão completa do processo de conversão de leads para otimização do funil de vendas

```sql
-- VIEW LEADS
CREATE VIEW vw_leads AS 
SELECT  *
FROM leads_qualified lq 
LEFT JOIN leads_closed lc
ON lq.mql_id = lc.mql_id;
```

---

## 📊 Estrutura das Páginas do Relatório

### 🏠 **Home Page**
**Propósito**: Página inicial com apresentação visual do projeto e navegação para as demais seções.

**Características**:
- Design atrativo com logo e identidade visual
- Navegação intuitiva para as diferentes análises
- Apresentação dos principais KPIs do negócio

### 👨‍👩‍👧‍👦 **Customers (Clientes)**
**Propósito**: Análise abrangente do comportamento e perfil dos clientes.

**Visualizações Principais**:
- **Distribuição Geográfica**: Mapa interativo mostrando concentração de clientes por região
- **Análise Demográfica**: Gráficos de distribuição por estado e cidade
- **Comportamento de Compra**: Análise de frequência e valor de compras
- **Segmentação**: Classificação de clientes por valor e recência

**Insights Fornecidos**:
- Identificação de mercados prioritários
- Padrões de comportamento de compra
- Oportunidades de expansão geográfica
- Estratégias de retenção de clientes

### 👥 **Sellers (Vendedores)**
**Propósito**: Análise de performance e distribuição dos vendedores da plataforma.

**Visualizações Principais**:
- **Performance por Vendedor**: Rankings e métricas de vendas
- **Distribuição Regional**: Concentração de vendedores por região
- **Análise de Produtos**: Categorias mais vendidas por vendedor
- **Métricas de Qualidade**: Avaliações e satisfação dos clientes

**Insights Fornecidos**:
- Identificação de vendedores top performers
- Oportunidades de expansão da base de vendedores
- Análise de concentração de risco
- Estratégias de desenvolvimento de vendedores

### 🎯 **Leads**
**Propósito**: Acompanhamento do funil de vendas e análise de conversão de leads.

**Visualizações Principais**:
- **Funil de Conversão**: Visualização do processo de qualificação e fechamento
- **Taxa de Conversão**: Métricas de eficiência do processo de vendas
- **Análise Temporal**: Tendências de geração e conversão de leads
- **Performance por Origem**: Efetividade de diferentes canais de captação

**Insights Fornecidos**:
- Identificação de gargalos no funil de vendas
- Otimização de processos de qualificação
- Análise de ROI por canal de marketing
- Estratégias de melhoria da taxa de conversão

### 📖 **Guia de Usuário**
**Propósito**: Documentação e orientações para utilização do relatório.

**Conteúdo**:
- Instruções de navegação
- Explicação das métricas e KPIs
- Dicas de interpretação dos dados
- Contatos para suporte

### 🔍 **Status_Tooltip**
**Propósito**: Página auxiliar para tooltips e informações contextuais.

**Funcionalidade**:
- Explicações detalhadas de métricas
- Definições de termos técnicos
- Informações adicionais sobre visualizações

---

## 🎯 Considerações Finais

### ✅ **Pontos Fortes do Projeto**
- **Estrutura Robusta**: Modelo dimensional bem estruturado com separação clara entre fatos e dimensões
- **Tratamento de Dados**: Limpeza e padronização abrangente dos dados geográficos e de clientes
- **Cobertura Completa**: Análise 360° cobrindo todos os aspectos do negócio
- **Interface Intuitiva**: Design limpo e navegação fácil entre as diferentes análises

### 🔧 **Oportunidades de Melhoria**
- **Atualização em Tempo Real**: Implementação de refresh automático dos dados
- **Alertas Inteligentes**: Configuração de notificações para métricas críticas
- **Análises Preditivas**: Incorporação de modelos de machine learning para previsões
- **Mobile Responsive**: Otimização para visualização em dispositivos móveis

### 📈 **Impacto Esperado**
Este relatório Power BI proporciona uma base sólida para tomada de decisões estratégicas, permitindo:
- **Otimização de Operações**: Identificação de gargalos e oportunidades de melhoria
- **Crescimento Sustentável**: Análise de tendências para planejamento estratégico
- **Melhoria da Experiência**: Insights sobre comportamento do cliente para personalização
- **Eficiência Operacional**: Monitoramento de KPIs para gestão proativa

### 🚀 **Próximos Passos Recomendados**
1. **Treinamento de Usuários**: Capacitação da equipe para utilização eficaz do relatório
2. **Definição de KPIs**: Estabelecimento de metas e indicadores de performance
3. **Processo de Revisão**: Implementação de rotinas de análise e tomada de decisão
4. **Evolução Contínua**: Feedback dos usuários para melhorias e novas funcionalidades

---

*Documentação criada para o projeto Power BI - Análise E-commerce Olist*  
*Versão: 1.0 | Data: Janeiro 2025*

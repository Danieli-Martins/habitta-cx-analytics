-- =====================================================================
-- 1. Criação das Tabelas Brutas (Raw Tables)
-- =====================================================================

CREATE TABLE habitta_atendimentos (
    id_atendimento INT,
    id_cliente INT,
    data_atendimento VARCHAR(50),
    hora_entrada_fila VARCHAR(50),
    hora_inicio_atendimento VARCHAR(50),
    hora_fim_atendimento VARCHAR(50),
    canal VARCHAR(50),
    funcionario VARCHAR(100)
);

CREATE TABLE habitta_motivo_contato (
    id_atendimento INT,
    servico_solicitado VARCHAR(150),
    motivo_atendimento VARCHAR(150)
);

CREATE TABLE habitta_pesquisa_satisfacao (
    id_atendimento INT,
    csat VARCHAR(10)
);

CREATE TABLE habitta_log_agentes (
    funcionario VARCHAR(100),
    data_log VARCHAR(50),
    hora_entrada VARCHAR(50),
    hora_saida VARCHAR(50),
    pausa_10 VARCHAR(50),
    pausa_20 VARCHAR(50),
    particular VARCHAR(50),
    reuniao VARCHAR(50),
    falha_tecnica VARCHAR(50)
);


-- =====================================================================
-- 2. Carga dos Dados (LOAD via CSV)
-- =====================================================================

COPY habitta_atendimentos 
FROM 'C:\dados\habitta_atendimentos.csv' 
WITH (FORMAT CSV, HEADER, DELIMITER ',', ENCODING 'UTF8');

COPY habitta_motivo_contato 
FROM 'C:\dados\habitta_motivo_contato.csv' 
WITH (FORMAT CSV, HEADER, DELIMITER ',', ENCODING 'UTF8');

COPY habitta_pesquisa_satisfacao 
FROM 'C:\dados\habitta_pesquisa_satisfacao.csv' 
WITH (FORMAT CSV, HEADER, DELIMITER ',', ENCODING 'UTF8');

COPY habitta_log_agentes 
FROM 'C:\dados\habitta_log_agentes.csv' 
WITH (FORMAT CSV, HEADER, DELIMITER ',', ENCODING 'UTF8');


-- =====================================================================
-- 3. Análise Exploratória de Dados (EDA) e Qualidade
-- =====================================================================

-- Validação de volumetria total
SELECT 'habitta_atendimentos' AS tabela, COUNT(*) AS total_linhas FROM habitta_atendimentos
UNION ALL
SELECT 'habitta_motivo_contato', COUNT(*) FROM habitta_motivo_contato
UNION ALL
SELECT 'habitta_pesquisa_satisfacao', COUNT(*) FROM habitta_pesquisa_satisfacao
UNION ALL
SELECT 'habitta_log_agentes', COUNT(*) FROM habitta_log_agentes;

-- Diagnóstico de Canais
SELECT canal, COUNT(*) AS total_atendimentos
FROM habitta_atendimentos
GROUP BY canal
ORDER BY total_atendimentos DESC;

-- Diagnóstico de Horários de Entrada na Fila
SELECT 
    LENGTH(hora_entrada_fila) AS caracteres, 
    COUNT(*) AS quantidade_linhas,
    MIN(hora_entrada_fila) AS exemplo_valor
FROM habitta_atendimentos
GROUP BY LENGTH(hora_entrada_fila)
ORDER BY caracteres ASC;

-- Diagnóstico de Horários de Início e Fim de Atendimento
SELECT 
    LENGTH(hora_inicio_atendimento) AS caracteres_inicio,
    LENGTH(hora_fim_atendimento) AS caracteres_fim,
    COUNT(*) AS quantidade_linhas,
    MIN(hora_fim_atendimento) AS exemplo_fim
FROM habitta_atendimentos
GROUP BY LENGTH(hora_inicio_atendimento), LENGTH(hora_fim_atendimento)
ORDER BY caracteres_inicio ASC, caracteres_fim ASC;

-- Diagnóstico de Padrão de Datas
SELECT 
    LENGTH(data_atendimento) AS caracteres_data, 
    COUNT(*) AS quantidade_linhas,
    MIN(data_atendimento) AS exemplo_data
FROM habitta_atendimentos
GROUP BY LENGTH(data_atendimento);

-- Integridade Temporal 1: Fim anterior ao início
SELECT id_atendimento, hora_inicio_atendimento, hora_fim_atendimento
FROM habitta_atendimentos
WHERE hora_fim_atendimento < hora_inicio_atendimento
LIMIT 5;

-- Integridade Temporal 2: Início anterior à entrada na fila
SELECT id_atendimento, hora_entrada_fila, hora_inicio_atendimento
FROM habitta_atendimentos
WHERE hora_inicio_atendimento < hora_entrada_fila
LIMIT 5;

-- Mapeamento de CSAT
SELECT 
    csat, 
    COUNT(*) AS quantidade_linhas
FROM habitta_pesquisa_satisfacao
GROUP BY csat
ORDER BY csat;

-- Mapeamento de Motivos de Atendimento
SELECT 
    motivo_atendimento, 
    COUNT(*) AS quantidade_linhas
FROM habitta_motivo_contato
GROUP BY motivo_atendimento
ORDER BY quantidade_linhas DESC;

-- Diagnóstico de Hífens na Tabela de Logs
SELECT 
    hora_entrada, 
    COUNT(*) AS quantidade_linhas
FROM habitta_log_agentes
WHERE hora_entrada = '-' OR hora_entrada NOT LIKE '%:%'
GROUP BY hora_entrada;


-- =====================================================================
-- 4. Camada de Transformação (Tabelas Físicas Analíticas)
-- =====================================================================

-- Tratamento de Logs de Agentes
DROP TABLE IF EXISTS tb_analytics_log_agentes CASCADE;

CREATE TABLE tb_analytics_log_agentes AS
SELECT 
    funcionario,
    TO_DATE(data_log, 'DD/MM/YYYY') AS data_log,
    NULLIF(hora_entrada, '-')::TIME AS hora_entrada,
    NULLIF(hora_saida, '-')::TIME AS hora_saida,
    NULLIF(pausa_10, '-')::TIME AS pausa_10,
    NULLIF(pausa_20, '-')::TIME AS pausa_20,
    NULLIF(particular, '-')::TIME AS particular,
    NULLIF(reuniao, '-')::TIME AS reuniao,
    NULLIF(falha_tecnica, '-')::TIME AS falha_tecnica
FROM habitta_log_agentes;

-- Tratamento e Enriquecimento de Atendimentos
CREATE TABLE tb_analytics_atendimentos AS
SELECT 
    id_atendimento,
    id_cliente,
    TO_DATE(data_atendimento, 'DD/MM/YYYY') AS data_atendimento,
    hora_entrada_fila::TIME AS hora_entrada_fila,
    hora_inicio_atendimento::TIME AS hora_inicio_atendimento,
    hora_fim_atendimento::TIME AS hora_fim_atendimento,
    (hora_inicio_atendimento::TIME - hora_entrada_fila::TIME) AS tempo_espera,
    (hora_fim_atendimento::TIME - hora_inicio_atendimento::TIME) AS tempo_atendimento,
    canal,
    funcionario
FROM habitta_atendimentos;

SELECT * FROM tb_analytics_atendimentos LIMIT 5;

-- Tratamento da Pesquisa de Satisfação
CREATE TABLE tb_analytics_pesquisa_satisfacao AS
SELECT 
    id_atendimento,
    csat::NUMERIC(3,1) AS csat
FROM habitta_pesquisa_satisfacao;

SELECT * FROM tb_analytics_pesquisa_satisfacao LIMIT 5;

-- Normalização de Motivos de Contato
CREATE TABLE tb_analytics_motivo_contato AS
SELECT 
    id_atendimento,
    servico_solicitado,
    motivo_atendimento    
FROM habitta_motivo_contato;

SELECT * FROM tb_analytics_motivo_contato LIMIT 5;


-- =====================================================================
-- 5. Tabelas de Dimensões (Star Schema)
-- =====================================================================

-- Dimensão de Agentes
DROP TABLE IF EXISTS dim_agentes CASCADE;
CREATE TABLE dim_agentes AS
SELECT 
    ROW_NUMBER() OVER (ORDER BY funcionario) AS sk_agente,
    funcionario AS nome_agente
FROM (
    SELECT DISTINCT funcionario FROM tb_analytics_atendimentos
    UNION
    SELECT DISTINCT funcionario FROM tb_analytics_log_agentes
) t
WHERE funcionario IS NOT NULL;
ALTER TABLE dim_agentes ADD PRIMARY KEY (sk_agente);
CREATE INDEX idx_dim_agentes_nome ON dim_agentes(nome_agente);

-- Dimensão de Motivos
DROP TABLE IF EXISTS dim_motivos CASCADE;
CREATE TABLE dim_motivos AS
SELECT 
    ROW_NUMBER() OVER (ORDER BY servico_solicitado, motivo_atendimento) AS sk_motivo,
    servico_solicitado,
    motivo_atendimento
FROM tb_analytics_motivo_contato
GROUP BY servico_solicitado, motivo_atendimento;
ALTER TABLE dim_motivos ADD PRIMARY KEY (sk_motivo);
CREATE INDEX idx_dim_motivos_par ON dim_motivos(servico_solicitado, motivo_atendimento);

-- Dimensão de Clientes
DROP TABLE IF EXISTS dim_clientes CASCADE;
CREATE TABLE dim_clientes AS
SELECT DISTINCT 
    id_cliente
FROM tb_analytics_atendimentos
WHERE id_cliente IS NOT NULL;
ALTER TABLE dim_clientes ADD PRIMARY KEY (id_cliente);

-- Dimensão de Calendário
DROP TABLE IF EXISTS dim_calendario CASCADE;
CREATE TABLE dim_calendario AS
SELECT DISTINCT
    data_atendimento AS data_ref,
    EXTRACT(YEAR FROM data_atendimento) AS ano,
    EXTRACT(MONTH FROM data_atendimento) AS mes,
    TO_CHAR(data_atendimento, 'TMMonth') AS nome_mes,
    EXTRACT(QUARTER FROM data_atendimento) AS trimestre,
    EXTRACT(DOW FROM data_atendimento) AS dia_semana_num
FROM tb_analytics_atendimentos
WHERE data_atendimento IS NOT NULL;
ALTER TABLE dim_calendario ADD PRIMARY KEY (data_ref);


-- =====================================================================
-- 6. Tabelas Fato (Star Schema)
-- =====================================================================

-- Fato Atendimentos
DROP TABLE IF EXISTS fato_atendimentos;

CREATE TABLE fato_atendimentos AS
SELECT 
    b.id_atendimento,
    b.id_cliente,
    b.data_atendimento,
    b.hora_entrada_fila,
    b.hora_inicio_atendimento,
    b.hora_fim_atendimento,
    b.canal,
    da.sk_agente,
    dm.sk_motivo,
    ps.csat,
    b.tempo_espera,
    b.tempo_atendimento
FROM tb_analytics_atendimentos b
LEFT JOIN tb_analytics_pesquisa_satisfacao ps ON b.id_atendimento = ps.id_atendimento
LEFT JOIN tb_analytics_motivo_contato mc ON b.id_atendimento = mc.id_atendimento
LEFT JOIN dim_agentes da ON b.funcionario = da.nome_agente
LEFT JOIN (
    SELECT servico_solicitado, motivo_atendimento, MIN(sk_motivo) AS sk_motivo
    FROM dim_motivos
    GROUP BY 1, 2
) dm ON mc.servico_solicitado = dm.servico_solicitado 
     AND mc.motivo_atendimento = dm.motivo_atendimento;

ALTER TABLE fato_atendimentos ADD PRIMARY KEY (id_atendimento);
CREATE INDEX idx_fato_sk_agente ON fato_atendimentos(sk_agente);
CREATE INDEX idx_fato_sk_motivo ON fato_atendimentos(sk_motivo);
CREATE INDEX idx_fato_data ON fato_atendimentos(data_atendimento);

-- Fato Jornada
DROP TABLE IF EXISTS fato_jornada;

CREATE TABLE fato_jornada AS
SELECT 
    d.sk_agente,             
    t.data_log AS data_ref,      
    t.hora_entrada,
    t.hora_saida,
    t.pausa_10,
    t.pausa_20,
    t.particular,
    t.reuniao,
    t.falha_tecnica
FROM tb_analytics_log_agentes t
JOIN dim_agentes d ON t.funcionario = d.nome_agente;

ALTER TABLE fato_jornada ADD COLUMN id_fato_jornada SERIAL PRIMARY KEY;
ALTER TABLE fato_jornada ADD CONSTRAINT fk_jornada_agente FOREIGN KEY (sk_agente) REFERENCES dim_agentes(sk_agente);


-- =====================================================================
-- 7. Validação Final das Fatos
-- =====================================================================

-- Teste de Cardinalidade
SELECT 
    (SELECT COUNT(*) FROM tb_analytics_atendimentos) AS total_origem,
    (SELECT COUNT(*) FROM fato_atendimentos) AS total_fato;

-- Teste de Preenchimento de Chaves e Métricas
SELECT 
    COUNT(*) AS total_linhas,
    COUNT(sk_agente) AS preenchidos_agente,
    COUNT(sk_motivo) AS preenchidos_motivo,
    COUNT(csat) AS preenchidos_csat
FROM fato_atendimentos;

-- Teste Analítico Prático
SELECT 
    da.nome_agente,
    dm.servico_solicitado,
    dm.motivo_atendimento,
    COUNT(f.id_atendimento) AS total_atendimentos,
    ROUND((EXTRACT(EPOCH FROM AVG(f.tempo_atendimento)) / 60)::numeric, 2) AS media_tempo_minutos
FROM fato_atendimentos f
JOIN dim_agentes da ON f.sk_agente = da.sk_agente
JOIN dim_motivos dm ON f.sk_motivo = dm.sk_motivo
GROUP BY 1, 2, 3
ORDER BY total_atendimentos DESC
LIMIT 10;

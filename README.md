# Habitta - End-to-End Business Intelligence & Customer Experience Analytics

---

## 1. Resumo Executivo

Este repositório contém um projeto ponta a ponta de Business Intelligence e Análise de Dados desenvolvido para simular um ambiente corporativo de Customer Experience (CX) e operações. O projeto modela a **Habitta**, uma empresa fictícia de serviços residenciais por assinatura, com atuação nas regiões Sul e Sudeste do Brasil.

O objetivo principal é transformar dados operacionais brutos em insights executivos acionáveis, monitorando acordos de nível de serviço (SLA), satisfação do cliente (CSAT), eficiência operacional (TMA/TME) e aderência da força de trabalho. A solução engloba todo o ciclo de vida dos dados: geração, armazenamento em banco de dados, Extração, Transformação e Carga (ETL), modelagem dimensional e um dashboard executivo interativo construído no Power BI.

---

## 2. Contexto de Negócio & Escopo

A Habitta gerencia planos de assinatura residencial que cobrem serviços como elétrica, hidráulica, chaveiro, pequenos reparos, limpeza residencial e manutenção de ar-condicionado.

### Estrutura Operacional
* **Base de Clientes Ativos:** 50.000 assinantes.
* **Canais de Atendimento:** WhatsApp (alto volume, resoluções rápidas), Chat (assistência em tempo real no app, alta variedade de solicitações) e E-mail (demandas complexas, reclamações formais, cancelamentos).
* **Força de Trabalho:** 30 atendentes, 3 supervisoras e 1 coordenador operando em três turnos de segunda a sábado (08:00 às 20:00).
* **Volume:** Aproximadamente 31.200 chamados mensais e 374.400 registros anuais.

---

## 3. Arquitetura de Dados & Pipeline ETL

O pipeline segue padrões modernos de engenharia de dados, movendo arquivos brutos não estruturados e semiestruturados para um banco de dados relacional robusto e, por fim, para um modelo semântico para visualização.

[Arquivos CSV Brutos (250k+ linhas)] ---> [PostgreSQL / pgAdmin (ELT & EDA)] ---> [Star Schema] ---> [Power BI (Modelo Semântico & DAX)]

### Banco de Dados e Armazenamento
* **Banco de Dados Relacional:** PostgreSQL hospedado em infraestrutura de servidor local.
* **Interface de Gerenciamento:** pgAdmin para execução de scripts SQL e validação de dados.
* **Tabelas Brutas (Raw):** `habitta_atendimentos`, `habitta_motivo_contato`, `habitta_pesquisa_satisfacao`, `habitta_log_agentes` e `habitta_horario_equipe`.

---

## 4. Análise Exploratória de Dados (EDA) & Tratamento de Qualidade

Antes da modelagem, um rigoroso perfilamento de dados foi conduzido via SQL para identificar anomalias, inconsistências estruturais e padrões de distribuição.

* **Integridade Temporal:** Verificação de que os horários de término dos chamados sucedem consistentemente os horários de início (`hora_fim_atendimento > hora_inicio_atendimento`) e que a entrada na fila precede o início.
* **Distribuição de CSAT:** Identificação de uma taxa de 39% de não resposta (`NULL`), alinhada com as expectativas de benchmark para pesquisas de satisfação, com notas válidas limitadas estritamente entre 1.0 e 5.0.
* **Limpeza de Logs de Agentes:** Detecção e tratamento de 299 anomalias na tabela `habitta_log_agentes`, onde erros de sistema registraram hifens (`-`) em vez de timestamps válidos para os registros de ponto, prevenindo falhas de pipeline durante a conversão de tipos (type casting).

---

## 5. Modelagem Dimensional (Star Schema)

O banco de dados foi estruturado em um Star Schema otimizado para performance analítica no Power BI:

| Tipo de Tabela | Nome da Tabela | Descrição |
| :--- | :--- | :--- |
| **Tabela Fato** | `fato_atendimentos` | Registros transacionais centrais das interações de atendimento ao cliente. |
| **Tabela Fato** | `fato_jornada` | Controle de ponto eletrônico, horas de turno e logs de pausas dos agentes. |
| **Dimensão** | `dim_agentes` | Perfis dos agentes, alocação de canal e escalas de turno. |
| **Dimensão** | `dim_motivos` | Árvore de categorização (Macrocategoria e serviço específico solicitado). |
| **Dimensão** | `dim_clientes` | Dados demográficos e detalhes da conta dos clientes. |
| **Dimensão** | `dim_calendario` | Tabela de datas padronizada para cálculos de inteligência de tempo (Time Intelligence). |

---

## 6. Indicadores-Chave de Desempenho & Regras de Negócio (DAX)

O modelo semântico incorpora medidas DAX avançadas para avaliar eficiência operacional, níveis de serviço e conformidade da força de trabalho.

### Métricas Operacionais
* **TMA (Tempo Médio de Atendimento):** Cálculo dinâmico da duração da conversa do agente formatado como `HH:MM:SS`.
* **TME (Tempo Médio de Espera):** Medição da duração na fila antes do engajamento do agente.
* **CSAT Equipe & Agente:** Notas médias de satisfação agregadas globalmente ou filtradas dinamicamente pela equipe selecionada.

### Regras de Aderência da Força de Trabalho
A aderência é computada com base em rigorosos parâmetros de conformidade corporativa:
* **Tolerância de Entrada:** Período de carência de até 5 minutos para o início do turno.
* **Limites de Pausa:** Máximo de 20 minutos totais para pausas de 10 minutos; máximo de 15 minutos permitidos para reuniões operacionais.
* **Penalidades:** Falhas técnicas, tempo particular e estouro de pausas categorizam automaticamente o dia do turno como não aderente.

---

## 7. Arquitetura do Dashboard em Power BI

O dashboard está estruturado em uma hierarquia de 5 abas projetadas para revisão executiva e monitoramento operacional, governadas por um filtro global de calendário sincronizado.

1. **Visão Geral (Canais Consolidados):** Resumo macro do volume total, TMA global, TME e CSAT em todos os canais de suporte.
2. **Análise do Canal Chat:** Visão operacional filtrada dedicada exclusivamente ao desempenho do chat no aplicativo.
3. **Análise do Canal E-mail:** Visão focada em solicitações de back-office, reclamações e tempos de resolução de chamados complexos.
4. **Análise do Canal WhatsApp:** Rastreamento operacional de alto volume para métricas de resposta rápida.
5. **Aderência da Força de Trabalho:** Painel de governança exibindo taxas de aderência individuais e de equipe, fatores de desvio (falhas técnicas, reuniões, pausas particulares) e percentuais de aderência por canal.

### Funcionalidades de Interatividade
* **Cross-Highlighting (Filtro Cruzado):** Selecionar uma categoria específica (ex: "Nota Fiscal") recalcula dinamicamente os cartões de volume e isola os gráficos de contribuição dos agentes.
* **Ativação Condicional de Cartões:** Métricas de contexto (como CSAT individual do agente ou aderência) permanecem em branco até que um colaborador específico seja selecionado, evitando interpretações macro distorcidas.

---

## 8. Stack Tecnológico

* **Banco de Dados:** PostgreSQL, SQL, pgAdmin
* **Modelagem de Dados:** Star Schema, Pipelines ELT
* **Visualização & Análise:** Power BI, DAX, Power Query

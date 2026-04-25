# Proposta de Tema — Projecto CDEG 2025/2026

**Curso:** Ciencia dos Dados para Economia e Gestao
**Ano lectivo:** 2025/2026
**Docente:** Pedro Bacao (pmab@fe.uc.pt)

## Membros do grupo

- Nome 1 — n.o mecanografico
- Nome 2 — n.o mecanografico
- Nome 3 — n.o mecanografico
- Nome 4 — n.o mecanografico

## Tema

**Rendibilidade e risco de diferentes activos financeiros: uma analise
comparada (2015–2025).**

## Dados a utilizar

Cotacoes diarias (Close ajustado) descarregadas do **Yahoo Finance**
(via pacote `yfinance` em Python, executado uma so vez para gerar o
CSV local). Universo de 12 activos cobrindo varias classes:

| Ticker      | Nome                       | Classe                  |
|-------------|----------------------------|-------------------------|
| `^GSPC`     | S&P 500                    | Accoes (EUA)            |
| `^STOXX50E` | Euro Stoxx 50              | Accoes (Zona Euro)      |
| `^FTSE`     | FTSE 100                   | Accoes (Reino Unido)    |
| `^N225`     | Nikkei 225                 | Accoes (Japao)          |
| `PSI20.LS`  | PSI-20                     | Accoes (Portugal)       |
| `GC=F`      | Ouro (futuros)             | Materias-primas         |
| `CL=F`      | Petroleo WTI (futuros)     | Materias-primas         |
| `BTC-USD`   | Bitcoin                    | Criptomoedas            |
| `ETH-USD`   | Ethereum                   | Criptomoedas            |
| `EURUSD=X`  | EUR / USD                  | Cambio                  |
| `^TNX`      | Yield Treasuries 10Y       | Obrigacoes (yield)      |
| `TLT`       | iShares 20+Y Treasury      | Obrigacoes (preco)      |

Resultado: cerca de **35 700 observacoes x 6 colunas** (date, ticker,
name, asset_class, close, return). CSV com 2.4 MB.

## Analise prevista (a expor na Shiny App)

1. **Exploracao e visualizacao**
   - Series de precos normalizados (base 100);
   - Rendibilidades cumulativas e periodos de drawdown;
   - Distribuicao das rendibilidades diarias (histograma, QQ-plot).

2. **Estatisticas descritivas**
   - Rendibilidade media anualizada, volatilidade anualizada;
   - Racio de Sharpe (assumindo taxa sem risco zero ou ajustavel);
   - Maximo drawdown, assimetria e curtose;
   - Matriz de correlacoes entre activos.

3. **Testes de hipoteses**
   - Teste t de Welch a igualdade de medias entre activos;
   - Teste de Jarque-Bera a normalidade das rendibilidades.

4. **Inferencia por reamostragem**
   - **Bootstrap** da media e do Sharpe;
   - **Simulacao de Monte Carlo** de trajectorias de preco (GBM).

5. **Machine Learning**
   - **Supervisionado**: regressao de uma rendibilidade sobre as
     outras (estilo factor model / beta CAPM);
   - **Nao supervisionado**: k-means dos activos no plano
     risco-retorno e clustering hierarquico sobre a matriz de
     correlacoes (dendrograma).

6. **Comunicacao** — relatorio em R Markdown (PDF) e visualizacoes
   interactivas via Plotly.

## Justificacao

O tema esta entre os exemplos sugeridos no enunciado ("rendibilidade
de diferentes activos") e permite ilustrar todos os topicos do
programa. Os dados sao oficiais (Yahoo Finance / fornecedores
underlying) e suficientemente ricos para suportar analise estatistica
significativa.

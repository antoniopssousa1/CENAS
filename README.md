# Projeto CDEG 2025/2026 — Rendibilidade e risco de diferentes activos

**Ciencia dos Dados para Economia e Gestao — FEUC 2025/2026**

Tema: **Rendibilidade e risco de diferentes activos financeiros (2015–2025)**.

Conjunto de 12 activos cobrindo accoes (S&P 500, Euro Stoxx 50, FTSE 100,
Nikkei 225, PSI-20), materias-primas (ouro, petroleo WTI), criptomoedas
(BTC, ETH), cambio (EUR/USD) e obrigacoes (yield 10Y EUA, ETF TLT).
Dados diarios descarregados do **Yahoo Finance** via `yfinance`.

## Estrutura

```
CDEG/
├── app.R                 # Shiny App (UI + server)
├── global.R              # Carregamento de dados e funcoes comuns
├── about.md              # Texto do separador "Sobre"
├── R/
│   ├── helpers.R         # Funcoes estatisticas e de ML
│   └── plots.R           # Funcoes de visualizacao (ggplot2)
├── data/
│   └── assets.csv        # ~35 700 linhas, 6 colunas (2.4 MB)
├── report/
│   ├── relatorio.Rmd     # Relatorio em R Markdown
│   └── relatorio.tex     # Esboco em LaTeX puro (alternativa)
├── generate_data.py      # Script Python que gera o CSV (yfinance)
├── proposta_tema.md      # Proposta a enviar ao docente
└── README.md
```

## Como executar

### Pre-requisitos R

```r
install.packages(c(
  "shiny", "shinythemes", "DT", "ggplot2", "dplyr", "tidyr",
  "readr", "lubridate", "scales", "broom", "boot", "forecast",
  "cluster", "factoextra", "plotly", "rmarkdown", "knitr", "tinytex"
))
tinytex::install_tinytex()    # apenas uma vez, para gerar o PDF
```

### Correr a Shiny App

```r
shiny::runApp()
```

A app **nao requer ligacao a Internet**: le tudo do CSV local.
A ligacao apenas e necessaria para (re)gerar o CSV via
`python generate_data.py`.

### Compilar o relatorio

```r
rmarkdown::render("report/relatorio.Rmd", output_format = "pdf_document")
```

ou, em alternativa, compilar o esboco LaTeX puro:

```bash
xelatex report/relatorio.tex
xelatex report/relatorio.tex
```

## Conformidade com o enunciado

- Apenas pacotes CRAN.
- Sem ligacao a Internet na app.
- 35 726 linhas << 200 000; 6 colunas << 100; CSV com 2.4 MB.
- Tempo de carregamento tipico: < 5 s.

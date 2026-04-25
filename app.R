# app.R --------------------------------------------------------------------
# Shiny App — Rendibilidade e risco de diferentes activos financeiros.
# Projecto CDEG 2025/2026 — FEUC.

source("global.R", local = FALSE)

# ===== UI =================================================================
ui <- fluidPage(
  theme = shinytheme("flatly"),
  titlePanel("Rendibilidade e risco de diferentes activos (2015–2025)"),

  sidebarLayout(
    sidebarPanel(
      width = 3,
      h4("Filtros globais"),
      selectInput("tickers", "Activos:",
                  choices = TICKER_CHO, selected = TICKER_CHO,
                  multiple = TRUE, selectize = TRUE),
      dateRangeInput("dates", "Periodo:",
                     start = DATE_RANGE[1], end = DATE_RANGE[2],
                     min   = DATE_RANGE[1], max = DATE_RANGE[2],
                     format = "yyyy-mm-dd", language = "pt"),
      hr(),
      h4("Parametros"),
      numericInput("rf", "Taxa sem risco anual (%):",
                   value = DEFAULT_RF, min = 0, max = 10, step = 0.25),
      hr(),
      helpText("Dados: Yahoo Finance (Close ajustado, diario)."),
      helpText("Projecto CDEG — FEUC 2025/2026.")
    ),

    mainPanel(
      width = 9,
      tabsetPanel(
        id = "main_tabs",

        # 1. Dados ---------------------------------------------------------
        tabPanel("Dados",
          br(),
          fluidRow(
            column(7, h4("Pre-visualizacao"),
                   DT::DTOutput("tbl_data")),
            column(5, h4("Estrutura"),
                   verbatimTextOutput("data_structure"),
                   h4("Observacoes em falta"),
                   verbatimTextOutput("missing_summary"))
          )
        ),

        # 2. Exploracao ----------------------------------------------------
        tabPanel("Exploracao",
          br(),
          h4("Cotacoes normalizadas (base 100)"),
          plotly::plotlyOutput("plot_index", height = "420px"),
          br(),
          h4("Rendibilidade cumulativa (%)"),
          plotly::plotlyOutput("plot_cum", height = "380px"),
          br(),
          h4("Distribuicao das rendibilidades diarias"),
          plotOutput("plot_dist", height = "520px")
        ),

        # 3. Risco e retorno ----------------------------------------------
        tabPanel("Risco e retorno",
          br(),
          h4("Estatisticas (anualizadas)"),
          DT::DTOutput("tbl_stats"),
          br(),
          h4("Plano risco-retorno"),
          plotly::plotlyOutput("plot_rr", height = "480px"),
          br(),
          h4("Matriz de correlacoes"),
          plotOutput("plot_corr", height = "520px")
        ),

        # 4. Inferencia ----------------------------------------------------
        tabPanel("Inferencia",
          br(),
          h4("Teste t (Welch) entre dois activos"),
          fluidRow(
            column(4, selectInput("ttest_a1", "Activo 1:",
                                  choices = TICKER_CHO,
                                  selected = "^GSPC")),
            column(4, selectInput("ttest_a2", "Activo 2:",
                                  choices = TICKER_CHO,
                                  selected = "BTC-USD"))
          ),
          verbatimTextOutput("ttest_out"),
          hr(),
          h4("Teste de Jarque-Bera a normalidade"),
          fluidRow(
            column(4, selectInput("jb_asset", "Activo:",
                                  choices = TICKER_CHO,
                                  selected = "^GSPC"))
          ),
          verbatimTextOutput("jb_out"),
          hr(),
          h4("Bootstrap da rendibilidade media e Sharpe"),
          fluidRow(
            column(4, selectInput("boot_asset", "Activo:",
                                  choices = TICKER_CHO,
                                  selected = "^GSPC")),
            column(3, numericInput("boot_R", "Replicas (R):",
                                   1000, min = 200, max = 5000, step = 200))
          ),
          fluidRow(
            column(6, plotOutput("plot_boot_mu",  height = "320px")),
            column(6, plotOutput("plot_boot_sh",  height = "320px"))
          ),
          hr(),
          h4("Monte Carlo: trajectorias de preco (GBM)"),
          fluidRow(
            column(4, selectInput("mc_asset", "Activo:",
                                  choices = TICKER_CHO,
                                  selected = "^GSPC")),
            column(3, numericInput("mc_steps", "Dias:",
                                   252, min = 20, max = 1260, step = 20)),
            column(3, numericInput("mc_paths", "Trajectorias:",
                                   200, min = 20, max = 2000, step = 20))
          ),
          plotOutput("plot_mc", height = "440px")
        ),

        # 5. Machine Learning ---------------------------------------------
        tabPanel("Machine Learning",
          br(),
          h4("Clustering k-means no plano risco-retorno"),
          fluidRow(
            column(3, sliderInput("k_clusters", "Numero de clusters (k):",
                                  min = 2, max = 5, value = 3))
          ),
          plotOutput("plot_clusters", height = "440px"),
          br(),
          h4("Dendrograma sobre 1 - |correlacao|"),
          plotOutput("plot_dendro", height = "420px"),
          hr(),
          h4("Regressao linear: rendibilidade do alvo ~ outras (factor exposure)"),
          fluidRow(
            column(4, selectInput("lm_target", "Activo alvo:",
                                  choices = TICKER_CHO,
                                  selected = "PSI20.LS"))
          ),
          verbatimTextOutput("lm_out"),
          h4("Validacao cruzada 5-fold"),
          tableOutput("cv_out")
        ),

        # 6. Sobre ---------------------------------------------------------
        tabPanel("Sobre",
          br(),
          includeMarkdown("about.md")
        )
      )
    )
  )
)

# ===== SERVER =============================================================
server <- function(input, output, session) {

  # Reactive: dados filtrados
  d <- reactive({
    req(input$tickers, input$dates)
    filter_data(assets, input$tickers, input$dates) |>
      recompute_returns()
  })

  stats_df <- reactive({
    risk_return_stats(d(), rf_annual_pct = input$rf)
  })

  # 1. Dados ---------------------------------------------------------------
  output$tbl_data <- DT::renderDT({
    DT::datatable(d(),
                  options = list(pageLength = 12, scrollX = TRUE),
                  rownames = FALSE) |>
      DT::formatRound(c("close", "return"), digits = 4)
  })

  output$missing_summary <- renderPrint({
    na_counts <- sapply(d(), \(x) sum(is.na(x)))
    cat("NA por coluna:\n"); print(na_counts)
    cat(sprintf("\nLinhas: %d   Colunas: %d\n", nrow(d()), ncol(d())))
  })

  output$data_structure <- renderPrint({ str(d()) })

  # 2. Exploracao ----------------------------------------------------------
  output$plot_index <- plotly::renderPlotly({
    plotly::ggplotly(plot_index100(d()))
  })

  output$plot_cum <- plotly::renderPlotly({
    plotly::ggplotly(plot_cum_return(d()))
  })

  output$plot_dist <- renderPlot({ plot_return_dist(d()) })

  # 3. Risco e retorno -----------------------------------------------------
  output$tbl_stats <- DT::renderDT({
    DT::datatable(stats_df(),
                  options = list(pageLength = 12, scrollX = TRUE),
                  rownames = FALSE)
  })

  output$plot_rr <- plotly::renderPlotly({
    plotly::ggplotly(plot_risk_return(stats_df()), tooltip = c("label","x","y"))
  })

  output$plot_corr <- renderPlot({ plot_corr_heatmap(d()) })

  # 4. Inferencia ----------------------------------------------------------
  output$ttest_out <- renderPrint({
    req(input$ttest_a1 != input$ttest_a2)
    res <- ttest_two_assets(d(), input$ttest_a1, input$ttest_a2)
    if (is.null(res)) cat("Dados insuficientes.\n") else print(res)
  })

  output$jb_out <- renderPrint({
    r <- d()$return[d()$ticker == input$jb_asset]
    res <- jarque_bera(r)
    cat(sprintf("Activo: %s\n", input$jb_asset))
    cat(sprintf("n               = %d\n", res$n))
    cat(sprintf("Skewness        = %.4f\n", res$skewness))
    cat(sprintf("Excess kurtosis = %.4f\n", res$excess_kurtosis))
    cat(sprintf("JB statistic    = %.4f  (df = %d)\n", res$stat, res$df))
    cat(sprintf("p-value         = %.4g\n", res$p.value))
    cat(if (is.na(res$p.value) || res$p.value > 0.05)
        "Nao se rejeita normalidade ao nivel 5%.\n" else
        "Rejeita-se normalidade ao nivel 5%.\n")
  })

  boot_obj <- reactive({
    r <- d()$return[d()$ticker == input$boot_asset]
    r <- r[!is.na(r)]
    req(length(r) > 30)
    boot_mean_sharpe(r, R = input$boot_R, rf_annual_pct = input$rf)
  })

  output$plot_boot_mu <- renderPlot({
    plot_boot_density(boot_obj(), idx = 1, label = "Rendib. media anualizada (%)")
  })
  output$plot_boot_sh <- renderPlot({
    plot_boot_density(boot_obj(), idx = 2, label = "Sharpe anualizado")
  })

  output$plot_mc <- renderPlot({
    r  <- d()$return[d()$ticker == input$mc_asset] / 100
    r  <- r[!is.na(r)]
    p  <- d()$close[d()$ticker == input$mc_asset]
    S0 <- tail(p[!is.na(p)], 1)
    M  <- mc_gbm(S0, mu_d = mean(r), sigma_d = sd(r),
                 n_steps = input$mc_steps, n_paths = input$mc_paths)
    plot_mc_paths(M)
  })

  # 5. Machine Learning ----------------------------------------------------
  cl_obj <- reactive({
    req(nrow(stats_df()) >= input$k_clusters)
    cluster_assets(stats_df(), k = input$k_clusters)
  })

  output$plot_clusters <- renderPlot({ plot_clusters_rr(cl_obj()) })

  output$plot_dendro <- renderPlot({
    d2 <- cor_distance(d())
    req(attr(d2, "Size") >= 3)
    plot_dendrogram(d2, k = input$k_clusters)
  })

  output$lm_out <- renderPrint({
    fit <- factor_lm(d(), input$lm_target)
    if (is.null(fit)) { cat("Activo nao disponivel no filtro.\n"); return() }
    print(summary(fit))
  })

  output$cv_out <- renderTable({
    fit <- factor_lm(d(), input$lm_target)
    if (is.null(fit)) return(data.frame(Mensagem = "Indisponivel"))
    W   <- returns_wide(d()) |> tidyr::drop_na()
    res <- cv_lm(W, formula(fit), k = 5)
    data.frame(
      Modelo     = paste("Alvo:", input$lm_target),
      RMSE_medio = res$rmse_mean,
      RMSE_dp    = res$rmse_sd,
      R2_medio   = res$r2_mean,
      R2_dp      = res$r2_sd
    )
  })
}

# ===== EXECUTAR ===========================================================
shinyApp(ui, server)

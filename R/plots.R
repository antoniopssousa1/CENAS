# R/plots.R ---------------------------------------------------------------
# Funcoes de visualizacao (ggplot2 / plotly).

theme_cdeg <- function() {
  ggplot2::theme_minimal(base_size = 13) +
    ggplot2::theme(
      panel.grid.minor = ggplot2::element_blank(),
      legend.position  = "bottom",
      plot.title       = ggplot2::element_text(face = "bold")
    )
}

# Series de precos normalizados a 100
plot_index100 <- function(df) {
  d <- to_index_100(df)
  ggplot2::ggplot(d, ggplot2::aes(date, index100, colour = name)) +
    ggplot2::geom_line(linewidth = 0.7) +
    ggplot2::scale_y_continuous(labels = scales::comma) +
    ggplot2::labs(title = "Cotacoes normalizadas (base 100 na primeira data)",
                  x = NULL, y = "Indice (base 100)", colour = NULL) +
    theme_cdeg()
}

# Rendibilidade cumulativa em %
plot_cum_return <- function(df) {
  d <- df |>
    recompute_returns() |>
    dplyr::group_by(ticker, name) |>
    dplyr::arrange(date, .by_group = TRUE) |>
    dplyr::mutate(cum = (cumprod(1 + dplyr::coalesce(return, 0) / 100) - 1) * 100) |>
    dplyr::ungroup()
  ggplot2::ggplot(d, ggplot2::aes(date, cum, colour = name)) +
    ggplot2::geom_line(linewidth = 0.7) +
    ggplot2::geom_hline(yintercept = 0, linetype = "dashed", colour = "grey50") +
    ggplot2::labs(title = "Rendibilidade cumulativa (%)",
                  x = NULL, y = "Cum. return (%)", colour = NULL) +
    theme_cdeg()
}

# Distribuicao das rendibilidades diarias (facetada por activo)
plot_return_dist <- function(df) {
  ggplot2::ggplot(df, ggplot2::aes(return, fill = name)) +
    ggplot2::geom_histogram(bins = 60, colour = "white", alpha = 0.85) +
    ggplot2::facet_wrap(~ name, scales = "free") +
    ggplot2::labs(title = "Distribuicao das rendibilidades diarias (%)",
                  x = "Rendibilidade diaria (%)", y = "Frequencia") +
    ggplot2::guides(fill = "none") +
    theme_cdeg()
}

# Mapa de calor da matriz de correlacoes
plot_corr_heatmap <- function(df) {
  W <- returns_wide(df) |> tidyr::drop_na()
  W <- W[, setdiff(names(W), "date"), drop = FALSE]
  if (ncol(W) < 2) return(NULL)
  C <- stats::cor(W, use = "complete.obs")
  d <- as.data.frame(as.table(C))
  ggplot2::ggplot(d, ggplot2::aes(Var1, Var2, fill = Freq)) +
    ggplot2::geom_tile() +
    ggplot2::geom_text(ggplot2::aes(label = sprintf("%.2f", Freq)),
                       colour = "black", size = 3) +
    ggplot2::scale_fill_gradient2(low = "#3b4cc0", mid = "grey90",
                                  high = "#b40426", midpoint = 0,
                                  limits = c(-1, 1)) +
    ggplot2::labs(title = "Correlacoes entre rendibilidades diarias",
                  x = NULL, y = NULL, fill = "r") +
    ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 45, hjust = 1)) +
    theme_cdeg()
}

# Diagrama risco-retorno
plot_risk_return <- function(stats_df) {
  ggplot2::ggplot(stats_df,
                  ggplot2::aes(vol_ann, mean_ann,
                               colour = asset_class, label = name)) +
    ggplot2::geom_point(size = 3.5, alpha = 0.9) +
    ggplot2::geom_text(nudge_y = 0.6, size = 3, show.legend = FALSE) +
    ggplot2::geom_hline(yintercept = 0, linetype = "dashed", colour = "grey50") +
    ggplot2::labs(title = "Plano risco-retorno (anualizados)",
                  x = "Volatilidade anualizada (%)",
                  y = "Rendibilidade media anualizada (%)",
                  colour = "Classe") +
    theme_cdeg()
}

# Bootstrap: histograma de uma estatistica replicada
plot_boot_density <- function(boot_obj, idx = 1, label = "estatistica") {
  vals <- boot_obj$t[, idx]
  ci <- boot::boot.ci(boot_obj, type = "perc", index = idx)$percent[4:5]
  ggplot2::ggplot(data.frame(x = vals), ggplot2::aes(x)) +
    ggplot2::geom_histogram(ggplot2::aes(y = ggplot2::after_stat(density)),
                            bins = 40, fill = "#4C78A8", colour = "white") +
    ggplot2::geom_density(linewidth = 1) +
    ggplot2::geom_vline(xintercept = ci, linetype = "dashed", colour = "red") +
    ggplot2::labs(title = sprintf("Bootstrap: %s", label),
                  subtitle = sprintf("IC 95%% percentil: [%.3f, %.3f]",
                                     ci[1], ci[2]),
                  x = label, y = "Densidade") +
    theme_cdeg()
}

# Trajectorias Monte Carlo (GBM)
plot_mc_paths <- function(M, n_show = 50) {
  n_show <- min(n_show, ncol(M))
  d <- data.frame(
    step = rep(seq_len(nrow(M)) - 1, n_show),
    path = rep(seq_len(n_show), each = nrow(M)),
    val  = as.vector(M[, seq_len(n_show)])
  )
  q <- t(apply(M, 1, stats::quantile, probs = c(0.05, 0.5, 0.95)))
  qd <- data.frame(step = seq_len(nrow(M)) - 1,
                   p05 = q[, 1], p50 = q[, 2], p95 = q[, 3])
  ggplot2::ggplot() +
    ggplot2::geom_line(data = d,
                       ggplot2::aes(step, val, group = path),
                       colour = "grey70", alpha = 0.4) +
    ggplot2::geom_ribbon(data = qd,
                         ggplot2::aes(step, ymin = p05, ymax = p95),
                         fill = "#4C78A8", alpha = 0.25) +
    ggplot2::geom_line(data = qd,
                       ggplot2::aes(step, p50),
                       colour = "#1F3B73", linewidth = 1) +
    ggplot2::labs(title = "Simulacao Monte Carlo (GBM)",
                  subtitle = "Banda 5%-95% e mediana sobre as trajectorias",
                  x = "Dias de negociacao", y = "Preco simulado") +
    theme_cdeg()
}

# Cluster k-means no plano risco-retorno
plot_clusters_rr <- function(cl_obj) {
  factoextra::fviz_cluster(cl_obj$km, data = cl_obj$scaled,
                           repel = TRUE, labelsize = 11,
                           main = "Clusters no plano risco-retorno (padronizado)")
}

# Dendrograma de clustering hierarquico sobre 1-|cor|
plot_dendrogram <- function(d, k = 3) {
  hc <- stats::hclust(d, method = "average")
  factoextra::fviz_dend(hc, k = k, cex = 0.8, rect = TRUE,
                        main = "Dendrograma — distancia 1 - |corr|")
}

# R/helpers.R --------------------------------------------------------------
# Funcoes estatisticas e de manipulacao de dados.

# --- Filtros e transformacoes --------------------------------------------

filter_data <- function(df, tickers, dates) {
  df |>
    dplyr::filter(ticker %in% tickers,
                  date >= dates[1], date <= dates[2]) |>
    dplyr::group_by(ticker) |>
    dplyr::arrange(date, .by_group = TRUE) |>
    dplyr::ungroup()
}

# Recalcula rendibilidades simples por ticker (em %)
recompute_returns <- function(df) {
  df |>
    dplyr::group_by(ticker) |>
    dplyr::arrange(date, .by_group = TRUE) |>
    dplyr::mutate(return = (close / dplyr::lag(close) - 1) * 100) |>
    dplyr::ungroup()
}

# Indexa cada serie para 100 na primeira data observada (no filtro)
to_index_100 <- function(df) {
  df |>
    dplyr::group_by(ticker) |>
    dplyr::arrange(date, .by_group = TRUE) |>
    dplyr::mutate(index100 = 100 * close / dplyr::first(close)) |>
    dplyr::ungroup()
}

# Tabela larga (date x ticker) das rendibilidades diarias
returns_wide <- function(df) {
  df |>
    dplyr::select(date, ticker, return) |>
    tidyr::pivot_wider(names_from = ticker, values_from = return)
}

# --- Estatisticas de risco e retorno -------------------------------------

# Maximo drawdown (pico->vale) em percentagem
max_drawdown <- function(prices) {
  prices <- as.numeric(prices)
  prices <- prices[!is.na(prices)]
  if (length(prices) < 2) return(NA_real_)
  peak <- cummax(prices)
  dd   <- (prices - peak) / peak
  min(dd, na.rm = TRUE) * 100
}

# Estatisticas por activo: media, vol, Sharpe, drawdown, skew, kurt
risk_return_stats <- function(df, rf_annual_pct = 0,
                              freq = TRADING_DAYS) {
  rf_daily <- rf_annual_pct / freq          # em %
  df |>
    dplyr::group_by(ticker, name, asset_class) |>
    dplyr::summarise(
      n            = sum(!is.na(return)),
      mean_d       = mean(return, na.rm = TRUE),
      sd_d         = sd(return,   na.rm = TRUE),
      mean_ann     = mean_d * freq,
      vol_ann      = sd_d * sqrt(freq),
      sharpe_ann   = (mean_d - rf_daily) / sd_d * sqrt(freq),
      max_dd_pct   = max_drawdown(close),
      skewness     = sk(return),
      kurtosis_ex  = kt(return),
      .groups = "drop"
    ) |>
    dplyr::mutate(dplyr::across(where(is.numeric), \(x) round(x, 4)))
}

# Skewness e curtose em excesso (formulas amostrais)
sk <- function(x) {
  x <- x[!is.na(x)]; n <- length(x); if (n < 3) return(NA_real_)
  m <- mean(x); s <- sd(x); if (s == 0) return(NA_real_)
  (sum((x - m)^3) / n) / s^3
}
kt <- function(x) {
  x <- x[!is.na(x)]; n <- length(x); if (n < 4) return(NA_real_)
  m <- mean(x); s <- sd(x); if (s == 0) return(NA_real_)
  (sum((x - m)^4) / n) / s^4 - 3
}

# --- Testes de hipoteses --------------------------------------------------

# Teste t de Welch a igualdade das medias das rendibilidades de dois activos
ttest_two_assets <- function(df, t1, t2) {
  x <- df$return[df$ticker == t1]
  y <- df$return[df$ticker == t2]
  x <- x[!is.na(x)]; y <- y[!is.na(y)]
  if (length(x) < 2 || length(y) < 2) return(NULL)
  stats::t.test(x, y, var.equal = FALSE)
}

# Teste de Jarque-Bera a normalidade (sem dependencias externas)
jarque_bera <- function(x) {
  x <- x[!is.na(x)]; n <- length(x)
  if (n < 8) return(list(stat = NA, df = 2, p.value = NA))
  S <- sk(x); K <- kt(x)
  JB <- (n / 6) * (S^2 + (K^2) / 4)
  list(stat = JB, df = 2, p.value = stats::pchisq(JB, df = 2, lower.tail = FALSE),
       skewness = S, excess_kurtosis = K, n = n)
}

# --- Reamostragem ---------------------------------------------------------

# Bootstrap da media e do Sharpe anualizado
boot_mean_sharpe <- function(returns, R = 1000, freq = TRADING_DAYS,
                             rf_annual_pct = 0, seed = 123) {
  set.seed(seed)
  rf_d <- rf_annual_pct / freq
  stat <- function(data, idx) {
    r <- data[idx]
    mu <- mean(r, na.rm = TRUE); sg <- sd(r, na.rm = TRUE)
    c(mean_ann = mu * freq,
      sharpe   = (mu - rf_d) / sg * sqrt(freq))
  }
  boot::boot(returns, statistic = stat, R = R)
}

# Simulacao Monte Carlo de trajectorias de preco (GBM diario)
mc_gbm <- function(S0, mu_d, sigma_d, n_steps = 252, n_paths = 200, seed = 7) {
  set.seed(seed)
  Z <- matrix(stats::rnorm(n_steps * n_paths), nrow = n_steps)
  log_ret <- (mu_d - 0.5 * sigma_d^2) + sigma_d * Z      # log-returns
  paths <- S0 * exp(apply(log_ret, 2, cumsum))
  rbind(rep(S0, n_paths), paths)
}

# --- Machine Learning ----------------------------------------------------

# Regressao linear: rendibilidade do alvo ~ rendibilidades dos restantes
factor_lm <- function(df, target_ticker) {
  W <- returns_wide(df) |> tidyr::drop_na()
  if (!target_ticker %in% names(W)) return(NULL)
  rhs <- setdiff(names(W), c("date", target_ticker))
  fml <- stats::as.formula(
    paste("`", target_ticker, "` ~ ", paste0("`", rhs, "`", collapse = " + "), sep = "")
  )
  stats::lm(fml, data = W)
}

# Validacao cruzada k-fold para a regressao
cv_lm <- function(df, formula, k = 5, seed = 42) {
  set.seed(seed)
  df <- df[sample(nrow(df)), ]
  folds <- cut(seq_len(nrow(df)), breaks = k, labels = FALSE)
  rmses <- numeric(k); r2s <- numeric(k)
  y_name <- all.vars(formula)[1]
  for (i in seq_len(k)) {
    test  <- df[folds == i, ]; train <- df[folds != i, ]
    fit   <- stats::lm(formula, data = train)
    pred  <- stats::predict(fit, newdata = test)
    y     <- test[[y_name]]
    rmses[i] <- sqrt(mean((y - pred)^2, na.rm = TRUE))
    r2s[i]   <- 1 - sum((y - pred)^2, na.rm = TRUE) /
                    sum((y - mean(y, na.rm = TRUE))^2, na.rm = TRUE)
  }
  list(rmse_mean = mean(rmses), rmse_sd = sd(rmses),
       r2_mean   = mean(r2s),   r2_sd   = sd(r2s))
}

# k-means dos activos no plano (vol_ann, mean_ann)
cluster_assets <- function(stats_df, k = 3, seed = 7) {
  set.seed(seed)
  m <- stats_df |> dplyr::select(vol_ann, mean_ann) |> as.matrix()
  rownames(m) <- stats_df$name
  ms <- scale(m)
  km <- stats::kmeans(ms, centers = min(k, nrow(ms) - 1), nstart = 25)
  list(km = km, profile = stats_df, scaled = ms)
}

# Distancia 1-|cor| para clustering hierarquico sobre correlacoes
cor_distance <- function(df) {
  W <- returns_wide(df) |> tidyr::drop_na()
  W <- W[, setdiff(names(W), "date"), drop = FALSE]
  C <- stats::cor(W, use = "complete.obs")
  stats::as.dist(1 - abs(C))
}

# global.R -----------------------------------------------------------------
# Carregamento de pacotes, dados e funcoes comuns a UI e ao server.
# Executado uma vez no arranque da Shiny App.

suppressPackageStartupMessages({
  library(shiny)
  library(shinythemes)
  library(DT)
  library(ggplot2)
  library(dplyr)
  library(tidyr)
  library(readr)
  library(lubridate)
  library(scales)
  library(broom)
  library(boot)
  library(cluster)
  library(factoextra)
  library(plotly)
})

source("R/helpers.R", local = FALSE)
source("R/plots.R",   local = FALSE)

# Carregar dados ----------------------------------------------------------
assets <- readr::read_csv(
  "data/assets.csv",
  show_col_types = FALSE,
  col_types = cols(
    date        = col_date(format = "%Y-%m-%d"),
    ticker      = col_character(),
    name        = col_character(),
    asset_class = col_character(),
    close       = col_double(),
    return      = col_double()
  )
)

# Vectores uteis para a UI ------------------------------------------------
TICKERS     <- assets |> dplyr::distinct(ticker, name) |> dplyr::arrange(name)
TICKER_CHO  <- setNames(TICKERS$ticker, TICKERS$name)
DATE_RANGE  <- range(assets$date, na.rm = TRUE)
TRADING_DAYS <- 252            # aproximacao classica para anualizar

# Constantes ---------------------------------------------------------------
DEFAULT_RF <- 0                # taxa sem risco anual (%) por omissao

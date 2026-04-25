"""Descarrega cotacoes diarias do Yahoo Finance e grava data/assets.csv.

Tema do projecto (alinhado com a sugestao do enunciado: "rendibilidade
de diferentes activos"): comparar a evolucao de varias classes de
activos financeiros entre 2015 e hoje.

Executar uma vez (requer ligacao a Internet APENAS para gerar o CSV;
a Shiny App nao precisa de Internet):

    python generate_data.py
"""
from __future__ import annotations

import os
import sys
import time
import pandas as pd
import yfinance as yf

# ---------------------------------------------------------------------------
# Universo de activos
# ---------------------------------------------------------------------------
ASSETS = [
    # ticker        nome legivel               classe
    ("^GSPC",       "S&P 500",                 "Accoes (EUA)"),
    ("^STOXX50E",   "Euro Stoxx 50",           "Accoes (Zona Euro)"),
    ("^FTSE",       "FTSE 100",                "Accoes (Reino Unido)"),
    ("^N225",       "Nikkei 225",              "Accoes (Japao)"),
    ("PSI20.LS",    "PSI-20",                  "Accoes (Portugal)"),
    ("GC=F",        "Ouro (futuros)",          "Materias-primas"),
    ("CL=F",        "Petroleo WTI (futuros)",  "Materias-primas"),
    ("BTC-USD",     "Bitcoin",                 "Criptomoedas"),
    ("ETH-USD",     "Ethereum",                "Criptomoedas"),
    ("EURUSD=X",    "EUR / USD",               "Cambio"),
    ("^TNX",        "Yield Treasuries 10Y",    "Obrigacoes (yield)"),
    ("TLT",         "iShares 20+Y Treasury",   "Obrigacoes (preco)"),
]

START = "2015-01-01"
END   = None     # ate ao dia de hoje
OUT   = os.path.join(os.path.dirname(__file__), "data", "assets.csv")

# ---------------------------------------------------------------------------

def download_one(ticker: str) -> pd.DataFrame:
    """Descarrega o historico diario (Close ajustado) para um ticker."""
    df = yf.download(
        ticker, start=START, end=END,
        progress=False, auto_adjust=True, threads=False,
    )
    if df is None or df.empty:
        return pd.DataFrame()
    if isinstance(df.columns, pd.MultiIndex):
        df.columns = df.columns.get_level_values(0)
    out = df[["Close"]].rename(columns={"Close": "close"}).copy()
    out.index.name = "date"
    return out.reset_index()


def main() -> None:
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    frames: list[pd.DataFrame] = []
    for ticker, name, klass in ASSETS:
        print(f"  -> {ticker:12s}  ({name})", flush=True)
        try:
            d = download_one(ticker)
        except Exception as exc:               # pragma: no cover
            print(f"     ! falhou: {exc}", file=sys.stderr)
            continue
        if d.empty:
            print(f"     ! sem dados", file=sys.stderr)
            continue
        d["ticker"]      = ticker
        d["name"]        = name
        d["asset_class"] = klass
        d = d.sort_values("date").reset_index(drop=True)
        d["return"] = d["close"].pct_change() * 100.0
        frames.append(d[["date", "ticker", "name", "asset_class",
                         "close", "return"]])
        time.sleep(0.4)

    if not frames:
        sys.exit("Nenhum activo descarregado.")

    big = pd.concat(frames, ignore_index=True)
    big["date"] = pd.to_datetime(big["date"]).dt.strftime("%Y-%m-%d")
    big.to_csv(OUT, index=False, float_format="%.6f")

    print("\nResumo:")
    summ = (big.groupby(["ticker", "name", "asset_class"])
                .agg(n=("close", "size"),
                     primeira=("date", "min"),
                     ultima=("date", "max"))
                .reset_index())
    print(summ.to_string(index=False))
    print(f"\nGravado em: {OUT}")
    print(f"Linhas: {len(big):,}   Tamanho: {os.path.getsize(OUT)/1024:.1f} KB")


if __name__ == "__main__":
    main()

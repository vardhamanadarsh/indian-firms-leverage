# Capital Structure of Indian Firms & the SARFAESI Act (2002)

Stata code for two assignments in *Banking, Corporate Finance, Contract Theory and Financial Contracts* (Semester 3).

All code is in [`CFB_assignment.do`](CFB_assignment.do).

## Assignment 1 — Determinants of leverage (Rajan & Zingales, 1995)

1. **Build the panel.** Import the CMIE Prowess dx Identity and Standalone financials extracts, convert text columns to numbers, parse the balance-sheet dates, and merge everything into a firm-year panel.
2. **Clean the data.**
   - Treat missing debt as zero debt.
   - Keep only 12-month reporting periods.
   - Drop firm-years with non-positive net worth or non-positive total assets, and the few rows with negative debt or negative net fixed assets.
   - Winsorize the ratios at the 1st and 99th percentiles.
3. **Build the variables.**

   | Variable | Definition |
   |---|---|
   | Leverage | Debt / (Debt + Net worth) |
   | Tangibility | Net fixed assets / Total assets |
   | Size | ln(Sales) |
   | Profitability | PBDITA / Total assets |
   | Market-to-book | (Total assets − Net worth + Market cap) / Total assets, using market cap on the last March trading day |

4. **Describe leverage.** Leverage over time, its distribution, and how concentrated it is across firms.
5. **Run the regressions.**
   - Leverage on the four determinants: pooled OLS, then with year fixed effects, then with year and industry fixed effects.
   - Standardized (one-SD) effects of each determinant.
   - A binned scatter of leverage against MTB, plus slopes by MTB quintile.

## Assignment 2 — Difference-in-differences around SARFAESI (2002)

- **Sample:** 1998–2006.
- **Treatment:** firms whose average tangibility before 2002 is above the median. Using only pre-reform years means the treatment can't be affected by the reform itself.
- **Pre-trend checks:** leverage trends for each group before 2002, and a formal test with `c.year##i.hightang`.
- **DiD regressions:**
  - The basic DiD, with and without main effects.
  - Firm and year fixed effects (`xtreg, fe`), after removing firms with two balance sheets in the same year.
- **Event study:** HighTangibility × year effects relative to 2001, plotted with 95% confidence intervals.

## Data

The data is **not included** because it comes from the licensed CMIE Prowess dx database. To run the code you need these extracts in your working folder:

| File | Contents |
|---|---|
| `128674_1_5_..._dat.txt` | Identity: one row per firm |
| `128674_1_70_..._dat.txt` | Standalone annual financials: one row per firm-year |
| `128709_1_120_..._dat.txt` | Daily BSE/NSE market capitalisation |

Before running, change the `cd` path on line 1 of the do-file to your own data folder.

## Outputs

Running the do-file saves these figures to your working folder:

- `leverage_over_time.png`
- `leverage_histogram.png`
- `leverage_vs_mtb.png`
- `leverage_by_tangibility.png`
- `event_study.png`

## Reference

Rajan, R. G., & Zingales, L. (1995). What do we know about capital structure? Some evidence from international data. *Journal of Finance*, 50(5), 1421–1460.

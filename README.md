# Canada Mortgage Delinquency: Unemployment, Interest Rates and Out-of-Sample Validation

Panel model of mortgage delinquency in Canada, 2012 to 2025, with out-of-sample validation and unemployment stress scenarios. Everything is done in R.

## Question

How are unemployment and the policy rate associated with mortgage delinquency across Canadian provinces, and how much of next quarter's delinquency can a model actually predict?

## Main results

- **Unemployment moves with delinquency.** In the main provincial model, one more point of unemployment is associated with roughly 17 to 19% higher delinquency. The result holds with 33 metropolitan areas instead of 10 provinces (0.154 vs 0.171 on log delinquency) and when the COVID quarters are dropped.
- **It weakens within a province.** Comparing metropolitan areas of the same province in the same quarter, the association falls to 0.03 and is only marginally significant. Most of the link comes from the cycle areas share, not from local differences.
- **The policy rate cannot be separated.** It is a single national series with one rate cycle in the sample. Its coefficient is negative at every lag and loses significance when errors are clustered by province.
- **Predicting one quarter ahead is hard to improve on.** Delinquency barely changes from one quarter to the next. The best model, a random forest on quarterly changes, cuts the error by 8% against persistence alone. No model anticipated the turn of 2023.
- **Stress scenarios.** Eight quarters after a 2-point rise in unemployment, delinquency is 11% above the baseline path. After a 4-point rise, 24% above.
- **The association is positive in every province,** from 0.09 (Alberta) to 0.30 (Prince Edward Island).

![Average delinquency under unemployment scenarios](outputs/figures/scenarios_average.png)

## Models and results

Each model adds one element to the baseline: unemployment, the policy rate, or a nonlinear learner. Predictions are one quarter ahead, in an expanding window over 16 test quarters (2022Q1 to 2025Q4), 10 provinces.

| Model | What it does |
|---|---|
| Last-quarter benchmark | Predicts last quarter's value. Nothing is estimated |
| Persistence only (baseline) | Last quarter's delinquency, plus province and quarter-of-year effects |
| Persistence + unemployment | Baseline plus lagged unemployment and a COVID indicator |
| Persistence + unemployment + policy rate | Adds the policy rate lagged four quarters |
| Economy only | Unemployment and COVID, without persistence |
| Random forest (level) | Predicts the delinquency level |
| Random forest (change) | Predicts the quarterly change |

| Model | RMSE | MAE | RMSE vs baseline |
|---|---|---|---|
| Random forest (change) | 0.089 | 0.065 | -8% |
| Persistence + unemployment + policy rate | 0.093 | 0.072 | -3% |
| Last-quarter benchmark | 0.093 | 0.069 | -3% |
| Persistence + unemployment | 0.094 | 0.070 | -2.5% |
| **Persistence only (baseline)** | 0.096 | 0.071 | n/a |
| Random forest (level) | 0.135 | 0.096 | +40% |
| Economy only | 0.453 | 0.381 | +370% |

Errors are in log points. The differences between the top models are small, and I did not test whether they are statistically different.

## Limitations

- The results are associations, not causal effects. Omitted variables that move with unemployment (house prices, income, credit conditions) can drive part of the link.
- The sample has one rate cycle (2022 to 2024), so the policy rate is not identified.
- There are 10 provinces. Clustered errors with so few groups are unreliable, which is why I repeat the models with 33 metropolitan areas. Ontario accounts for 15 of them.
- Metropolitan unemployment comes from a survey with small samples, so it is measured with noise.
- Scenario paths are conditional projections, not forecasts, and have no confidence bands. Averages across provinces are simple, not weighted by number of mortgages.

Methods, including why fixed effects and how I handle omitted variable bias and COVID, are in the [report]([link to report]).

## Data

- Mortgage delinquency rate (90+ days past due, share of loans): [CMHC / Equifax](https://www.cmhc-schl.gc.ca/en/data-and-research/data-tables/mortgage-delinquency-rate-canada-provinces-cmas). Not seasonally adjusted. **Manual download.**
- Unemployment rate: Statistics Canada Labour Force Survey, tables 14-10-0287-01 (provinces) and 14-10-0459-01 (metropolitan areas), seasonally adjusted.
- Policy rate: Bank of Canada Valet API, series V39079.

## How to reproduce

1. Clone the repository and open `Canada_mortgage_risk.Rproj` in RStudio.
2. Install the packages: [list of packages].
3. Download the CMHC Excel file and save it as `data/raw/cmhc_delinquency.xlsx`.
4. Run `source("R/00_run_all.R")`. Statistics Canada and Bank of Canada data download automatically. It takes around [N] minutes.
5. Render the report: `quarto render reports/report.qmd`.

## Repository structure

```
R/              analysis scripts, run in order by 00_run_all.R
R/exploration/  data inspection scripts, not part of the pipeline
data/           raw and processed data (not tracked, rebuilt by the scripts)
outputs/        model tables, validation scores, scenario paths
outputs/figures figures used in the report
reports/        Quarto report
```

## Notes

I used Claude (Anthropic) as a coding and methods assistant during development.
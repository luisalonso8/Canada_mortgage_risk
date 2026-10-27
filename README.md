# Mortgage delinquency in Canada: what moves it?

This is a  data project on provincial mortgage delinquency in Canada, using public data and R.

## Question

How does mortgage delinquency by province move with unemployment and interest rates, and how well can a simple model predict it?

## Approach

1. Estimate a provincial panel model of delinquency on unemployment and lagged interest rates.
2. Validate it out of sample on the most recent quarters.
3. Extension: use the model to project delinquency under simple rate and unemployment scenarios.

## Status

Work in progress (First version: provincial panel from public aggregate data).

## Data

- CMHC, mortgage delinquency rate by province and CMA (quarterly, source: Equifax Canada)
- Statistics Canada, unemployment by province
- Bank of Canada, interest rates

## Scope and limits

Public data are aggregate, not loan-level, so this project describes associations; it does not identify causal effects.


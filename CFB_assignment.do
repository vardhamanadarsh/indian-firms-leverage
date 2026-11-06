cd "U:\SEM 3\Banking, Corporate Finance, Contract Theory and Financial Contract\bundle_128674_1"
clear all
set more off

import delimited "128674_1_5_20260921_161204_dat.txt", clear stringcols(3 6 8)

describe
isid co_code

save identity.dta, replace


import delimited "128674_1_70_20260921_161204_dat.txt", clear

describe

* 1. Turn the date-like text into a real Stata date
gen fdate = date(sa_finance1_year, "DMY")
format fdate %td
gen year = year(fdate)
label var year "Calendar year of balance-sheet date"

* 2. Convert text financial columns to numbers ("NA" -> missing)
destring sa_sales sa_pbdita sa_long_term_borrowings sa_shareholders_funds ///
    sa_net_worth sa_debt sa_secured_borrowings sa_unsecured_borrowings ///
    sa_total_assets sa_net_fixed_assets, replace ignore("NA")

* 3. Find and rename the long-name variable safely (it was auto-truncated)
ds sa_long_term_borrowings_incl_c*
local ltb_var `r(varlist)'
display "`ltb_var'"
destring `ltb_var', replace ignore("NA")
rename `ltb_var' sa_ltb_incl_cur

describe

rename sa_finance1_cocode co_code

isid co_code fdate

save financials.dta, replace

*merge

use financials.dta, clear

merge m:1 co_code using identity.dta

tab _merge

*Now run this 
keep if _merge == 3
drop _merge

order co_code company_name fdate year sa_ann_rep_months sa_sales sa_pbdita ///
    sa_debt sa_net_worth sa_total_assets sa_net_fixed_assets

compress

describe

save panel.dta, replace




*now run this 
use panel.dta, clear

* How many rows have missing Debt?
count if missing(sa_debt)
count

* Fiscal years that are not 12 months
tab sa_ann_rep_months

* Firms with negative or zero net worth
count if sa_net_worth <= 0 & !missing(sa_net_worth)
count if missing(sa_net_worth)

* Does missing Debt look like "no debt" or "not reported"?
* Compare Net worth / Total assets for Debt-missing vs Debt-reported rows
gen byte debt_missing = missing(sa_debt)
tabstat sa_net_worth sa_total_assets if sa_total_assets > 0, ///
    by(debt_missing) statistics(p50) columns(statistics)

* Do Debt-missing rows also have long-term borrowings missing?
count if debt_missing == 1 & !missing(sa_ltb_incl_cur)



*Step 8: Build the four Rajan-Zingales variables and leverage

use panel.dta, clear

* Rule 1: missing Debt = zero debt (justified above)
replace sa_debt = 0 if missing(sa_debt)

* Rule 2: keep only 12-month reporting periods
drop if sa_ann_rep_months != 12

* Rule 3: drop firms with non-positive net worth (leverage undefined/explosive)
drop if sa_net_worth <= 0 | missing(sa_net_worth)

* Also need positive total assets for the ratios to make sense
drop if missing(sa_total_assets) | sa_total_assets <= 0

count

gen leverage      = sa_debt / (sa_debt + sa_net_worth)
gen tangibility   = sa_net_fixed_assets / sa_total_assets
gen size          = ln(sa_sales)
gen profitability = sa_pbdita / sa_total_assets

label var leverage      "Book leverage: Debt / (Debt + Net worth)"
label var tangibility   "Net fixed assets / Total assets"
label var size          "log(Sales)"
label var profitability "PBDITA / Total assets"

summarize leverage tangibility size profitability, detail



*Run this 
* Check: is Debt itself negative anywhere?
count if sa_debt < 0
summarize sa_debt if sa_debt < 0

* Check: is net fixed assets negative anywhere?
count if sa_net_fixed_assets < 0
summarize sa_net_fixed_assets if sa_net_fixed_assets < 0

* Check: how many total assets values are suspiciously tiny (driving profitability outliers)?
summarize sa_total_assets, detail
count if sa_total_assets < 1


*Run this
*Drop the tiny error rows, then winsorize

* Drop the small number of clear data errors identified above
drop if sa_debt < 0
drop if sa_net_fixed_assets < 0

count

* Rebuild the four variables cleanly now
drop leverage tangibility size profitability
gen leverage      = sa_debt / (sa_debt + sa_net_worth)
gen tangibility   = sa_net_fixed_assets / sa_total_assets
gen size          = ln(sa_sales)
gen profitability = sa_pbdita / sa_total_assets

label var leverage      "Book leverage: Debt / (Debt + Net worth)"
label var tangibility   "Net fixed assets / Total assets"
label var size          "log(Sales)"
label var profitability "PBDITA / Total assets"

* Winsorize at 1st/99th percentile to limit the effect of extreme ratios
* (driven mostly by very small total-assets denominators)
foreach v of varlist leverage tangibility profitability {
    quietly summarize `v', detail
    replace `v' = r(p1)  if `v' < r(p1)  & !missing(`v')
    replace `v' = r(p99) if `v' > r(p99) & !missing(`v')
}

summarize leverage tangibility size profitability, detail

*run this
*Save the clean panel

save panel_clean.dta, replace

*Firm and observation counts, time period, leverage distribution
*run this

use panel_clean.dta, clear

* Number of unique firms
egen byte tag = tag(co_code)
count if tag
display "Number of firms: " r(N)
drop tag

* Number of firm-year observations
count
display "Number of firm-year observations: " r(N)

* Time period covered
summarize year

* Mean and median leverage (already have distribution from Step 10, but isolate it)
summarize leverage, detail

* Median leverage by year
tabstat leverage, by(year) statistics(median mean n) format(%9.3f)


*Run this 
preserve

collapse (median) med_lev = leverage (mean) mean_lev = leverage (count) n = leverage, by(year)

twoway (line med_lev year, lcolor(navy) lwidth(medthick)) ///
       (line mean_lev year, lcolor(maroon) lpattern(dash)), ///
    title("Leverage of Indian Firms Over Time, 1995-2015") ///
    ytitle("Leverage") xtitle("Year") ///
    legend(order(1 "Median" 2 "Mean")) ///
    xlabel(1995(2)2015)

graph export "leverage_over_time.png", replace width(1400)

restore

*Run this 
*Concentration of leverage — is it driven by a small group of firms?

use panel_clean.dta, clear

* Simple check: what share of firm-years have very low vs very high leverage?
gen byte lev_zero = (leverage == 0)
gen byte lev_high = (leverage > 0.7) if !missing(leverage)

count if lev_zero
display "Share with zero leverage: " r(N)/263817

count if lev_high
display "Share with leverage > 0.7: " r(N)/263817

* Histogram of the leverage distribution
histogram leverage, bin(40) percent ///
    title("Distribution of Book Leverage") ///
    xtitle("Leverage") ytitle("Percent of firm-years")

graph export "leverage_histogram.png", replace width(1400)

* Within-firm variation: does the "same" firm tend to stay in the same leverage
* range over time, or bounce around? (informs "small group of firms" question)
bysort co_code: egen firm_mean_lev = mean(leverage)
egen byte tag2 = tag(co_code)
summarize firm_mean_lev if tag2, detail
drop tag2


*run this
**This completes Part II. Now let's move to Part III: the regressions.

***Prepare industry variable and run the pooled regression


use panel_clean.dta, clear

* co_industry_gp_code is a string. encode() turns it into a numeric factor
* variable that Stata's i. notation can use for fixed effects.
encode co_industry_gp_code, gen(industry)

* Column (1): Pooled OLS
regress leverage tangibility size profitability


*run this
*Add year FE, then year + industry FE, and get standardized effects


* Column (2): Year fixed effects
regress leverage tangibility size profitability i.year

* Column (3): Year + Industry fixed effects
regress leverage tangibility size profitability i.year i.industry


*run this
*Standardized (one-SD) effects

* Get the standard deviation of each variable and of leverage itself
quietly summarize leverage
scalar sd_lev = r(sd)

quietly summarize tangibility
scalar sd_tang = r(sd)

quietly summarize size
scalar sd_size = r(sd)

quietly summarize profitability
scalar sd_prof = r(sd)

display "SD of leverage: " sd_lev
display "SD of tangibility: " sd_tang
display "SD of size: " sd_size
display "SD of profitability: " sd_prof

* Re-run column 1 (pooled) and compute standardized effect for each variable:
* (coefficient * SD of X) / SD of Y = effect in SD units of leverage
quietly regress leverage tangibility size profitability
display "Tangibility: 1-SD increase -> " _b[tangibility]*sd_tang " leverage pts, or " (_b[tangibility]*sd_tang)/sd_lev*100 "% of leverage SD"
display "Size: 1-SD increase -> " _b[size]*sd_size " leverage pts, or " (_b[size]*sd_size)/sd_lev*100 "% of leverage SD"
display "Profitability: 1-SD increase -> " _b[profitability]*sd_prof " leverage pts, or " (_b[profitability]*sd_prof)/sd_lev*100 "% of leverage SD"

*Run this For MTB 
*Load and clean the market cap file
import delimited "128709_1_120_20260921_235436_dat.txt", clear

describe

gen tdate = date(co_stkdate, "DMY")
format tdate %td
drop if missing(tdate)

gen year  = year(tdate)
gen month = month(tdate)

* Keep only March trading days (to match your mostly-March fiscal year-ends)
keep if month == 3

* Convert the string financial columns to numbers ("NA" -> missing)
destring bse_closing_price bse_market_cap nse_market_cap equity_shares_on_stkdate, replace ignore("NA")

* Now this will work
gen double mcap = bse_market_cap
replace mcap = nse_market_cap if missing(mcap)
drop if missing(mcap)

count
summarize year

*Collapse to one observation per firm-year (last March trading day), and save
* Keep the LAST trading day in March for each firm-year
sort co_code year tdate
by co_code year: keep if _n == _N

isid co_code year

count
tab year
summarize mcap, detail

keep co_code year tdate mcap
label var mcap "Market cap, last March trading day of the fiscal year (Rs. Million)"

save mktcap_march.dta, replace

*Step 20: Merge onto the clean panel and build MTB

use panel_clean.dta, clear

merge m:1 co_code year using mktcap_march.dta

tab _merge

*Run this
*Step 21: Drop the using-only rows, build MTB, check it, save

keep if _merge != 2
drop _merge

* Build market-to-book (Rajan-Zingales style):
* (Book assets - Book equity + Market equity) / Book assets
gen mtb = (sa_total_assets - sa_net_worth + mcap) / sa_total_assets

* Drop the zero-market-cap oddities flagged earlier
replace mtb = . if mcap == 0

count if !missing(mtb)
summarize mtb, detail


*Run this
*Step 22: Winsorize MTB, save the final panel

quietly summarize mtb, detail
replace mtb = r(p1)  if mtb < r(p1)  & !missing(mtb)
replace mtb = r(p99) if mtb > r(p99) & !missing(mtb)

label var mtb "Market-to-book: (Assets - Book equity + Market equity) / Assets"

summarize mtb, detail

save panel_with_mtb.dta, replace

*Step 23: Re-run Part III with all four variables

use panel_with_mtb.dta, clear

* Column (1): Pooled OLS, all four variables
regress leverage tangibility mtb size profitability

* Column (2): Year fixed effects
regress leverage tangibility mtb size profitability i.year

*Step 24 (fixed): recreate the industry variable, then run column 3
*Step 24: Column 3 (year + industry FE) with MTB, then standardized effects

encode co_industry_gp_code, gen(industry)

regress leverage tangibility mtb size profitability i.year i.industry

*Step 25: Standardized effects with MTB included

quietly summarize leverage
scalar sd_lev = r(sd)
quietly summarize tangibility
scalar sd_tang = r(sd)
quietly summarize mtb
scalar sd_mtb = r(sd)
quietly summarize size
scalar sd_size = r(sd)
quietly summarize profitability
scalar sd_prof = r(sd)

quietly regress leverage tangibility mtb size profitability

display "Tangibility: " (_b[tangibility]*sd_tang)/sd_lev*100 "% of leverage SD"
display "MTB: " (_b[mtb]*sd_mtb)/sd_lev*100 "% of leverage SD"
display "Size: " (_b[size]*sd_size)/sd_lev*100 "% of leverage SD"
display "Profitability: " (_b[profitability]*sd_prof)/sd_lev*100 "% of leverage SD"

save panel_final.dta, replace

*Step 26: Graph the MTB-leverage relationship
use panel_final.dta, clear

* Scatter is often too noisy with 47,000 points - use a binned scatter instead:
* group MTB into 20 equal-sized bins and plot mean leverage in each bin
xtile mtb_bin = mtb, nquantiles(20)

preserve
collapse (mean) mean_mtb = mtb (mean) mean_lev = leverage (count) n = leverage, by(mtb_bin)

twoway (scatter mean_lev mean_mtb, mcolor(navy) msize(medium)) ///
       (lfit mean_lev mean_mtb, lcolor(maroon)), ///
    title("Leverage vs. Market-to-Book (binned)") ///
    xtitle("Market-to-book ratio (bin mean)") ytitle("Mean leverage (bin mean)") ///
    legend(off)

graph export "leverage_vs_mtb.png", replace width(1400)

restore

*Step 27: Formalize this with a piecewise/quintile regression (like RZ's footnote 32)

use panel_final.dta, clear

xtile mtb_quint = mtb, nquantiles(5)

* Run the standard regression separately within each MTB quintile
forvalues q = 1/5 {
    display "----- MTB Quintile `q' -----"
    quietly regress leverage mtb if mtb_quint == `q'
    display "Coefficient on MTB: " _b[mtb] " (t=" _b[mtb]/_se[mtb] ")"
}

* Also check: what does the leverage-MTB slope look like just for the bottom
* vs top half of the distribution?
quietly summarize mtb, detail
scalar med_mtb = r(p50)

display "Below-median MTB:"
regress leverage mtb if mtb < med_mtb

display "Above-median MTB:"
regress leverage mtb if mtb >= med_mtb




*Assignment 2******************

*Run this
*Step 1: Load the dataset and check the window
use panel_final.dta, clear

* Restrict to a window around the reform, as suggested by the assignment
keep if year >= 1998 & year <= 2006

count
tab year


*Step 2: Build Post2002 and HighTangibility
*Run this

* Post2002: following the assignment's literal instruction
gen byte post2002 = (year >= 2002)
label var post2002 "1 if fiscal year-end is 2002 or later"

* HighTangibility: based ONLY on each firm's pre-2002 average tangibility
* (must not use post-reform tangibility, since it could itself respond to the reform)

preserve
    keep if year < 2002
    collapse (mean) pre_tang = tangibility (count) n_pre = tangibility, by(co_code)
    count
    summarize pre_tang, detail
    save pretang.dta, replace
restore

merge m:1 co_code using pretang.dta
tab _merge

*Step 3: Drop unmatched, build HighTangibility, save
*rUN THIS 

keep if _merge == 3
drop _merge

* HighTangibility = 1 if pre-2002 average tangibility is above the median
* of the pre-2002 distribution (median computed across firms, using pretang.dta's values)
summarize pre_tang, detail
scalar med_pretang = r(p50)

gen byte hightang = (pre_tang > med_pretang) if !missing(pre_tang)
label var hightang "1 if firm's average pre-2002 tangibility is above the pre-2002 median"

tab hightang
tab hightang post2002

save panel_assign2.dta, replace

*Step 4: Leverage trends by tangibility group around 2002

use panel_assign2.dta, clear

preserve
collapse (mean) mean_lev = leverage (median) med_lev = leverage, by(hightang year)

twoway (line med_lev year if hightang==1, lcolor(navy) lwidth(medthick)) ///
       (line med_lev year if hightang==0, lcolor(maroon) lwidth(medthick) lpattern(dash)), ///
    xline(2002, lcolor(black) lpattern(dot)) ///
    title("Median Leverage by Tangibility Group, 1998-2006") ///
    ytitle("Median leverage") xtitle("Year") ///
    legend(order(1 "High Tangibility" 2 "Low Tangibility")) ///
    xlabel(1998(1)2006)

graph export "leverage_by_tangibility.png", replace width(1400)
restore

*Step 5: Quantify the pre-trend difference and move to Part III
* Quantify the pre-2002 trend for each group separately
regress leverage year if hightang==1 & year<2002
display "High-tangibility pre-trend: " _b[year]

regress leverage year if hightang==0 & year<2002
display "Low-tangibility pre-trend: " _b[year]

*Step 6: Formal pre-trend test (single regression)

regress leverage c.year##i.hightang if year < 2002

*Part III: the main DiD regressions
*Step 7: Basic DiD (no fixed effects)

use panel_assign2.dta, clear

gen did = hightang * post2002
label var did "HighTangibility x Post2002"

regress leverage did

*Step 8: Correctly-specified basic DiD (with main effects)

regress leverage hightang post2002 did

*Step 9:

duplicates tag co_code year, gen(dup_yr)

count if dup_yr > 0
tab dup_yr

* Look at a few examples
list co_code company_name fdate year sa_ann_rep_months leverage if dup_yr > 0, sepby(co_code) abbreviate(15)

*Step 9 (continued): drop the duplicate, keeping the later fiscal date

sort co_code year fdate
by co_code year: keep if _n == _N

drop dup_yr

isid co_code year

count

*Step 10: Save, then run the firm + year fixed effects DiD

save panel_assign2_clean.dta, replace

xtset co_code year

xtreg leverage did i.year, fe

*Step 11

use panel_assign2_clean.dta, clear
xtset co_code year

* Generate separate interaction terms: hightang x year, for each year except 2001
forvalues y = 1998/2006 {
    gen did_`y' = hightang * (year == `y')
}

* Drop the 2001 interaction (reference/omitted year)
drop did_2001

xtreg leverage did_1998 did_1999 did_2000 did_2002 did_2003 did_2004 did_2005 did_2006 i.year, fe

matrix b = e(b)
matrix list b

*Step 12: Plot the event study

clear
input year coef se
1998 -.0222377 .0054226
1999 -.0043554 .0051784
2000 -.0033206 .0050622
2001 0 0
2002 .001706 .0050714
2003 -.0035723 .0051593
2004 -.0157948 .0052568
2005 -.0193133 .0052454
2006 -.0275205 .0052306
end

gen ci_lo = coef - 1.96*se
gen ci_hi = coef + 1.96*se

twoway (rcap ci_lo ci_hi year, lcolor(gs8)) ///
       (scatter coef year, mcolor(navy) msize(medium) connect(l) lcolor(navy)), ///
    yline(0, lcolor(black) lpattern(dash)) ///
    xline(2001.5, lcolor(red) lpattern(dot)) ///
    title("Event Study: HighTangibility x Year Effect on Leverage") ///
    subtitle("Relative to 2001 (year before SARFAESI)") ///
    ytitle("Coefficient (relative to 2001)") xtitle("Year") ///
    legend(off) xlabel(1998(1)2006)

graph export "event_study.png", replace width(1400)
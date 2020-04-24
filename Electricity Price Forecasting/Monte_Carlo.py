# Import libraries
import pandas as pd
from scipy.interpolate import interp1d
import random


# - - - Import data - - - 
df = pd.read_csv("data.csv", index_col=0, parse_dates=True)
df.sort_index(inplace = True)
df = df.resample('30min').mean()


#=======================================================================
#    MONTE CARLO SIMULATION
#=======================================================================

# Define function that performs Monte Carlo simulation
def rand_diff():
    '''Monte Carlo simulation of price difference on a single time
    period. It calculates the difference between randomly generated
    imbalance and day-ahead prices 10,000 times.
    
    Variables
    ----------
    f_imb, f_dam : interp1d
        Functions interpolated to the quantile forecasts of imbalance
        and day-ahead prices, respectively.
    
    Returns
    ----------
    df_diff : pandas.DataFrame
       One-column DataFrame with 10,000 rows.
       The column name corresponds to the time period.
    '''
    diff_rand = []
    for i in range(10000):
        y_diff = f_imb(random.uniform(0.05, 0.95)) - f_dam(random.uniform(0.05, 0.95))
        diff_rand.append(y_diff)
    df_diff = pd.DataFrame(diff_rand, columns=[y_dam.name])
    return (df_diff)


# Day-ahead price forecast quantiles
df_dam = df[['lower90_dam', 'lower80_dam', 'lower50_dam', 'point_dam',
             'upper50_dam', 'upper80_dam', 'upper90_dam']]

# Imbalance price forecast quantiles
df_imb = df[['lower90_imb', 'lower80_imb', 'lower50_imb', 'point_imb', 
             'upper50_imb', 'upper80_imb', 'upper90_imb']]

# List of corresponding probabilities
x = [0.05, 0.10, 0.25, 0.50, 0.75, 0.90, 0.95]


# Run Monte Carlo simulation on each time period in the test set
df_mc = pd.DataFrame()
for i in range(len(df_dam)):
    y_dam = df_dam.iloc[i]
    y_imb = df_imb.iloc[i]

    # Interpolate quadratic function to quantiles
    f_dam = interp1d(x, y_dam, kind='quadratic')
    f_imb = interp1d(x, y_imb, kind='quadratic')

    # Run Monte Carlo simulation
    df_mc = pd.concat([df_mc, rand_diff()], axis=1)


#=======================================================================
#    DATA ANALYSIS
#=======================================================================

# - - - Descriptive statistics for each distribution - - -
mc_prob = [(df_mc[col] > 0).sum()/float(len(df_mc[col]))
            for col in df_mc.columns]    # probability of positive price difference
mc_mean = [df_mc[col].mean() for col in df_mc.columns]    # mean
mc_median = [df_mc[col].median() for col in df_mc.columns]    # median
mc_std = [df_mc[col].std() for col in df_mc.columns]    # std. dev.

# 5, 10, 25, 75, 90, 95% quantiles
mc_q05 = [df_mc[col].quantile(0.05) for col in df_mc.columns]
mc_q10 = [df_mc[col].quantile(0.10) for col in df_mc.columns]
mc_q25 = [df_mc[col].quantile(0.25) for col in df_mc.columns]
mc_q75 = [df_mc[col].quantile(0.75) for col in df_mc.columns]
mc_q90 = [df_mc[col].quantile(0.90) for col in df_mc.columns]
mc_q95 = [df_mc[col].quantile(0.95) for col in df_mc.columns]


# Store statistics in DataFrame        
mc_res = pd.DataFrame({'prob_positive':mc_prob, 'mc_mean':mc_mean,
                       'mc_median':mc_median, 'mc_std':mc_std,
                       'q05':mc_q05, 'q10':mc_q10, 'q25':mc_q25,
                       'q75':mc_q75, 'q90':mc_q90, 'q95':mc_q95
                       },
                       index = df.index)

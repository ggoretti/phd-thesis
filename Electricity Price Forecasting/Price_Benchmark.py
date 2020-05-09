# Import libraries
import pandas as pd


# - - - Import data - - -
df = pd.read_csv("data.csv", index_col=0, parse_dates=True)
df.sort_index(inplace = True)
df = df.resample('30min').mean()


#=======================================================================
#    BENCHMARK MODEL
#=======================================================================
# - - - Monday, Saturday, Sunday - - -
# Shift forward of one week (48*7 periods) the 'price' column
df['bench'] = df['price'].shift(7*48)


# - - - Wednesday, Thursday, Friday - - -
# Shift forward of one day hours before 10:00
df['bench'].mask((df.index.hour<10) & (df.index.dayofweek.isin([2,3,4])),
                 df['price'].shift(1*48), inplace=True)

# Shift forward of two days hours after 10:00
df['bench'].mask((df.index.hour>=10) & (df.index.dayofweek.isin([2,3,4])),
                 df['price'].shift(2*48), inplace=True)


# - - - Tuesday - - -
# Shift forward of one day hours before 10:00
df['bench'].mask((df.index.hour<10) & (df.index.dayofweek.isin([1])),
                 df['price'].shift(1*48), inplace=True)

# Shift forward of four days hours after 10:00 (previous Friday)
df['bench'].mask((df.index.hour>=10) & (df.index.dayofweek.isin([1])),
                 df['price'].shift(4*48), inplace=True)

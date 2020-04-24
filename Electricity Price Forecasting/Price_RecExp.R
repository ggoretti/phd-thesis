# Set working directory
setwd(".../Historical_data/dam_prices")

# Import packages
library(fpp2, tsibble, readr, purrr)

# Import prices from half-hourly .csv files
temp = list.files(pattern="weekday/*.csv")
myfiles = lapply(temp, read.csv)
freq = 5    # period of seasonal component (weekday=5, weekend=2)

# Create empty lists to store outputs
dflist = list()
fit_list = list()
coef_list = list()

# Loop through the half-hourly files
for(j in 1:length(myfiles)){
  df_file <- data.frame(myfiles[j])
  df <- ts(df_file, frequency=freq)    # convert to Time series object
  
  # split data into initial Training and Test sets
  df_train <- subset(df, end=nrow(df)*0.5716)
  df_test <- subset(df, start=nrow(df)*0.5716 + 1)

  
  # - - - One-step forecast with re-selection and re-estimation of ARIMA model - - - 
  h <- 2    # forecast horizon
  n <- nrow(df_test) - 1    # number of forecasts to issue
  
  fcmat <- matrix(0, nrow=n, ncol=14)    # empty matrix to store forecast values
  colnames(fcmat) <- c("point_1", "lower50_1", "lower80_1", "lower90_1",
                       "upper50_1", "upper80_1", "upper90_1",
                       "point_2", "lower50_2", "lower80_2", "lower90_2",
                       "upper50_2", "upper80_2", "upper90_2")
  
  fit_df = data.frame(aic=numeric(),
                      p=integer(), d=integer(), q=integer(),
                      P=integer(), D=integer(), Q=integer())    # empty df for AIC value and model order
  
  coef_df = list()    # empty list for coefficients of fitted model
  
  # *RECURSIVELY EXPANDING* Training set
  lambda <- BoxCox.lambda(df_train[,"dam_price"])    # BoxCox transformation lambda for Training data
  for(i in 1:n){
    x_i <- subset(df, end=nrow(df)*0.5716 + i - 1)    # increase x by (i-1)
    xreg_i <- subset(df, start=nrow(df)*0.5716 + i)    # shift regressors by i
    
    # fit ARIMA model to updated x and xreg
    fit_i <- auto.arima(x_i[,"dam_price"],
                        xreg=x_i[,c("Demand_Fcst", "p50_All", "interval_All", "penetration")],
                        lambda=lambda)
    
    fit_df[i,1] <- fit_i$aic
    fit_df[i,2:7] <- arimaorder(fit_i)[1:6]
    coef_df <- rbind(coef_df, fit_i$coef)
    
    # forecast with updated model
    fcst <- forecast(fit_i, h=h,
                     xreg=xreg_i[,c("Demand_Fcst", "p50_All", "interval_All", "penetration")],
                     level=c(50, 80, 90))
    
    # forecast horizon: h = 1
    fcmat[i,1] <- fcst$mean[1]
    fcmat[i,2:4] <- fcst$lower[1,]
    fcmat[i,5:7] <- fcst$upper[1,]
    
    # forecast horizon: h = 2
    fcmat[i,8] <- fcst$mean[2]
    fcmat[i,9:11] <- fcst$lower[2,]
    fcmat[i,12:14] <- fcst$upper[2,]
  }
  
  df_fcst <- df_file[(nrow(df_file)*0.5716+1):(nrow(df_file)-1),]
  dflist[[j]] <- cbind(df_fcst, as.data.frame(fcmat))    # list of dataframes; each df includes forecast and observed values for a single load period
  
  fit_list[[j]] <- fit_df    # list of dataframes with AIC and model order values
  
  coef_list[[j]] <- as.data.frame(coef_df)    # list of dataframes with model coefficients
}


# Store results in separate data.frames
df_tot <- do.call(rbind, dflist)

fit_tot <- map_df(fit_list, ~as.data.frame(.x), .id="id")    # merge into data.frame keeping id of each list

coef_tot <- map_df(coef_list, ~as.data.frame(.x), .id="id")    # merge into data.frame keeping id of each list
is.na(coef_tot) <- coef_tot == "NULL"     # replace NULL with NA
coef_tot <- as.data.frame(sapply(coef_tot, unlist))    # unlist each column and convert to data.frame

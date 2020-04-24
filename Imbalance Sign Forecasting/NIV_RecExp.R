# Set working directory
setwd(".../Historical_data/NIV")

# Import packages
library(fpp2, tsibble, readr)

# Import data from half-hourly .csv files
temp = list.files(pattern="*.csv")
myfiles = lapply(temp, read.csv)

dflist = list()    # empty list to store outputs

# Loop through the half-hourly files
for(j in 1:length(myfiles)){
  df = data.frame(myfiles[j])
  
  # split data into Training and Test sets
  df_train <- df[1 : (nrow(df)*0.5716-1),]
  df_test <- df[(nrow(df)*0.5716) : nrow(df),]
  
  # - - - One- and two-step forecasts with re-estimation of GLM model - - - 
  h <- 2    # forecast horizon
  n <- nrow(df_test) - 1    # number of forecasts to issue

  # empty lists to store forecast outputs
  NIV_list_1 = list()
  NIV_list_2 = list()
  formula_list = list()

  # *RECURSIVELY EXPANDING* training set
  for(i in 1:n){
    train_i <- df[1 : (nrow(df)*0.5716-1+i-1),]    # increase x by (i-1)
    test_i <- df[(nrow(df)*0.5716+i-1) : nrow(df),]    # shift regressors by i
    
    # fit GLM model to updated Training set, train_i
    fit_i <- glm(NIV ~ p50_All + interval_All + Demand_Fcst + penetration + factor(day),
                 data=train_i, family=binomial())
    
    #fit_i <- step(fit_i, direction="backward", trace=0)    # *STEPWISE SELECTION* of model with lowest AIC
    formula_list[i] <- deparse(fit_i$formula)    # formula of selected model

    pred_i = predict(fit_i, newdata=test_i, se.fit=T)  # predict on updated Test set, test_i
    
    NIV_fcst_i = exp(pred_i$fit)/(1+exp(pred_i$fit))  # convert to probability
    
    NIV_list_1[i] <- NIV_fcst_i[1]    # first (h=1) forecast value 
    NIV_list_2[i] <- NIV_fcst_i[2]    # second (h=2) forecast value
  }
  
  df_fcst <- df_test[1:(nrow(df_test)-1),]
  df_fcst$NIV_fcst_1 <- NIV_list_1   # attach forecast data to Test set
  df_fcst$NIV_fcst_2 <- NIV_list_2  
  df_fcst$formulas <- unlist(formula_list)
  dflist[[j]] <- df_fcst
  
}


# Store results in df_tot data.frame
df_tot <- do.call(rbind, dflist)
df_tot$NIV_fcst_1 <- unlist(df_tot$NIV_fcst_1)
df_tot$NIV_fcst_2 <- unlist(df_tot$NIV_fcst_2)

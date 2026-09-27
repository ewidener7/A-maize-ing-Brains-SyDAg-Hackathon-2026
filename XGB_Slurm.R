.libPaths("~/R/x86_64-pc-linux-gnu-library/4.5")

library(xgboost)
library(dplyr)
library(ggplot2)
library(Matrix)
library(caret)
library(here)

genodir <- "~/SyDAg_Hackathon/Genotype_Files/proportion_imputed_geno.csv"
phenodir <- "~/SyDAg_Hackathon/Phenotype_Files"
traitlist <- c("YLD_BE","PHT","TWT")
testyearlist <- c(2000,2001,2002,2003,2004,2005,2006,2007,2008)
validyearlist <- c(2008,2000,2001,2002,2003,2004,2005,2006,2007)

prop_geno <- read.csv("Genotype_Files/proportion_imputed_geno.csv") |> select(!c("X"))


# Build Dataset

## Load YLD_BLUP

for(t in 3){
  
  for(y in 8:9){
    
    TRAIT_NAME <- traitlist[t]
    
    pheno_df <- read.csv(here(phenodir,paste0(TRAIT_NAME,".csv"))) |> select("LINE_UNIQUE_ID",TRAIT_NAME,"YEAR","LOC") |>
      mutate(LOC_YEAR = paste0(LOC,"_",YEAR))
    
    ## Load Env_Data
    
    weather <- read.csv("Weather_Data/4GS_Binned_Weather_Data_Mean.csv") |> select(!c("FAMILY","X","LINE","ERM"))
    
    ## Combine
    
    norm_df <- inner_join(pheno_df, prop_geno, by = "LINE_UNIQUE_ID")
    
    norm_df <- inner_join(norm_df, weather, by = join_by("LINE_UNIQUE_ID",
                                                         "YEAR","LOC","LOC_YEAR")) %>% select(!c())
    
    # Separate features and target and set training and test datasets
    
    testyr <- testyearlist[y]
    validyr <- validyearlist[y]
    CV_Year <- testyearlist[y]
    
    traindf <- norm_df |> filter(YEAR != c(testyr,validyr))
    validdf <- norm_df |> filter(YEAR == validyr)
    testdf <- norm_df |> filter(YEAR == testyr)
    
    
    
    train_labels <- traindf[[TRAIT_NAME]]
    train_features <- traindf %>% select(!c(TRAIT_NAME,"LINE_UNIQUE_ID", "YEAR","LOC","LOC_YEAR"))
    
    # One-hot encode categorical variables and convert to sparse matrix
    # The "-1" removes the intercept column, which XGBoost does not need
    train_sparse_matrix <- as.matrix(train_features)
    
    # Create the XGBoost DMatrix
    dtrain <- xgb.DMatrix(data = train_sparse_matrix, label = train_labels)
    
    #Same for Valid
    valid_labels <- validdf[[TRAIT_NAME]]
    valid_features <- validdf %>% select(!c(TRAIT_NAME,"LINE_UNIQUE_ID", "YEAR","LOC","LOC_YEAR"))
    
    valid_sparse_matrix <- as.matrix(valid_features)
    
    dvalid <- xgb.DMatrix(data = valid_sparse_matrix, label = valid_labels)
    
    #Same for Test
    test_labels <- testdf[[TRAIT_NAME]]
    test_features <- testdf %>% select(!c(TRAIT_NAME,"LINE_UNIQUE_ID", "YEAR","LOC","LOC_YEAR"))
    
    test_sparse_matrix <- as.matrix(test_features)
    
    dtest <- xgb.DMatrix(data = test_sparse_matrix, label = test_labels)
    
    # Define hyperparameter grid
    xgb_params <- list(
      booster = "gbtree",
      objective = "reg:squarederror", # Use binary:logistic for classification
      # Computational scaling for 500k x 1.7k
      tree_method      = "hist",        # Crucial for scaling runtime and memory
      max_bin          = 256,           # Discrete binning for continuous/discrete data
      
      # Tree structure & complexity
      max_depth        = 5,             # Prevents combinatorial explosion across 1,700 markers
      min_child_weight = 50,            # Avoids splitting on rare alleles/outliers in 500k rows
      
      # Subsampling
      subsample        = 0.8,           # Row subsampling for speed and variance reduction
      colsample_bytree = 0.15,          # Selects ~250 markers/variables per tree
      
      # Regularization for collinear markers & growth stages
      lambda           = 10,            # L2 penalty to handle LD and autocorrelated stages
      alpha            = 1,             # L1 penalty to zero out uninformative markers
      
      # Optimization
      eta              = 0.05           # Slower learning rate paired with early stopping
    )
    
    
    # Model continued to improve even at 1000 rounds of training. Training will be capped at 1000 to reduce computational cost, but marginial increases past 700
    
    watchlist <- list(train = dtrain, holdout_valid = dvalid)
    
    model_1 <- xgb.train(
      params = xgb_params,
      data = dtrain,
      nrounds = 700,
      watchlist = watchlist,
      early_stopping_rounds = 15,
      print_every_n = 50
    )
    
    
    #Normal Genotype prediction and accuracy
    
    preds <- predict(model_1, dtest)
    
    resultsdf <- testdf %>% select("LINE_UNIQUE_ID",TRAIT_NAME)
    
    resultsdf$Prediction <- as.numeric(preds)
    
    
    # Save output
    write.csv(resultsdf, here("XGB_Env_Pred",paste0(CV_Year,"_",TRAIT_NAME,".csv")), row.names = FALSE)
    
    # Save Model
    xgb.save(model_1, here("XGB_Env_Pred",paste0(CV_Year,"_",TRAIT_NAME,"_EnvXGB.json")))
    
  }}

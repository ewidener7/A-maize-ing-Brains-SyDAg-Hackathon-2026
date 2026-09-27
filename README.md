[SyDAg_Documentation.txt](https://github.com/user-attachments/files/32701519/SyDAg_Documentation.txt)
1. Data Preparation
   1. Phenotype Files
      1. Data Cleaning
Data were cleaned by removing any values that were more than 3 standard deviations outside of the distribution of values. 
      2. Spatial Correction
Plot level data is not provided, so we were unable to perform spatial corrections. This is one potential limitation of the study. 
      3. BLUP Calculation (for GBLUP)
BLUP values were calculated using the following model: 
trait, "~ (1 | LINE_UNIQUE_ID) + (1 | LOC) + (1 | YEAR) +",
                       "(1 | LINE_UNIQUE_ID:YEAR) + (1 | LOC:YEAR)"

   2. Genotype Files
      1. Compilation
Compile genomic data into 2 separate files:
First: This will include all of the progeny lines that we are predicting on. 
Column 1 - Unique ID = Cluster.Population.Line
Column 2 - Cluster
Column 3 - Population
Column 4 - Line
Column 5 - Parent ID 1
Column 6 - Parent ID 2
All remaining columns are markers
Make this combined for all clusters, populations, and lines, and then perform QC
*The unimputed files already have this, but we would need to perform imputation ourselves. I think we can just trust Bayer imputation

Second: This will include all of the parent lines and their genotypes. This will be saved as a reference and could be used to generate new progeny files in the future
      2. Genotypic Quality Control
         1. Marker Missingness
            1. Starting on 2,911 markers from the final genotype file, using a marker missing rate of <= 0.1 was found to be too strict lowering the number of markers to only 1,264.
            2. We then increased to a missing rate of <=0.2 which was found to be too lenient only reducing markers by ~400. 
            3. The final marker missing rate we accepted was <=0.15 reducing the number of markers to 2,071. We found that this was a good midpoint between being too strict and too lenient. 
         2. Individual Missingness
            1. Similar to the marker missing rate we started with an individual missing rate of <= 0.1 that was found to be quite strict, losing 66,836 individuals. 
            2. We then increased to a missing rate of <=0.2 which was again found to be too lenient only reducing the number of individuals by ~9,000.
            3. The final individual missing rate we accepted was <=0.15 reducing the final number of individual progeny to 105,712. We found that this was a good midpoint between being too strict and too lenient again.
         3. Minor allele frequency
            1. For minor allele frequency, we went with a standard cutoff of >=0.05 to try to capture differences in allele frequency that could be meaningful for the model without creating false positives from spurious associations. This brought the final marker set down by 332 leading to a final marker set of 1,739.
      3. Imputation
Missing values following QC were imputed with the mode of each column. We recognize there are more advanced and accurate imputation methods, but this was a “quick and dirty” solution used

XGBoost and other non-linear models may utilize one-hot encoding of genetic data because traditional genetic encodings imply a linear relationship between alleles. One challenge of one-hot encoding is that the number of columns is tripled, significantly increasing the computational cost. An alternative that we implemented is to replace genetic encodings with relative proportions for each marker. For instance, if the relative proportions of 0,1,2 are 35%, 45%, and 20% respectively, the encodings would be replaced with 0.35, 0.45, 0.20. This incorporates a level of non-linear variation without increasing the number of columns. The two methods of encoding were superficially compared in a BLUP prediction xgboost model for only one holdout year scenario, and results from this indicated that the performance of the model using either method of genotypic representation were similar.

   3. Weather Data
      1. Envirotyping
Growth stage estimates are based on an arbitrary planting date and end based on calculated GDD accumulation. Weather data were grouped into 4 growth stages: Early Vegetative, Late Vegetative, Silking, and Black Layer. GDD cutoffs were calculated based on the average ERM for each genotype. If genotype specific ERM was not available, the Family ERM was used, and if family ERM was not available, the cluster ERM was used. Using this method for environment representation may reduce the risk of location overfitting because multiple unique sets of weather variables exist for a single location in a single year because each ERM within a location will have slightly different clustered data. One potential improvement is to provide location meta data such as planting data that would improve accuracy of envirotyping. 

4 growth stage grouping - Maybe create a figure that displays this, at least for the documentation
      2. Static Location Data
Static location data was not included in the model due to time and data constraints. Due to the difference in modality between static nutrition and soil data compared to genetic and environmental data, which are much less static, including this data may have increased the likelihood of overfitting. However, future work could be focused on how to represent the static characteristics of a location, especially as they relate to fertility and soil characteristics. 
      3. New Year Prediction
Due to time constraints, the true weather data was used for model predictions, when in reality, this would be unknown information when making predictions. Two potential realistic alternatives to this would be to use the weather of the previous year or to use the average weather of the previous set of years. Depending on the goals of the breeders, predictions could also be performed based on average, ideal, or stressed weather conditions. 
   4. Variable Selection
A thorough variable importance analysis was not performed, but this could be useful to indicate what weather variables, data types, and growth stages are most important for predicting specific traits. Additionally, reducing the variable set to only the most informative variables could make models lighter and more efficient to run. For this hackathon, all genetic information following QC was included and weather data grouped into 4 growth stages and across 5 variables (max temp, min temp, precipitation, solar radiation, and percent cloud cover)

2. Models
   1. GBLUP
A simple GBLUP model that included Additive and Dominance factors was used as a baseline. Additive effects were represented with 125 principal components, and Dominance effects were represented with 50 principal components. Principal components and ridge regression were used instead of genomic relationship matrices due to the computational cost associated with calculating these matrices. Finally, this model was trained on only BLUP values, and no LocID or Year variables were used in training and prediction. 
   2. XGBoost
      1. BLUP Model
The BLUP XGBoost model was trained only on genetic data and BLUP values and predicted BLUP values, just the same as GBLUP. The transformed genetic encodings were used instead of 0,1,2 encodings to enable better non-linear representations of genetic effects and interactions.
      2. Environment Model
The most complicated model was an XGBoost model trained on genotypic and environmental data. All variables included were numeric, so no one hot encoding was required. This is the only model that is not trained on BLUP values and that gives location specific predictions. 
      3. Hyperparameter Tuning
Minimal hyperparameter tuning was performed, only to determine the ideal number of trees included in the forest (a max of 700 was set). More thorough cross validation would be a potentially significant improvement to this research. 
3. Cross Validation
   1. Year Fold CV
9 fold cross validation was performed for all three predicted traits (YLD_BE, PHT, TWT)
Within the GBLUP model, the validation year was held out (ex. 2001) and the model was trained on the remaining years. For xgboost, a validation set is also required for early stopping, so the year immediately prior to the test year was retained as validation, and there was no data leakage between training, validation, and testing datasets. 

Accuracy figures were only generated for the 2007 and 2008 predictions.
Perform CV for each training year and use accuracy metrics across validations to get estimates of accuracy and model instability 

For weather data, compare true weather data prediction accuracy to average of previous 5 years of weather

Multiple CV will be used to get estimates and distribution of accuracy metrics, figures to present to breeders will be used only for 2007 validation
4. Accuracy Reports
   1. Quartile Matrix for Ranking Accuracy
   2. Model Agreement
   3. E, G, and GxE Accuracies
E accuracy is calculated on a per location basis (do predicted and actual location yield averages match?)
G accuracy is calculated on a per hybrid basis (do predicted and actual genotype averages across locations match?)
GxE accuracy is calculated as the within location ranking accuracy, which has a weighted average across all locations (weight is based on location size, on average, how does the model do with ranking specific hybrids within a specific location?0
   4. Breeder Impact
5. Product Pipeline
   1. Model Updates
Currently has model trained on 2001-2007. As the breeding program continues, models will be updated, but historical models should be maintained to benchmark accuracies over time. Naming convention will be the model type and last year of data used to train (i.e. XGBoost_2007). 
   2. Scalability
This framework could easily incorporate additional model architectures and based on provided accuracy metrics, breeders can choose to rely on specific models
Potential for location/region/breeder specific accuracy reports also 
   3. User Interface
User interface where trained models and genotype and weather data are stored on a server. Breeders upload genotype files and indicate locations where predictions are wanted. Additionally, they can just obtain BLUP predictions if that is wanted. 
The user interface will then load trained models and feed in provided genotype information and stored weather information for locations to generate predictions. This should be relatively light because the data requirements are kept small by avoiding model training. 
*Note, this is not the case for GBLUP, which must be retrained, so it is only used as a benchmark
The UI should also include capabilities to view predictions results immediately and for multiple traits simultaneously, for instance if a breeder wanted to visualize the relationship between plant height and test weight in a set of predictions

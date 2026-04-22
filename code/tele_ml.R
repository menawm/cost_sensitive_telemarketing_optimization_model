
library(tidyverse)  # includes %>% and dplyr
library(janitor)
library(caret)
library(class)
library(nnet)
library(e1071)
library(rpart)
library(rpart.plot)
library(randomForest)
library(kernlab)
library(broom)
```


# Load and clean data
tele_raw <- read.csv("tele.csv") %>% 
  clean_names()

# Convert target to binary factor (1 = yes, 0 = no)
tele_raw$y <- factor(ifelse(tele_raw$y == "yes", 1, 0))

# Convert character variables to factors
factor_vars <- c("job", "marital", "education", "default", "housing", 
                 "loan", "contact", "month", "day_of_week", "poutcome")
tele_raw[factor_vars] <- lapply(tele_raw[factor_vars], as.factor)
tele_raw$y <- as.factor(tele_raw$y)

# Drop 'duration' (per instructions)
tele_raw <- tele_raw %>% select(-duration)

#Preserve clean version for Random Forest (factors only)
tele <- tele_raw  # used for dummy encoding later


# One-hot encode categorical variables
tele_dummies <- dummyVars(" ~ .", data = tele)
tele_encoded <- predict(tele_dummies, newdata = tele) %>% as.data.frame()

# Add the target variable back
tele_encoded$y <- tele$y



# Normalize numeric features for KNN, ANN, SVM
normalize <- function(x) {
  return((x - min(x)) / (max(x) - min(x)))
}

# Normalize numeric variables
tele_scaled <- tele_encoded
numeric_cols <- sapply(tele_scaled, is.numeric)
tele_scaled[numeric_cols] <- lapply(tele_scaled[numeric_cols], normalize)
tele_scaled$y <- tele$y




# Train/Test Split (50/50)


# Create 50/50 train/test split
split_index <- createDataPartition(tele$y, p = 0.5, list = FALSE)
train_clean <- tele_encoded[split_index, ]
test_clean <- tele_encoded[-split_index, ]

train_scaled <- tele_scaled[split_index, ]
test_scaled <- tele_scaled[-split_index, ]
```


**class balance**
  
  The dataset is imbalanced, with only 11.3% of customers subscribing (y = 1). This imbalance can cause models to favor the majority class (y = 0), leading to high overall accuracy but poor performance in detecting actual conversions. As a result, recall and precision for the positive class may suffer, which is critical when the goal is to identify potential buyers. To help with this, we used models that handle imbalance well and applied a loss matrix in the decision tree to make the model more sensitive to potential subscribers.


table(tele$y)
prop.table(table(tele$y))

# Step 5: Building first level Models
To predict whether a telemarketing call will successfully result in a term deposit subscription, we applied six supervised classification models: Logistic Regression, K-Nearest Neighbors (KNN), Artificial Neural Network (ANN), Support Vector Machine (SVM), Decision Tree, and Random Forest. Each model was trained on 50% of the dataset and evaluated on the remaining 50% using accuracy and Kappa scores.

After evaluating individual models, we implemented a Stacked Model (ensemble) to combine predictions and enhance overall accuracy. This two-level approach helps us identify the most effective strategy for maximizing marketing ROI while reducing unsuccessful calls.


**LR Model**
  
  
  

print("Preview y column in test_clean:")
str(test_clean$y)



# Train logistic regression with caret for cross-validation
set.seed(123)
model_logit <- train(
  y ~ ., 
  data = train_clean, 
  method = "glm",
  trControl = trainControl(method = "cv", number = 5)
)

# Predict on test data
logit_preds <- predict(model_logit, newdata = test_clean)

# Confusion matrix
cm_logit <- confusionMatrix(logit_preds, test_clean$y)
cm_logit




# Load broom for tidy summary
# Fit logistic regression model on encoded training data
model_logit <- glm(y ~ ., data = train_clean, family = binomial)

# Extract and sort coefficients
coeffs <- tidy(model_logit)
coeffs_sorted <- coeffs[order(-abs(coeffs$estimate)), ]

# Show top 10 strongest predictors (by absolute coefficient)
head(coeffs_sorted, 10)

#KNN Model
  

set.seed(123)
model_knn <- train(
  y ~ ., data = train_scaled, method = "knn",
  tuneLength = 10,  # Increased for more refined k
  trControl = trainControl(method = "cv", number = 5)
)
knn_preds <- predict(model_knn, newdata = test_scaled)
cm_knn <- confusionMatrix(knn_preds, test_scaled$y)
cm_knn

#ANN
 
# Train ANN using scaled data
set.seed(123)
model_ann <- nnet(
  y ~ ., 
  data = train_scaled, 
  size = 5,       # number of hidden units (can be tuned)
  decay = 0.1,    # weight decay (regularization)
  maxit = 200,    # number of iterations
  trace = FALSE   # suppress training output
)

# Predict probabilities
ann_probs <- predict(model_ann, newdata = test_scaled, type = "raw")

# Convert to binary class (threshold = 0.5)
ann_preds <- as.factor(ifelse(ann_probs > 0.5, 1, 0))

# Confusion matrix
cm_ann <- confusionMatrix(ann_preds, test_scaled$y)
cm_ann

#SVM Model
# Train SVM with radial kernel on scaled data
set.seed(123)
model_svm <- train(
  y ~ ., 
  data = train_scaled, 
  method = "svmRadial", 
  trControl = trainControl(method = "cv", number = 5), 
  tuneLength = 3  # you can increase this to explore more C and sigma values
)

# Predict on test data
svm_preds <- predict(model_svm, newdata = test_scaled)

# Confusion matrix
cm_svm <- confusionMatrix(svm_preds, test_scaled$y)
cm_svm

# Define loss matrix: penalize missing a 'yes' more than predicting a false 'yes'
loss_matrix <- matrix(c(0, 1, 5, 0), nrow = 2)

# Train tree with loss matrix
set.seed(123)
model_dt <- rpart(
  y ~ ., 
  data = train_clean, 
  method = "class",
  parms = list(loss = loss_matrix),
  control = rpart.control(cp = 0.01, maxdepth = 4)
)

# Predict and evaluate
dt_preds <- predict(model_dt, newdata = test_clean, type = "class")
cm_dt <- confusionMatrix(dt_preds, test_clean$y)
cm_dt


# Visualize the updated tree
rpart.plot(model_dt, main = "Decision Tree with Loss Matrix")


#RF Model


# Create train/test split from factor-based data (only for Random Forest)
split_index <- createDataPartition(tele_raw$y, p = 0.5, list = FALSE)
train_factors <- tele_raw[split_index, ]
test_factors <- tele_raw[-split_index, ]

# Train Random Forest on factor-based dataset
set.seed(123)
model_rf <- randomForest(
  y ~ ., 
  data = train_factors, 
  ntree = 100, 
  importance = TRUE
)

# Predict and evaluate
rf_preds <- predict(model_rf, newdata = test_factors)
cm_rf <- confusionMatrix(rf_preds, test_factors$y)
cm_rf

# Plot variable importance
varImpPlot(model_rf, 
           main = "Random Forest - Feature Importance", 
           type = 2)  # type = 2 shows mean decrease in accuracy
```

The Random Forest model achieved an accuracy of 89.8% and Kappa of 0.35, indicating modest agreement beyond chance. While its sensitivity (97.4%) is strong, capturing most of the 'no' responses, it struggled with specificity (30.3%), often misclassifying true 'yes' responses. This imbalance is also seen in the low negative predictive value (59.3%), which could result in missed opportunities. However, its feature importance plot revealed valuable insights, highlighting age, euribor3m, education, and campaign as key predictors. Overall, while RF provides interpretability and good recall, it may benefit from tuning or balanced resampling to better detect conversions.

#retubed random-forest-mode 
set.seed(123)
tunegrid <- expand.grid(mtry = c(2, 5, 10, 15))

tuned_rf <- train(
  y ~ ., 
  data = train_factors,
  method = "rf",
  metric = "Kappa",
  trControl = trainControl(method = "cv", number = 5),
  tuneGrid = tunegrid,
  ntree = 200
)

# Evaluate tuned model
tuned_rf_preds <- predict(tuned_rf, newdata = test_factors)
cm_rf_tuned <- confusionMatrix(tuned_rf_preds, test_factors$y)
cm_rf_tuned
```
```{r first-level-model-summary, message=FALSE, warning=FALSE}
# Create summary table for first-level models
first_level_summary <- data.frame(
  Model = c("Logistic Regression", "KNN", "ANN", "SVM", "Decision Tree", "Random Forest"),
  Accuracy = c(
    cm_logit$overall["Accuracy"],
    cm_knn$overall["Accuracy"],
    cm_ann$overall["Accuracy"],
    cm_svm$overall["Accuracy"],
    cm_dt$overall["Accuracy"],
    cm_rf$overall["Accuracy"]
  ),
  Kappa = c(
    cm_logit$overall["Kappa"],
    cm_knn$overall["Kappa"],
    cm_ann$overall["Kappa"],
    cm_svm$overall["Kappa"],
    cm_dt$overall["Kappa"],
    cm_rf$overall["Kappa"]
  ),
  Sensitivity = c(
    cm_logit$byClass["Sensitivity"],
    cm_knn$byClass["Sensitivity"],
    cm_ann$byClass["Sensitivity"],
    cm_svm$byClass["Sensitivity"],
    cm_dt$byClass["Sensitivity"],
    cm_rf$byClass["Sensitivity"]
  ),
  Specificity = c(
    cm_logit$byClass["Specificity"],
    cm_knn$byClass["Specificity"],
    cm_ann$byClass["Specificity"],
    cm_svm$byClass["Specificity"],
    cm_dt$byClass["Specificity"],
    cm_rf$byClass["Specificity"]
  )
)

first_level_summary

#Building Stacked Model


# Combine predictions from individual models
stacked_data <- data.frame(
  logit = logit_preds,
  knn = knn_preds,
  ann = ann_preds,
  svm = svm_preds,
  dt = dt_preds,
  rf = rf_preds,
  y = test_clean$y  # use the same ground truth for evaluation
)


# Split the stacked dataset into train/test for second-level model
set.seed(123)
stack_index <- createDataPartition(stacked_data$y, p = 0.7, list = FALSE)
stack_train <- stacked_data[stack_index, ]
stack_test <- stacked_data[-stack_index, ]

# Train a Decision Tree on the stacked predictions
model_stack <- rpart(y ~ ., data = stack_train, method = "class")

# Predict on stack test set
stack_preds <- predict(model_stack, newdata = stack_test, type = "class")

# Evaluate performance
cm_stack <- confusionMatrix(stack_preds, stack_test$y)
cm_stack

The stacked model is showing perfect performance across all metrics again (accuracy, sensitivity, specificity, etc.). While impressive, this level of perfection on a real-world imbalanced dataset strongly suggests overfitting so we dropped the DT Model.

#Stacked Model with out DT 

# Combine selected model predictions into a stacked dataset
stacked_data <- data.frame(
  logit = logit_preds,
  knn = knn_preds,
  ann = ann_preds,
  svm = svm_preds,
  rf = rf_preds,
  y = test_clean$y  # true labels
)

# Split stacked dataset (70/30)
set.seed(123)
stack_index <- createDataPartition(stacked_data$y, p = 0.7, list = FALSE)
stack_train <- stacked_data[stack_index, ]
stack_test  <- stacked_data[-stack_index, ]

# Train stacked decision tree model (excluding DT input)
model_stack <- rpart(y ~ ., data = stack_train, method = "class")

# Predict on test portion of stacked data
stack_preds <- predict(model_stack, newdata = stack_test, type = "class")

# Evaluate stacked model
cm_stack <- confusionMatrix(stack_preds, stack_test$y)
cm_stack



#Stacked Model with out ANN and DT

# Stack KNN, SVM, RF, and LR
stacked_data_drop2 <- data.frame(
  logit = as.numeric(logit_preds),
  knn   = as.numeric(knn_preds),
  svm   = as.numeric(svm_preds),
  rf    = as.numeric(rf_preds),
  y     = test_clean$y
)

# Split into train/test
set.seed(123)
stack_index <- createDataPartition(stacked_data_drop2$y, p = 0.7, list = FALSE)
stack_train <- stacked_data_drop2[stack_index, ]
stack_test  <- stacked_data_drop2[-stack_index, ]

# Train and evaluate meta-model
model_stack_drop2 <- rpart(y ~ ., data = stack_train, method = "class")
stack_preds <- predict(model_stack_drop2, newdata = stack_test, type = "class")
cm_stack <- confusionMatrix(stack_preds, stack_test$y)
cm_stack


#Stacked Model with out DT, LR, ANN

# Stack only KNN, SVM, and RF
stacked_data_drop3 <- data.frame(
  knn = as.numeric(knn_preds),
  svm = as.numeric(svm_preds),
  rf  = as.numeric(rf_preds),
  y   = test_clean$y
)

# Split into train/test
set.seed(123)
stack_index <- createDataPartition(stacked_data_drop3$y, p = 0.7, list = FALSE)
stack_train <- stacked_data_drop3[stack_index, ]
stack_test  <- stacked_data_drop3[-stack_index, ]

# Train and evaluate meta-model
model_stack_drop3 <- rpart(y ~ ., data = stack_train, method = "class")
stack_preds <- predict(model_stack_drop3, newdata = stack_test, type = "class")
cm_stack <- confusionMatrix(stack_preds, stack_test$y)
cm_stack



#For the original stacked model (includes all models):
cm_stack1 <- confusionMatrix(stack_preds, stack_test$y)
cm_stack1

#For stacked model without DT:
cm_stack2 <- confusionMatrix(stack_preds, stack_test$y)
cm_stack2

#For stacked model without DT:
cm_stack3 <- confusionMatrix(stack_preds, stack_test$y)
cm_stack3


#For stacked model without DT, ANN, and LR:
cm_stack4 <- confusionMatrix(stack_preds, stack_test$y)
cm_stack4



#stack-combine-names
stacked_summary <- data.frame(
  Model = c("All Models", "Drop DT", "Drop DT & ANN", "Drop DT, ANN & LR"),
  Accuracy = c(cm_stack1$overall["Accuracy"],
               cm_stack2$overall["Accuracy"],
               cm_stack3$overall["Accuracy"],
               cm_stack4$overall["Accuracy"]),
  Kappa = c(cm_stack1$overall["Kappa"],
            cm_stack2$overall["Kappa"],
            cm_stack3$overall["Kappa"],
            cm_stack4$overall["Kappa"]),
  Sensitivity = c(cm_stack1$byClass["Sensitivity"],
                  cm_stack2$byClass["Sensitivity"],
                  cm_stack3$byClass["Sensitivity"],
                  cm_stack4$byClass["Sensitivity"]),
  Specificity = c(cm_stack1$byClass["Specificity"],
                  cm_stack2$byClass["Specificity"],
                  cm_stack3$byClass["Specificity"],
                  cm_stack4$byClass["Specificity"])
)
stacked_summary









# Final Model Recomendation 

# Extract confusion matrix for final stacked model
cm_table <- cm_stack4$table

# Assign values
TP <- cm_table["1", "1"]  # Predicted 1, Actual 1
FP <- cm_table["1", "0"]  # Predicted 1, Actual 0
TN <- cm_table["0", "0"]  # Predicted 0, Actual 0
FN <- cm_table["0", "1"]  # Predicted 0, Actual 1

# Print results
cat("True Positives (TP):", TP, "\n")
cat("False Positives (FP):", FP, "\n")
cat("True Negatives (TN):", TN, "\n")
cat("False Negatives (FN):", FN, "\n")


#financial_df
financial_df <- data.frame(
  Metric = c("True Positives (Successful Calls)", 
             "False Positives (Wasted Calls)", 
             "False Negatives (Missed Converts)", 
             "True Negatives (Correctly Ignored)", 
             "Total Calls Made", 
             "Cost per Call", 
             "Revenue per Subscription", 
             "Total Cost", 
             "Total Revenue", 
             "Net Profit"),
  Value = c(694, 0, 2, 5482, 694, "$1", "$5", "$694", "$3,470", "$2,776")
)

financial_df
```


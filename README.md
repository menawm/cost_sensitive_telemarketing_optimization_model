# Telemarketing Optimization with Machine Learning

## Overview
This project builds a machine learning–driven lead scoring system to improve telemarketing efficiency by targeting only customers most likely to convert.

Instead of high-volume outreach, the model enables **precision targeting**, reducing cost while maintaining revenue.

---

## Problem
Traditional telemarketing relies on broad outreach with:

- ~11% conversion rate  
- High operational costs  
- Inefficient use of call center resources  

Most calls generate no value, leading to wasted spend and missed high-value opportunities.

---

## Solution
Developed a **stacked ensemble model** to predict conversion likelihood:

- K-Nearest Neighbors (KNN)  
- Support Vector Machine (SVM)  
- Random Forest  

The model scores customers before outreach, allowing teams to prioritize high-probability leads and eliminate low-value calls.

---

## Results

### Model Performance
- Accuracy: ~99.97%  
- Recall (Sensitivity): ~100%  
- False Positives: ~0  

### Business Impact
- ~85% reduction in call volume  
- ~90% reduction in operational costs  
- ~4x ROI  

| Metric | Traditional Approach | Model-Driven Approach |
|--------|---------------------|----------------------|
| Calls Made | 6,178 | 694 |
| Cost | $6,178 | $694 |
| Revenue | — | $3,470 |
| Net Profit | — | $2,776 |

---

## Data
The dataset (`tele.csv`) contains historical telemarketing campaign data used to predict whether a customer will subscribe to a product.

### Target Variable
- `y` → Whether the customer subscribed (Yes/No)

### Key Features
- **Demographics:** age, job, marital status, education  
- **Financial:** balance, housing loan, personal loan  
- **Contact Info:** contact type, day, month, duration  
- **Campaign Data:** number of contacts, previous outcomes  

The dataset enables modeling customer behavior and identifying high-probability conversion segments.

---

## Models Used
Multiple machine learning models were developed and evaluated:

- Logistic Regression  
- K-Nearest Neighbors (KNN)  
- Support Vector Machine (SVM)  
- Decision Tree  
- Random Forest  

### Ensemble Approach
In addition to individual models, several **stacked ensemble models** were tested by combining different algorithms (e.g., Logistic Regression, Decision Tree, KNN, SVM, Random Forest).

While many configurations achieved similarly high accuracy, increasing model complexity did **not** lead to meaningful performance improvements.

### Final Model
The final model selected was a **stacked ensemble (KNN + SVM + Random Forest)** based on:

- Near-perfect recall (captures almost all converters)  
- Near-zero false positives (minimizes wasted outreach)  
- No incremental gain from adding more models  
- Lower risk of overfitting compared to more complex stacks  
- Simpler, more reliable deployment  

This approach ensures both **high predictive performance and operational efficiency**.

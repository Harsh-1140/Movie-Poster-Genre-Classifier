# Movie Poster Classification (Comedy vs. Thriller)

This repository contains the implementation for **MTH441: Assignment 2**. The objective is to build a feature extraction pipeline and binary classifier to identify whether a given movie poster belongs to the **Comedy** (`class = 0`) or **Thriller** (`class = 1`) genre.

---

## Problem Overview & Dataset

* **Test Benchmark**: 190 movie posters from post-2000s United States films.
* **Ground Truth Labeling**: 
  * A movie is labeled **Comedy (`0`)** if and only if *Comedy* is its first genre tag on IMDb.
  * A movie is labeled **Thriller (`1`)** if and only if *Thriller* is its first genre tag on IMDb.
* **Evaluation Metric**: **Misclassification Rate** (lowest error across the hidden test set).

---

## Methodology & Feature Engineering

Since movie genres heavily correlate with visual themes (e.g., bright, vibrant colours in comedies vs. dark tones, high contrast, and sharp edges in thrillers), we extract a rich, structured $\mathbb{R}^p$ numerical representation using the `imager` package:

1. **Spatial Standardisation**:
   * Posters are resized to a fixed $128 \times 128$ resolution and dynamic range normalized to $[0, 1]$.
2. **Colour Channel Distributions**:
   * Channel-wise normalised colour histograms (16 bins across R, G, and B channels) capturing colour palette differences.
3. **Luminance & Texture Statistics**:
   * Grayscale moments: Mean brightness, standard deviation (contrast), skewness, and kurtosis.
   * Spatial gradient magnitudes (`imgradient`) measuring edge density, mean edge strength, and variance.
4. **Spatial Layout Representation**:
   * Downsampled $16 \times 16$ grayscale intensity map capturing macro spatial composition and lighting distribution.
5. **Model Estimation**:
   * Sparse Logistic Regression trained via **LASSO (L1 Regularization)** with 10-fold cross-validation (`glmnet`) to prevent overfitting on the high-dimensional feature space.

---

## Submission Objects

The generated `.Rdata` file stores exactly four runtime objects:

| Object | Type | Description |
| :--- | :--- | :--- |
| `make_feature` | Function | Accepts an `imager::cimg` image and returns an $\mathbb{R}^p$ numerical feature vector. |
| `beta_hat` | Vector | The fitted coefficient vector in $\mathbb{R}^p$. |
| `class_prob` | Function | Takes the linear prediction $\mathbf{x}_i^\top \hat{\boldsymbol{\beta}}$ and computes class probability via the logistic sigmoid function. |
| `classify` | Function | Maps the predicted probability to a categorical character output (`"0"` for Comedy, `"1"` for Thriller). |

---

## Evaluation Pipeline Verification

The model is structured to execute seamlessly in the automated grading environment:

```R
library(imager)

# 1. Load submission environment
load("230443.Rdata")

# 2. Process input poster
poster <- load.image("path/to/test_poster.jpg")
x_i <- make_feature(poster)

# 3. Predict linear score and class probability
linear_pred <- sum(x_i * beta_hat)
p_i <- class_prob(linear_pred)

# 4. Final discrete prediction ("0" or "1")
predicted_label <- classify(p_i)

# ============================================
# MTH441 Assignment 2 - Poster Auto Training (Final Submission Ready - LASSO, No Scaling)
# ============================================

library(imager)
library(glmnet)
library(parallel)

# --- Step 1: Define required functions ---
make_feature <- function(img, resize_dim = c(128, 128), color_bins = 16) {
  if (!inherits(img, "cimg")) stop("make_feature expects an imager cimg object.")
  
  resized <- tryCatch({
    imager::resize(img, size_x = resize_dim[1], size_y = resize_dim[2])
  }, error = function(e) {
    tryCatch(imager::imresize(img, resize_dim[1], resize_dim[2]),
             error = function(e2) stop("Resize failed."))
  })
  
  resized <- resized / (max(resized) + 1e-9)
  
  channels <- imager::imsplit(resized, "c")
  if (length(channels) == 1) {
    ch_r <- channels[[1]]; ch_g <- channels[[1]]; ch_b <- channels[[1]]
  } else {
    ch_r <- channels[[1]]; ch_g <- channels[[2]]; ch_b <- channels[[3]]
  }
  
  vec_hist <- c()
  for (ch in list(ch_r, ch_g, ch_b)) {
    vals <- as.vector(ch)
    h <- hist(vals, breaks = seq(0, 1, length.out = color_bins + 1),
              plot = FALSE)$counts
    h <- h / sum(h)
    vec_hist <- c(vec_hist, h)
  }
  
  gray <- suppressWarnings(imager::grayscale(resized))
  gray_v <- as.vector(gray)
  g_mean <- mean(gray_v)
  g_sd <- sd(gray_v)
  g_skew <- mean((gray_v - g_mean)^3) / (g_sd^3 + 1e-9)
  g_kurt <- mean((gray_v - g_mean)^4) / (g_sd^4 + 1e-9)
  
  gx <- imager::imgradient(gray, "x")
  gy <- imager::imgradient(gray, "y")
  mag <- sqrt((as.numeric(gx))^2 + (as.numeric(gy))^2)
  edge_density <- mean(mag > 0.1)
  edge_mean <- mean(mag)
  edge_sd <- sd(mag)
  
  small <- imager::resize(gray, size_x = 16, size_y = 16)
  small_vec <- as.numeric(small)
  
  feat <- c(1, vec_hist, g_mean, g_sd, g_skew, g_kurt,
            edge_density, edge_mean, edge_sd, small_vec)
  as.numeric(feat)
}

# --- Step 2: Probability and classification functions ---
class_prob <- function(lin_pred) 1 / (1 + exp(-lin_pred))

classify <- function(p_or_linpred, threshold = 0.02, input_is_prob = TRUE) {
  if (!input_is_prob) p <- 1 / (1 + exp(-p_or_linpred)) else p <- p_or_linpred
  res <- ifelse(p >= threshold, "1", "0")
  as.character(res)
}

# --- Step 3: Load dataset ---
comedy_dir <- "D:/SEM 5/MTH441/Assignment/testing/posters/comedy"
thriller_dir <- "D:/SEM 5/MTH441/Assignment/testing/posters/thriller"

comedy_files <- list.files(comedy_dir, pattern = "\\.jpg$|\\.png$|\\.jpeg$", full.names = TRUE)
thriller_files <- list.files(thriller_dir, pattern = "\\.jpg$|\\.png$|\\.jpeg$", full.names = TRUE)

cat("Found", length(comedy_files), "comedy and", length(thriller_files), "thriller posters.\n")

extract_safe <- function(path) {
  tryCatch(make_feature(load.image(path)),
           error = function(e) { cat("Skipping", basename(path), ":", e$message, "\n"); NULL })
}

n_cores <- detectCores() - 5
cl <- makeCluster(n_cores)
clusterExport(cl, c("extract_safe", "make_feature"))
clusterEvalQ(cl, library(imager))

comedy_features   <- parLapply(cl, comedy_files, extract_safe)
thriller_features <- parLapply(cl, thriller_files, extract_safe)
stopCluster(cl)

comedy_features <- Filter(Negate(is.null), comedy_features)
thriller_features <- Filter(Negate(is.null), thriller_features)

X_train <- do.call(rbind, c(comedy_features, thriller_features))
y_train <- c(rep(0, length(comedy_features)), rep(1, length(thriller_features)))

X_train[!is.finite(X_train)] <- 0
X_train[is.na(X_train)] <- 0

cat("Extracted features for", length(y_train), "posters.\n")

# --- Step 4: Train LASSO logistic regression (CV + stronger regularization) ---
cat("Training LASSO logistic regression (10-fold CV, stronger regularization)...\n")

cvfit <- cv.glmnet(
  X_train, y_train,
  family = "binomial",
  alpha = 1,
  standardize = FALSE,
  nfolds = 10,
  type.measure = "deviance"
)

lambda_cv <- cvfit$lambda.min
lambda_strong <- lambda_cv * 0.25     # enforce stronger shrinkage

fit <- glmnet(
  X_train, y_train,
  family = "binomial",
  alpha = 1,
  lambda = lambda_strong,
  standardize = FALSE
)

beta_hat <- as.numeric(coef(fit))[-1]
nonzero <- sum(beta_hat != 0)

cat("Chosen λ:", lambda_strong, "\n")
cat("Non-zero coefficients:", nonzero, "\n")
cat("Length of beta_hat:", length(beta_hat), "\n")

# --- Step 5: Save submission ---
save(make_feature, beta_hat, class_prob, classify, file = "rollnumber.Rdata")
cat("Saved rollnumber.Rdata\n")








p <- class_prob(X_train %*% beta_hat)

thresholds <- seq(0, 1, by = 0.01)

J <- numeric(length(thresholds))

for (i in seq_along(thresholds)) {
  t <- thresholds[i]
  pred <- ifelse(p >= t, 1, 0)
  sens <- mean(pred[y_train == 1] == 1)
  spec <- mean(pred[y_train == 0] == 0)
  J[i] <- sens + spec - 1
}

best_t <- thresholds[which.max(J)]
best_t






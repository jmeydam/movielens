library(tidyverse)
library(caret)

###############################################################################
# Create edx set and validation set. Code provided by Prof. Irizarry:
#
#   https://www.edx.org/course/data-science-capstone
###############################################################################

rm(list = ls())

# MovieLens 10M dataset:
# https://grouplens.org/datasets/movielens/10m/
# http://files.grouplens.org/datasets/movielens/ml-10m.zip

dl <- tempfile()
download.file("http://files.grouplens.org/datasets/movielens/ml-10m.zip", dl)

ratings <- read.table(text = gsub("::", "\t", readLines(unzip(dl, "ml-10M100K/ratings.dat"))),
                      col.names = c("userId", "movieId", "rating", "timestamp"))

movies <- str_split_fixed(readLines(unzip(dl, "ml-10M100K/movies.dat")), "\\::", 3)
colnames(movies) <- c("movieId", "title", "genres")
movies <- as.data.frame(movies) %>% mutate(movieId = as.numeric(levels(movieId))[movieId],
                                           title = as.character(title),
                                           genres = as.character(genres))

movielens <- left_join(ratings, movies, by = "movieId")

# Validation set will be 10% of MovieLens data

set.seed(1) # if using R 3.6.0: set.seed(1, sample.kind = "Rounding")
test_index <- createDataPartition(y = movielens$rating, times = 1, p = 0.1, list = FALSE)
edx <- movielens[-test_index,]
temp <- movielens[test_index,]

# Make sure userId and movieId in validation set are also in edx set

validation <- temp %>% 
  semi_join(edx, by = "movieId") %>%
  semi_join(edx, by = "userId")

# Add rows removed from validation set back into edx set

removed <- anti_join(temp, validation)
edx <- rbind(edx, removed)

rm(dl, ratings, movies, test_index, temp, movielens, removed)


###############################################################################
# Model with regularized movie and user effect.
# Based on model and code covered in course. See also:
#
#   https://rafalab.github.io/dsbook/
#   http://blog.echen.me/2011/10/24/winning-the-netflix-prize-a-summary/
#
# In this implementation, the edx dataset is split into a training set and a 
# test set, and the parameter lambda is determined using the test set.
# The model is then trained on the complete edx dataset and evaluated using
# the validation set.
###############################################################################

# Function to calculate root mean square error

RMSE <- function(true_ratings, predicted_ratings){
  sqrt(mean((true_ratings - predicted_ratings)^2))
}

set.seed(999)

# Split edx dataset into training and test set
# Test set will be 20% of edx dataset

test_index <- createDataPartition(y = edx$rating,
                                  times = 1,
                                  p = 0.2,
                                  list = FALSE)
train_set <- edx[-test_index,]
test_set <- edx[test_index,]

# As above: Make sure userId and movieId in test set are also in training set

test_set <- test_set %>%
  semi_join(train_set, by = "movieId") %>%
  semi_join(train_set, by = "userId")

# Range of tuning parameter lambda, used for regularization

lambdas <- seq(0, 10, 0.25)

# Determine RMSE (test set) for values of lambda within the ramge above
# (The graph of the RMSE values shows that the minimum RSME lies within 
# this range)

rmses <- sapply(lambdas, function(lambda) {
  
  # Mean rating
  mu <- mean(train_set$rating)
  
  # Regularized movie effect
  b_i <- train_set %>% 
    group_by(movieId) %>%
    summarize(b_i = sum(rating - mu) / (n() + lambda))
  
  # Regularized user effect
  b_u <- train_set %>% 
    left_join(b_i, by="movieId") %>%
    group_by(userId) %>%
    summarize(b_u = sum(rating - b_i - mu) / (n() + lambda))
  
  predicted_ratings <- test_set %>% 
    left_join(b_i, by = "movieId") %>%
    left_join(b_u, by = "userId") %>%
    mutate(pred = mu + b_i + b_u) %>%
    pull(pred)
  
  return(RMSE(predicted_ratings, test_set$rating))
})

# Visualization
tuning <- data_frame(lambda = lambdas, RMSE = rmses)
plot <- ggplot(tuning) + geom_point(aes(lambda, RMSE))
# plot

# Choose lambda that minimizes RMSE for test set
lambda <- lambdas[which.min(rmses)]
paste("lambda minimizing RMSE:", lambda)

# With this lambda, fit model using entire dataset edx

# Mean rating
mu <- mean(edx$rating)

# Regularized movie effect
b_i <- edx %>% 
  group_by(movieId) %>%
  summarize(b_i = sum(rating - mu) / (n() + lambda))

# Regularized user effect
b_u <- edx %>% 
  left_join(b_i, by="movieId") %>%
  group_by(userId) %>%
  summarize(b_u = sum(rating - b_i - mu) / (n() + lambda))

# Evaluate the model using the validation set

predicted_ratings <- validation %>% 
  left_join(b_i, by = "movieId") %>%
  left_join(b_u, by = "userId") %>%
  mutate(pred = mu + b_i + b_u) %>%
  pull(pred)

# RMSE validation set
rmse_submission <- RMSE(predicted_ratings, validation$rating)
paste("RMSE submission:", round(rmse_submission, 5))

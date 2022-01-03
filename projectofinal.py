# Import libraries
import numpy as np
import pandas as pd
from scipy.sparse.linalg import svds
from surprise import Reader, Dataset, SVD
from surprise.model_selection import KFold, cross_validate


def recommend_movies(predictions, userID, movies, original_ratings, num_recommendations):
    # Get and sort the user's predictions
    user_row_number = userID - 1  # User ID starts at 1, not 0
    sorted_user_predictions = preds.iloc[user_row_number].sort_values(ascending=False)  # User ID starts at 1
    # Get the user's data and merge in the movie information.
    user_data = original_ratings[original_ratings.user_id == (userID)]
    user_full = (user_data.merge(movies, how='left', left_on='movie_id', right_on='movie_id').
                 sort_values(['rating'], ascending=False)
                 )
    print
    'User {0} has already rated {1} movies.'.format(userID, user_full.shape[0])
    print
    'Recommending highest {0} predicted ratings movies not already rated.'.format(num_recommendations)
    # Recommend the highest predicted rating movies that the user hasn't seen yet.
    recommendations = (movies[~movies['movie_id'].isin(user_full['movie_id'])].
                           merge(pd.DataFrame(sorted_user_predictions).reset_index(), how='left',
                                 left_on='movie_id',
                                 right_on='movie_id').
                           rename(columns={user_row_number: 'Predictions'}).
                           sort_values('Predictions', ascending=False).
                           iloc[:num_recommendations, :-1]
                           )
    return user_full, recommendations


# Reading ratings file
ratings = pd.read_csv('./ratings.csv', sep='\t', encoding='latin-1', usecols=['user_id', 'movie_id', 'rating', 'timestamp'])
# Reading users file
users = pd.read_csv('./users.csv', sep='\t', encoding='latin-1', usecols=['user_id', 'gender', 'zipcode', 'age_desc', 'occ_desc'])
# Reading movies file
movies = pd.read_csv('./movies.csv', sep='\t', encoding='latin-1', usecols=['movie_id', 'title', 'genres'])

n_users = ratings.user_id.unique().shape[0]
n_movies = ratings.movie_id.unique().shape[0]
print ('Number of users = ' + str(n_users) + ' | Number of movies = ' + str(n_movies))

Ratings = ratings.pivot(index = 'user_id', columns ='movie_id', values = 'rating').fillna(0)
print (Ratings.head())


# R = Ratings.as_matrix() -- https://pandas.pydata.org/pandas-docs/version/0.25.1/reference/api/pandas.DataFrame.as_matrix.html

R = Ratings.to_numpy()
user_ratings_mean = np.mean(R, axis = 1)
Ratings_demeaned = R - user_ratings_mean.reshape(-1, 1)

sparsity = round(1.0 - len(ratings) / float(n_users * n_movies), 3)
print ('The sparsity level of dataset is ' +  str(sparsity * 100) + '%')


U, sigma, Vt = svds(Ratings_demeaned, k = 50)

sigma = np.diag(sigma)


all_user_predicted_ratings = np.dot(np.dot(U, sigma), Vt) + user_ratings_mean.reshape(-1, 1)

preds = pd.DataFrame(all_user_predicted_ratings, columns = Ratings.columns)
print('-----------------------------')
uindex=list(ratings['user_id'][ratings['user_id'] == 918].index)
print(uindex[0])
print('-----------------------------')

already_rated, predictions = recommend_movies(preds, uindex[0], movies, ratings, 20)

print (already_rated.head())

print (predictions)

# Load Reader library
reader = Reader()
# Load ratings dataset with Dataset library
data = Dataset.load_from_df(ratings[['user_id', 'movie_id', 'rating']], reader)
# Split the dataset for 5-fold evaluation
kf = KFold(n_splits=5)
kf.split(data)
# Use the SVD algorithm.
svd = SVD()
# Compute the RMSE of the SVD algorithm.
cross_validate(svd, data, measures=['RMSE', 'MAE'], cv=5, verbose=True)


trainset = data.build_full_trainset()
svd.fit(trainset);

print (ratings[ratings['user_id'] == 918])

print (svd.predict(918, 25937))
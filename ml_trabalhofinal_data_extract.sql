-- Movies.csv
select a.id as movie_id,  case
    when a.assetable_type='movies' then m.original_title
    when  a.assetable_type='series' then s.original_title
    when  a.assetable_type='seasons' then s.original_title
    when a.assetable_type='episodes' then e.original_title
    when a.assetable_type='channels' then c.original_title
    end as title,
    group_concat(vag.slug separator '|') as genres
from assets a
    left join movies m on a.assetable_type='movies' and a.assetable_id=m.id
    left join series s on a.assetable_type='series' and a.assetable_id=s.id
    left join seasons se on a.assetable_type='seasons' and a.assetable_id=se.id
    left join episodes e on a.assetable_type='episodes' and a.assetable_id=e.id
    left join channels c on a.assetable_type='channles' and a.assetable_id=c.id
    join vw_asset_genres vag on a.id=vag.id
where
    a.deleted_at is null
    and a.assetable_type in ('movies','series','seasons','episodes','channles')
group by vag.id

-- users.csv
select
    ua.id as user_id,
    coalesce(gender, 'N') as gender,
    round(rand()*100,0) as age,
    round(rand()*10,0) as occupation,
    coalesce(address, 6200) as zipcode,
    coalesce(ag.classification, 'G') as age_desc,
    'NA' as occ_desc
from users_app ua
    left join age_groups ag on  ua.agerating=ag.id
where deleted_at is null;


-- ratings
select
    user_id as user_id ,
    asset_id as movie_id,
    round(rating/20,0) as rating,
    UNIX_TIMESTAMP(ur.created_at) as timestamp,
    user_id-1 as user_emb_id,
    asset_id-1 as movie_emb_id
from users_ratings ur
join assets on ur.asset_id = assets.id and deleted_at is not null
group by user_id, asset_id
;

/* 

Problem with this rattings:
sparsity level very high! All users recomentations were the same!!!

Number of users = 3995 | Number of movies = 415
movie_id  24788  24799  24805  24806  24808  ...  26623  26624  26625  26689  28339
user_id                                      ...                                   
57          0.0    0.0    0.0    0.0    0.0  ...    0.0    0.0    0.0    0.0    0.0
73          0.0    0.0    0.0    0.0    4.0  ...    0.0    0.0    0.0    0.0    0.0
86          0.0    0.0    3.0    3.0    1.0  ...    0.0    0.0    0.0    0.0    0.0
132         0.0    0.0    0.0    0.0    0.0  ...    0.0    0.0    0.0    0.0    0.0
202         0.0    0.0    0.0    0.0    0.0  ...    0.0    0.0    0.0    0.0    0.0

[5 rows x 415 columns]
The sparsity level of dataset is 99.5%
-----------------------------
2
-----------------------------
Empty DataFrame
Columns: [user_id, rating, timestamp, movie_id, title, genres]
Index: []
    movie_id  ...                                             genres
0      24770  ...                              earthlings-love-drama
1      24772  ...                                  animated-universe
2      24774  ...                  a-childs-perspective|supernatural
3      24775  ...                 deep-space-adventures|famous-faces
4      24777  ...                   earthlings-love-drama|technology
5      24778  ...                       aliens-monsters|famous-faces
6      24779  ...                         essential-action|ai-robots
7      24780  ...                         aliens-monsters|technology
8      24781  ...                  essential-action|mysteries-abound
9      24782  ...                      technology|the-future-of-love
10     24783  ...      mysteries-abound|out-of-this-world-adventures
11     24784  ...                      comedy-is-universal|paradoxes
12     24785  ...                   earthlings-love-drama|technology
13     24786  ...  earthlings-love-drama|technology|the-future-of...
14     24787  ...  body-horror|drama|mystery|psychological|horror...
15     24789  ...  mystery|thriller|drama|experimental|out-of-thi...
16     24790  ...                       out-of-this-world-adventures
17     24791  ...  the-future-is-female|ai-robots|out-of-this-wor...
18     24792  ...  earthlings-love-drama|paradoxes|the-future-is-...
19     24793  ...  aliens|creature-feature|drama|character-driven...

[20 rows x 3 columns]
Evaluating RMSE, MAE of algorithm SVD on 5 split(s).

                  Fold 1  Fold 2  Fold 3  Fold 4  Fold 5  Mean    Std     
RMSE (testset)    1.2312  1.2066  1.1931  1.2103  1.1942  1.2071  0.0138  
MAE (testset)     0.9477  0.9340  0.9248  0.9293  0.9350  0.9342  0.0077  
Fit time          0.38    0.40    0.39    0.43    0.39    0.40    0.02    
Test time         0.01    0.01    0.01    0.01    0.01    0.01    0.00    

*/





-- -------------------------------------------------------------------------

drop view if exists vw_recomendation_rattings;
create view vw_recomendation_rattings as
select
    user_id as user_id ,
    asset_id as movie_id,
    round(rating/20,0) as rating,
    UNIX_TIMESTAMP(ur.created_at) as timestamp,
    user_id-1 as user_emb_id,
    asset_id-1 as movie_emb_id
from users_ratings ur
join assets on ur.asset_id = assets.id and deleted_at is null
join users_app ua on ur.id=ua.id and ua.deleted_at is null
group by user_id, asset_id
union
select
    user_id as user_id ,
    asset_id as movie_id,
    5 rating, -- assuming that if its a favorite, then top score!
    UNIX_TIMESTAMP(f.created_at) as timestamp,
    user_id-1 as user_emb_id,
    asset_id-1 as movie_emb_id
from favourites f
join assets on f.asset_id = assets.id and deleted_at is  null
join users_app ua on f.id=ua.id and ua.deleted_at is null
group by user_id, asset_id
union
select
    user_id as user_id ,
    asset_id as movie_id,
    5 as rating, -- assuming that if its a favorite, then top score!
    UNIX_TIMESTAMP(b.created_at) as timestamp,
    user_id-1 as user_emb_id,
    asset_id-1 as movie_emb_id
from bookmarks b
join assets on b.asset_id = assets.id and deleted_at is null
join users_app ua on b.id=ua.id and ua.deleted_at is null
group by user_id, asset_id
;

select user_id, movie_id, sum(rating) as rating, UNIX_TIMESTAMP(now()) as timestamp, user_emb_id, movie_emb_id
from vw_recomendation_rattings group by user_id, movie_id;



/*

Number of users = 103008 | Number of movies = 1002


movie_id  24770  24772  24774  24775  24777  ...  28380  28381  28382  28383  28384
user_id                                      ...                                   
15          0.0    0.0    0.0    0.0    0.0  ...    0.0    0.0    0.0    0.0    0.0
22          0.0    0.0    0.0    0.0    0.0  ...    0.0    0.0    0.0    0.0    0.0
30          0.0    0.0    0.0    0.0    0.0  ...    0.0    0.0    0.0    0.0    0.0
35          0.0    0.0    0.0    0.0    0.0  ...    0.0    0.0    0.0    0.0    0.0
38          0.0    0.0    0.0    0.0    0.0  ...    0.0    0.0    0.0    0.0    0.0

[5 rows x 1002 columns]
The sparsity level of dataset is 99.6%
-----------------------------
55
-----------------------------
Empty DataFrame
Columns: [user_id, rating, timestamp, movie_id, title, genres]
Index: []
     movie_id  ...                                             genres
170     25228  ...                        mysteries-abound|technology
167     25224  ...                evil-ai-assistants|ai-robots|horror
165     25154  ...     ai-robots|animated-universe|stranded-abandoned
163     25131  ...                             ai-robots|famous-faces
160     25127  ...                      mysteries-abound|famous-faces
6       24779  ...                         essential-action|ai-robots
157     25124  ...                             ai-robots|famous-faces
121     25032  ...         technology|earthlings-love-drama|ai-robots
158     25125  ...  ai-robots|animated-universe|earthlings-love-drama
162     25129  ...            mysteries-abound|horror|aliens-monsters
156     25122  ...                             ai-robots|famous-faces
3       24775  ...                 deep-space-adventures|famous-faces
166     25212  ...                       mysteries-abound|time-travel
171     25256  ...                   aliens-monsters|mysteries-abound
174     25298  ...                    technology|a-childs-perspective
161     25128  ...                      dust-original|aliens-monsters
154     25120  ...                             ai-robots|famous-faces
30      24878  ...                        mysteries-abound|technology
124     25035  ...                               technology|ai-robots
155     25121  ...                             dystopian|famous-faces

[20 rows x 3 columns]
Evaluating RMSE, MAE of algorithm SVD on 5 split(s).

                  Fold 1  Fold 2  Fold 3  Fold 4  Fold 5  Mean    Std     
RMSE (testset)    1.0513  1.0336  1.0607  1.0390  1.0786  1.0526  0.0161  
MAE (testset)     0.2554  0.2540  0.2620  0.2548  0.2681  0.2589  0.0054  
Fit time          18.52   17.76   18.34   17.75   18.22   18.12   0.31    
Test time         0.64    0.89    0.72    0.61    0.61    0.69    0.10   


*/


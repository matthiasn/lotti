import tensorflow as tf


def cat_id_column(train_x, test_x, unlabeled, col_name):
    train_set = set(train_x[col_name])
    test_set = set(test_x[col_name])
    unlabeled_set = set(unlabeled[col_name])
    id_max = max(train_set.union(test_set).union(unlabeled_set))
    return tf.feature_column.indicator_column(
        tf.feature_column.categorical_column_with_identity(
            key=col_name, num_buckets=id_max + 1))


def cat_id_embedding(train_x, test_x, unlabeled, col_name, dimension):
    train_set = set(train_x[col_name])
    test_set = set(test_x[col_name])
    unlabeled_set = set(unlabeled[col_name])
    id_max = max(train_set.union(test_set).union(unlabeled_set))
    return tf.feature_column.embedding_column(
        tf.feature_column.categorical_column_with_identity(
            key=col_name, num_buckets=id_max + 1), dimension)


def cat_id_column_fixed_buckets(col_name, buckets):
    return tf.feature_column.indicator_column(
        tf.feature_column.categorical_column_with_identity(
            key=col_name, num_buckets=buckets))


def numeric_column(k):
    return tf.feature_column.numeric_column(key=k)


def cat_dict_column(train_x, test_x, unlabeled, col_name):
    train_set = set(train_x[col_name])
    test_set = set(test_x[col_name])
    unlabeled_set = set(unlabeled[col_name])
    dictionary_set = train_set.union(test_set).union(unlabeled_set)
    return tf.feature_column.indicator_column(
        tf.feature_column.categorical_column_with_vocabulary_list(
            col_name, dictionary_set))

def cat_dict_embedding(train_x, test_x, unlabeled, col_name, dimension):
    train_set = set(train_x[col_name])
    test_set = set(test_x[col_name])
    unlabeled_set = set(unlabeled[col_name])
    dictionary_set = train_set.union(test_set).union(unlabeled_set)
    return tf.feature_column.embedding_column(
        tf.feature_column.categorical_column_with_vocabulary_list(
            col_name, dictionary_set), dimension)

def story_model_columns(train_x, test_x, unlabeled):
    return [
        cat_dict_embedding(train_x, test_x, unlabeled, 'Geohash', 1500),
        cat_dict_column(train_x, test_x, unlabeled, 'GeohashWide'),
        cat_dict_embedding(train_x, test_x, unlabeled, 'Tags1', 1000),
        cat_dict_embedding(train_x, test_x, unlabeled, 'Mentions1', 200),
        cat_id_column_fixed_buckets('Hour', 24),
        cat_id_column_fixed_buckets('HalfQuarterDay', 8),
        cat_id_column(train_x, test_x, unlabeled, 'WeeksAgo'),
        cat_id_column(train_x, test_x, unlabeled, 'DaysAgo'),
        cat_id_embedding(train_x, test_x, unlabeled, 'Md', 100),
        numeric_column('Visit'),
        numeric_column('Screenshot'),
        numeric_column('Starred'),
        numeric_column('ImgFile'),
        numeric_column('AudioFile'),
        numeric_column('Task')
    ]

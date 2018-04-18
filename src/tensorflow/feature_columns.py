import tensorflow as tf


def cat_id_column(train_x, test_x, col_name):
    id_max = max(set(train_x[col_name]).union(set(test_x[col_name])))
    return tf.feature_column.indicator_column(
        tf.feature_column.categorical_column_with_identity(
            key=col_name, num_buckets=id_max + 1))


def cat_id_column_fixed_buckets(col_name, buckets):
    return tf.feature_column.indicator_column(
        tf.feature_column.categorical_column_with_identity(
            key=col_name, num_buckets=buckets))


def numeric_column(k):
    return tf.feature_column.numeric_column(key=k)


def cat_dict_column(train_x, test_x, col_name):
    dictionary_set = set(train_x[col_name]).union(set(test_x[col_name]))
    return tf.feature_column.indicator_column(
        tf.feature_column.categorical_column_with_vocabulary_list(
            col_name, dictionary_set))


def story_model_columns(train_x, test_x):
    return [
        cat_dict_column(train_x, test_x, 'Geohash'),
        cat_dict_column(train_x, test_x, 'GeohashWide'),
        cat_dict_column(train_x, test_x, 'Tags'),
        cat_dict_column(train_x, test_x, 'Mentions'),
        cat_id_column_fixed_buckets('Hour', 24),
        cat_id_column_fixed_buckets('HalfQuarterDay', 8),
        cat_id_column(train_x, test_x, 'WeeksAgo'),
        cat_id_column(train_x, test_x, 'DaysAgo'),
        cat_id_column(train_x, test_x, 'Md'),
        numeric_column('Starred'),
        numeric_column('ImgFile'),
        numeric_column('AudioFile'),
        numeric_column('Task')
    ]

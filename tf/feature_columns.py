from __future__ import absolute_import
from __future__ import division
from __future__ import print_function

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

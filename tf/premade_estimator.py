#  Copyright 2016 The TensorFlow Authors. All Rights Reserved.
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.

# Adapted from Iris example

from __future__ import absolute_import
from __future__ import division
from __future__ import print_function

import argparse
import tensorflow as tf

import meo_data

parser = argparse.ArgumentParser()
parser.add_argument('--batch_size', default=100, type=int, help='batch size')
parser.add_argument('--train_steps', default=10000, type=int,
                    help='number of training steps')


def main(argv):
    args = parser.parse_args(argv[1:])

    (train_x, train_y), (test_x, test_y) = meo_data.load_data()

    my_feature_columns = []

    geohash_set = set(train_x['Geohash'])
    geohash_column = tf.feature_column.indicator_column(
        tf.feature_column.categorical_column_with_vocabulary_list(
            "Geohash", geohash_set))
    my_feature_columns.append(geohash_column)

    mentions_set = set(train_x['Mentions'])
    mentions_column = tf.feature_column.indicator_column(
        tf.feature_column.categorical_column_with_vocabulary_list(
            "Mentions", mentions_set))
    my_feature_columns.append(mentions_column)

    hour_column = tf.feature_column.indicator_column(
        tf.feature_column.categorical_column_with_identity(
            key="Hour", num_buckets=24))
    my_feature_columns.append(hour_column)

    days = max(set(train_x['Day']))
    day_column = tf.feature_column.indicator_column(
        tf.feature_column.categorical_column_with_identity(
            key="Day", num_buckets=days+1))
    my_feature_columns.append(day_column)

    wc = max(set(train_x['Md']))
    wc_column = tf.feature_column.indicator_column(
        tf.feature_column.categorical_column_with_identity(
            key="Md", num_buckets=wc+1))
    my_feature_columns.append(wc_column)

    num_keys = ['Starred', 'ImgFile', 'AudioFile', 'Task']

    for key in num_keys:
        my_feature_columns.append(tf.feature_column.numeric_column(key=key))

    classifier = tf.estimator.DNNClassifier(
        feature_columns=my_feature_columns,
        hidden_units=[512, 512],
        n_classes=439)

    classifier.train(
        input_fn=lambda: meo_data.train_input_fn(train_x, train_y,
                                                 args.batch_size),
        steps=args.train_steps)

    eval_result = classifier.evaluate(
        input_fn=lambda: meo_data.eval_input_fn(test_x, test_y,
                                                args.batch_size))

    print('\nTest set accuracy: {accuracy:0.3f}\n'.format(**eval_result))

    expected = [108, 29, 324]
    predict_x = {
        'Geohash': ['u33df1j', 'u1x0eq6', 'u1x0vju'],
        'Starred': [0, 1, 0],
        'ImgFile': [0, 0, 0],
        'AudioFile': [0, 0, 0],
        'Task': [1, 0, 0],
        'Md': [8, 9, 11],
        'Day': [326, 19, 95],
        'Hour': [10, 16, 10],
        'Mentions': ['none', 'none', 'none']
    }

    predictions = classifier.predict(
        input_fn=lambda: meo_data.eval_input_fn(predict_x,
                                                labels=None,
                                                batch_size=args.batch_size))

    template = ('\nPrediction is "{}" ({:.1f}%), expected "{}"')

    for pred_dict, expec in zip(predictions, expected):
        class_id = pred_dict['class_ids'][0]
        probability = pred_dict['probabilities'][class_id]
        print(template.format(class_id, 100 * probability, expec))


if __name__ == '__main__':
    tf.logging.set_verbosity(tf.logging.INFO)
    tf.app.run(main)

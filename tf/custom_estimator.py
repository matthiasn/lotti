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
"""An Example of a custom Estimator for the Iris dataset."""
from __future__ import absolute_import
from __future__ import division
from __future__ import print_function

import argparse
import tensorflow as tf
import random

import meo_data

parser = argparse.ArgumentParser()
parser.add_argument('--batch_size', default=100, type=int, help='batch size')
parser.add_argument('--train_steps', default=10000, type=int,
                    help='number of training steps')


def my_model(features, labels, mode, params):
    """DNN with three hidden layers, and dropout of 0.1 probability."""
    # Create three fully connected layers each layer having a dropout
    # probability of 0.1.
    net = tf.feature_column.input_layer(features, params['feature_columns'])
    for units in params['hidden_units']:
        net = tf.layers.dense(net, units=units, activation=tf.nn.relu)

    # Compute logits (1 per class).
    logits = tf.layers.dense(net, params['n_classes'], activation=None)

    # Compute predictions.
    predicted_classes = tf.argmax(logits, 1)
    if mode == tf.estimator.ModeKeys.PREDICT:
        predictions = {
            'class_ids': predicted_classes[:, tf.newaxis],
            'probabilities': tf.nn.softmax(logits),
            'top_k': tf.nn.top_k(logits, k=10)[1],
            'logits': logits,
        }
        return tf.estimator.EstimatorSpec(mode, predictions=predictions)

    # Compute loss.
    loss = tf.losses.sparse_softmax_cross_entropy(labels=labels, logits=logits)

    accuracy = tf.metrics.accuracy(labels=labels,
                                   predictions=predicted_classes,
                                   name='acc_op')

    accuracy_top_5 = tf.metrics.mean(tf.nn.in_top_k(predictions=logits,
                                                    targets=labels,
                                                    k=5))
    accuracy_top_10 = tf.metrics.mean(tf.nn.in_top_k(predictions=logits,
                                                     targets=labels,
                                                     k=10))
    accuracy_top_25 = tf.metrics.mean(tf.nn.in_top_k(predictions=logits,
                                                     targets=labels,
                                                     k=25))

    metrics = {'accuracy': accuracy,
               'accuracy_top_5': accuracy_top_5,
               'accuracy_top_10': accuracy_top_10,
               'accuracy_top_25': accuracy_top_25,
               }

    tf.summary.scalar('accuracy', accuracy[1])

    if mode == tf.estimator.ModeKeys.EVAL:
        return tf.estimator.EstimatorSpec(
            mode, loss=loss, eval_metric_ops=metrics)

    # Create training op.
    assert mode == tf.estimator.ModeKeys.TRAIN

    optimizer = tf.train.AdagradOptimizer(learning_rate=0.1)
    train_op = optimizer.minimize(loss, global_step=tf.train.get_global_step())
    return tf.estimator.EstimatorSpec(mode, loss=loss, train_op=train_op)

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
            key="Day", num_buckets=days + 1))
    my_feature_columns.append(day_column)

    wc = max(set(train_x['Md']))
    wc_column = tf.feature_column.indicator_column(
        tf.feature_column.categorical_column_with_identity(
            key="Md", num_buckets=wc + 1))
    my_feature_columns.append(wc_column)

    num_keys = ['Starred', 'ImgFile', 'AudioFile', 'Task']

    for key in num_keys:
        my_feature_columns.append(tf.feature_column.numeric_column(key=key))

    classifier = tf.estimator.Estimator(
        model_fn=my_model,
        params={
            'feature_columns': my_feature_columns,
            'hidden_units': [512, 512],
            'n_classes': 439,
        })

    classifier.train(
        input_fn=lambda: meo_data.train_input_fn(train_x, train_y,
                                                 args.batch_size),
        steps=args.train_steps)

    eval_result = classifier.evaluate(
        input_fn=lambda: meo_data.eval_input_fn(test_x, test_y,
                                                args.batch_size))

    print(
        '\nTest set accuracy: \033[1m{accuracy:0.3f} match\033[0m, '
        '{accuracy_top_5:0.3f} top five, \033[1m{accuracy_top_10:0.3f} top ten\033[0m, '
        '{accuracy_top_25:0.3f} top 25\n'.format(
            **eval_result))

    predictions = classifier.predict(
        input_fn=lambda: meo_data.eval_input_fn(test_x,
                                                labels=None,
                                                batch_size=args.batch_size))

    pred_exps = list(zip(predictions, test_y))
    random.shuffle(pred_exps)
    print('\n')

    for pred_dict, expec in pred_exps[:50]:
        template = ('expected: {:3d},  predicted: {:3d} ({:04.1f}%),  top ten: {},  {}')

        class_id = pred_dict['class_ids'][0]
        probabilities = pred_dict['probabilities']
        probability = probabilities[class_id]
        top_k = pred_dict['top_k']
        contained = expec in set(top_k)
        success = '\033[92mSUCCESS\033[0m' if contained else '\033[91mFAIL\033[0m'

        print(template.format(expec, class_id, 100 * probability, top_k, success))

    print('\n')


if __name__ == '__main__':
    tf.logging.set_verbosity(tf.logging.INFO)
    tf.app.run(main)

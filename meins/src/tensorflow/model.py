import tensorflow as tf
import tflearn.layers as tl
import metrics as m


def story_model(features, labels, mode, params):
    n_classes = params['n_classes']

    # DNN with two hidden layers
    input_layer = tf.feature_column.input_layer(features, params['feature_columns'])
    net = input_layer

    #net = tl.merge_ops.merge ([input_layer, input_layer], 'concat')

    # hidden layers
    net = tf.layers.dense(net, units=512, activation=tf.nn.relu)
    net = tf.layers.dense(net, units=512, activation=tf.nn.relu)

    #net = tf.nn.dropout(tf.layers.dense(net, units=units, activation=tf.nn.relu),0.5)

    # Compute logits (1 per class).
    logits = tf.layers.dense(net, n_classes, activation=None)

    # Compute predictions.
    predicted_classes = tf.argmax(logits, 1)
    if mode == tf.estimator.ModeKeys.PREDICT:
        predictions = {
            'class_ids': predicted_classes[:, tf.newaxis],
            'probabilities': tf.nn.softmax(logits),
            'top_10': tf.nn.top_k(logits, k=10)[1],
            'ranked': tf.nn.top_k(logits, k=25)[1],
            'logits': logits,
        }
        return tf.estimator.EstimatorSpec(mode, predictions=predictions)

    # Compute loss.
    loss = tf.losses.sparse_softmax_cross_entropy(labels=labels, logits=logits)

    metrics = m.metrics(labels, predicted_classes, logits)

    if mode == tf.estimator.ModeKeys.EVAL:
        return tf.estimator.EstimatorSpec(
            mode,
            loss=loss,
            eval_metric_ops=metrics)

    # Create training op.
    assert mode == tf.estimator.ModeKeys.TRAIN

    optimizer = tf.train.AdagradOptimizer(learning_rate=0.1)

    train_op = optimizer.minimize(loss, global_step=tf.train.get_global_step())
    return tf.estimator.EstimatorSpec(mode, loss=loss, train_op=train_op)

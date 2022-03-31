import tensorflow as tf


def accuracy_top_k(logits, labels, k):
    return tf.metrics.mean(tf.nn.in_top_k(predictions=logits,
                                          targets=labels,
                                          k=k))


def accuracy_top_1(labels, predicted_classes):
    return tf.metrics.accuracy(labels=labels,
                               predictions=predicted_classes,
                               name='acc_op')


def metrics(labels, predicted, logits):
    accuracy = accuracy_top_1(labels, predicted)
    accuracy_top_3 = accuracy_top_k(logits, labels, 3)
    accuracy_top_5 = accuracy_top_k(logits, labels, 5)
    accuracy_top_10 = accuracy_top_k(logits, labels, 10)
    accuracy_top_25 = accuracy_top_k(logits, labels, 25)

    tf.summary.scalar('accuracy', accuracy[1])
    tf.summary.scalar('accuracy_top_3', accuracy_top_3[1])
    tf.summary.scalar('accuracy_top_5', accuracy_top_5[1])
    tf.summary.scalar('accuracy_top_10', accuracy_top_10[1])
    tf.summary.scalar('accuracy_top_25', accuracy_top_25[1])

    return {
        'accuracy': accuracy,
        'accuracy_top_3': accuracy_top_3,
        'accuracy_top_5': accuracy_top_5,
        'accuracy_top_10': accuracy_top_10,
        'accuracy_top_25': accuracy_top_25,
    }


def print_eval(eval_result):
    print(
        '\nTest set accuracy: \033[1m{accuracy:0.3f} match\033[0m, '
        '{accuracy_top_3:0.3f} top three, '
        ' {accuracy_top_5:0.3f} top five, \033[1m{accuracy_top_10:0.3f} top ten\033[0m, '
        '{accuracy_top_25:0.3f} top 25\n'.format(
            **eval_result))

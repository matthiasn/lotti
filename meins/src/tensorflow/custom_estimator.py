import argparse
import tensorflow as tf
import meo_data
import model
import feature_columns as fc
import metrics as m
import predictions as p


parser = argparse.ArgumentParser()
parser.add_argument('--batch_size', default=100, type=int, help='batch size')
parser.add_argument('--train_steps', default=1000, type=int,
                    help='number of training steps')
parser.add_argument('--classes', default=500, type=int,
                    help='number of classes')

def main(argv):
    args = parser.parse_args(argv[1:])
    batch_size = args.batch_size

    (train_x, train_y), (test_x, test_y), unlabeled = meo_data.load_data()

    # construct classifier
    classifier = tf.estimator.Estimator(
        model_fn=model.story_model,
        params={
            'feature_columns': fc.story_model_columns(train_x, test_x,
                                                      unlabeled),
            'n_classes': args.classes,
        })

    # train model
    classifier.train(
        input_fn=lambda: meo_data.train_input_fn(train_x, train_y, batch_size),
        steps=args.train_steps)

    # evaluate and print results
    eval_result = classifier.evaluate(
        input_fn=lambda: meo_data.eval_input_fn(test_x, test_y, batch_size))
    m.print_eval(eval_result)

    # predict classes in test data, print a random sample
    p.predict(classifier, test_x, test_y, unlabeled, batch_size)


if __name__ == '__main__':
    tf.logging.set_verbosity(tf.logging.INFO)
    tf.app.run(main)

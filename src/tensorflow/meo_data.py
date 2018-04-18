import pandas as pd
import tensorflow as tf

TRAIN_PATH = "./data/export/entries_stories_training.csv"
TEST_PATH = "./data/export/entries_stories_test.csv"

CSV_COLUMN_NAMES = ['Geohash', 'GeohashWide', 'Starred', 'ImgFile', 'AudioFile',
                    'Task', 'Md', 'WeeksAgo', 'DaysAgo', 'QuarterDay',
                    'HalfQuarterDay', 'Hour', 'Tags', 'Mentions',
                    'PrimaryStory']


def hot(sa):
    ia = [int(k) for k in sa]
    return tf.one_hot(ia, 500, 1.0, 0.1)


def load_data(y_name='PrimaryStory'):
    train = pd.read_csv(TRAIN_PATH, names=CSV_COLUMN_NAMES, header=0)
    train_x, train_y = train, train.pop(y_name)

    test = pd.read_csv(TEST_PATH, names=CSV_COLUMN_NAMES, header=0)
    test_x, test_y = test, test.pop(y_name)

    return (train_x, train_y), (test_x, test_y)


def train_input_fn(features, labels, batch_size):
    dataset = tf.data.Dataset.from_tensor_slices((dict(features), labels))
    dataset = dataset.shuffle(1000).repeat().batch(batch_size)
    return dataset


def eval_input_fn(features, labels, batch_size):
    features = dict(features)
    if labels is None:
        inputs = features
    else:
        inputs = (features, labels)

    dataset = tf.data.Dataset.from_tensor_slices(inputs)

    # Batch the examples
    assert batch_size is not None, "batch_size must not be None"
    dataset = dataset.batch(batch_size)

    return dataset

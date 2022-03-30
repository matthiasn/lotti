import pandas as pd
import tensorflow as tf

TRAIN_PATH = "./data/export/entries_stories_training.csv"
TEST_PATH = "./data/export/entries_stories_test.csv"
UNLABELED_PATH = "./data/export/entries_stories_unlabeled.csv"

CSV_COLUMN_NAMES = ['Timestamp', 'Geohash40', 'Geohash35', 'Geohash30',
                    'Geohash25', 'Geohash20', 'Geohash15', 'Visit', 'Starred',
                    'ImgFile', 'AudioFile', 'Task', 'Screenshot', 'Md', 'WeeksAgo',
                    'DaysAgo', 'QuarterDay', 'HalfQuarterDay', 'Hour', 'Tags1',
                    'Mentions1']
CSV_COLUMN_NAMES_2 = CSV_COLUMN_NAMES + ['PrimaryStory']


def one_hot(sa):
    ia = [int(k) for k in sa]
    return tf.one_hot(ia, 500, 1.0, 0.1)


def load_data(y_name='PrimaryStory'):
    train = pd.read_csv(TRAIN_PATH, names=CSV_COLUMN_NAMES_2, header=0)
    train['Tags1'] = train['Tags1'].str.split('|', expand=True)

    train_x, train_y = train, train.pop(y_name)
    test = pd.read_csv(TEST_PATH, names=CSV_COLUMN_NAMES_2, header=0)
    test['Tags1'] = test['Tags1'].str.split('|', expand=True)
    test_x, test_y = test, test.pop(y_name)

    unlabeled = pd.read_csv(UNLABELED_PATH, names=CSV_COLUMN_NAMES, header=0)
    unlabeled['Tags1'] = unlabeled['Tags1'].str.replace('cat-', '').str.split(';', expand=True)

    return (train_x, train_y), (test_x, test_y), unlabeled


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

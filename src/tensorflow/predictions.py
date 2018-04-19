import random
import numpy
import meo_data

PREDICTIONS_PATH = "./data/export/entries_stories_predictions.csv"


def predict(classifier, test_x, test_y, unlabeled, batch_size):
    test_predictions = classifier.predict(
        input_fn=lambda: meo_data.eval_input_fn(test_x,
                                                labels=None,
                                                batch_size=batch_size))

    test_pred_exps = list(zip(test_predictions, test_y))
    random.shuffle(test_pred_exps)
    print('\n')

    for pred_dict, expec in test_pred_exps[:50]:
        template = (
            'expected: {:3d},  predicted: {:3d} ({:04.1f}%),  top ten: {},  {}')

        class_id = pred_dict['class_ids'][0]
        probabilities = pred_dict['probabilities']
        probability = probabilities[class_id]
        top_k = pred_dict['top_10']
        contained = expec in set(top_k)
        success = '\033[92mSUCCESS\033[0m' if contained else '\033[91mFAIL\033[0m'

        print(
            template.format(expec, class_id, 100 * probability, top_k, success))

    print('\n')

    # predict on unlabeled data
    predictions = classifier.predict(
        input_fn=lambda: meo_data.eval_input_fn(unlabeled,
                                                labels=None,
                                                batch_size=batch_size))

    unlabeled_pred_ts = list(zip(predictions, unlabeled['Timestamp']))

    csv_file = open(PREDICTIONS_PATH,'w')
    csv_tpl = ('{},{:0.6f},{}\n')

    for pred_dict, ts in unlabeled_pred_ts:
        class_id = pred_dict['class_ids'][0]
        probabilities = pred_dict['probabilities']
        p = probabilities[class_id]
        ranked = pred_dict['ranked']
        csv_file.write(csv_tpl.format(ts, p, numpy.array2string(ranked, max_line_width=10000)))
        #csv_file.write(str(ts) + ',' + str(p) + ',' + str(ranked))

    csv_file.close()

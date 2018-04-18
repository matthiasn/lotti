import random
import meo_data


def predict(classifier, test_x, test_y, batch_size):
    predictions = classifier.predict(
        input_fn=lambda: meo_data.eval_input_fn(test_x,
                                                labels=None,
                                                batch_size=batch_size))

    pred_exps = list(zip(predictions, test_y))
    random.shuffle(pred_exps)
    print('\n')

    for pred_dict, expec in pred_exps[:50]:
        template = (
            'expected: {:3d},  predicted: {:3d} ({:04.1f}%),  top ten: {},  {}')

        class_id = pred_dict['class_ids'][0]
        probabilities = pred_dict['probabilities']
        probability = probabilities[class_id]
        top_k = pred_dict['top_k']
        contained = expec in set(top_k)
        success = '\033[92mSUCCESS\033[0m' if contained else '\033[91mFAIL\033[0m'

        print(
            template.format(expec, class_id, 100 * probability, top_k, success))

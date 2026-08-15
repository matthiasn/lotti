/// Rounds a goal aggregate to the precision the number can actually carry.
///
/// The rolling aggregates are means, so a step average arrives as
/// 7684.428571… and quoting every digit of it invites a reader to believe
/// the tail means something. The rule is scale rather than data type,
/// because the same policy covers step counts, kilograms and millimetres of
/// mercury:
///
///  * **1000 and above → nearest hundred.** A seven-day step average is an
///    estimate of a habit, not a measurement.
///  * **100 to 999 → whole numbers.** A blood pressure of 127.3 is 127.
///  * **Below 100 → one decimal.** Weight is the case that needs it:
///    94.5 kg is a real distinction, 94.53 is not.
///
/// This is THE quantization for goal aggregates, shared by the dimension
/// card's headline and the FACTS handed to the agent, so the card and the
/// report cannot quote two precisions of one number.
///
/// [against] guards the comparison the number is shown next to: a value is
/// never rounded onto the wrong side of its target — 9,950 against a 10,000
/// target would otherwise read "10,000 of 10,000" directly above a
/// "Needs attention" line. Where the coarse step would erase a real
/// difference, decimals are added (bounded at six places) until the two stop
/// reading as the same number.
num roundGoalAggregate(num value, {num? against}) {
  var rounded = _roundByMagnitude(value);
  if (against != null && value != against) {
    if (rounded == _roundByMagnitude(against)) {
      for (var places = 0; places <= 6; places++) {
        if (value.toStringAsFixed(places) != against.toStringAsFixed(places)) {
          rounded = double.parse(value.toStringAsFixed(places));
          break;
        }
      }
    }
  }
  // A whole number stays an int: a serialized 95.0 where the input was 95
  // would make every integral FACTS value grow a spurious decimal.
  return rounded == rounded.roundToDouble() ? rounded.toInt() : rounded;
}

num _roundByMagnitude(num value) {
  final magnitude = value.abs();
  return magnitude >= 1000
      ? (value / 100).roundToDouble() * 100
      : magnitude >= 100
      ? value.roundToDouble()
      : (value * 10).roundToDouble() / 10;
}

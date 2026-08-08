/// Merges `[newStart, newEnd)` into sorted ligature context [ranges].
///
/// Adjacent ranges remain distinct, matching xterm.js. Overlapping ranges are
/// coalesced in place and the same list is returned.
List<(int, int)> mergeLigatureRange(
  List<(int, int)> ranges,
  int newStart,
  int newEnd,
) {
  var inRange = false;
  for (var index = 0; index < ranges.length; index++) {
    final range = ranges[index];
    if (!inRange) {
      if (newEnd <= range.$1) {
        ranges.insert(index, (newStart, newEnd));
        return ranges;
      }
      if (newEnd <= range.$2) {
        ranges[index] = (newStart < range.$1 ? newStart : range.$1, range.$2);
        return ranges;
      }
      if (newStart < range.$2) {
        ranges[index] = (newStart < range.$1 ? newStart : range.$1, range.$2);
        inRange = true;
      } else {
        continue;
      }
    } else if (newEnd <= range.$1) {
      final previous = ranges[index - 1];
      ranges[index - 1] = (previous.$1, newEnd);
      return ranges;
    } else if (newEnd <= range.$2) {
      final previous = ranges[index - 1];
      ranges[index - 1] = (
        previous.$1,
        newEnd > range.$2 ? newEnd : range.$2,
      );
      ranges.removeAt(index);
      return ranges;
    } else {
      ranges.removeAt(index);
      index--;
    }
  }

  if (inRange) {
    final last = ranges.last;
    ranges[ranges.length - 1] = (last.$1, newEnd);
  } else {
    ranges.add((newStart, newEnd));
  }
  return ranges;
}

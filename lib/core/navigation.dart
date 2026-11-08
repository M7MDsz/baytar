import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

extension LeavePage on BuildContext {
  /// Back to the previous page with [result], or to [fallback] when there is none: on the web a page opened
  /// from a link or after a refresh has nothing to pop, and `pop()` threw, leaving the user stuck after saving.
  void leave<T extends Object?>(String fallback, [T? result]) => canPop() ? pop<T>(result) : go(fallback);
}

import 'package:flame/src/components/core/component.dart';
import 'package:flame/src/components/core/recycled_queue.dart';
import 'package:meta/meta.dart';

/// [ComponentTreeRoot] is a component that can be used as a root node of a
/// component tree.
///
/// This class is just a regular [Component], with some additional
/// functionality, namely: it contains global lifecycle events for the component
/// tree.
class ComponentTreeRoot extends Component {
  ComponentTreeRoot({super.children})
      : _queue = RecycledQueue(_LifecycleEvent.new);

  final RecycledQueue<_LifecycleEvent> _queue;
  final Set<int> _blockedComponents = {};

  @internal
  void enqueueAdd(Component child, Component parent) {
    _queue.addLast()
      ..kind = _LifecycleEventKind.add
      ..child = child
      ..parent = parent;
  }

  @internal
  void enqueueRemove(Component child) {
    _queue.addLast()
      ..kind = _LifecycleEventKind.remove
      ..child = child
      ..parent = null;
  }

  // @internal
  // void enqueueMove(Component child, Component newParent) {
  //   _queue.addLast()
  //     ..kind = _LifecycleEventKind.reparent
  //     ..child = child
  //     ..parent = newParent;
  // }

  @internal
  void processLifecycleEvents() {
    assert(_blockedComponents.isEmpty);
    while (_queue.isNotEmpty) {
      final event = _queue.first;
      final child = event.child!;
      final parent = event.parent;
      if (_blockedComponents.contains(identityHashCode(child)) ||
          _blockedComponents.contains(identityHashCode(parent))) {
        continue;
      }
      switch (event.kind) {
        case _LifecycleEventKind.add:
          if (parent!.isMounted && child.isLoaded) {
            child.internalMount(parent: parent);
          } else {
            _blockedComponents.add(identityHashCode(child));
            _blockedComponents.add(identityHashCode(parent));
          }
          break;
        default:
          throw UnsupportedError('Event ${event.kind} not supported');
      }
      // if (parent == null) {
      //   // The component should be removed
      //   if (child.isLoading) {
      //     // cannot remove right now
      //     break;
      //   } else {
      //     child.internalRemoveFromParent();
      //   }
      // }
      _queue.removeFirst();
    }
    _blockedComponents.clear();
  }
}

enum _LifecycleEventKind {
  unknown,
  add,
  remove,
  // reparent,
  // rebalance,
}

class _LifecycleEvent extends Disposable {
  _LifecycleEventKind kind = _LifecycleEventKind.unknown;
  Component? child;
  Component? parent;

  @override
  void dispose() {
    kind = _LifecycleEventKind.unknown;
    child = null;
    parent = null;
  }
}

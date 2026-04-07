import rclpy
from rclpy.node import Node
from rclpy.action import ActionServer, CancelResponse, GoalResponse
from rclpy.callback_groups import ReentrantCallbackGroup
from rclpy.executors import MultiThreadedExecutor
import time
import threading

from action_tutorials_interfaces.action import Fibonacci


class FibonacciActionServer(Node):

    def __init__(self):
        super().__init__('fibonacci_action_server')

        self._cb_group = ReentrantCallbackGroup()
        self._lock = threading.Lock()

        self._current_goal_handle = None
        self._preempt_requested_for = None  # store a handle (may be None)

        self._action_server = ActionServer(
            self,
            Fibonacci,
            'fibonacci',
            execute_callback=self.execute_callback,
            cancel_callback=self.cancel_callback,
            goal_callback=self.goal_callback,
            callback_group=self._cb_group
        )

    def goal_callback(self, goal_request):
        self.get_logger().info(f'Received goal request: order={goal_request.order}')
        with self._lock:
            if self._current_goal_handle is not None:
                self.get_logger().warn('Preempting previous goal (server abort)')
                self._preempt_requested_for = self._current_goal_handle
        return GoalResponse.ACCEPT

    def cancel_callback(self, goal_handle):
        self.get_logger().warn('Received cancel request (from client)')
        return CancelResponse.ACCEPT

    def execute_callback(self, goal_handle):
        self.get_logger().info('Executing goal...')
        with self._lock:
            self._current_goal_handle = goal_handle

        feedback_msg = Fibonacci.Feedback()
        feedback_msg.partial_sequence = [0, 1]

        for i in range(1, goal_handle.request.order):

            # 1) Cancel requested by client
            if goal_handle.is_cancel_requested:
                self.get_logger().warn('Cancel requested by client, stopping execution')
                goal_handle.canceled()
                result = Fibonacci.Result()
                result.sequence = feedback_msg.partial_sequence
                with self._lock:
                    if self._current_goal_handle is goal_handle:
                        self._current_goal_handle = None
                return result

            # 2) Preemption requested by server policy (new goal arrived)
            with self._lock:
                preempt_id = (
                    self._preempt_requested_for.goal_id
                    if self._preempt_requested_for is not None
                    else None
                )
            preempt_me = (preempt_id is not None and goal_handle.goal_id == preempt_id)

            if preempt_me:
                self.get_logger().warn('Preempted by a newer goal, aborting this one')
                goal_handle.abort()
                result = Fibonacci.Result()
                result.sequence = feedback_msg.partial_sequence
                with self._lock:
                    if self._current_goal_handle is goal_handle:
                        self._current_goal_handle = None
                    # clear only if it still points to this goal id
                    if self._preempt_requested_for is not None and self._preempt_requested_for.goal_id == goal_handle.goal_id:
                        self._preempt_requested_for = None
                return result

            feedback_msg.partial_sequence.append(
                feedback_msg.partial_sequence[i] + feedback_msg.partial_sequence[i - 1]
            )
            goal_handle.publish_feedback(feedback_msg)
            time.sleep(1)

        goal_handle.succeed()
        result = Fibonacci.Result()
        result.sequence = feedback_msg.partial_sequence

        with self._lock:
            if self._current_goal_handle is goal_handle:
                self._current_goal_handle = None

        return result


def main(args=None):
    rclpy.init(args=args)
    node = FibonacciActionServer()

    executor = MultiThreadedExecutor()
    executor.add_node(node)
    executor.spin()

    rclpy.shutdown()


if __name__ == '__main__':
    main()
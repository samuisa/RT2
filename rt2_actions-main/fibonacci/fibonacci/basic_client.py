import rclpy
from rclpy.node import Node
from rclpy.action import ActionClient

from action_tutorials_interfaces.action import Fibonacci


class FibonacciClient(Node):

    def __init__(self):
        super().__init__('fibonacci_client')
        self._client = ActionClient(self, Fibonacci, 'fibonacci')

    def send_goal(self, order):
        goal_msg = Fibonacci.Goal()
        goal_msg.order = order

        self._client.wait_for_server()

        # Send goal
        send_goal_future = self._client.send_goal_async(goal_msg)
        rclpy.spin_until_future_complete(self, send_goal_future)

        goal_handle = send_goal_future.result()

        if not goal_handle.accepted:
            self.get_logger().info('Goal rejected')
            return

        self.get_logger().info('Goal accepted')

        # Wait for result
        result_future = goal_handle.get_result_async()
        rclpy.spin_until_future_complete(self, result_future)

        result = result_future.result().result
        self.get_logger().info(f'Result sequence: {result.sequence}')


def main(args=None):
    rclpy.init(args=args)

    client = FibonacciClient()
    client.send_goal(10)

    client.destroy_node()
    rclpy.shutdown()


if __name__ == '__main__':
    main()

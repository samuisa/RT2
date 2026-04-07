import rclpy
from rclpy.action import ActionClient
from rclpy.node import Node
from turtlesim.action import RotateAbsolute

class RotateAbsoluteClient(Node):		
	def __init__(self):
		super().__init__('rotate_absolute_client')
		self._action_client = ActionClient(self, RotateAbsolute, '/turtle1/rotate_absolute')
		
	def send_goal(self, theta):
			goal = RotateAbsolute.Goal()
			goal.theta = theta
			self._action_client.wait_for_server()
			future = self._action_client.send_goal_async(goal)
			rclpy.spin_until_future_complete(self, future)
			goal_handle = future.result()	
			if not goal_handle.accepted:
				self.get_logger().info('Goal rejected :(')
				return
			self.get_logger().info('Goal accepted :)')
				
			result_future = goal_handle.get_result_async()
			rclpy.spin_until_future_complete(self, result_future)
			result = result_future.result().result
			self.get_logger().info(f'Rotation done, delta: {result.delta}')

		
def main(args=None):
	rclpy.init(args=args)
	action_client = RotateAbsoluteClient()
	action_client.send_goal(3.14)
	rclpy.spin(action_client)
	
if __name__ == '__main__':
	main()

import rclpy
from rclpy.action import ActionClient
from rclpy.node import Node
from turtlesim.action import RotateAbsolute

class RotateAbsoluteClient(Node):		
	def __init__(self):
		super().__init__('rotate_absolute_client')
		self._action_client = ActionClient(self, RotateAbsolute, '/turtle1/rotate_absolute')
		
	def send_goal(self, theta):
		goal_msg = RotateAbsolute.Goal()
		goal_msg.theta = theta
		self._action_client.wait_for_server()
		self._action_client.send_goal_async(goal_msg)
		
	
def main(args=None):
	rclpy.init(args=args)
	action_client = RotateAbsoluteClient()
	action_client.send_goal(3.14)
	rclpy.spin_once(action_client, timeout_sec=0.5)
	
if __name__ == '__main__':
	main()

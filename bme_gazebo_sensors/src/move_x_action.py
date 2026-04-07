#!/usr/bin/env python3
import rclpy
from rclpy.node import Node
from rclpy.action import ActionServer, CancelResponse
from rclpy.callback_groups import ReentrantCallbackGroup
from rclpy.executors import MultiThreadedExecutor

from geometry_msgs.msg import Twist
from nav_msgs.msg import Odometry
from action_tutorials_interfaces_ex.action import MoveX
from turtlesim.action import RotateAbsolute
import time

class MoveXActionServer(Node):
    def __init__(self):
        super().__init__('move_x_action_server')
        
        # Gruppo di callback per gestire più eventi (odom e goal) insieme [cite: 570, 578]
        self._cb_group = ReentrantCallbackGroup()
        
        self._action_server = ActionServer(
            self,
            MoveX,
            'move_x',
            execute_callback=self.execute_callback,
            cancel_callback=self.cancel_callback,
            callback_group=self._cb_group
        )
        
        self.cmd_vel_pub = self.create_publisher(Twist, '/cmd_vel', 10)
        self.odom_sub = self.create_subscription(
            Odometry, 
            '/odom', 
            self.odom_callback, 
            10, 
            callback_group=self._cb_group
        )
        
        self.current_x = 0.0

    def odom_callback(self, msg):
        # Legge la posizione X dal simulatore [cite: 639]
        self.current_x = msg.pose.pose.position.x

    def cancel_callback(self, goal_handle):
        # Permette di cancellare il comando da terminale con Ctrl+C [cite: 209, 571]
        self.get_logger().warn('Ricevuta richiesta di cancellazione!')
        return CancelResponse.ACCEPT

    def execute_callback(self, goal_handle):
        self.get_logger().info(f'Esecuzione iniziata per target_x: {goal_handle.request.target_x}')
        
        target_x = goal_handle.request.target_x
        feedback_msg = MoveX.Feedback()
        result_msg = MoveX.Result()
        vel_msg = Twist()
        
        # Logica di movimento [cite: 638]
        while abs(target_x - self.current_x) > 0.1:
            if goal_handle.is_cancel_requested:
                self.get_logger().warn('Goal annullato!')
                self.cmd_vel_pub.publish(Twist()) 
                goal_handle.canceled()
                result_msg.final_x = self.current_x
                return result_msg
            
            # Decide la direzione
            vel_msg.linear.x = 0.3 if self.current_x < target_x else -0.3
            self.cmd_vel_pub.publish(vel_msg)
            
            # Invia feedback al terminale [cite: 192, 530]
            feedback_msg.current_x = self.current_x
            goal_handle.publish_feedback(feedback_msg)
            
            time.sleep(0.1)
            
        # Stop e successo [cite: 498, 527]
        self.cmd_vel_pub.publish(Twist())
        goal_handle.succeed()
        result_msg.final_x = self.current_x
        return result_msg 

class RotateAbsoluteActionServer(Node):
    def __init__(self):
        super().__init__('rotate_absolute_action_server')
        self._action_server = ActionServer(
            self,
            RotateAbsolute,
            '/turtle1/rotate_absolute',
            execute_callback=self.execute_callback,
            cancel_callback=self.cancel_callback
        )
        self.cmd_vel_pub = self.create_publisher(Twist, '/turtle1/cmd_vel', 10)

    def cancel_callback(self, goal_handle):
        self.get_logger().warn('Ricevuta richiesta di cancellazione per Turtle!')
        return CancelResponse.ACCEPT

    def execute_callback(self, goal_handle):
        theta = goal_handle.request.theta
        self.get_logger().info(f'Esecuzione iniziata per Turtle: {theta} rad')
        
        # Logica di rotazione (semplificata) [cite: 639]
        vel_msg = Twist()
        vel_msg.angular.z = 0.5 if theta > 0 else -0.5
        
        # Simula la rotazione per un tempo calcolato (non preciso, solo per demo)
        duration = abs(theta) / 0.5
        start_time = time.time()
        
        while time.time() - start_time < duration:
            if goal_handle.is_cancel_requested:
                self.get_logger().warn('Goal Turtle annullato!')
                self.cmd_vel_pub.publish(Twist()) 
                goal_handle.canceled()
                return RotateAbsolute.Result()
            
            self.cmd_vel_pub.publish(vel_msg)
            time.sleep(0.1)
        
        self.cmd_vel_pub.publish(Twist())
        goal_handle.succeed()
        return RotateAbsolute.Result()

def main(args=None):
    rclpy.init(args=args)
    node = MoveXActionServer()
    # Executor multithreaded per non bloccare i feedback [cite: 585, 592]
    executor = MultiThreadedExecutor()
    executor.add_node(node)
    try:
        executor.spin()
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        rclpy.shutdown()

if __name__ == '__main__':
    main()    
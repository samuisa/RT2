#!/usr/bin/env python3
import sys
import rclpy
from rclpy.action import ActionClient
from rclpy.node import Node
from rclpy.executors import SingleThreadedExecutor # IMPORT MANCANTE AGGIUNTO

from action_tutorials_interfaces_ex.action import MoveX
from turtlesim.action import RotateAbsolute

# NOME DELLA CLASSE CORRETTO (non può chiamarsi ActionClient)
class MoveXActionClient(Node):
    def __init__(self):
        super().__init__('move_x_action_client')
        # Inizializzazione del client
        self._action_client = ActionClient(self, MoveX, 'move_x')

    def send_goal(self, target_x):
        goal_msg = MoveX.Goal()
        goal_msg.target_x = float(target_x)
        
        self.get_logger().info(f'Inviando obiettivo: {target_x} metri...')
        
        # Attesa del server con timeout di sicurezza
        if not self._action_client.wait_for_server(timeout_sec=5.0):
            self.get_logger().error('Server MoveX non disponibile!')
            return

        # Invio asincrono
        self._send_goal_future = self._action_client.send_goal_async(
            goal_msg, 
            feedback_callback=self.feedback_callback
        )
        self._send_goal_future.add_done_callback(self.goal_response_callback)

    def goal_response_callback(self, future):
        goal_handle = future.result()
        if not goal_handle.accepted:
            self.get_logger().info('Obiettivo MoveX rifiutato')
            return

        self.get_logger().info('Obiettivo MoveX accettato dal server!')
        self._get_result_future = goal_handle.get_result_async()
        self._get_result_future.add_done_callback(self.get_result_callback)

    def feedback_callback(self, feedback_msg):
        # Ricezione feedback
        current_pos = feedback_msg.feedback.current_x
        self.get_logger().info(f'FEEDBACK MoveX: Posizione attuale = {current_pos:.2f}')

    def get_result_callback(self, future):
        # Risultato finale
        result = future.result().result
        self.get_logger().info(f'RISULTATO FINALE MoveX: {result.final_x:.2f}')


class RotateAbsoluteClient(Node):
    def __init__(self):
        super().__init__('rotate_absolute_client')
        self._action_client = ActionClient(self, RotateAbsolute, '/turtle1/rotate_absolute')

    def send_goal(self, theta):
        goal_msg = RotateAbsolute.Goal()
        goal_msg.theta = float(theta)
        
        self.get_logger().info(f'Inviando obiettivo Turtle: {theta} rad...')

        if not self._action_client.wait_for_server(timeout_sec=5.0):
            self.get_logger().error('Server Turtlesim non disponibile!')
            return
            
        self._action_client.send_goal_async(goal_msg)


def main(args=None):
    # INIZIALIZZAZIONE ROS 2 (Mancava!)
    rclpy.init(args=args)

    # LETTURA DEGLI ARGOMENTI DA TERMINALE
    if len(sys.argv) < 3:
        print("ERRORE: Parametri mancanti!")
        print("Uso corretto: ros2 run <pacchetto> move_x_client.py <target_x> <theta_turtle>")
        rclpy.shutdown()
        return

    try:
        target_x_val = float(sys.argv[1])
        theta_val = float(sys.argv[2])
    except ValueError:
        print("ERRORE: I parametri inseriti devono essere dei numeri!")
        rclpy.shutdown()
        return

    # Inizializza i due nodi client
    move_client = MoveXActionClient()
    turtle_client = RotateAbsoluteClient()
    
    # INVIO EFFETTIVO DEI GOAL (Mancavano!)
    move_client.send_goal(target_x_val)
    turtle_client.send_goal(theta_val)
    
    # Usa un Executor per far "girare" entrambi i nodi contemporaneamente
    executor = SingleThreadedExecutor()
    executor.add_node(move_client)
    executor.add_node(turtle_client)

    try:
        print("\nMesso in ascolto entrambi i client. Premi Ctrl+C per uscire.\n")
        executor.spin() # Ascolta le callback di ENTRAMBI i nodi
    except KeyboardInterrupt:
        print("Terminazione richiesta dall'utente.")
    finally:
        move_client.destroy_node()
        turtle_client.destroy_node()
        rclpy.shutdown()

if __name__ == '__main__':
    main()
from launch import LaunchDescription
from launch_ros.actions import ComposableNodeContainer
from launch_ros.descriptions import ComposableNode

def generate_launch_description():
    container = ComposableNodeContainer(
        name='navigation_container',
        namespace='',
        package='rclcpp_components',
        executable='component_container',
        # AGGIUNGI QUESTA RIGA: apre un terminale esterno interattivo
        prefix=['xterm -e'], 
        composable_node_descriptions=[
            ComposableNode(
                package='bme_gazebo_sensors',
                plugin='bme_gazebo_sensors::MoveActionServer',
                name='move_server_node',
            ),
            ComposableNode(
                package='bme_gazebo_sensors',
                plugin='bme_gazebo_sensors::UserInterface',
                name='user_interface_node',
            ),
        ],
        output='screen',
    )

    return LaunchDescription([container])
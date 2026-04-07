from launch import LaunchDescription
from launch_ros.actions import ComposableNodeContainer
from launch_ros.descriptions import ComposableNode

def generate_launch_description():
    container = ComposableNodeContainer(
        name='navigation_container',
        namespace='',
        package='rclcpp_components',
        executable='component_container',
        prefix='xterm -e',
        composable_node_descriptions=[
            ComposableNode(
                package='bme_gazebo_sensors',
                plugin='bme_gazebo_sensors::MoveActionServer',
                name='move_server_node',
                # AGGIUNTA DEL PARAMETRO FRAME:
                parameters=[{'target_frame': 'base_link'}]
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
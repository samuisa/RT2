from launch import LaunchDescription
from launch_ros.actions import ComposableNodeContainer
from launch_ros.descriptions import ComposableNode

def generate_launch_description():
    
    server_container = ComposableNodeContainer(
        name='server_container',
        namespace='',
        package='rclcpp_components',
        executable='component_container',
        prefix='xterm -T "Action Server" -e', 
        composable_node_descriptions=[
            ComposableNode(
                package='bme_gazebo_sensors',
                plugin='bme_gazebo_sensors::MoveActionServer',
                name='move_server_node',
                parameters=[{'target_frame': 'base_link'}]
            ),
        ],
        output='screen',
    )

    ui_container = ComposableNodeContainer(
        name='ui_container',
        namespace='',
        package='rclcpp_components',
        executable='component_container',
        prefix='xterm -T "Robot Control Menu" -e', 
        composable_node_descriptions=[
            ComposableNode(
                package='bme_gazebo_sensors',
                plugin='bme_gazebo_sensors::UserInterface',
                name='user_interface_node',
            ),
        ],
        output='screen',
    )

    return LaunchDescription([
        server_container,
        ui_container
    ])
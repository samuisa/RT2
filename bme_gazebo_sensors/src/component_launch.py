import launch
from launch_ros.actions import ComposableNodeContainer
from launch_ros.descriptions import ComposableNode

def generate_launch_description():
    
    # Definiamo il Componente (Plugin) compilato in C++
    move_server_node = ComposableNode(
        package='bme_gazebo_sensors',
        plugin='bme_gazebo_sensors::MoveXActionServer',
        name='move_x_server_component',
        # extra_arguments=[{'use_intra_process_comms': True}]
    )

    # Creiamo il Container in cui verrà caricato il Componente
    container = ComposableNodeContainer(
        name='action_server_container',
        namespace='',
        package='rclcpp_components',
        executable='component_container_mt', # Usiamo il multithreaded per gli actions
        composable_node_descriptions=[
            move_server_node,
        ],
        output='screen',
    )

    return launch.LaunchDescription([container])
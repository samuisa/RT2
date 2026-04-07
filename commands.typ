

```bash

source /opt/ros/jazzy/setup.bash &&
colcon build &&
source install/local_setup.sh

```


```bash

ros2 launch bme_gazebo_sensors spawn_robot_ex.launch.py
ros2 launch bme_gazebo_sensors/src move_x_action.py
ros2 launch bme_gazebo_sensors/src move_x_client.py

ros2 launch bme_gazebo_sensors component_launch.py
ros2 run bme_gazebo_sensors move_x_client.py

```

```bash

ros2 action send_goal /move_x action_tutorials_interfaces_ex/action/MoveX "{target_x: 1.0}"

ros2 action send_goal /turtle1/rotate_absolute turtlesim/action/RotateAbsolute "{theta: 1.57}"

```

```bash

colcon build &&
source install/local_setup.sh

```
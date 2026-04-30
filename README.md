# Assignment 1

This project is a ROS 2 package designed to control and navigate a simulated robot in Gazebo Sim. It uses an architecture based on **Action Server/Client** and **TF2** for pose calculation, providing an interactive Command Line Interface (CLI) to send movement commands to the robot.

## Main Features

* **CLI Interface (User Interface):** An interactive menu running in a separate terminal (`xterm`) that allows the user to send target coordinates (X, Y, Theta), or cancel ongoing actions (E-STOP).
* **Move Action Server:** An action server that calculates and publishes velocity commands on `/cmd_vel` based on real-time position and orientation errors.
* **TF2 Integration:** Robot localization is handled by listening to real-time transforms from the `odom` frame to the `base_footprint` (or `base_link`) frame.
* **ROS 2 Components:** Both control nodes (`MoveActionServer` and `UserInterface`) are implemented as components (`rclcpp_components`) and run inside a single `ComposableNodeContainer` to optimize performance.

---

## Node and Message Structure

The project relies on two main packages (or sections within the workspace):

### 1. Custom Interfaces (`action_msg`)
Defines the actions used for asynchronous communication:
* `Linear.action`: Receives the `(x, y)` coordinates as a *Goal*. Returns the completion status and feedback on the remaining distance.
* `Angular.action`: Receives the `theta` angle as a *Goal*. Returns the delta angle and feedback on the remaining rotation.

### 2. Navigation Nodes (`bme_gazebo_sensors`)
* **`user_interface_node`**: Action Client that exposes the on-screen menu.
* **`move_server_node`**: Action Server that reads the current pose via TF2, computes the differential logic (rotate/forward/align), and publishes velocities to the robot.

---

## Build Instructions

 Source the environment:
 
```bash
source /opt/ros/jazzy/setup.bash &&
colcon build &&
source install/local_setup.sh
```

---

## Execution

To launch the complete simulation environment—including the bridges, RViz, and the container hosting both the `user_interface_node` and `move_server_node` —run the following command:

```bash
ros2 launch bme_gazebo_sensors spawn_robot_ex.launch.py
```
This command will automatically open two `xterm` windows: one for interacting with the user interface, and another to monitor the server node's feedback, warnings, and info logs.

---

## Usage Guide (user interface)

- **Option 1:** You will be prompted to enter the X and Y coordinates (limited between -10 and 10) and the final orientation Theta (in radians), measured with respect to the absolute frane. The robot will move to the point and then rotate. If the robot is running you can change the target in real-time by sending new coordinates
- **Option c:** While running, instantly stops the robot by canceling all ongoing linear and angular actions.
- **Option q:** Safely closes the interface and shuts down the UserInterface node.





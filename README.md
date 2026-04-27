# bme_gazebo_sensors

This project is a ROS 2 package designed to control and navigate a simulated robot in Gazebo Sim. It uses an architecture based on **Action Server/Client** and **TF2** for pose calculation, providing an interactive Command Line Interface (CLI) to send movement commands to the robot.

## Main Features

* **CLI Interface (User Interface):** An interactive menu running in a separate terminal (`xterm`) that allows the user to send target coordinates (X, Y, Theta), perform rotation-only movements, or cancel ongoing actions (E-STOP).
* **Move Action Server:** An action server that calculates and publishes velocity commands on `/cmd_vel` based on real-time position and orientation errors.
* **TF2 Integration:** Robot localization is handled by listening to real-time transforms from the `odom` frame to the `base_footprint` (or `base_link`) frame.
* **ROS 2 Components:** Both control nodes (`MoveActionServer` and `UserInterface`) are implemented as components (`rclcpp_components`) and run inside a single `ComposableNodeContainer` to optimize performance.
* **Gazebo-ROS 2 Bridge:** Seamless communication between ROS 2 and Gazebo via `ros_gz_bridge` for clock, odometry, laser scan, TF, and cmd_vel.

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

1. Clone the repository into your ROS 2 workspace (e.g., `~/ros2_ws/src`).
2. Ensure you have both the main package and the custom messages package (`action_msg`).
3. Build the project using `colcon`:

    ```bash
    cd ~/ros2_ws
    colcon build
    ```

4. Source the environment:

    ```bash
    source install/setup.bash
    ```

---

## Execution

To start the entire simulation, bridges, RViz, and the user interface, use the main launch file. Assuming your file is named `main.launch.py`:

```bash
ros2 launch bme_gazebo_sensors spawn_robot_ex.launch.py
```

## Usage Guide (CLI Menu)

- **Option 1:** You will be prompted to enter the X and Y coordinates (limited between -10 and 10) and the final orientation Theta (in radians). The robot will move to the point and then rotate.
- **Option 2:** Instantly stops the robot by canceling all ongoing linear and angular actions.
- **Option q:** Safely closes the interface and shuts down the UserInterface node.





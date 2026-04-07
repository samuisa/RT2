#set page(
  paper: "a4",
  margin: (x: 2cm, y: 2.5cm),
  numbering: "1",
)

#set text(font: "New Computer Modern", size: 10pt)
#set par(justify: true)
#set heading(numbering: "1.1")

// --- STYLING SIMILE A MAIN.PDF ---
#show heading.where(level: 1): it => [
  #v(1.5em)
  #block(width: 100%, fill: rgb("#eef4fa"), inset: 8pt, radius: 4pt)[
    #text(weight: "bold", size: 14pt, fill: rgb("#1d3557"))[#it]
  ]
  #v(0.5em)
]

#show heading.where(level: 2): it => [
  #v(1em)
  #text(weight: "bold", size: 12pt, fill: rgb("#457b9d"))[#it]
  #v(0.5em)
]

// REGOLA GLOBALE PER IL CODICE
// breakable: true è FONDAMENTALE per evitare enormi spazi bianchi a fine pagina!
#show raw.where(block: true): it => block(
  fill: luma(248),
  inset: 10pt,
  radius: 5pt,
  width: 100%,
  breakable: true, 
  text(size: 9pt, it) 
)

// --- TITOLO ---
#align(center)[
  #text(size: 24pt, weight: "bold", fill: rgb("#1d3557"))[Research Track 2] \
  #v(0.5em)
  #text(size: 18pt, weight: "bold")[Frames TF2] \
  #v(1em)
  #text(size: 12pt)[Carmine Tommaso Recchiuto] \
  #text(size: 10pt, style: "italic")[Research Track II - Class III]
]

#v(2em)

// --- INDICE ---
#outline(title: "Contents", depth: 2, indent: auto)
#pagebreak()

// --- CONTENUTO ---

= Introduction to TF2

`tf2` is a core library used for tracking and transforming coordinate frames over time. The package is very important for robotics: indeed, robots have different components (sensors, actuators, but also structures such as maps) that all operate in their own coordinate systems.

However, users constantly need to convert data between them. Imagine a robot with:
- a camera
- a laser scanner
- a base
- a global map

Each produces data in its own frame. `tf2` maintains a tree of coordinate frames connected by transforms. 

Each transform (e.g., `base_link` vs `map`, `laser_frame` vs `base_link`, `camera_frame` vs `base_link`) defines:
- a translation (x, y, z)
- a rotation (quaternion)

== How do frames work practically in ROS2?

Let's see an example. First, install the necessary packages and launch the demo:

```bash
>> (sudo) apt-get install ros-jazzy-rviz2 ros-jazzy-turtle-tf2-py ros-jazzy-tf2-ros ros-jazzy-tf2-tools ros-jazzy-turtlesim python3-scipy
>> ros2 launch turtle_tf2_py turtle_tf2_demo.launch.py
```

You will see now two turtles in the environment. In another terminal, you can type:

```bash
>> ros2 run turtlesim turtle_teleop_key
```

You can drive the turtle around with the arrow keys. You will see that the second turtle will follow the leader one.

#rect(fill: rgb("#fff3cd"), stroke: rgb("#ffe69c"), inset: 10pt, radius: 4pt, width: 100%)[
  *How is this implemented?* \
  This demo uses the `tf2` library to create three coordinate frames: a `world` frame, a `turtle1` frame, and a `turtle2` frame. 
  Two tf2 broadcasters publish the turtle coordinate frames. The `tf2_listener` spawns the second turtle and transforms the `turtle1` pose into the `turtle2` frame to compute a control to follow the turtle.
]

= How this can be helpful?

In the example, we have a controller for `turtle2`, which has to reach the position of `turtle1`. The two broadcasters actually publish the translation and orientation matrices for `turtle1` and `turtle2` in the world frame.

#table(
  columns: (1fr, 1fr),
  align: left,
  fill: (col, row) => if row == 0 { rgb("#1d3557") } else { none },
  stroke: 0.5pt + luma(200),
  [#text(fill: white, weight: "bold")[Implementation in World Frame]], 
  [#text(fill: white, weight: "bold")[Implementation with tf2]],
  [
    If you have to implement everything in the world frame, it is not simple. You need to:
    + Subscribe to the `turtle1` and `turtle2` pose (world frame).
    + Compute their orientation in the world frame and relative distance.
    + Compute the orientation error.
    + Finally set the angular and linear velocity.
  ],
  [
    With `tf2`, we can obtain the same result by:
    + Listening to the tf topic, and getting the `turtle1` frame.
    + Transforming `turtle1` pose from the world frame to the `turtle2` frame (using `tf2` package functionalities).
    + Using `turtle1` position and orientation (in the `turtle2` frame) as references for our controller.
  ]
)

= Debugging Tools

== view_frames
`view_frames` creates a diagram of the frames being broadcast by `tf2` over ROS.
```bash
ros2 run tf2_tools view_frames
```
It generates a PDF tree showing all frames (e.g., `world` -> `turtle1`, `world` -> `turtle2`) and reports diagnostic information (most recent transform, oldest transform, average rate) for debugging.

== tf_echo
`tf_echo` implements a listener between any two frames broadcasted over ROS2.
```bash
ros2 run tf2_ros tf2_echo turtle2 turtle1
```
It gives you exactly the pose of `turtle1` in the `turtle2` frame, outputting translation, rotation (Quaternion and RPY), and the transformation matrix.

== Rviz2
`rviz2` is a helpful tool to visualize frames broadcasted by our nodes.
```bash
ros2 run rviz2 rviz2
```
Once started, add `TF` to the visualization options and select the frames you want to see.

= Quaternions

A quaternion is a representation of orientation with 4 values, which is more concise than a rotation matrix. Quaternions are very efficient for analyzing situations where rotations in three dimensions are involved, and are widely used in robotics.

A quaternion has 4 components `(x, y, z, w)`. In ROS 2, `w` is the last value. The magnitude of a quaternion should *always be one*. To avoid numerical errors, we should normalize it. The no-rotation quaternion is `(0, 0, 0, 1)`.

- `tf2` → core transform library
- `tf2_ros` → ROS interface (listeners, broadcasters)
- `tf2_geometry_msgs` → transform geometry messages (points, poses, etc.)
- `geometry_msgs` → message definitions

== Implementation Examples

*Note: The complete C++ and Python implementation examples for Quaternions are available in the "Code Implementations" section at the end of this document.*

= Broadcasters

== Static Broadcaster
Publishing static transforms is useful to define the relationship between a robot base and its sensors or non-moving parts (e.g., a laser scanner). A static broadcaster sends a transform that does not change in time.

The `tf2_ros` package provides a `StaticTransformBroadcaster`. Transforms are published through the `TransformStamped` message from `geometry_msgs`, which contains:
- A timestamp
- The name of the parent frame
- The name of the child frame
- The actual 6D pose of the object

*Command Line Tool:*
You can leverage an existing executable to publish static transforms directly:
```bash
ros2 run tf2_ros static_transform_publisher --x 4 --y 4 --z 0 --yaw 1.57 --pitch 0 --roll 0 --frame-id world --child-frame-id myturtle
```

`static_transform_publisher` can be used also within a launch file:

```python
Node(
  package='tf2_ros',
  executable='static_transform_publisher',
  arguments=[ '--x', '4', '--y', '4', '--z', '0', '--yaw', '1.57', '--pitch', '0', '--roll', '0', '--frame-id', 'world', '--child-frame-id', 'myturtle']
),
```

*Note: The complete Python and C++ source codes for the Static Frame Publisher are available in the "Code Implementations" section at the end of this document.*

== Dynamic Broadcaster
In many cases, frames move relatively and we need to update their value constantly (e.g., keeping track of a moving turtle). 
- We use a `TransformBroadcaster` (not Static) so the frame is expected to vary in time.
- We need to subscribe to the `/pose` topic to retrieve the 6D pose.
- We use parameters (like the turtle name) to keep the code modular and reusable for different entities.

We have both a C++ and a Python implementation of the dynamic broadcaster. The code is quite similar to the static one, but we need to implement a callback function to update the transform every time we receive a new pose message.

*Note: The complete Python and C++ source codes (along with the required launch file) for the Dynamic Frame Publisher are available in the "Code Implementations" section at the end of this document.*


= Listener

The `tf2_ros` package provides a `TransformListener` to help receive transforms. Once created, it buffers incoming `tf2` transformations for up to 10 seconds. 

In the timer callback, we query for a specific transformation using the `lookup_transform` method with these arguments: Target frame, Source frame, and The time at which we want to transform.

*Note: The complete Python and C++ source codes for the Frame Listener are available in the "Code Implementations" section at the end of this document.*


= Using Time and Time Travel

`tf2` stores a time snapshot for every transform. 
- `tf2::TimePointZero` means "the latest available transform".
- `this->get_clock()->now()` means the current time.

If you request a transform at time "now", you might get a "Lookup would require extrapolation into the future" error because it takes a few milliseconds for transforms to arrive in the buffer. We fix this by adding a *timeout* (e.g., `50ms`).

```cpp
t = tf_buffer_->lookupTransform(
  toFrameRel, fromFrameRel,
  this->get_clock()->now(), 50ms);
```

== Time Travel
`tf2` is able to transform data in time as well as in space. If we want `turtle2` to follow 5 seconds behind `carrot1`, we must look up transforms back in time.

To do this correctly, `lookup_transform` takes six arguments:
1. Target frame
2. The time to transform to
3. Source frame
4. The time at which source frame will be evaluated
5. Frame that does not change over time (`world`)
6. Time to wait (timeout)

```cpp
t = tf_buffer_->lookupTransform(
  toFrameRel, 
  this->get_clock()->now(),
  fromFrameRel, 
  this->get_clock()->now() - rclcpp::Duration(5, 0), 
  "world", 
  50ms);
```

== Debugging problems (Time)
When running ROS on different machines, clock mismatch or network delay can cause errors. You can monitor chain delays using:
```bash
ros2 run tf2_ros tf2_monitor turtle2 turtle1
```

= Assignment 1

Now that we know how to use frames, we could write an action server that moves around in the environment (not only along x), implementing a complete navigation stack (without obstacle avoidance).

You need to write a package with:
- A user interface to:
  - set a `x, y, theta` as a target for our robot (refer to the free environment given in class 1)
  - cancel the target
- An action server to implement robot navigation

Both the user interface (action client) and the action server should be executed as libraries (plugins) within the same container.

*Requirements:*
- Language: C++
- Submission: GitHub Link
- *Deadline:* 2/5/2026

#pagebreak()

= Code Implementations

In this section, you can find the complete implementation codes for both Python and C++ discussed throughout the course.

#pagebreak()

== 1. Quaternions

*C++ Implementation:*
```cpp
#include <tf2/LinearMath/Quaternion.h>

tf2::Quaternion q;
// Create a quaternion from RPY in radians
q.setRPY(0, 0, 0);

// Print the quaternion components
RCLCPP_INFO(this->get_logger(), 
  "%f %f %f %f", 
  q.x(), q.y(), q.z(), q.w());
```

*Python Implementation:*
```python
import rclpy
from rclpy.node import Node
from scipy.spatial.transform import Rotation

class QuaternionNode(Node):
    def __init__(self):
        super().__init__('quat_node')
        q = Rotation.from_euler('xyz', 
            [1.57, 0.0, 1.57]).as_quat()
        self.get_logger().info(
            f"{q[0]} {q[1]} {q[2]} {q[3]}")

def main(args=None):
    rclpy.init(args=args)
    node = QuaternionNode()
    rclpy.shutdown()
```

#pagebreak()

== 2. Static Frame Publisher

*Python Implementation:*
```python
import sys
from geometry_msgs.msg import TransformStamped
import numpy as np
import rclpy
from rclpy.node import Node
from tf2_ros.static_transform_broadcaster import StaticTransformBroadcaster
from scipy.spatial.transform import Rotation

class StaticFramePublisher(Node):
    def __init__(self, transformation):
        super().__init__('static_turtle_tf2_broadcaster')
        self.tf_static_broadcaster = StaticTransformBroadcaster(self)
        self.make_transforms(transformation)

    def make_transforms(self, transformation):
        t = TransformStamped()

        t.header.stamp = self.get_clock().now().to_msg()
        t.header.frame_id = 'world'
        t.child_frame_id = transformation[1]

        t.transform.translation.x = float(transformation[2])
        t.transform.translation.y = float(transformation[3])
        t.transform.translation.z = float(transformation[4])
        
        quat = Rotation.from_euler(
            'xyz', 
            [float(transformation[5]), float(transformation[6]), float(transformation[7])]
        ).as_quat()
        
        t.transform.rotation.x = quat[0]
        t.transform.rotation.y = quat[1]
        t.transform.rotation.z = quat[2]
        t.transform.rotation.w = quat[3]
        
        self.tf_static_broadcaster.sendTransform(t)

def main():
    logger = rclpy.logging.get_logger('logger')

    # obtain parameters from command line arguments
    if len(sys.argv) != 8:
        logger.info('Invalid number of parameters. Usage: \n'
                    '$ ros2 run turtle_tf2_py static_turtle_tf2_broadcaster '
                    'child_frame_name x y z roll pitch yaw')
        sys.exit(1)

    if sys.argv[1] == 'world':
        logger.info('Your static turtle name cannot be "world"')
        sys.exit(2)

    # pass parameters and initialize node
    rclpy.init()
    node = StaticFramePublisher(sys.argv)
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass

    rclpy.shutdown()
```

*C++ Implementation:*
```cpp
#include <memory>
#include "geometry_msgs/msg/transform_stamped.hpp"
#include "rclcpp/rclcpp.hpp"
#include "tf2/LinearMath/Quaternion.hpp"
#include "tf2_ros/static_transform_broadcaster.hpp"

class StaticFramePublisher : public rclcpp::Node
{
public:
  explicit StaticFramePublisher(char * transformation[])
  : Node("static_turtle_tf2_broadcaster")
  {
    tf_static_broadcaster_ = 
        std::make_shared<tf2_ros::StaticTransformBroadcaster>(this);

    // Publish static transforms once at startup
    this->make_transforms(transformation);
  }

private:
  void make_transforms(char * transformation[])
  {
    geometry_msgs::msg::TransformStamped t;

    t.header.stamp = this->get_clock()->now();
    t.header.frame_id = "world";
    t.child_frame_id = transformation[1];

    t.transform.translation.x = atof(transformation[2]);
    t.transform.translation.y = atof(transformation[3]);
    t.transform.translation.z = atof(transformation[4]);
    
    tf2::Quaternion q;
    q.setRPY(
      atof(transformation[5]),
      atof(transformation[6]),
      atof(transformation[7]));
      
    t.transform.rotation.x = q.x();
    t.transform.rotation.y = q.y();
    t.transform.rotation.z = q.z();
    t.transform.rotation.w = q.w();

    tf_static_broadcaster_->sendTransform(t);
  }

  std::shared_ptr<tf2_ros::StaticTransformBroadcaster> tf_static_broadcaster_;
};

int main(int argc, char * argv[])
{
  auto logger = rclcpp::get_logger("logger");

  // Obtain parameters from command line arguments
  if (argc != 8) {
    RCLCPP_INFO(
      logger, "Invalid number of parameters\nusage: "
      "$ ros2 run cpp_tf2_pkg static_broadcaster "
      "child_frame_name x y z roll pitch yaw");
    return 1;
  }

  if (strcmp(argv[1], "world") == 0) {
    RCLCPP_INFO(logger, "Your static turtle name cannot be 'world'");
    return 1;
  }

  // Pass parameters and initialize node
  rclcpp::init(argc, argv);
  rclcpp::spin(std::make_shared<StaticFramePublisher>(argv));
  rclcpp::shutdown();
  return 0;
}
```

#pagebreak()

== 3. Dynamic Frame Publisher

*Python Implementation:*
```python
from geometry_msgs.msg import TransformStamped
import numpy as np
import rclpy
from rclpy.node import Node
from tf2_ros import TransformBroadcaster
from turtlesim.msg import Pose
from scipy.spatial.transform import Rotation

class FramePublisher(Node):

    def __init__(self):
        super().__init__('turtle_tf2_frame_publisher')

        # Declare and acquire `turtlename` parameter
        self.turtlename = self.declare_parameter(
          'turtlename', 'turtle').get_parameter_value().string_value

        # Initialize the transform broadcaster
        self.tf_broadcaster = TransformBroadcaster(self)

        # Subscribe to a turtle{1}{2}/pose topic
        self.subscription = self.create_subscription(Pose,
            f'/{self.turtlename}/pose',
            self.handle_turtle_pose,
            1)
        self.subscription  

    def handle_turtle_pose(self, msg):
        t = TransformStamped()

        # Read message content and assign it to tf variables
        t.header.stamp = self.get_clock().now().to_msg()
        t.header.frame_id = 'world'
        t.child_frame_id = self.turtlename

        # Turtle only exists in 2D
        t.transform.translation.x = msg.x
        t.transform.translation.y = msg.y
        t.transform.translation.z = 0.0

        # Set rotation in z axis from the message
        quat = Rotation.from_euler('xyz', [0, 0, msg.theta]).as_quat()
        t.transform.rotation.x = quat[0]
        t.transform.rotation.y = quat[1]
        t.transform.rotation.z = quat[2]
        t.transform.rotation.w = quat[3]

        # Send the transformation
        self.tf_broadcaster.sendTransform(t)

def main():
    rclpy.init()
    node = FramePublisher()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass

    rclpy.shutdown()
```

*C++ Implementation:*
```cpp
#include <functional>
#include <memory>
#include <sstream>
#include <string>

#include "geometry_msgs/msg/transform_stamped.hpp"
#include "rclcpp/rclcpp.hpp"
#include "tf2/LinearMath/Quaternion.hpp"
#include "tf2_ros/transform_broadcaster.hpp"
#include "turtlesim/msg/pose.hpp"

class FramePublisher : public rclcpp::Node
{
public:
  FramePublisher()
  : Node("turtle_tf2_frame_publisher")
  {
    // Declare and acquire `turtlename` parameter
    turtlename_ = this->declare_parameter<std::string>("turtlename", "turtle");

    // Initialize the transform broadcaster
    tf_broadcaster_ =
      std::make_unique<tf2_ros::TransformBroadcaster>(*this);

    // Subscribe to a turtle{1}{2}/pose topic
    std::ostringstream stream;
    stream << "/" << turtlename_.c_str() << "/pose";
    std::string topic_name = stream.str();

    auto handle_turtle_pose = [this](
        const std::shared_ptr<const turtlesim::msg::Pose> msg){
        
        geometry_msgs::msg::TransformStamped t;

        t.header.stamp = this->get_clock()->now();
        t.header.frame_id = "world";
        t.child_frame_id = turtlename_.c_str();

        // Turtle only exists in 2D
        t.transform.translation.x = msg->x;
        t.transform.translation.y = msg->y;
        t.transform.translation.z = 0.0;

        // Rotation in z axis from the message
        tf2::Quaternion q;
        q.setRPY(0, 0, msg->theta);
        t.transform.rotation.x = q.x();
        t.transform.rotation.y = q.y();
        t.transform.rotation.z = q.z();
        t.transform.rotation.w = q.w();

        // Send the transformation
        tf_broadcaster_->sendTransform(t);
    };
    
    subscription_ = this->create_subscription<turtlesim::msg::Pose>(
      topic_name, 10,
      handle_turtle_pose);
  }

private:
  rclcpp::Subscription<turtlesim::msg::Pose>::SharedPtr subscription_;
  std::unique_ptr<tf2_ros::TransformBroadcaster> tf_broadcaster_;
  std::string turtlename_;
};

int main(int argc, char * argv[])
{
  rclcpp::init(argc, argv);
  rclcpp::spin(std::make_shared<FramePublisher>());
  rclcpp::shutdown();
  return 0;
}
```

*Launch file for Dynamic Broadcaster (Python):*
```python
from launch import LaunchDescription
from launch_ros.actions import Node

def generate_launch_description():
    return LaunchDescription([
        Node(
            package='turtlesim',
            executable='turtlesim_node',
            name='sim'
        ),
        Node(
            package='python_tf2_pkg',
            executable='turtle_broadcaster',
            name='broadcaster1',
            parameters=[
                {'turtlename': 'turtle1'}
            ]),])
```

#pagebreak()

== 4. Frame Listener

*Python Implementation:*
```python
import math
from geometry_msgs.msg import Twist
import rclpy
from rclpy.node import Node
from tf2_ros import TransformException
from tf2_ros.buffer import Buffer
from tf2_ros.transform_listener import TransformListener
from turtlesim.srv import Spawn

class FrameListener(Node):

    def __init__(self):
        super().__init__('turtle_tf2_frame_listener')

        # Declare and acquire `target_frame` parameter
        self.target_frame = self.declare_parameter(
          'target_frame', 'turtle1').get_parameter_value().string_value

        self.tf_buffer = Buffer()
        self.tf_listener = TransformListener(self.tf_buffer, self)

        # Create a client to spawn a turtle
        self.spawner = self.create_client(Spawn, 'spawn')
        
        # Boolean values to store the information
        self.turtle_spawning_service_ready = False
        self.turtle_spawned = False

        # Create turtle2 velocity publisher
        self.publisher = self.create_publisher(Twist, 'turtle2/cmd_vel', 1)

        # Call on_timer function every second
        self.timer = self.create_timer(1.0, self.on_timer)

    def on_timer(self):
        from_frame_rel = self.target_frame
        to_frame_rel = 'turtle2'

        if self.turtle_spawning_service_ready:
            if self.turtle_spawned:
                try:
                    t = self.tf_buffer.lookup_transform(
                        to_frame_rel,
                        from_frame_rel,
                        rclpy.time.Time())
                except TransformException as ex:
                    self.get_logger().info(
                        f'Could not transform {to_frame_rel} to {from_frame_rel}: {ex}')
                    return

                msg = Twist()
                scale_rotation_rate = 1.0
                msg.angular.z = scale_rotation_rate * math.atan2(
                    t.transform.translation.y,
                    t.transform.translation.x)

                scale_forward_speed = 0.5
                msg.linear.x = scale_forward_speed * math.sqrt(
                    t.transform.translation.x ** 2 +
                    t.transform.translation.y ** 2)

                self.publisher.publish(msg)
            else:
                if self.result.done():
                    self.get_logger().info(
                        f'Successfully spawned {self.result.result().name}')
                    self.turtle_spawned = True
                else:
                    self.get_logger().info('Spawn is not finished')
        else:
            if self.spawner.service_is_ready():
                # Initialize request with turtle name and coordinates
                request = Spawn.Request()
                request.name = 'turtle2'
                request.x = float(4)
                request.y = float(2)
                request.theta = float(0)
                
                # Call request
                self.result = self.spawner.call_async(request)
                self.turtle_spawning_service_ready = True
            else:
                self.get_logger().info('Service is not ready')

def main():
    rclpy.init()
    node = FrameListener()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass

    rclpy.shutdown()
```

*C++ Implementation:*
```cpp
#include <chrono>
#include <functional>
#include <memory>
#include <string>

#include "geometry_msgs/msg/transform_stamped.hpp"
#include "geometry_msgs/msg/twist.hpp"
#include "rclcpp/rclcpp.hpp"
#include "tf2/exceptions.hpp"
#include "tf2_ros/transform_listener.hpp"
#include "tf2_ros/buffer.hpp"
#include "turtlesim/srv/spawn.hpp"

using namespace std::chrono_literals;

class FrameListener : public rclcpp::Node
{
public:
  FrameListener()
  : Node("turtle_tf2_frame_listener"),
    turtle_spawning_service_ready_(false),
    turtle_spawned_(false)
  {
    // Declare and acquire `target_frame` parameter
    target_frame_ = this->declare_parameter<std::string>("target_frame", "turtle1");

    tf_buffer_ =
      std::make_unique<tf2_ros::Buffer>(this->get_clock());
    tf_listener_ =
      std::make_shared<tf2_ros::TransformListener>(*tf_buffer_);

    // Create a client to spawn a turtle
    spawner_ =
      this->create_client<turtlesim::srv::Spawn>("spawn");

    // Create turtle2 velocity publisher
    publisher_ =
      this->create_publisher<geometry_msgs::msg::Twist>("turtle2/cmd_vel", 1);

    // Call on_timer function every second
    timer_ = this->create_wall_timer(
      1s, [this]() {return this->on_timer();});
  }

private:
  void on_timer()
  {
    std::string fromFrameRel = target_frame_.c_str();
    std::string toFrameRel = "turtle2";

    if (turtle_spawning_service_ready_) {
      if (turtle_spawned_) {
        geometry_msgs::msg::TransformStamped t;

        try {
          t = tf_buffer_->lookupTransform(
            toFrameRel, fromFrameRel,
            tf2::TimePointZero);
        } catch (const tf2::TransformException & ex) {
          RCLCPP_INFO(
            this->get_logger(), "Could not transform %s to %s: %s",
            toFrameRel.c_str(), fromFrameRel.c_str(), ex.what());
          return;
        }

        geometry_msgs::msg::Twist msg;

        static const double scaleRotationRate = 1.0;
        msg.angular.z = scaleRotationRate * atan2(
          t.transform.translation.y,
          t.transform.translation.x);

        static const double scaleForwardSpeed = 0.5;
        msg.linear.x = scaleForwardSpeed * sqrt(
          pow(t.transform.translation.x, 2) +
          pow(t.transform.translation.y, 2));

        publisher_->publish(msg);
      } else {
        RCLCPP_INFO(this->get_logger(), "Successfully spawned");
        turtle_spawned_ = true;
      }
    } else {
      // Check if the service is ready
      if (spawner_->service_is_ready()) {
        auto request = std::make_shared<turtlesim::srv::Spawn::Request>();
        request->x = 4.0;
        request->y = 2.0;
        request->theta = 0.0;
        request->name = "turtle2";

        // Call request
        using ServiceResponseFuture =
          rclcpp::Client<turtlesim::srv::Spawn>::SharedFuture;
        auto response_received_callback = [this](ServiceResponseFuture future) {
            auto result = future.get();
            if (strcmp(result->name.c_str(), "turtle2") == 0) {
              turtle_spawning_service_ready_ = true;
            } else {
              RCLCPP_ERROR(this->get_logger(), "Service callback result mismatch");
            }
          };
        auto result = spawner_->async_send_request(request, response_received_callback);
      } else {
        RCLCPP_INFO(this->get_logger(), "Service is not ready");
      }
    }
  }

  bool turtle_spawning_service_ready_;
  bool turtle_spawned_;
  rclcpp::Client<turtlesim::srv::Spawn>::SharedPtr spawner_{nullptr};
  rclcpp::TimerBase::SharedPtr timer_{nullptr};
  rclcpp::Publisher<geometry_msgs::msg::Twist>::SharedPtr publisher_{nullptr};
  std::shared_ptr<tf2_ros::TransformListener> tf_listener_{nullptr};
  std::unique_ptr<tf2_ros::Buffer> tf_buffer_;
  std::string target_frame_;
};

int main(int argc, char * argv[])
{
  rclcpp::init(argc, argv);
  rclcpp::spin(std::make_shared<FrameListener>());
  rclcpp::shutdown();
  return 0;
}
```

#pagebreak()

== 5. Adding a frame

*Python Implementation:*
```python
from geometry_msgs.msg import TransformStamped

import rclpy
from rclpy.node import Node

from tf2_ros import TransformBroadcaster


class FixedFrameBroadcaster(Node):

   def __init__(self):
       super().__init__('fixed_frame_tf2_broadcaster')
       self.tf_broadcaster = TransformBroadcaster(self)
       self.timer = self.create_timer(0.1, self.broadcast_timer_callback)

   def broadcast_timer_callback(self):
       t = TransformStamped()

       t.header.stamp = self.get_clock().now().to_msg()
       t.header.frame_id = 'turtle1'
       t.child_frame_id = 'carrot1'
       t.transform.translation.x = -1.0
       t.transform.translation.y = 0.0
       t.transform.translation.z = 0.0
       t.transform.rotation.x = 0.0
       t.transform.rotation.y = 0.0
       t.transform.rotation.z = 0.0
       t.transform.rotation.w = 1.0

       self.tf_broadcaster.sendTransform(t)


def main():
    rclpy.init()
    node = FixedFrameBroadcaster()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass

    rclpy.shutdown()
```

*C++ Implementation:*
```cpp
#include <chrono>
#include <functional>
#include <memory>

#include "geometry_msgs/msg/transform_stamped.hpp"
#include "rclcpp/rclcpp.hpp"
#include "tf2_ros/transform_broadcaster.hpp"

using namespace std::chrono_literals;

class FixedFrameBroadcaster : public rclcpp::Node
{
public:
  FixedFrameBroadcaster()
  : Node("fixed_frame_tf2_broadcaster")
  {
    tf_broadcaster_ = std::make_shared<tf2_ros::TransformBroadcaster>(this);

    auto broadcast_timer_callback = [this](){
        geometry_msgs::msg::TransformStamped t;

        t.header.stamp = this->get_clock()->now();
        t.header.frame_id = "turtle1";
        t.child_frame_id = "carrot1";
        t.transform.translation.x = -1.0;
        t.transform.translation.y = 0.0;
        t.transform.translation.z = 0.0;
        t.transform.rotation.x = 0.0;
        t.transform.rotation.y = 0.0;
        t.transform.rotation.z = 0.0;
        t.transform.rotation.w = 1.0;

        tf_broadcaster_->sendTransform(t);
    };
    timer_ = this->create_wall_timer(100ms, broadcast_timer_callback);
  }

private:
  rclcpp::TimerBase::SharedPtr timer_;
  std::shared_ptr<tf2_ros::TransformBroadcaster> tf_broadcaster_;
};

int main(int argc, char * argv[])
{
  rclcpp::init(argc, argv);
  rclcpp::spin(std::make_shared<FixedFrameBroadcaster>());
  rclcpp::shutdown();
  return 0;
}
```

#pagebreak()

= Terminal Commands Summary

Below is a summary of all the important `bash` commands used in this document:

*1. Install the necessary packages for the demo:*
```bash
sudo apt-get install ros-jazzy-rviz2 ros-jazzy-turtle-tf2-py ros-jazzy-tf2-ros ros-jazzy-tf2-tools ros-jazzy-turtlesim python3-scipy
```

*2. Launch the TF2 Demo:*
```bash
ros2 launch turtle_tf2_py turtle_tf2_demo.launch.py
```

*3. Run the Teleop Node to drive the turtle:*
```bash
ros2 run turtlesim turtle_teleop_key
```

*4. View the broadcasted TF frames tree (creates a PDF):*
```bash
ros2 run tf2_tools view_frames
```

*5. Echo the transformation between two specific frames:*
```bash
ros2 run tf2_ros tf2_echo turtle2 turtle1
```

*6. Launch RViz2 for visualization:*
```bash
ros2 run rviz2 rviz2
```

*7. Run the simple Python quaternion example:*
```bash
ros2 run python_tf2_pkg simple_quaternion
```

*8. Run the static transform publisher via Command Line:*
```bash
ros2 run tf2_ros static_transform_publisher --x 4 --y 4 --z 0 --yaw 1.57 --pitch 0 --roll 0 --frame-id world --child-frame-id myturtle
```

*9. Monitor the TF2 chain delays:*
```bash
ros2 run tf2_ros tf2_monitor turtle2 turtle1
```
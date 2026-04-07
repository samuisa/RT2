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

#show raw.where(block: true): it => block(
  fill: luma(245),
  inset: 10pt,
  radius: 5pt,
  width: 100%,
  text(size: 9pt, it) 
)

// --- TITOLO ---
#align(center)[
  #text(size: 24pt, weight: "bold", fill: rgb("#1d3557"))[Research Track 2] \
  #v(0.5em)
  #text(size: 18pt, weight: "bold")[Course Introduction & ROS2 Actions] \
  #v(1em)
  #text(size: 12pt)[Carmine Tommaso Recchiuto] \
  #text(size: 10pt, style: "italic")[Research Track II - Class I]
]

#v(2em)

// --- INDICE ---
#outline(title: "Contents", depth: 2, indent: auto)
#pagebreak()

// --- CONTENUTO ---

= Course Introduction

== Why Research Track 2?
Hands-on experiences are required for engineering education. Research Track I put the basis for letting you work with robots, giving practical fundamentals in different contexts. 

Research Track II moves the paradigm from:
#align(center)[
  *#text(fill: rgb("#457b9d"))["I can program a robot"]* $arrow.r$ *#text(fill: rgb("#1d3557"))["I can design, document, and validate a robotic experiment"]*
]

- *Design* $arrow.r$ *Implementation*
- *Validation* $arrow.r$ *Communication*

== Course Contents
+ *ROS2 Advanced Topics (about 15 hours):* ROS2 Actions, Components and modular architectures, TF2 and coordinate transformations, Testing in ROS2.
+ *Research Line Development (about 25 hours):* Literature review in robotics, Experimental design and validation, Software documentation and Markdown, Data visualization principles and tools, Jupyter Notebooks for reproducible research, Statistics for robotics experiments.

== Evaluation & Assignments
Each assignment must be done individually and delivered within the given deadline. They constitute *70%* of the final evaluation. There will be a final discussion to present and discuss both assignments (*30%*).

1. *1st Assignment:* An architecture with ROS2 involving the concepts seen in the first part of the course.
2. *2nd Assignment:* An article about a research line of your choice, comprehensive of a state of the art, experimental methodology, results, discussion. Results may be "simulated" but must be coherently discussed.

= Introduction to ROS2 Actions

== The Problem
Some robotic tasks take a long time to complete (e.g., Navigation to a goal, Manipulation sequence, Exploration mission). For these tasks, services are not enough because:
- They need *feedback* during execution.
- They may need to be *cancelled* mid-execution.

#table(
  columns: (1fr, auto, auto, auto),
  align: center,
  fill: (col, row) => if row == 0 { rgb("#1d3557") } else { none },
  stroke: 0.5pt + luma(200),
  [#text(fill: white, weight: "bold")[Feature]], 
  [#text(fill: white, weight: "bold")[Topics]], 
  [#text(fill: white, weight: "bold")[Services]], 
  [#text(fill: white, weight: "bold")[Actions]],
  align(left)[*Async*], [X], [], [X],
  align(left)[*Feedback*], [], [], [X],
  align(left)[*Cancel*], [], [], [X],
  align(left)[*Long tasks*], [], [], [X]
)

*Key idea:* Actions are designed for long-running, preemptable tasks. They are built on topics and services but are managed as a third, distinct communication paradigm. An Action is composed of three parts: a *Goal*, a *Feedback*, and a *Result*.

= Actions in Turtlesim

The Turtlesim environment provides an action server to rotate the turtle towards a predefined angle. It's a long-term task, you might want to cancel it, and you want feedback (current angle).

*Command Line Tools:*
```bash
>> ros2 action list
/turtle1/rotate_absolute

>> ros2 action info /turtle1/rotate_absolute
Action: /turtle1/rotate_absolute
Action clients: 0
Action servers: 1

>> ros2 action type /turtle1/rotate_absolute
turtlesim/action/RotateAbsolute

>> ros2 interface show turtlesim/action/RotateAbsolute
# The desired heading in radians
float32 theta
---
# The angular displacement in radians to the starting position
float32 delta
---
# The remaining rotation in radians
float32 remaining
```

*Sending a Goal from CLI:*
```bash
ros2 action send_goal /turtle1/rotate_absolute turtlesim/action/RotateAbsolute "{theta: 1.57}" --feedback
```
You can cancel the goal using `ros2 action send_goal --cancel` or pressing `CTRL+C`.

= Writing an Action Client (Python)

To use actions inside our code, we create an Action Client. 

#rect(fill: rgb("#fff3cd"), stroke: rgb("#ffe69c"), inset: 10pt, radius: 4pt, width: 100%)[
  *Client Logic Flow:*
  1. Initialize `ActionClient` with node, action type, and action name.
  2. Wait for the server (`wait_for_server()`).
  3. Send the goal asynchronously (`send_goal_async()`), attaching a feedback callback.
  4. Attach a "done callback" to handle the server's acceptance/rejection of the goal.
  5. If accepted, request the result asynchronously and attach another "done callback" to process the final output.
]

== Full Example with Callbacks
```python
import rclpy
from rclpy.action import ActionClient
from rclpy.node import Node
from turtlesim.action import RotateAbsolute

class RotateAbsoluteClient(Node):
    def __init__(self):
        super().__init__('rotate_absolute_client')
        self._action_client = ActionClient(self, RotateAbsolute, '/turtle1/rotate_absolute')

    def send_goal(self, theta):
        goal_msg = RotateAbsolute.Goal()
        goal_msg.theta = theta
        self._action_client.wait_for_server()
        
        # Send goal async with a feedback callback
        self._send_goal_future = self._action_client.send_goal_async(
            goal_msg, feedback_callback=self.feedback_callback)
        self._send_goal_future.add_done_callback(self.goal_response_callback)

    def goal_response_callback(self, future):
        goal_handle = future.result()
        if not goal_handle.accepted:
            self.get_logger().info('Goal rejected :(')
            return
        self.get_logger().info('Goal accepted :)')
        
        self._get_result_future = goal_handle.get_result_async()
        self._get_result_future.add_done_callback(self.get_result_callback)

    def get_result_callback(self, future):
        result = future.result().result
        self.get_logger().info(f'Result: {result.delta}')
        rclpy.shutdown()

    def feedback_callback(self, feedback_msg):
        feedback = feedback_msg.feedback
        self.get_logger().info(f'Received feedback: remaining = {feedback.remaining}')
```

== Cancelling a Goal from the Client
We can use the feedback to trigger a cancellation (e.g., if `remaining < 1.0`).
```python
    def feedback_callback(self, feedback_msg):
        remaining = feedback_msg.feedback.remaining
        if self._cancel_sent or self._goal_handle is None:
            return
            
        if -1.0 < remaining < 1.0:
            self._cancel_sent = True
            self.get_logger().warn('Remaining angle < 1, cancelling goal...')
            cancel_future = self._goal_handle.cancel_goal_async()
            cancel_future.add_done_callback(self.cancel_done_callback)
```

= Writing an Action Server (Python)

== 1. Defining a Custom Action
Custom actions are defined in `.action` files (e.g., `Fibonacci.action`):
```text
int32 order
---
int32[] sequence
---
int32[] partial_sequence
```
You must update `CMakeLists.txt` (`rosidl_generate_interfaces`) and `package.xml` (`rosidl_default_generators`, `action_msgs`) to compile it.

== 2. Implementing the Server
The basic skeleton uses `ActionServer` and an `execute_callback` to process the goal, publish feedback, and return the result.

```python
import time
import rclpy
from rclpy.action import ActionServer
from rclpy.node import Node
from action_tutorials_interfaces.action import Fibonacci

class FibonacciActionServer(Node):
    def __init__(self):
        super().__init__('fibonacci_action_server')
        self._action_server = ActionServer(
            self, Fibonacci, 'fibonacci', self.execute_callback)

    def execute_callback(self, goal_handle):
        self.get_logger().info('Executing goal...')
        feedback_msg = Fibonacci.Feedback()
        feedback_msg.partial_sequence = [0, 1]

        for i in range(1, goal_handle.request.order):
            feedback_msg.partial_sequence.append(
                feedback_msg.partial_sequence[i] + feedback_msg.partial_sequence[i-1])
            self.get_logger().info(f'Feedback: {feedback_msg.partial_sequence}')
            goal_handle.publish_feedback(feedback_msg)
            time.sleep(1)

        goal_handle.succeed()
        result = Fibonacci.Result()
        result.sequence = feedback_msg.partial_sequence
        return result
```

== 3. Handling Goal Cancellation (Advanced)

If a client cancels a goal, the server loop will keep running forever unless we explicitly handle cancellations. We must:
1. Provide a `cancel_callback` to accept the cancellation.
2. Use a `MultiThreadedExecutor` and a `ReentrantCallbackGroup` so the cancel request can be processed concurrently while the execution loop runs.
3. Check `goal_handle.is_cancel_requested` inside our execution loop.

#rect(fill: rgb("#f8d7da"), stroke: rgb("#f5c2c7"), inset: 10pt, radius: 4pt, width: 100%)[
  *Single-Threaded vs Multi-Threaded Executor:* \
  `rclpy.spin(node)` uses a Single Threaded Executor. If `execute_callback` has a `time.sleep()`, it blocks the entire node, preventing cancel requests from being received. `MultiThreadedExecutor` + `ReentrantCallbackGroup` solves this by allowing multiple callbacks to run concurrently.
]

*Updated Server Logic:*
```python
from rclpy.executors import MultiThreadedExecutor
from rclpy.callback_groups import ReentrantCallbackGroup

class FibonacciActionServer(Node):
    def __init__(self):
        super().__init__('fibonacci_action_server')
        self._cb_group = ReentrantCallbackGroup()
        self._action_server = ActionServer(
            self, Fibonacci, 'fibonacci', 
            execute_callback=self.execute_callback,
            cancel_callback=self.cancel_callback, 
            callback_group=self._cb_group)

    def cancel_callback(self, goal_handle):
        self.get_logger().warn('Received cancel request')
        return CancelResponse.ACCEPT

    def execute_callback(self, goal_handle):
        # ... setup ...
        for i in range(1, goal_handle.request.order):
            if goal_handle.is_cancel_requested:
                self.get_logger().warn('Cancel requested, stopping execution')
                goal_handle.canceled()
                result = Fibonacci.Result()
                result.sequence = feedback_msg.partial_sequence
                return result
            # ... process and publish feedback ...
```
*In `main()`:*
```python
def main(args=None):
    rclpy.init(args=args)
    node = FibonacciActionServer()
    executor = MultiThreadedExecutor()
    executor.add_node(node)
    executor.spin()
    rclpy.shutdown()
```

= Notes on C++ Implementation
In C++ (`rclcpp_action::create_server`), you have to provide three callbacks:
- `handle_goal` $arrow.r$ decides accept/reject.
- `handle_cancel` $arrow.r$ decides accept/reject cancellation.
- `handle_accepted` $arrow.r$ called when accepted; execution starts from here (typically launches the "execute" step in a new thread).

= Exercise (Preliminary part of Assignment 1)
Write an action server for the `bme_gazebo_sensors` robot (branch `rt2`).
```bash
ros2 launch bme_gazebo_sensors spawn_robot_ex.launch.py
```
The action server must move the robot along $x$ until it reaches the goal sent by the client. You can measure the robot's position with `odom` and send velocity commands with `cmd_vel`.
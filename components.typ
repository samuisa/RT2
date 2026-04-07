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

// Font monospazio di default di Typst per i codici
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
  #text(size: 18pt, weight: "bold")[ROS2 Components] \
  #v(1em)
  #text(size: 12pt)[Carmine Tommaso Recchiuto] \
  #text(size: 10pt, style: "italic")[Research Track II - Class II]
]

#v(2em)

// --- INDICE ---
#outline(title: "Contents", depth: 2, indent: auto)
#pagebreak()

// --- CONTENUTO ---

= Background: Nodes and Nodelets (ROS1)

In ROS 1, you can write your code as a *node* or a *nodelet*. Both perform computations (read topics, process data, publish results), but they differ in how they run and communicate.

== Nodes vs Nodelets
- *Node*: A separate process in the operating system. Nodes run independently and communicate through ROS topics, services, or actions. Data is serialized and copied when sent between nodes.
- *Nodelet*: Like a node, but multiple nodelets run inside the *same process*, managed by a *Nodelet Manager*. Instead of sending data through serialization, they can pass pointers to the same memory (zero-copy transport).

#table(
  columns: (1fr, 1fr),
  align: left,
  fill: (col, row) => if row == 0 { rgb("#1d3557") } else { none },
  stroke: 0.5pt + luma(200),
  [#text(fill: white, weight: "bold")[Nodes (ROS 1)]], 
  [#text(fill: white, weight: "bold")[Nodelets (ROS 1)]],
  [
    *Advantages:*
    - Very modular.
    - Robust (if one crashes, others survive).
    - Easy to debug and run separately.
    *Disadvantages:*
    - Data copying overhead.
    - Slower for large messages (like images/point clouds) due to serialization.
  ],
  [
    *Advantages:*
    - Zero-copy transport (fast for large data).
    *Disadvantages:*
    - Less isolation and modularity.
    - If one nodelet crashes, the whole manager process may crash.
    - Slightly more complex to implement.
  ]
)

== The Problem in ROS 1
In ROS 1, writing a node and writing a nodelet required using different base classes and programming structures. You couldn't easily reuse the same code. Nodelets required OOP style, inheriting from `nodelet::Nodelet`, initialization in `onInit()`, and lacked a standard `main()`.

= ROS2 Nodes and Components

In ROS 2, the recommended way of writing your code is similar to a nodelet, but *nodelets do not exist anymore*. They have been replaced by *Components*.
This avoids the biggest drawback in ROS 1: having different APIs. In ROS 2, both approaches (standalone node and component) use the exact same API.

By making the process layout a deploy-time decision, the user can choose between:
1. Running multiple nodes in *separate processes* (benefits: fault isolation, easier debugging).
2. Running multiple nodes in a *single process* (benefits: lower overhead, zero-copy communication).

== ROS2 Containers

To load components dynamically, ROS 2 uses Containers. A component container is a host process that allows you to load and manage multiple components at runtime within the same process space.

#rect(fill: rgb("#fff3cd"), stroke: rgb("#ffe69c"), inset: 10pt, radius: 4pt, width: 100%)[
  *Types of Containers in ROS 2:*
  - `component_container`: Uses a single *SingleThreadedExecutor* to execute all components.
  - `component_container_mt`: Uses a single *MultiThreadedExecutor* to execute the components concurrently.
  - `component_container_isolated`: Uses a dedicated executor for each component (either SingleThreaded or MultiThreaded).
]

= Writing a ROS2 Component (C++)

If you have written your node following the Object-Oriented style, converting it to a component is extremely simple.

== 1. The Constructor (`NodeOptions`)
The only change to your class definition is ensuring that the constructor takes a `NodeOptions` argument.

```cpp
// Normal standalone node constructor
MinimalPublisher() : Node("minimal_publisher") {}

// Component constructor
explicit MinimalPublisher(const rclcpp::NodeOptions & options) 
  : Node("minimal_publisher", options) {}
```

The container loads the component dynamically and passes `NodeOptions` to it.

== 2. No More `main()` Method
Replace your `main()` method with a pluginlib-style macro invocation.

```cpp
// Remove this:
// int main(int argc, char * argv[]) { ... }

// Add this at the bottom of the file:
RCLCPP_COMPONENTS_REGISTER_NODE(MinimalPublisher)
```

This tells ROS 2 that the class is a component plugin that can be dynamically loaded.

== 3. Namespaces
Using namespaces is extremely important for ROS 2 components because they are dynamically loaded using their name. Doing `class MinimalPublisher : public rclcpp::Node` in the global namespace is bad practice. Most ROS 2 packages use the package name as the namespace.

```cpp
namespace first_package_cpp
{
  class MinimalPublisher : public rclcpp::Node { ... };
}
RCLCPP_COMPONENTS_REGISTER_NODE(first_package_cpp::MinimalPublisher)
```

= CMakeLists.txt and package.xml

Components are plugins that must be compiled as shared libraries.

*CMakeLists.txt Additions:*

```cmake
# Build both a standalone executable and a shared library for the component
add_executable(talker_exe src/talker.cpp)
add_library(talker_component SHARED src/talker_component.cpp)

# Dependencies
find_package(rclcpp_components REQUIRED)
ament_target_dependencies(talker_component rclcpp rclcpp_components std_msgs)

# Register the node as a component
rclcpp_components_register_node(talker_component 
  PLUGIN "first_package_cpp::MinimalPublisher" 
  EXECUTABLE talker_exe
)

# Export and install
ament_export_targets(export_${PROJECT_NAME}_talker_component)
install(TARGETS talker_component 
  EXPORT export_${PROJECT_NAME}_talker_component
  ARCHIVE DESTINATION lib
  LIBRARY DESTINATION lib
  RUNTIME DESTINATION bin
)
```

*package.xml:* Add `` `<depend>rclcpp_components</depend>` ``.

= Running Components

Once built, you can run the node either as a standard executable (`` `ros2 run first_package_cpp talker_exe` ``) or load it into a container.

*Step 1: Start the container*

```sh
ros2 run rclcpp_components component_container
```

*Step 2: Check available components*

```sh
ros2 component types
```

*Step 3: Load the plugin inside the container*

```sh
ros2 component load /ComponentManager first_package_cpp first_package_cpp::MinimalPublisher
```

= Practical Test: Intra-Process Communication

By default, components do *not* implement intra-process communication automatically. To enable zero-copy data transfer, we must explicitly enable it:

*1. Enable `use_intra_process_comms`:*

```cpp
Node("minimal_publisher", rclcpp::NodeOptions(options).use_intra_process_comms(true))
```

*2. Use `std::unique_ptr` for publish and subscribe* (with `shared_ptr`, a copy of the object is still created).

```cpp
auto message = std::make_unique<std_msgs::msg::String>();
void topic_callback(std_msgs::msg::String::UniquePtr msg)
```

#rect(fill: rgb("#f8d7da"), stroke: rgb("#f5c2c7"), inset: 10pt, radius: 4pt, width: 100%)[
  *Memory Addresses Observation:* \
  If you print the memory addresses of the messages:
  - As *standalone nodes*: Addresses are completely different (serialization happens).
  - Inside a `component_container` (SingleThreaded): Addresses are exactly the same. The allocator reuses the same memory block.
  - Inside a `component_container_mt` (MultiThreaded): Addresses may change because memory allocation and deallocation happen with different timing across threads.
]

= Launch Files and Manual Composition

== Launch File Composition
You can automatically start containers and load components using Python launch files.

```python
import launch
from launch_ros.actions import ComposableNodeContainer
from launch_ros.descriptions import ComposableNode

def generate_launch_description():
    container = ComposableNodeContainer(
        name='my_container',
        namespace='',
        package='rclcpp_components',
        executable='component_container',
        composable_node_descriptions=[
            ComposableNode(
                package='first_package_cpp',
                plugin='first_package_cpp::MinimalSubscriber',
                name='listener',
                extra_arguments=[{'use_intra_process_comms': True}]
            ),
            # ... add publisher node here
        ],
        output='screen',
    )
    return launch.LaunchDescription([container])
```

== Manual Composition in C++
You can also load components manually within your code, avoiding launch files altogether. To do this, you must write your classes using header files (``.hpp``), and then instantiate them in a single executable:

```cpp
#include "first_package_cpp/subscriber_component.hpp"
#include "first_package_cpp/talker_component.hpp"
#include "rclcpp/rclcpp.hpp"

int main(int argc, char * argv[]) {
    rclcpp::init(argc, argv);
    
    rclcpp::NodeOptions options;
    options.use_intra_process_comms(true);
    
    auto publisher = std::make_shared<first_package_cpp::MinimalPublisher>(options);
    auto subscriber = std::make_shared<first_package_cpp::MinimalSubscriber>(options);
    
    rclcpp::executors::SingleThreadedExecutor executor;
    executor.add_node(publisher);
    executor.add_node(subscriber);
    
    executor.spin();
    rclcpp::shutdown();
    return 0;
}
```

= Exercise

After you have implemented the action server for moving the robot (from the previous class), try to adapt it to launch it as a component in a container. 
Also, create a launch file to start it together with the container.

#pagebreak()

// ---------------------------------------------------------
// SEZIONE: COMANDI TERMINALE
// ---------------------------------------------------------
= Terminal Commands Reference

== Building and Running Standalone Nodes
Run a demo node directly from a package:

```sh
ros2 run intra_process_demo two_node_pipeline
```

Run your custom executable nodes:

```sh
ros2 run first_package_cpp talker_exe
ros2 run first_package_cpp subscriber_exe
```

== Containers Management
Start the default single-threaded container:

```sh
ros2 run rclcpp_components component_container
```

Start the multithreaded container:

```sh
ros2 run rclcpp_components component_container_mt
```

Start the isolated executor container:

```sh
ros2 run rclcpp_components component_container_isolated
```

== Components Management
List all the available plugins/components in your workspace:

```sh
ros2 component types
```

List all the currently active components loaded into containers:

```sh
ros2 component list
```

Load a component dynamically into a running container:

```sh
ros2 component load /ComponentManager first_package_cpp first_package_cpp::MinimalPublisher
ros2 component load /ComponentManager first_package_cpp first_package_cpp::MinimalSubscriber
```

Load a component with explicit arguments (e.g., enabling intra-process comms):

```sh
ros2 component load /ComponentManager first_package_cpp first_package_cpp::MinimalPublisher -e use_intra_process_comms:=true -e forward_global_arguments:=false
```

#pagebreak()

// ---------------------------------------------------------
// SEZIONE: CODICI E IMPLEMENTAZIONI
// ---------------------------------------------------------
= Code Implementation Reference

== 1. Basic Component Examples

=== Minimal Publisher Component

```cpp
#include "rclcpp/rclcpp.hpp"
#include "std_msgs/msg/string.hpp"
#include <rclcpp_components/register_node_macro.hpp>
#include <iostream>

namespace first_package_cpp
{
    class MinimalPublisher : public rclcpp::Node 
    { 
        public: 
            explicit MinimalPublisher(const rclcpp::NodeOptions & options) : Node("minimal_publisher", options)
            { 
                publisher_ = this->create_publisher<std_msgs::msg::String>("topic", 10); 
                timer_ = this->create_wall_timer(std::chrono::milliseconds(500), std::bind(&MinimalPublisher::timer_callback, this)); 
                count_ = 0;
            }

        private:
            void timer_callback()
            {
                auto message = std_msgs::msg::String();
                message.data = "Hello, world! " + std::to_string(count_++);
                RCLCPP_INFO(this->get_logger(), "Publishing: '%s'", message.data.c_str());
                publisher_->publish(message);
            }
            rclcpp::Publisher<std_msgs::msg::String>::SharedPtr publisher_;
            rclcpp::TimerBase::SharedPtr timer_;
            size_t count_;
    };
}

RCLCPP_COMPONENTS_REGISTER_NODE(first_package_cpp::MinimalPublisher)
```

=== Minimal Subscriber Component

```cpp
#include "rclcpp/rclcpp.hpp" 
#include "std_msgs/msg/string.hpp" 
#include <rclcpp_components/register_node_macro.hpp>

using std::placeholders::_1; 

namespace first_package_cpp
{
    class MinimalSubscriber: public rclcpp::Node 
    { 
        public: 
            explicit MinimalSubscriber(const rclcpp::NodeOptions & options) : Node("minimal_subscriber", options)
            { 
                subscription_ = this->create_subscription<std_msgs::msg::String>("topic", 10, std::bind(&MinimalSubscriber::topic_callback, this, _1)); 
            } 
            
        private:  
            void topic_callback(const std_msgs::msg::String::SharedPtr msg) const 
            { 
                RCLCPP_INFO(this->get_logger(), "I heard: '%s'", msg->data.c_str()); 
            } 
            rclcpp::Subscription<std_msgs::msg::String>::SharedPtr subscription_; 
    };
}

RCLCPP_COMPONENTS_REGISTER_NODE(first_package_cpp::MinimalSubscriber)
```

== 2. Intra-Process Communication (Zero-Copy)

=== Publisher Component (Unique Pointers)

```cpp
#include "rclcpp/rclcpp.hpp"
#include "std_msgs/msg/string.hpp"
#include <rclcpp_components/register_node_macro.hpp>
#include <cinttypes>
#include <cstdio>

namespace first_package_cpp
{
class MinimalPublisher : public rclcpp::Node
{
public:
    explicit MinimalPublisher(const rclcpp::NodeOptions & options): Node("minimal_publisher", rclcpp::NodeOptions(options).use_intra_process_comms(true))
    {
        publisher_ = this->create_publisher<std_msgs::msg::String>("topic", 10);
        timer_ = this->create_wall_timer(std::chrono::milliseconds(500), std::bind(&MinimalPublisher::timer_callback, this));
        count_ = 0;
    }

private:
    void timer_callback()
    {
        auto message = std::make_unique<std_msgs::msg::String>();
        message->data = "Hello, world! " + std::to_string(count_++);

        RCLCPP_INFO(this->get_logger(),"Published message with value: %s, and address: 0x%" PRIXPTR "\n", message->data.c_str(), reinterpret_cast<std::uintptr_t>(message.get()));
        publisher_->publish(std::move(message));
    }

    rclcpp::Publisher<std_msgs::msg::String>::SharedPtr publisher_;
    rclcpp::TimerBase::SharedPtr timer_;
    size_t count_;
};
}

RCLCPP_COMPONENTS_REGISTER_NODE(first_package_cpp::MinimalPublisher)
```

=== Subscriber Component (Unique Pointers)

```cpp
#include "rclcpp/rclcpp.hpp"
#include "std_msgs/msg/string.hpp"
#include <rclcpp_components/register_node_macro.hpp>
#include <cinttypes>
#include <cstdio>

using std::placeholders::_1;

namespace first_package_cpp
{
class MinimalSubscriber : public rclcpp::Node
{
public:
    explicit MinimalSubscriber(const rclcpp::NodeOptions & options): Node("minimal_subscriber", rclcpp::NodeOptions(options).use_intra_process_comms(true))
    {
        subscription_ = this->create_subscription<std_msgs::msg::String>("topic",10,std::bind(&MinimalSubscriber::topic_callback, this, _1));
    }

private:
    void topic_callback(std_msgs::msg::String::UniquePtr msg) const
    {
        RCLCPP_INFO(this->get_logger(), "Received message with value: %s, and address: 0x%" PRIXPTR "\n",msg->data.c_str(), reinterpret_cast<std::uintptr_t>(msg.get()));
    }

    rclcpp::Subscription<std_msgs::msg::String>::SharedPtr subscription_;
};
}

RCLCPP_COMPONENTS_REGISTER_NODE(first_package_cpp::MinimalSubscriber)
```

== 3. Service Components

=== Minimal Client Component

```cpp
#include <iostream>
#include <cinttypes>
#include "example_interfaces/srv/add_two_ints.hpp"
#include "rclcpp/rclcpp.hpp"
#include "rclcpp_components/register_node_macro.hpp"

using namespace std::chrono_literals;

namespace first_package_cpp
{
    class MinimalClient: public rclcpp::Node 
    { 
    public:
        explicit MinimalClient(const rclcpp::NodeOptions & options) : Node("minimal_client", options)
        {
        client_ = create_client<example_interfaces::srv::AddTwoInts>("add_two_ints");
        timer_ = create_wall_timer(2s, [this]() {return this->on_timer();});
        }      

    private:
        void on_timer()
        {
            if (!client_->wait_for_service(1s)) {
                if (!rclcpp::ok()) {
                RCLCPP_ERROR(this->get_logger(), "Interrupted while waiting for the service. Exiting.");
                return;
                    }
        RCLCPP_INFO(this->get_logger(), "Service not available after waiting");
        return;
                }

        auto request = std::make_shared<example_interfaces::srv::AddTwoInts::Request>();
        request->a = 2;
        request->b = 3;

        using ServiceResponseFuture = rclcpp::Client<example_interfaces::srv::AddTwoInts>::SharedFuture;
        auto response_received_callback = [this](ServiceResponseFuture future) {
        RCLCPP_INFO(this->get_logger(), "Got result: [%" PRId64 "]", future.get()->sum);
            };
        auto future_result = client_->async_send_request(request, response_received_callback);
        }
        rclcpp::Client<example_interfaces::srv::AddTwoInts>::SharedPtr client_;
        rclcpp::TimerBase::SharedPtr timer_; 
    };
}

RCLCPP_COMPONENTS_REGISTER_NODE(first_package_cpp::MinimalClient)
```

== 4. Launching and Composing 

=== Python Launch File (ComposableNodeContainer)

```python
import launch
from launch_ros.actions import ComposableNodeContainer
from launch_ros.descriptions import ComposableNode

def generate_launch_description():
    container = ComposableNodeContainer(
            name='my_container',
            namespace='',
            package='rclcpp_components',
            executable='component_container',
            composable_node_descriptions=[
                ComposableNode(
                    package='first_package_cpp',
                    plugin='first_package_cpp::MinimalSubscriber',
                    name='listener',
                    ),
                    
                ComposableNode(
                    package='first_package_cpp',
                    plugin='first_package_cpp::MinimalPublisher',
                    name='talker',
                    )
            ],
            output='screen',
    )

    return launch.LaunchDescription([container])
```

=== Manual Composition (Single Executable with Executor)

```cpp
#include "rclcpp/rclcpp.hpp"
#include "std_msgs/msg/string.hpp"
#include <cinttypes>
#include <cstdio>
#include <memory>
#include <chrono>

using std::placeholders::_1;

namespace first_package_cpp
{

class MinimalPublisher : public rclcpp::Node
{
public:
    explicit MinimalPublisher(const rclcpp::NodeOptions & options)
    : Node("minimal_publisher", rclcpp::NodeOptions(options).use_intra_process_comms(true)),
      count_(0)
    {
        publisher_ = this->create_publisher<std_msgs::msg::String>("topic", 10);

        timer_ = this->create_wall_timer(
            std::chrono::milliseconds(500),
            std::bind(&MinimalPublisher::timer_callback, this));
    }

private:
    void timer_callback()
    {
        auto message = std::make_unique<std_msgs::msg::String>();
        message->data = "Hello, world! " + std::to_string(count_++);

        RCLCPP_INFO(
            this->get_logger(),
            "Published message with value: %s, and address: 0x%" PRIXPTR,
            message->data.c_str(),
            reinterpret_cast<std::uintptr_t>(message.get()));

        publisher_->publish(std::move(message));
    }

    rclcpp::Publisher<std_msgs::msg::String>::SharedPtr publisher_;
    rclcpp::TimerBase::SharedPtr timer_;
    size_t count_;
};

class MinimalSubscriber : public rclcpp::Node
{
public:
    explicit MinimalSubscriber(const rclcpp::NodeOptions & options)
    : Node("minimal_subscriber", rclcpp::NodeOptions(options).use_intra_process_comms(true))
    {
        subscription_ = this->create_subscription<std_msgs::msg::String>(
            "topic",
            10,
            std::bind(&MinimalSubscriber::topic_callback, this, _1));
    }

private:
    void topic_callback(std_msgs::msg::String::UniquePtr msg) const
    {
        RCLCPP_INFO(
            this->get_logger(),
            "Received message with value: %s, and address: 0x%" PRIXPTR,
            msg->data.c_str(),
            reinterpret_cast<std::uintptr_t>(msg.get()));
    }

    rclcpp::Subscription<std_msgs::msg::String>::SharedPtr subscription_;
};

}  // namespace first_package_cpp

int main(int argc, char * argv[])
{
    rclcpp::init(argc, argv);

    rclcpp::NodeOptions options;
    options.use_intra_process_comms(true);

    auto publisher = std::make_shared<first_package_cpp::MinimalPublisher>(options);
    auto subscriber = std::make_shared<first_package_cpp::MinimalSubscriber>(options);

    rclcpp::executors::SingleThreadedExecutor executor;
    executor.add_node(publisher);
    executor.add_node(subscriber);
    executor.spin();

    rclcpp::shutdown();
    return 0;
}

```
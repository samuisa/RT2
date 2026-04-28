#include <functional>
#include <memory>
#include <thread>
#include <cmath>
#include <string>

#include "rclcpp/rclcpp.hpp"
#include "rclcpp_action/rclcpp_action.hpp"
#include "rclcpp_components/register_node_macro.hpp"

#include "geometry_msgs/msg/twist.hpp"
#include "geometry_msgs/msg/transform_stamped.hpp"

#include "tf2_ros/transform_listener.hpp"
#include "tf2_ros/buffer.hpp"
#include "tf2/exceptions.hpp"

#include "action_msg/action/linear.hpp" 
#include "action_msg/action/angular.hpp"

namespace bme_gazebo_sensors
{
class MoveActionServer : public rclcpp::Node
{
public:
  using Linear = action_msg::action::Linear;
  using GoalHandleLinear = rclcpp_action::ServerGoalHandle<Linear>;

  using Angular = action_msg::action::Angular;
  using GoalHandleAngular = rclcpp_action::ServerGoalHandle<Angular>;

  explicit MoveActionServer(const rclcpp::NodeOptions & options = rclcpp::NodeOptions())
  : Node("move_server", options), current_x_(0.0), current_y_(0.0), current_yaw_(0.0)
  {
    using namespace std::placeholders;

    // Parameters for frame names (allowing flexibility via ROS 2 parameters)
    target_frame_ = this->declare_parameter<std::string>("target_frame", "base_footprint");
    source_frame_ = this->declare_parameter<std::string>("source_frame", "odom");

    // Publisher for robot velocity commands
    cmd_vel_pub_ = this->create_publisher<geometry_msgs::msg::Twist>("/cmd_vel", 10);

    // --- TF2 LISTENER INITIALIZATION ---
    // Sets up the buffer and listener to track the robot's position and orientation in real-time
    tf_buffer_ = std::make_unique<tf2_ros::Buffer>(this->get_clock());
    tf_listener_ = std::make_shared<tf2_ros::TransformListener>(*tf_buffer_);

    // --- ACTION SERVERS INITIALIZATION ---
    // Server for handling linear movement (X, Y coordinates)
    action_server_move_ = rclcpp_action::create_server<Linear>(
      this, "linear_server",
      std::bind(&MoveActionServer::handle_move_goal, this, _1, _2),
      std::bind(&MoveActionServer::handle_move_cancel, this, _1),
      std::bind(&MoveActionServer::handle_move_accepted, this, _1));

    // Server for handling angular movement (Rotation to a specific Theta)
    action_server_rotate_ = rclcpp_action::create_server<Angular>(
      this, "angular_server", 
      std::bind(&MoveActionServer::handle_rotate_goal, this, _1, _2),
      std::bind(&MoveActionServer::handle_rotate_cancel, this, _1),
      std::bind(&MoveActionServer::handle_rotate_accepted, this, _1));
      
    RCLCPP_INFO(this->get_logger(), "Move Server started with TF2 logic (Global Rotation)!");
  }

private:
  rclcpp::Publisher<geometry_msgs::msg::Twist>::SharedPtr cmd_vel_pub_;
  rclcpp_action::Server<Linear>::SharedPtr action_server_move_;
  rclcpp_action::Server<Angular>::SharedPtr action_server_rotate_;
  
  // --- TF2 VARIABLES ---
  std::unique_ptr<tf2_ros::Buffer> tf_buffer_;
  std::shared_ptr<tf2_ros::TransformListener> tf_listener_;
  std::string target_frame_;
  std::string source_frame_;
  
  // Internal state variables for current pose
  double current_x_;
  double current_y_;
  double current_yaw_;

  /**
   * @brief Fetches the latest transform from TF2 and updates the robot's current pose.
   * @return true if transform was successfully retrieved, false otherwise.
   */
  bool update_current_pose()
  {
    try {
      // Lookup the latest transform from source (odom) to target (base_footprint)
      geometry_msgs::msg::TransformStamped t = tf_buffer_->lookupTransform(
        source_frame_, target_frame_, tf2::TimePointZero);

      // Extract translation (X, Y)
      current_x_ = t.transform.translation.x;
      current_y_ = t.transform.translation.y;

      // Extract rotation (Quaternion)
      double qx = t.transform.rotation.x;
      double qy = t.transform.rotation.y;
      double qz = t.transform.rotation.z;
      double qw = t.transform.rotation.w;
      
      // Convert Quaternion to Euler Yaw (Z-axis rotation)
      current_yaw_ = std::atan2(2.0 * (qw * qz + qx * qy), 1.0 - 2.0 * (qy * qy + qz * qz));
      return true;
    } catch (const tf2::TransformException & ex) {
      // Log a warning if the transform is unavailable (throttled to avoid spamming the console)
      RCLCPP_WARN_THROTTLE(this->get_logger(), *this->get_clock(), 2000, 
        "Waiting for TF2 transform from %s to %s: %s", source_frame_.c_str(), target_frame_.c_str(), ex.what());
      return false;
    }
  }

  // --- GOAL HANDLING CALLBACKS (LINEAR) ---
  rclcpp_action::GoalResponse handle_move_goal(const rclcpp_action::GoalUUID & uuid, std::shared_ptr<const Linear::Goal> goal) { 
      (void)uuid; (void)goal; 
      RCLCPP_INFO(this->get_logger(), "Received new Linear goal.");
      return rclcpp_action::GoalResponse::ACCEPT_AND_EXECUTE; 
  }
  
  rclcpp_action::CancelResponse handle_move_cancel(const std::shared_ptr<GoalHandleLinear> goal_handle) { 
      (void)goal_handle; 
      RCLCPP_WARN(this->get_logger(), "Received request to STOP Linear movement!");
      return rclcpp_action::CancelResponse::ACCEPT; 
  }
  
  void handle_move_accepted(const std::shared_ptr<GoalHandleLinear> goal_handle) { 
      // Execute the movement logic in a separate thread to avoid blocking the ROS 2 executor
      std::thread{std::bind(&MoveActionServer::execute_move, this, std::placeholders::_1), goal_handle}.detach(); 
  }

  // --- GOAL HANDLING CALLBACKS (ANGULAR) ---
  rclcpp_action::GoalResponse handle_rotate_goal(const rclcpp_action::GoalUUID & uuid, std::shared_ptr<const Angular::Goal> goal) { 
      (void)uuid; (void)goal; 
      RCLCPP_INFO(this->get_logger(), "Received new Angular goal.");
      return rclcpp_action::GoalResponse::ACCEPT_AND_EXECUTE; 
  }
  
  rclcpp_action::CancelResponse handle_rotate_cancel(const std::shared_ptr<GoalHandleAngular> goal_handle) { 
      (void)goal_handle; 
      RCLCPP_WARN(this->get_logger(), "Received request to STOP Angular movement!");
      return rclcpp_action::CancelResponse::ACCEPT; 
  }
  
  void handle_rotate_accepted(const std::shared_ptr<GoalHandleAngular> goal_handle) { 
      // Execute the rotation logic in a separate thread
      std::thread{std::bind(&MoveActionServer::execute_rotate, this, std::placeholders::_1), goal_handle}.detach(); 
  }

  // --- EXECUTING LINEAR MOVEMENT ---
  void execute_move(const std::shared_ptr<GoalHandleLinear> goal_handle)
  {
    rclcpp::Rate loop_rate(10); // Control loop runs at 10 Hz
    const auto goal = goal_handle->get_goal();
    auto feedback = std::make_shared<Linear::Feedback>();
    auto result = std::make_shared<Linear::Result>();
    auto vel_msg = geometry_msgs::msg::Twist();

    while (rclcpp::ok()) {
      // Check if a cancellation request was received
      if (goal_handle->is_canceling()) {
        RCLCPP_WARN(this->get_logger(), "Linear movement successfully aborted.");
        // Stop the robot
        vel_msg.linear.x = 0.0;
        vel_msg.angular.z = 0.0;
        cmd_vel_pub_->publish(vel_msg);
        goal_handle->canceled(result);
        return;
      }

      // Update pose; if TF is temporarily unavailable, wait for the next iteration
      if (!update_current_pose()) {
        loop_rate.sleep();
        continue;
      }

      // Calculate Euclidean distance to the target coordinates
      double distance = std::hypot(goal->x - current_x_, goal->y - current_y_);
      
      // Print distance on the same line using carriage return (\r)
      std::cout << "\rDistance to goal: " << distance << std::flush;

      // Check if target is reached (within 5cm tolerance)
      if (distance < 0.05){
        std::cout << std::endl; // Move to the next line to avoid overwriting the final distance
        break;
      }
      
      // Compute the heading required to point towards the target
      double angle_to_goal = std::atan2(goal->y - current_y_, goal->x - current_x_);
      double angle_error = angle_to_goal - current_yaw_;
      
      // Normalize the angle error to be within [-PI, PI]
      while (angle_error > M_PI) angle_error -= 2.0 * M_PI;
      while (angle_error < -M_PI) angle_error += 2.0 * M_PI;

      // Simple Proportional (P) Controller for movement
      if (std::abs(angle_error) > 0.1) {
        // If not facing the target, stop forward motion and rotate towards it
        vel_msg.linear.x = 0.0;
        vel_msg.angular.z = (angle_error > 0) ? 0.4 : -0.4;
      } else {
        // If facing the target, move forward
        vel_msg.linear.x = 0.3;
        vel_msg.angular.z = 0.0;
      }

      // Publish velocity commands and send feedback
      cmd_vel_pub_->publish(vel_msg);
      goal_handle->publish_feedback(feedback);
      loop_rate.sleep();
    }

    // Action successfully completed
    if (rclcpp::ok()) {
      RCLCPP_INFO(this->get_logger(), "\nLinear movement COMPLETED. Ready for rotation.");
      // Ensure the robot is fully stopped
      vel_msg.linear.x = 0.0;
      vel_msg.angular.z = 0.0;
      cmd_vel_pub_->publish(vel_msg);
      goal_handle->succeed(result);
    }
  }

  // --- EXECUTING ANGULAR ROTATION ---
  void execute_rotate(const std::shared_ptr<GoalHandleAngular> goal_handle)
  {
    rclcpp::Rate loop_rate(10); // Control loop runs at 10 Hz
    const auto goal = goal_handle->get_goal();
    auto feedback = std::make_shared<Angular::Feedback>();
    auto result = std::make_shared<Angular::Result>();
    auto vel_msg = geometry_msgs::msg::Twist();

    // Ensure we have a valid pose before starting
    while (!update_current_pose() && rclcpp::ok()) { loop_rate.sleep(); }
    double initial_yaw = current_yaw_;

    double target_yaw = goal->theta;

    // Normalize target yaw to be within [-PI, PI]
    while (target_yaw > M_PI) target_yaw -= 2.0 * M_PI;
    while (target_yaw < -M_PI) target_yaw += 2.0 * M_PI;

    while (rclcpp::ok()) {
      // Check if a cancellation request was received
      if (goal_handle->is_canceling()) {
        RCLCPP_WARN(this->get_logger(), "\nRotation successfully aborted.");
        // Stop the robot
        vel_msg.angular.z = 0.0;
        cmd_vel_pub_->publish(vel_msg);
        
        // Populate result with the rotation completed before cancellation
        result->delta = current_yaw_ - initial_yaw; 
        
        goal_handle->canceled(result);
        return;
      }

      update_current_pose();

      // Calculate the difference between current orientation and target orientation
      double error = target_yaw - current_yaw_;

      // Print orientation error on the same line
      std::cout << "\rOrientation error: " << error << std::flush;
      
      // Normalize the error to choose the shortest rotation path [-PI, PI]
      while (error > M_PI) error -= 2.0 * M_PI;
      while (error < -M_PI) error += 2.0 * M_PI;

      // Check if target orientation is reached (within ~2.8 degrees tolerance)
      if (std::abs(error) < 0.05){
        std::cout << std::endl; // Move to the next line
        break;
      }

      // Simple Proportional (P) Controller for rotation
      vel_msg.angular.z = (error > 0) ? 0.4 : -0.4;
      cmd_vel_pub_->publish(vel_msg);

      goal_handle->publish_feedback(feedback);
      loop_rate.sleep();
    }

    // Action successfully completed
    if (rclcpp::ok()) {
      RCLCPP_INFO(this->get_logger(), "\nRotation COMPLETED. The robot has reached the final orientation.");
      // Ensure the robot stops rotating
      vel_msg.angular.z = 0.0;
      cmd_vel_pub_->publish(vel_msg);
      
      // Provide the total rotation performed as a result
      result->delta = current_yaw_ - initial_yaw; 
      
      goal_handle->succeed(result);
    }
  }
};
}

RCLCPP_COMPONENTS_REGISTER_NODE(bme_gazebo_sensors::MoveActionServer)
#include <functional>
#include <memory>
#include <thread>
#include <cmath>

#include "rclcpp/rclcpp.hpp"
#include "rclcpp_action/rclcpp_action.hpp"
#include "rclcpp_components/register_node_macro.hpp"

#include "geometry_msgs/msg/twist.hpp"
#include "nav_msgs/msg/odometry.hpp"

// Use your custom action messages
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

    cmd_vel_pub_ = this->create_publisher<geometry_msgs::msg::Twist>("/cmd_vel", 10);

    odom_sub_ = this->create_subscription<nav_msgs::msg::Odometry>(
      "/odom", 10, std::bind(&MoveActionServer::odom_callback, this, _1));

    // Linear Action Server
    action_server_move_ = rclcpp_action::create_server<Linear>(
      this,
      "linear_server",
      std::bind(&MoveActionServer::handle_move_goal, this, _1, _2),
      std::bind(&MoveActionServer::handle_move_cancel, this, _1),
      std::bind(&MoveActionServer::handle_move_accepted, this, _1));

    // Angular Action Server
    action_server_rotate_ = rclcpp_action::create_server<Angular>(
      this,
      "angular_server", 
      std::bind(&MoveActionServer::handle_rotate_goal, this, _1, _2),
      std::bind(&MoveActionServer::handle_rotate_cancel, this, _1),
      std::bind(&MoveActionServer::handle_rotate_accepted, this, _1));
      
    RCLCPP_INFO(this->get_logger(), "Move and Rotate Action Servers (Components) started!");
  }

private:
  rclcpp::Publisher<geometry_msgs::msg::Twist>::SharedPtr cmd_vel_pub_;
  rclcpp::Subscription<nav_msgs::msg::Odometry>::SharedPtr odom_sub_;
  
  rclcpp_action::Server<Linear>::SharedPtr action_server_move_;
  rclcpp_action::Server<Angular>::SharedPtr action_server_rotate_;
  
  double current_x_;
  double current_y_;
  double current_yaw_;

  void odom_callback(const nav_msgs::msg::Odometry::SharedPtr msg)
  {
    current_x_ = msg->pose.pose.position.x;
    current_y_ = msg->pose.pose.position.y;

    double qx = msg->pose.pose.orientation.x;
    double qy = msg->pose.pose.orientation.y;
    double qz = msg->pose.pose.orientation.z;
    double qw = msg->pose.pose.orientation.w;
    
    current_yaw_ = std::atan2(2.0 * (qw * qz + qx * qy), 1.0 - 2.0 * (qy * qy + qz * qz));
  }

  // --- LINEAR METHODS ---
  rclcpp_action::GoalResponse handle_move_goal(
    const rclcpp_action::GoalUUID & uuid, std::shared_ptr<const Linear::Goal> goal)
  {
    (void)uuid;
    RCLCPP_INFO(this->get_logger(), "Linear request received -> X: %.2f, Y: %.2f", goal->x, goal->y);
    return rclcpp_action::GoalResponse::ACCEPT_AND_EXECUTE;
  }

  rclcpp_action::CancelResponse handle_move_cancel(const std::shared_ptr<GoalHandleLinear> goal_handle)
  {
    (void)goal_handle;
    RCLCPP_WARN(this->get_logger(), "Cancel request for Linear movement received.");
    return rclcpp_action::CancelResponse::ACCEPT;
  }

  void handle_move_accepted(const std::shared_ptr<GoalHandleLinear> goal_handle)
  {
    std::thread{std::bind(&MoveActionServer::execute_move, this, std::placeholders::_1), goal_handle}.detach();
  }

void execute_move(const std::shared_ptr<GoalHandleLinear> goal_handle)
  {
    rclcpp::Rate loop_rate(10);
    const auto goal = goal_handle->get_goal();
    auto feedback = std::make_shared<Linear::Feedback>();
    auto result = std::make_shared<Linear::Result>();
    auto vel_msg = geometry_msgs::msg::Twist();

    while (rclcpp::ok()) {
      if (goal_handle->is_canceling()) {
        vel_msg.linear.x = 0.0;
        vel_msg.angular.z = 0.0;
        cmd_vel_pub_->publish(vel_msg);
        goal_handle->canceled(result);
        return;
      }

      // Calcola la distanza rimanente
      double distance = std::hypot(goal->x - current_x_, goal->y - current_y_);
      
      if (distance < 0.1) {
        break; // Obiettivo lineare raggiunto!
      }

      // Calcola l'angolo verso l'obiettivo (x, y)
      double angle_to_goal = std::atan2(goal->y - current_y_, goal->x - current_x_);
      double angle_error = angle_to_goal - current_yaw_;
      
      // Normalizza l'errore tra -PI e +PI
      while (angle_error > M_PI) angle_error -= 2.0 * M_PI;
      while (angle_error < -M_PI) angle_error += 2.0 * M_PI;

      // Se il robot non punta verso l'obiettivo, fallo ruotare
      if (std::abs(angle_error) > 0.1) {
        vel_msg.linear.x = 0.0;
        vel_msg.angular.z = (angle_error > 0) ? 0.4 : -0.4;
      } 
      // Se è allineato, fallo avanzare dritto
      else {
        vel_msg.linear.x = 0.3;
        vel_msg.angular.z = 0.0;
      }

      cmd_vel_pub_->publish(vel_msg);
      goal_handle->publish_feedback(feedback);
      loop_rate.sleep();
    }

    if (rclcpp::ok()) {
      vel_msg.linear.x = 0.0;
      vel_msg.angular.z = 0.0;
      cmd_vel_pub_->publish(vel_msg);
      // result->success = true; // Scommenta se il tuo Result ha un campo success
      goal_handle->succeed(result);
      RCLCPP_INFO(this->get_logger(), "Target lineare raggiunto!");
    }
  }

  // --- ANGULAR METHODS ---
  rclcpp_action::GoalResponse handle_rotate_goal(
    const rclcpp_action::GoalUUID & uuid, std::shared_ptr<const Angular::Goal> goal)
  {
    (void)uuid;
    RCLCPP_INFO(this->get_logger(), "Angular request received -> Theta: %.2f", goal->theta);
    return rclcpp_action::GoalResponse::ACCEPT_AND_EXECUTE;
  }

  rclcpp_action::CancelResponse handle_rotate_cancel(const std::shared_ptr<GoalHandleAngular> goal_handle)
  {
    (void)goal_handle;
    RCLCPP_WARN(this->get_logger(), "Cancel request for Rotation received.");
    return rclcpp_action::CancelResponse::ACCEPT;
  }

  void handle_rotate_accepted(const std::shared_ptr<GoalHandleAngular> goal_handle)
  {
    std::thread{std::bind(&MoveActionServer::execute_rotate, this, std::placeholders::_1), goal_handle}.detach();
  }

  void execute_rotate(const std::shared_ptr<GoalHandleAngular> goal_handle)
  {
    rclcpp::Rate loop_rate(10);
    const auto goal = goal_handle->get_goal();
    auto feedback = std::make_shared<Angular::Feedback>();
    auto result = std::make_shared<Angular::Result>();
    auto vel_msg = geometry_msgs::msg::Twist();

    double initial_yaw = current_yaw_;

    while (rclcpp::ok()) {
      if (goal_handle->is_canceling()) {
        vel_msg.angular.z = 0.0;
        cmd_vel_pub_->publish(vel_msg);
        result->delta = current_yaw_ - initial_yaw; // <-- Aggiungi questa riga
        goal_handle->canceled(result);
        return;
      }

      double error = goal->theta - current_yaw_;
      while (error > M_PI) error -= 2.0 * M_PI;
      while (error < -M_PI) error += 2.0 * M_PI;

      if (std::abs(error) < 0.05) {
        break;
      }

      vel_msg.angular.z = (error > 0) ? 0.4 : -0.4;
      cmd_vel_pub_->publish(vel_msg);

      goal_handle->publish_feedback(feedback);
      loop_rate.sleep();
    }

    if (rclcpp::ok()) {
      vel_msg.angular.z = 0.0;
      cmd_vel_pub_->publish(vel_msg);
      result->delta = current_yaw_ - initial_yaw; // <-- Aggiungi questa riga
      goal_handle->succeed(result);
      RCLCPP_INFO(this->get_logger(), "Rotation completed!");
    }
  }
};
}  // namespace bme_gazebo_sensors

RCLCPP_COMPONENTS_REGISTER_NODE(bme_gazebo_sensors::MoveActionServer)
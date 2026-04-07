#include <functional>
#include <memory>
#include <thread>
#include <cmath>

#include "rclcpp/rclcpp.hpp"
#include "rclcpp_action/rclcpp_action.hpp"
#include "rclcpp_components/register_node_macro.hpp"

#include "geometry_msgs/msg/twist.hpp"
#include "nav_msgs/msg/odometry.hpp"
#include "action_tutorials_interfaces_ex/action/move_x.hpp"
// Aggiungiamo l'inclusione per l'azione di turtlesim
#include "turtlesim/action/rotate_absolute.hpp"

namespace bme_gazebo_sensors
{
class MoveXActionServer : public rclcpp::Node
{
public:
  using MoveX = action_tutorials_interfaces_ex::action::MoveX;
  using GoalHandleMoveX = rclcpp_action::ServerGoalHandle<MoveX>;

  using RotateAbsolute = turtlesim::action::RotateAbsolute;
  using GoalHandleRotate = rclcpp_action::ServerGoalHandle<RotateAbsolute>;

  explicit MoveXActionServer(const rclcpp::NodeOptions & options = rclcpp::NodeOptions())
  : Node("move_x_action_server", options), current_x_(0.0), current_yaw_(0.0)
  {
    using namespace std::placeholders;

    // Publisher per muovere il robot
    cmd_vel_pub_ = this->create_publisher<geometry_msgs::msg::Twist>("/cmd_vel", 10);

    // Subscriber per leggere l'odometria
    odom_sub_ = this->create_subscription<nav_msgs::msg::Odometry>(
      "/odom", 10, std::bind(&MoveXActionServer::odom_callback, this, _1));

    // 1. Action Server per il movimento lineare (MoveX)
    action_server_move_ = rclcpp_action::create_server<MoveX>(
      this,
      "move_x",
      std::bind(&MoveXActionServer::handle_move_goal, this, _1, _2),
      std::bind(&MoveXActionServer::handle_move_cancel, this, _1),
      std::bind(&MoveXActionServer::handle_move_accepted, this, _1));

    // 2. Action Server per la rotazione (RotateAbsolute)
    action_server_rotate_ = rclcpp_action::create_server<RotateAbsolute>(
      this,
      "rotate_absolute",  // Puoi chiamarlo "/turtle1/rotate_absolute" se vuoi un match esatto col tuo comando
      std::bind(&MoveXActionServer::handle_rotate_goal, this, _1, _2),
      std::bind(&MoveXActionServer::handle_rotate_cancel, this, _1),
      std::bind(&MoveXActionServer::handle_rotate_accepted, this, _1));
      
    RCLCPP_INFO(this->get_logger(), "MoveX e Rotate Action Server (Component) avviati!");
  }

private:
  rclcpp::Publisher<geometry_msgs::msg::Twist>::SharedPtr cmd_vel_pub_;
  rclcpp::Subscription<nav_msgs::msg::Odometry>::SharedPtr odom_sub_;
  
  rclcpp_action::Server<MoveX>::SharedPtr action_server_move_;
  rclcpp_action::Server<RotateAbsolute>::SharedPtr action_server_rotate_;
  
  double current_x_;
  double current_yaw_;

  void odom_callback(const nav_msgs::msg::Odometry::SharedPtr msg)
  {
    // Aggiorna posizione lineare
    current_x_ = msg->pose.pose.position.x;

    // Estrae e calcola lo Yaw (imbardata) dal quaternione
    double qx = msg->pose.pose.orientation.x;
    double qy = msg->pose.pose.orientation.y;
    double qz = msg->pose.pose.orientation.z;
    double qw = msg->pose.pose.orientation.w;
    
    // Formula standard di conversione da quaternione a angoli di Eulero (Yaw)
    current_yaw_ = std::atan2(2.0 * (qw * qz + qx * qy), 1.0 - 2.0 * (qy * qy + qz * qz));
  }

  // ==========================================
  // METODI PER MOVE_X
  // ==========================================
  rclcpp_action::GoalResponse handle_move_goal(
    const rclcpp_action::GoalUUID & uuid, std::shared_ptr<const MoveX::Goal> goal)
  {
    (void)uuid;
    RCLCPP_INFO(this->get_logger(), "Ricevuta richiesta target_x: %.2f", goal->target_x);
    return rclcpp_action::GoalResponse::ACCEPT_AND_EXECUTE;
  }

  rclcpp_action::CancelResponse handle_move_cancel(const std::shared_ptr<GoalHandleMoveX> goal_handle)
  {
    (void)goal_handle;
    RCLCPP_WARN(this->get_logger(), "Ricevuta richiesta di cancellazione per MoveX!");
    return rclcpp_action::CancelResponse::ACCEPT;
  }

  void handle_move_accepted(const std::shared_ptr<GoalHandleMoveX> goal_handle)
  {
    std::thread{std::bind(&MoveXActionServer::execute_move, this, std::placeholders::_1), goal_handle}.detach();
  }

  void execute_move(const std::shared_ptr<GoalHandleMoveX> goal_handle)
  {
    rclcpp::Rate loop_rate(10);
    const auto goal = goal_handle->get_goal();
    auto feedback = std::make_shared<MoveX::Feedback>();
    auto result = std::make_shared<MoveX::Result>();
    auto vel_msg = geometry_msgs::msg::Twist();

    while (std::abs(goal->target_x - current_x_) > 0.1 && rclcpp::ok()) {
      if (goal_handle->is_canceling()) {
        vel_msg.linear.x = 0.0;
        cmd_vel_pub_->publish(vel_msg);
        result->final_x = current_x_;
        goal_handle->canceled(result);
        return;
      }

      vel_msg.linear.x = (current_x_ < goal->target_x) ? 0.3 : -0.3;
      cmd_vel_pub_->publish(vel_msg);
      feedback->current_x = current_x_;
      goal_handle->publish_feedback(feedback);
      loop_rate.sleep();
    }

    if (rclcpp::ok()) {
      vel_msg.linear.x = 0.0;
      cmd_vel_pub_->publish(vel_msg);
      result->final_x = current_x_;
      goal_handle->succeed(result);
      RCLCPP_INFO(this->get_logger(), "MoveX Goal raggiunto!");
    }
  }

  // ==========================================
  // METODI PER ROTATE_ABSOLUTE
  // ==========================================
  rclcpp_action::GoalResponse handle_rotate_goal(
    const rclcpp_action::GoalUUID & uuid, std::shared_ptr<const RotateAbsolute::Goal> goal)
  {
    (void)uuid;
    RCLCPP_INFO(this->get_logger(), "Ricevuta richiesta rotazione theta: %.2f", goal->theta);
    return rclcpp_action::GoalResponse::ACCEPT_AND_EXECUTE;
  }

  rclcpp_action::CancelResponse handle_rotate_cancel(const std::shared_ptr<GoalHandleRotate> goal_handle)
  {
    (void)goal_handle;
    RCLCPP_WARN(this->get_logger(), "Ricevuta richiesta di cancellazione per Rotate!");
    return rclcpp_action::CancelResponse::ACCEPT;
  }

  void handle_rotate_accepted(const std::shared_ptr<GoalHandleRotate> goal_handle)
  {
    std::thread{std::bind(&MoveXActionServer::execute_rotate, this, std::placeholders::_1), goal_handle}.detach();
  }

  void execute_rotate(const std::shared_ptr<GoalHandleRotate> goal_handle)
  {
    rclcpp::Rate loop_rate(10);
    const auto goal = goal_handle->get_goal();
    auto feedback = std::make_shared<RotateAbsolute::Feedback>();
    auto result = std::make_shared<RotateAbsolute::Result>();
    auto vel_msg = geometry_msgs::msg::Twist();

    double initial_yaw = current_yaw_;

    while (rclcpp::ok()) {
      if (goal_handle->is_canceling()) {
        vel_msg.angular.z = 0.0;
        cmd_vel_pub_->publish(vel_msg);
        result->delta = current_yaw_ - initial_yaw;
        goal_handle->canceled(result);
        return;
      }

      // Calcola l'errore e normalizzalo tra -PI e +PI per girare nel senso più breve
      double error = goal->theta - current_yaw_;
      while (error > M_PI) error -= 2.0 * M_PI;
      while (error < -M_PI) error += 2.0 * M_PI;

      // Tolleranza di circa 2.8 gradi (0.05 radianti)
      if (std::abs(error) < 0.05) {
        break;
      }

      // Velocità angolare semplice. Puoi usare anche un controllore P (es: 1.5 * error)
      vel_msg.angular.z = (error > 0) ? 0.4 : -0.4;
      cmd_vel_pub_->publish(vel_msg);

      feedback->remaining = std::abs(error);
      goal_handle->publish_feedback(feedback);
      loop_rate.sleep();
    }

    if (rclcpp::ok()) {
      vel_msg.angular.z = 0.0;
      cmd_vel_pub_->publish(vel_msg);
      result->delta = current_yaw_ - initial_yaw;
      goal_handle->succeed(result);
      RCLCPP_INFO(this->get_logger(), "Rotazione completata!");
    }
  }
};
}  // namespace bme_gazebo_sensors

RCLCPP_COMPONENTS_REGISTER_NODE(bme_gazebo_sensors::MoveXActionServer)
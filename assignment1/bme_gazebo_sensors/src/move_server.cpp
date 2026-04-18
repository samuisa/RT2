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

// --- LIBRERIE TF2 AGGIUNTE ---
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

    // Parametri per i nomi dei frame (cambiali se il tuo robot in Gazebo usa nomi diversi)
    target_frame_ = this->declare_parameter<std::string>("target_frame", "base_footprint");
    source_frame_ = this->declare_parameter<std::string>("source_frame", "odom");

    cmd_vel_pub_ = this->create_publisher<geometry_msgs::msg::Twist>("/cmd_vel", 10);

    // --- INIZIALIZZAZIONE TF2 LISTENER ---
    tf_buffer_ = std::make_unique<tf2_ros::Buffer>(this->get_clock());
    tf_listener_ = std::make_shared<tf2_ros::TransformListener>(*tf_buffer_);

    action_server_move_ = rclcpp_action::create_server<Linear>(
      this, "linear_server",
      std::bind(&MoveActionServer::handle_move_goal, this, _1, _2),
      std::bind(&MoveActionServer::handle_move_cancel, this, _1),
      std::bind(&MoveActionServer::handle_move_accepted, this, _1));

    action_server_rotate_ = rclcpp_action::create_server<Angular>(
      this, "angular_server", 
      std::bind(&MoveActionServer::handle_rotate_goal, this, _1, _2),
      std::bind(&MoveActionServer::handle_rotate_cancel, this, _1),
      std::bind(&MoveActionServer::handle_rotate_accepted, this, _1));
      
    RCLCPP_INFO(this->get_logger(), "Move Server avviato con logica TF2!");
  }

private:
  rclcpp::Publisher<geometry_msgs::msg::Twist>::SharedPtr cmd_vel_pub_;
  rclcpp_action::Server<Linear>::SharedPtr action_server_move_;
  rclcpp_action::Server<Angular>::SharedPtr action_server_rotate_;
  
  // --- VARIABILI TF2 ---
  std::unique_ptr<tf2_ros::Buffer> tf_buffer_;
  std::shared_ptr<tf2_ros::TransformListener> tf_listener_;
  std::string target_frame_;
  std::string source_frame_;
  
  double current_x_;
  double current_y_;
  double current_yaw_;

  // --- NUOVA FUNZIONE: AGGIORNA LA POSA TRAMITE TF2 ---
  bool update_current_pose()
  {
    try {
      // Cerca la trasformata dalla mappa/odom al robot (es. da "odom" a "base_footprint")
      geometry_msgs::msg::TransformStamped t = tf_buffer_->lookupTransform(
        source_frame_, target_frame_, tf2::TimePointZero);

      current_x_ = t.transform.translation.x;
      current_y_ = t.transform.translation.y;

      double qx = t.transform.rotation.x;
      double qy = t.transform.rotation.y;
      double qz = t.transform.rotation.z;
      double qw = t.transform.rotation.w;
      
      current_yaw_ = std::atan2(2.0 * (qw * qz + qx * qy), 1.0 - 2.0 * (qy * qy + qz * qz));
      return true;
    } catch (const tf2::TransformException & ex) {
      RCLCPP_WARN_THROTTLE(this->get_logger(), *this->get_clock(), 2000, 
        "Attesa trasformata TF2 da %s a %s: %s", source_frame_.c_str(), target_frame_.c_str(), ex.what());
      return false;
    }
  }

  // (Le callback Goal, Cancel e Accepted rimangono invariate...)
  rclcpp_action::GoalResponse handle_move_goal(const rclcpp_action::GoalUUID & uuid, std::shared_ptr<const Linear::Goal> goal) { (void)uuid; (void)goal; return rclcpp_action::GoalResponse::ACCEPT_AND_EXECUTE; }  rclcpp_action::CancelResponse handle_move_cancel(const std::shared_ptr<GoalHandleLinear> goal_handle) { (void)goal_handle; return rclcpp_action::CancelResponse::ACCEPT; }
  void handle_move_accepted(const std::shared_ptr<GoalHandleLinear> goal_handle) { std::thread{std::bind(&MoveActionServer::execute_move, this, std::placeholders::_1), goal_handle}.detach(); }

  rclcpp_action::GoalResponse handle_rotate_goal(const rclcpp_action::GoalUUID & uuid, std::shared_ptr<const Angular::Goal> goal) { (void)uuid; (void)goal; return rclcpp_action::GoalResponse::ACCEPT_AND_EXECUTE; }
  rclcpp_action::CancelResponse handle_rotate_cancel(const std::shared_ptr<GoalHandleAngular> goal_handle) { (void)goal_handle; return rclcpp_action::CancelResponse::ACCEPT; }
  void handle_rotate_accepted(const std::shared_ptr<GoalHandleAngular> goal_handle) { std::thread{std::bind(&MoveActionServer::execute_rotate, this, std::placeholders::_1), goal_handle}.detach(); }

  // --- ESECUZIONE MOVIMENTO LINEARE ---
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

      // 1. Aggiorna la posa PRIMA di calcolare l'errore!
      if (!update_current_pose()) {
        loop_rate.sleep();
        continue; // Salta il ciclo se la TF non è pronta
      }

      // 2. Calcoli cinematica
      double distance = std::hypot(goal->x - current_x_, goal->y - current_y_);
      if (distance < 0.1) break;

      double angle_to_goal = std::atan2(goal->y - current_y_, goal->x - current_x_);
      double angle_error = angle_to_goal - current_yaw_;
      
      while (angle_error > M_PI) angle_error -= 2.0 * M_PI;
      while (angle_error < -M_PI) angle_error += 2.0 * M_PI;

      if (std::abs(angle_error) > 0.1) {
        vel_msg.linear.x = 0.0;
        vel_msg.angular.z = (angle_error > 0) ? 0.4 : -0.4;
      } else {
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
      goal_handle->succeed(result);
    }
  }

  // --- ESECUZIONE ROTAZIONE ---
  void execute_rotate(const std::shared_ptr<GoalHandleAngular> goal_handle)
  {
    rclcpp::Rate loop_rate(10);
    const auto goal = goal_handle->get_goal();
    auto feedback = std::make_shared<Angular::Feedback>();
    auto result = std::make_shared<Angular::Result>();
    auto vel_msg = geometry_msgs::msg::Twist();

    // Attendi la prima TF valida per stabilire il punto di partenza
    while (!update_current_pose() && rclcpp::ok()) { loop_rate.sleep(); }
    double initial_yaw = current_yaw_;

    // FIX: Calcoliamo l'angolo target come rotazione RELATIVA all'orientamento iniziale
    double target_yaw = initial_yaw + goal->theta;

    while (rclcpp::ok()) {
      if (goal_handle->is_canceling()) {
        vel_msg.angular.z = 0.0;
        cmd_vel_pub_->publish(vel_msg);
        result->delta = current_yaw_ - initial_yaw;
        goal_handle->canceled(result);
        return;
      }

      // Aggiorna la posa continuamente
      update_current_pose();

      // Calcoliamo l'errore rispetto al nuovo target_yaw calcolato
      double error = target_yaw - current_yaw_;
      
      // Normalizzazione dell'angolo tra -PI e PI
      while (error > M_PI) error -= 2.0 * M_PI;
      while (error < -M_PI) error += 2.0 * M_PI;

      // Tolleranza per considerare la rotazione completata
      if (std::abs(error) < 0.05) break;

      vel_msg.angular.z = (error > 0) ? 0.4 : -0.4;
      cmd_vel_pub_->publish(vel_msg);

      goal_handle->publish_feedback(feedback);
      loop_rate.sleep();
    }

    if (rclcpp::ok()) {
      vel_msg.angular.z = 0.0;
      cmd_vel_pub_->publish(vel_msg);
      result->delta = current_yaw_ - initial_yaw;
      goal_handle->succeed(result);
    }
  }
};
}  // namespace bme_gazebo_sensors

RCLCPP_COMPONENTS_REGISTER_NODE(bme_gazebo_sensors::MoveActionServer)
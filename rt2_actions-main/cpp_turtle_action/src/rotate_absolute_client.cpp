#include <memory>
#include <functional>

#include "rclcpp/rclcpp.hpp"
#include "rclcpp_action/rclcpp_action.hpp"
#include "turtlesim/action/rotate_absolute.hpp"

class RotateAbsoluteClient : public rclcpp::Node
{
public:
  using RotateAbsolute = turtlesim::action::RotateAbsolute;
  using GoalHandleRotateAbsolute = rclcpp_action::ClientGoalHandle<RotateAbsolute>;

  RotateAbsoluteClient()
  : Node("rotate_absolute_client"), cancel_sent_(false)
  {
    action_client_ = rclcpp_action::create_client<RotateAbsolute>(
      this,
      "/turtle1/rotate_absolute");
  }

  void send_goal(double theta)
  {
    if (!action_client_->wait_for_action_server()) {
      RCLCPP_ERROR(this->get_logger(), "Action server not available");
      return;
    }

    cancel_sent_ = false;

    auto goal_msg = RotateAbsolute::Goal();
    goal_msg.theta = theta;

    using namespace std::placeholders;

    rclcpp_action::Client<RotateAbsolute>::SendGoalOptions options;

    options.goal_response_callback =
      std::bind(&RotateAbsoluteClient::goal_response_callback, this, _1);

    options.feedback_callback =
      std::bind(&RotateAbsoluteClient::feedback_callback, this, _1, _2);

    options.result_callback =
      std::bind(&RotateAbsoluteClient::result_callback, this, _1);

    action_client_->async_send_goal(goal_msg, options);
  }

private:
  rclcpp_action::Client<RotateAbsolute>::SharedPtr action_client_;
  GoalHandleRotateAbsolute::SharedPtr goal_handle_;
  bool cancel_sent_;

  void goal_response_callback(GoalHandleRotateAbsolute::SharedPtr goal_handle)
  {
    if (!goal_handle) {
      RCLCPP_INFO(this->get_logger(), "Goal rejected");
      return;
    }

    RCLCPP_INFO(this->get_logger(), "Goal accepted");
    goal_handle_ = goal_handle;
  }

  void feedback_callback(
    GoalHandleRotateAbsolute::SharedPtr,
    const std::shared_ptr<const RotateAbsolute::Feedback> feedback)
  {
    double remaining = feedback->remaining;

    RCLCPP_INFO(this->get_logger(),
                "Feedback: remaining angle = %f",
                remaining);

    if (cancel_sent_ || !goal_handle_) {
      return;
    }

    if (remaining < 1.0 && remaining > -1.0) {
      cancel_sent_ = true;
      RCLCPP_WARN(this->get_logger(),
                  "Remaining angle less than 1.0, cancelling goal...");

      action_client_->async_cancel_goal(goal_handle_);
    }
  }

  void result_callback(const GoalHandleRotateAbsolute::WrappedResult & result)
  {
    RCLCPP_INFO(this->get_logger(),
                "Result status=%d, delta=%f",
                result.code,
                result.result->delta);

    rclcpp::shutdown();
  }
};


int main(int argc, char ** argv)
{
  rclcpp::init(argc, argv);

  auto node = std::make_shared<RotateAbsoluteClient>();
  node->send_goal(3.14);

  rclcpp::spin(node);
  return 0;
}

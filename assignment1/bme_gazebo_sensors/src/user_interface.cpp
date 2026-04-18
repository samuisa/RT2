#include <memory>
#include <string>
#include <iostream>
#include <chrono>
#include <thread>

#include "rclcpp/rclcpp.hpp"
#include "rclcpp_action/rclcpp_action.hpp"
#include "rclcpp_components/register_node_macro.hpp"

#include "action_msg/action/linear.hpp"
#include "action_msg/action/angular.hpp"

using Linear = action_msg::action::Linear;
using Angular = action_msg::action::Angular;
using GoalHandleLinear = rclcpp_action::ClientGoalHandle<Linear>;
using GoalHandleAngular = rclcpp_action::ClientGoalHandle<Angular>;

namespace bme_gazebo_sensors
{
class UserInterface : public rclcpp::Node {
public:
    explicit UserInterface(const rclcpp::NodeOptions & options = rclcpp::NodeOptions()) 
    : Node("user_interface_node", options), ui_running_(true) {

        setvbuf(stdout, NULL, _IONBF, 0);

        linear_client_ = rclcpp_action::create_client<Linear>(this, "linear_server");
        angular_client_ = rclcpp_action::create_client<Angular>(this, "angular_server");

        // Start the UI loop in a background thread to prevent blocking the component container
        menu_thread_ = std::thread(&UserInterface::run_menu, this);
    }

    ~UserInterface() {
        ui_running_ = false;
        if (menu_thread_.joinable()) {
            menu_thread_.join();
        }
    }

private:
    rclcpp_action::Client<Linear>::SharedPtr linear_client_;
    rclcpp_action::Client<Angular>::SharedPtr angular_client_;
    GoalHandleLinear::SharedPtr linear_goal_handle_;
    GoalHandleAngular::SharedPtr angular_goal_handle_;
    
    std::thread menu_thread_;
    bool ui_running_;

    void run_menu() {
        // Short sleep to let the console settle before printing the menu
        std::this_thread::sleep_for(std::chrono::milliseconds(500));
        
        std::string choice;
        float x, y, theta;

        while (rclcpp::ok() && ui_running_) {
            std::cout << "\n=== ROBOT CONTROL MENU ===\n";
            std::cout << "1. Set new target (X, Y, Theta)\n";
            std::cout << "2. Cancel current target\n";
            std::cout << "3. Rotate only (Relative Theta)\n"; // AGGIUNTA NUOVA OPZIONE
            std::cout << "q. Quit (closes component)\n";
            
            std::cout << "Choice: " << std::flush; 
            
            std::cin >> choice;

            if (choice == "q" || choice == "Q") {
                std::cout << "Exiting UI component...\n";
                rclcpp::shutdown();
                break;
            } else if (choice == "1") {
                std::cout << "Enter X: " << std::flush; std::cin >> x;
                if(x < -10 || x>10) {
                    std::cout << "X must be between -10 and 10. Please try again.\n";
                    continue;
                }
                std::cout << "Enter Y: " << std::flush; std::cin >> y;
                if(y < -10 || y>10) {
                    std::cout << "Y must be between -10 and 10. Please try again.\n";
                    continue;
                }
                std::cout << "Enter Theta (rad): " << std::flush; std::cin >> theta;
                send_target(x, y, theta);
            } else if (choice == "2") {
                cancel_target();
            } else if (choice == "3") {
                // GESTIONE DELLA SOLA ROTAZIONE RELATIVA
                std::cout << "Enter Relative Theta to rotate (rad): " << std::flush; std::cin >> theta;
                send_angular_target(theta);
            } else {
                std::cout << "Invalid choice.\n";
            }
        }
    }

    void send_target(float x, float y, float theta) {
        if (!linear_client_->wait_for_action_server(std::chrono::seconds(2)) ||
            !angular_client_->wait_for_action_server(std::chrono::seconds(2))) {
            RCLCPP_ERROR(this->get_logger(), "Action Servers offline.");
            return;
        }

        RCLCPP_INFO(this->get_logger(), "Inviando Target Lineare -> X: %.2f, Y: %.2f", x, y);

        auto linear_goal = Linear::Goal();
        linear_goal.x = x; 
        linear_goal.y = y;

        auto linear_send_options = rclcpp_action::Client<Linear>::SendGoalOptions();
        linear_send_options.goal_response_callback = [this](const GoalHandleLinear::SharedPtr & goal_handle) {
            if (!goal_handle) RCLCPP_ERROR(this->get_logger(), "Linear goal rejected.");
            else this->linear_goal_handle_ = goal_handle; 
        };
        
        // MODIFICA QUI: Quando finisce l'azione lineare, invia l'azione angolare
        linear_send_options.result_callback = [this, theta](const GoalHandleLinear::WrappedResult & result) {
            (void)result; 
            this->linear_goal_handle_.reset(); 
            RCLCPP_INFO(this->get_logger(), "Movimento lineare completato. Avvio rotazione finale...");
            this->send_angular_target(theta);
        };
        
        linear_client_->async_send_goal(linear_goal, linear_send_options);
    }

    // NUOVO METODO: Invia solo la rotazione
    void send_angular_target(float theta) {
        RCLCPP_INFO(this->get_logger(), "Inviando Target Angolare -> Theta: %.2f", theta);
        
        auto angular_goal = Angular::Goal();
        angular_goal.theta = theta; 

        auto angular_send_options = rclcpp_action::Client<Angular>::SendGoalOptions();
        angular_send_options.goal_response_callback = [this](const GoalHandleAngular::SharedPtr & goal_handle) {
            if (!goal_handle) RCLCPP_ERROR(this->get_logger(), "Angular goal rejected.");
            else this->angular_goal_handle_ = goal_handle; 
        };
        angular_send_options.result_callback = [this](const GoalHandleAngular::WrappedResult & result) {
            (void)result; 
            this->angular_goal_handle_.reset(); 
            RCLCPP_INFO(this->get_logger(), "Azione completata! Il robot ha raggiunto (X, Y, Theta).");
        };
        
        angular_client_->async_send_goal(angular_goal, angular_send_options);
    }

    void cancel_target() {
        bool canceled = false;
        if (linear_goal_handle_) {
            linear_client_->async_cancel_goal(linear_goal_handle_);
            linear_goal_handle_.reset();
            canceled = true;
        }
        if (angular_goal_handle_) {
            angular_client_->async_cancel_goal(angular_goal_handle_);
            angular_goal_handle_.reset();
            canceled = true;
        }
        if (!canceled) {
            RCLCPP_WARN(this->get_logger(), "No active target to cancel.");
        }
    }
};
} // namespace bme_gazebo_sensors

RCLCPP_COMPONENTS_REGISTER_NODE(bme_gazebo_sensors::UserInterface)
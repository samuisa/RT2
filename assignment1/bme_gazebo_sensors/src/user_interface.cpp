#include <memory>
#include <string>
#include <iostream>
#include <chrono>
#include <thread>
#include <atomic> 

#include "rclcpp/rclcpp.hpp"
#include "rclcpp_action/rclcpp_action.hpp"
#include "rclcpp_components/register_node_macro.hpp"

#include "action_msg/action/linear.hpp"
#include "action_msg/action/angular.hpp"

// Aliases for better readability
using Linear = action_msg::action::Linear;
using Angular = action_msg::action::Angular;
using GoalHandleLinear = rclcpp_action::ClientGoalHandle<Linear>;
using GoalHandleAngular = rclcpp_action::ClientGoalHandle<Angular>;

namespace bme_gazebo_sensors
{
class UserInterface : public rclcpp::Node {
public:
    explicit UserInterface(const rclcpp::NodeOptions & options = rclcpp::NodeOptions()) 
    : Node("user_interface_node", options), ui_running_(true), is_moving_(false), canceling_for_new_target_(false) {

        // Disable output buffering for standard output to ensure immediate console printing
        setvbuf(stdout, NULL, _IONBF, 0);

        // Initialize action clients for linear and angular movements
        linear_client_ = rclcpp_action::create_client<Linear>(this, "linear_server");
        angular_client_ = rclcpp_action::create_client<Angular>(this, "angular_server");

        // Launch the User Interface in a separate thread to prevent blocking the ROS 2 executor
        menu_thread_ = std::thread(&UserInterface::run_menu, this);
    }

    ~UserInterface() {
        // Safely shutdown the UI thread when the node is destroyed
        ui_running_ = false;
        if (menu_thread_.joinable()) {
            menu_thread_.join();
        }
    }

private:
    // Action clients
    rclcpp_action::Client<Linear>::SharedPtr linear_client_;
    rclcpp_action::Client<Angular>::SharedPtr angular_client_;
    
    // Handles for tracking the current ongoing goals
    GoalHandleLinear::SharedPtr linear_goal_handle_;
    GoalHandleAngular::SharedPtr angular_goal_handle_;
    
    // UI execution variables
    std::thread menu_thread_;
    bool ui_running_;
    
    // Thread-safe flag to track if the robot is currently executing an action
    std::atomic<bool> is_moving_; 
    std::atomic<bool> canceling_for_new_target_;

    // --- METHOD TO PRINT CONTEXT-AWARE MENU ---
    void print_menu() {
        // Show a different menu depending on the robot's current state
        if (is_moving_) {
            std::cout << "\n=== ACTION IN PROGRESS ===\n";
            std::cout << "1. Set new target (X, Y, Theta)\n";
            std::cout << "c. STOP ALL (Cancel any movement)\n";
            std::cout << "q. Quit (closes component)\n";
        } else {
            std::cout << "\n=== ROBOT CONTROL MENU ===\n";
            std::cout << "1. Set new target (X, Y, Theta)\n";
            std::cout << "q. Quit (closes component)\n";
        }
        std::cout << "Choice: " << std::flush; 
    }

    // --- MAIN UI LOOP ---
    void run_menu() {
        // Small delay to allow ROS 2 logs to print before the first menu appears
        std::this_thread::sleep_for(std::chrono::milliseconds(500));
        
        std::string choice;
        float x, y, theta;

        while (rclcpp::ok() && ui_running_) {
            
            print_menu(); // Print the menu at every iteration
            
            // Blocking wait for user input
            std::cin >> choice;

            // Handle Quit command
            if (choice == "q" || choice == "Q") {
                std::cout << "Exiting UI component...\n";
                rclcpp::shutdown();
                break;
            } 
            // Handle New Target command
            else if (choice == "1") {
                if (is_moving_) {
                    std::cout << "Enter X: " << std::flush; std::cin >> x;
                    if(x < -10 || x > 10) {
                        std::cout << "X must be between -10 and 10. Please try again.\n";
                        continue;
                    }
                    std::cout << "Enter Y: " << std::flush; std::cin >> y;
                    if(y < -10 || y > 10) {
                        std::cout << "Y must be between -10 and 10. Please try again.\n";
                        continue;
                    }
                    std::cout << "Enter Theta (rad): " << std::flush; std::cin >> theta;
                    // If already moving, cancel the current action before sending the new target
                    canceling_for_new_target_ = true; 
                    cancel_target();
                    send_target(x, y, theta);
                } else {
                    std::cout << "Enter X: " << std::flush; std::cin >> x;
                    if(x < -10 || x > 10) {
                        std::cout << "X must be between -10 and 10. Please try again.\n";
                        continue;
                    }
                    std::cout << "Enter Y: " << std::flush; std::cin >> y;
                    if(y < -10 || y > 10) {
                        std::cout << "Y must be between -10 and 10. Please try again.\n";
                        continue;
                    }
                    std::cout << "Enter Theta (rad): " << std::flush; std::cin >> theta;
                    
                    // Send the full target sequence (Linear, then Angular)
                    send_target(x, y, theta);
                }
            } 
            // Handle Stop/Cancel command
            else if (choice == "c" || choice == "C") {
                if (!is_moving_) {
                    std::cout << "No movement in progress to stop.\n";
                } else {
                    canceling_for_new_target_ = false;
                    cancel_target();
                }
            } else {
                std::cout << "Invalid choice.\n";
            }
        }
    }

    // --- SEND LINEAR TARGET ---
    void send_target(float x, float y, float theta) {
        // Ensure action servers are up and running before sending goals
        if (!linear_client_->wait_for_action_server(std::chrono::seconds(2)) ||
            !angular_client_->wait_for_action_server(std::chrono::seconds(2))) {
            RCLCPP_ERROR(this->get_logger(), "Action Servers offline.");
            return;
        }

        // Lock the UI into "moving" state
        is_moving_ = true; 
        RCLCPP_INFO(this->get_logger(), "Sending Linear Target -> X: %.2f, Y: %.2f", x, y);

        // Populate the linear goal message
        auto linear_goal = Linear::Goal();
        linear_goal.x = x; 
        linear_goal.y = y;

        auto linear_send_options = rclcpp_action::Client<Linear>::SendGoalOptions();
        
        // Callback triggered when the server accepts or rejects the goal
        linear_send_options.goal_response_callback = [this](const GoalHandleLinear::SharedPtr & goal_handle) {
            if (!goal_handle) {
                RCLCPP_ERROR(this->get_logger(), "Linear goal rejected.");
                this->is_moving_ = false; // Reset state if rejected
                this->print_menu();       // Reprint the idle menu
            }
            else {
                this->linear_goal_handle_ = goal_handle; // Store handle for potential cancellation
            }
        };
        
        // Callback triggered when the linear movement action is fully completed, failed, or canceled
        linear_send_options.result_callback = [this, theta](const GoalHandleLinear::WrappedResult & result) {
            this->linear_goal_handle_.reset(); // Clear the handle

            if (result.code == rclcpp_action::ResultCode::SUCCEEDED) {
                // If linear movement succeeds, proceed to chain the angular rotation
                this->send_angular_target(theta); 
            } else if (result.code == rclcpp_action::ResultCode::CANCELED) {
                if (this->canceling_for_new_target_) {
                    this->canceling_for_new_target_ = false;
                } else {
                    this->is_moving_ = false; 
                    this->print_menu();
                }
            } else if(result.code == rclcpp_action::ResultCode::ABORTED) {
                RCLCPP_ERROR(this->get_logger(), "Target aborted.");
                this->is_moving_ = false; 
                this->print_menu();
            } else {
                // Handle any other failure types
                this->is_moving_ = false; 
                this->print_menu();
            }
        };
        
        // Send the goal asynchronously
        linear_client_->async_send_goal(linear_goal, linear_send_options);
    }

    // --- SEND ANGULAR TARGET ---
    void send_angular_target(float theta) {
        RCLCPP_INFO(this->get_logger(), "Sending Angular Target -> Theta: %.2f", theta);
        
        // Populate the angular goal message
        auto angular_goal = Angular::Goal();
        angular_goal.theta = theta; 

        auto angular_send_options = rclcpp_action::Client<Angular>::SendGoalOptions();
        
        // Callback triggered when the server accepts or rejects the angular goal
        angular_send_options.goal_response_callback = [this](const GoalHandleAngular::SharedPtr & goal_handle) {
            if (!goal_handle) {
                RCLCPP_ERROR(this->get_logger(), "Angular goal rejected.");
                this->is_moving_ = false;
                this->print_menu();
            }
            else {
                this->angular_goal_handle_ = goal_handle; 
            }
        };
        
        angular_send_options.result_callback = [this](const GoalHandleAngular::WrappedResult & result) {
            this->angular_goal_handle_.reset(); 
            
            if (result.code == rclcpp_action::ResultCode::SUCCEEDED) {
                RCLCPP_INFO(this->get_logger(), "Action completed! The robot has reached (X, Y, Theta).");
                this->is_moving_ = false; 
                this->print_menu();
            } else if (result.code == rclcpp_action::ResultCode::CANCELED) {
                if (this->canceling_for_new_target_) {
                    this->canceling_for_new_target_ = false;
                } else {
                    this->is_moving_ = false; 
                    this->print_menu();
                }
            } else {
                this->is_moving_ = false; 
                this->print_menu();
            }
        };
        
        // Send the goal asynchronously
        angular_client_->async_send_goal(angular_goal, angular_send_options);
    }

    // --- CANCEL ONGOING ACTIONS ---
    void cancel_target() {
        // Send a cancellation request to whichever goal is currently active
        if (linear_goal_handle_) {
            linear_client_->async_cancel_goal(linear_goal_handle_);
        }
        if (angular_goal_handle_) {
            angular_client_->async_cancel_goal(angular_goal_handle_);
        }
    }
};
}

RCLCPP_COMPONENTS_REGISTER_NODE(bme_gazebo_sensors::UserInterface)
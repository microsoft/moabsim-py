###

# MSFT Bonsai 
# Copyright 2021 Microsoft
# This code is licensed under MIT license (see LICENSE for details)

# Moab Tutorial 3
# This sample demonstrates teaching an AI to avoid an obstacle
# while balancing the ball in the center of the plate.
# Obstacles are defined as an x, y coordinate with a radius.

# To understand this Inkling better, please follow our tutorial walkthrough: 
# https://aka.ms/moab/tutorial3

###

inkling "2.0"

using Math
using Goal

# Distances measured in meters
const RadiusOfPlate = 0.1125 # m

# Velocities measured in meters per sec.
const MaxVelocity = 1.0

# Threshold for ball placement
const CloseEnough = 0.02

# Cushion value in avoiding obstacle
const Cushion = 0.01

# Ping-Pong ball constants
const PingPongRadius = 0.020    # m
const PingPongShell = 0.0002    # m

# Obstacle definitions
const ObstacleRadius = 0.01
const ObstacleLocationX = 0.04
const ObstacleLocationY = 0.04

# This is the state received from the simulator
# after each iteration.
type SimState {
    # Ball X,Y position
    ball_x: number<-RadiusOfPlate .. RadiusOfPlate>,
    ball_y: number<-RadiusOfPlate .. RadiusOfPlate>,

    # Ball X,Y velocity
    ball_vel_x: number<-MaxVelocity .. MaxVelocity>,
    ball_vel_y: number<-MaxVelocity .. MaxVelocity>,

    # Obstacle data
    obstacle_direction: number<-Math.Pi .. Math.Pi>,
    obstacle_distance: number<-2.0*RadiusOfPlate .. 2.0*RadiusOfPlate>,
}

# This is the state sent to the brain as it observed
# after each iteration.
type ObservableState {
    # Ball X,Y position
    ball_x: number<-RadiusOfPlate .. RadiusOfPlate>,
    ball_y: number<-RadiusOfPlate .. RadiusOfPlate>,

    # Ball X,Y velocity
    ball_vel_x: number<-MaxVelocity .. MaxVelocity>,
    ball_vel_y: number<-MaxVelocity .. MaxVelocity>,
}

# Action provided as output by policy (and sent as
# input to the simulator)
type SimAction {
    # Range -1 to 1 is a scaled value that represents
    # the full plate rotation range supported by the hardware.
    input_pitch: number<-1 .. 1>, # rotate about x-axis
    input_roll: number<-1 .. 1>, # rotate about y-axis
}

# Per-episode configuration that can be sent to the simulator.
# All iterations within an episode will use the same configuration.
type SimConfig {
    initial_x: number<-RadiusOfPlate .. RadiusOfPlate>,
    initial_y: number<-RadiusOfPlate .. RadiusOfPlate>,

    initial_vel_x: number<-MaxVelocity .. MaxVelocity>,  # in (m/s)
    initial_vel_y: number<-MaxVelocity .. MaxVelocity>,

    # Range -1 to 1 is a scaled value that represents
    # the full plate rotation range supported by the hardware.
    initial_pitch: number<-1 .. 1>,
    initial_roll: number<-1 .. 1>,
    
    # Model configuration
    ball_radius: number,            # Radius of the ball in (m)
    ball_shell: number,             # Shell thickness of ball in (m), shell>0, shell<=radius

    # Obstacle configuration
    obstacle_radius: number<0.0 .. RadiusOfPlate>,
    obstacle_x: number<-RadiusOfPlate .. RadiusOfPlate>,
    obstacle_y: number<-RadiusOfPlate .. RadiusOfPlate>,
}

# Define a concept graph with a single concept
graph (input: ObservableState) {
    concept MoveToCenter(input): SimAction {
        curriculum {
            # The source of training for this concept is a simulator that
            #  - can be configured for each episode using fields defined in SimConfig,
            #  - accepts per-iteration actions defined in SimAction, and
            #  - outputs states with the fields defined in SimState.
            source simulator MoabSim (Action: SimAction, Config: SimConfig): SimState {
            }

            # The objective of training is expressed as a goal with three
            # subgoals: don't let the ball fall off the plate, drive
            # the ball to the center of the plate, and avoid obstacle
            goal (State: SimState) {
                avoid FallOffPlate:
                    Math.Hypot(State.ball_x, State.ball_y) in Goal.RangeAbove(RadiusOfPlate * 0.9)
                drive CenterOfPlate:
                    [State.ball_x, State.ball_y] in Goal.Sphere([0, 0], CloseEnough)
                avoid HitObstacle: 
                    State.obstacle_distance in Goal.RangeBelow(Cushion)
            }

			training {
                # Limit episodes to 250 iterations instead of the default 1000.
                EpisodeIterationLimit: 250
            }

            lesson `Balance with Constraint` {
                # Specify the configuration parameters that should be varied
                # from one episode to the next during this lesson.
                scenario {
                    # Configure the initial positions within a reasonable effective radius 
                    initial_x: number<-RadiusOfPlate * 0.6 .. RadiusOfPlate * 0.6>,
                    initial_y: number<-RadiusOfPlate * 0.6 .. RadiusOfPlate * 0.6>,

                    # Configure the initial velocities of the ball
                    initial_vel_x: number<-MaxVelocity * 0.4 .. MaxVelocity * 0.4>,
                    initial_vel_y: number<-MaxVelocity * 0.4 .. MaxVelocity * 0.4>,

                    # Configure the initial plate angles
                    initial_pitch: number<-0.2 .. 0.2>,
                    initial_roll: number<-0.2 .. 0.2>,
                    
                    # Domain randomize the ping pong ball parameters
                    ball_radius: number<PingPongRadius * 0.8 .. PingPongRadius * 1.2>,
                    ball_shell: number<PingPongShell * 0.8 .. PingPongShell * 1.2>,
                    
                    # Configure obstacle parameters
                    obstacle_radius: ObstacleRadius,
                    obstacle_x: ObstacleLocationX,
                    obstacle_y: ObstacleLocationY,
                    
                }
            }
        }
    }
}

# Special string to hook up the simulator visualizer
# in the web interface.
const SimulatorVisualizer = "/moabviz/"
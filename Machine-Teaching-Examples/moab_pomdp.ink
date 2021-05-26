###

# MSFT Bonsai 
# Copyright 2021 Microsoft
# This code is licensed under MIT license (see LICENSE for details)

# Sample illustrating how brain memory helps solve partially observable 
# problems, where the available sensor information does not provide enough 
# information to control the system. The system learns to control the actions
# based on the history of the system dynamics.

# Note: This sample includes only the ball position in the observable state, 
# removing velocity. This is for illustration, and not recommended in real 
# problems: if there is information that you know is helpful for solving the 
# problem, like ball velocity for balancing a ball on a plate, include them! 
# Memory helps capture other history-dependent features that are difficulty 
# to explicitly define.

###

inkling "2.0"

using Math
using Goal

# Distances measured in meters
const RadiusOfPlate = 0.1125 # m

# Velocities measured in meters per sec.
const MaxVelocity = 6.0
const MaxInitialVelocity = 1.0

# Threshold for ball placement
const CloseEnough = 0.02

# Default time delta between simulation steps (s)
const DefaultTimeDelta = 0.045

# Maximum distance per step in meters
const MaxDistancePerStep = DefaultTimeDelta * MaxVelocity

# State received from the simulator after each iteration
type SimState {
    # Ball X,Y position
    ball_x: number<-MaxDistancePerStep - RadiusOfPlate .. RadiusOfPlate + MaxDistancePerStep>,
    ball_y: number<-MaxDistancePerStep - RadiusOfPlate .. RadiusOfPlate + MaxDistancePerStep>,

    # Ball X,Y velocity
    ball_vel_x: number<-MaxVelocity .. MaxVelocity>,
    ball_vel_y: number<-MaxVelocity .. MaxVelocity>,
}

# Deliberately remove ball velocity from the state passed to the brain, and 
# give it only the ball position. This turns this problem into a Partially 
# Observable Markov Decision Process (POMDP)
type ObservableState {
    # Ball X,Y position
    ball_x: number<-MaxDistancePerStep - RadiusOfPlate .. RadiusOfPlate + MaxDistancePerStep>,
    ball_y: number<-MaxDistancePerStep - RadiusOfPlate .. RadiusOfPlate + MaxDistancePerStep>,
}

# Action provided as output by policy and sent as
# input to the simulator
type SimAction {
    # Range -1 to 1 is a scaled value that represents
    # the full plate rotation range supported by the hardware.
    input_pitch: number<-1 .. 1>, # rotate about x-axis
    input_roll: number<-1 .. 1>, # rotate about y-axis
}

# Per-episode configuration that can be sent to the simulator.
# All iterations within an episode will use the same configuration.
type SimConfig {
    # Model initial ball conditions
    initial_x: number<-RadiusOfPlate .. RadiusOfPlate>, # in (m)
    initial_y: number<-RadiusOfPlate .. RadiusOfPlate>,

    # Model initial ball velocity conditions
    initial_vel_x: number<-MaxInitialVelocity .. MaxInitialVelocity>, # in (m/s)
    initial_vel_y: number<-MaxInitialVelocity .. MaxInitialVelocity>,

    # Range -1 to 1 is a scaled value that represents
    # the full plate rotation range supported by the hardware.
    initial_pitch: number<-1 .. 1>,
    initial_roll: number<-1 .. 1>,
}

# Define a concept graph with a single concept
graph (input: ObservableState) {
    concept MoveToCenter(input): SimAction {
        curriculum {
            # The source of training for this concept is a simulator that
            #  - can be configured for each episode using fields defined in SimConfig,
            #  - accepts per-iteration actions defined in SimAction, and
            #  - outputs states with the fields defined in SimState.
            source simulator MoabSim(Action: SimAction, Config: SimConfig): SimState {
                # Automatically launch the simulator with this
                # registered package name.
                package "Moab"
            }

            training {
                # Limit episodes to 250 iterations instead of the default 1000.
                EpisodeIterationLimit: 250
            }

            algorithm {
                # Use supported values:
                # default - AI engine will choose automatically
                # none - no memory, learned actions depend on current state
                # state - memory of past states
                # state and action - memory of past states and actions.
                MemoryMode: "state and action"
            }

            # The objective of training is expressed as a goal with two
            # subgoals: don't let the ball fall off the plate, and drive
            # the ball to the center of the plate.
            goal (State: SimState) {
                avoid `Fall Off Plate`:
                    Math.Hypot(State.ball_x, State.ball_y) in Goal.RangeAbove(RadiusOfPlate * 0.8)
                drive `Center Of Plate`:
                    [State.ball_x, State.ball_y] in Goal.Sphere([0, 0], CloseEnough)
            }

            lesson `Randomize Start` {
                # Specify the configuration parameters that should be varied
                # from one episode to the next during this lesson.
                scenario {
                    initial_x: number<-RadiusOfPlate * 0.6 .. RadiusOfPlate * 0.6>,
                    initial_y: number<-RadiusOfPlate * 0.6 .. RadiusOfPlate * 0.6>,

                    initial_vel_x: number<-MaxInitialVelocity * 0.2 .. MaxInitialVelocity * 0.2>,
                    initial_vel_y: number<-MaxInitialVelocity * 0.2 .. MaxInitialVelocity * 0.2>,

                    initial_pitch: number<-0.1 .. 0.1>,
                    initial_roll: number<-0.1 .. 0.1>,
                }
            }
        }
    }
}

# Special string to hook up the simulator visualizer
# in the web interface.
const SimulatorVisualizer = "/moabviz/"
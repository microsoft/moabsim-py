###

# MSFT Bonsai 
# Copyright 2021 Microsoft
# This code is licensed under MIT license (see LICENSE for details)

# Moab example demonstrating AI learning a general policy despite noise
# added to the simulated sensors and plate angles. The noise is a gaussian
# with a mean of zero and a sigma of scalar/3

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
    
    # Ball X,Y position
    estimated_x: number<-MaxDistancePerStep - RadiusOfPlate .. RadiusOfPlate + MaxDistancePerStep>,
    estimated_y: number<-MaxDistancePerStep - RadiusOfPlate .. RadiusOfPlate + MaxDistancePerStep>,

    # Ball X,Y velocity
    estimated_vel_x: number<-MaxVelocity .. MaxVelocity>,
    estimated_vel_y: number<-MaxVelocity .. MaxVelocity>,
}

# State to send to the brain with simulated noise
type ObservableState {
    # Ball X,Y position
    estimated_x: number<-MaxDistancePerStep - RadiusOfPlate .. RadiusOfPlate + MaxDistancePerStep>,
    estimated_y: number<-MaxDistancePerStep - RadiusOfPlate .. RadiusOfPlate + MaxDistancePerStep>,

    # Ball X,Y velocity
    estimated_vel_x: number<-MaxVelocity .. MaxVelocity>,
    estimated_vel_y: number<-MaxVelocity .. MaxVelocity>,
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
    initial_x: number<-RadiusOfPlate .. RadiusOfPlate>,     # in (m)
    initial_y: number<-RadiusOfPlate .. RadiusOfPlate>,

    # Model initial ball velocity conditions
    initial_vel_x: number<-MaxInitialVelocity .. MaxInitialVelocity>,  # in (m/s)
    initial_vel_y: number<-MaxInitialVelocity .. MaxInitialVelocity>,

    # Range -1 to 1 is a scaled value that represents
    # the full plate rotation range supported by the hardware.
    initial_pitch: number<-1 .. 1>,
    initial_roll: number<-1 .. 1>,

    # Add sensor noise to the states and actuator noise to the actual plate angles
    ball_noise: number,
    plate_noise: number,
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

            # The objective of training is expressed as a goal with two
            # subgoals: don't let the ball fall off the plate, and drive
            # the ball to the center of the plate.
            goal (State: SimState) {
                avoid `Fall Off Plate`:
                    Math.Hypot(State.ball_x, State.ball_y) in Goal.RangeAbove(RadiusOfPlate * 0.8)
                drive `Center Of Plate`:
                    [State.ball_x, State.ball_y] in Goal.Sphere([0, 0], CloseEnough)
            }

            training {
                # Limit episodes to 250 iterations instead of the default 1000.
                EpisodeIterationLimit: 250
            }

            lesson `Randomize Start` {
                # Specify the configuration parameters that should be varied
                # from one episode to the next during this lesson.
                scenario {
                    initial_x: number<-RadiusOfPlate * 0.5 .. RadiusOfPlate * 0.5>,
                    initial_y: number<-RadiusOfPlate * 0.5 .. RadiusOfPlate * 0.5>,

                    initial_vel_x: number<-MaxInitialVelocity * 0.02 .. MaxInitialVelocity * 0.02>,
                    initial_vel_y: number<-MaxInitialVelocity * 0.02 .. MaxInitialVelocity * 0.02>,
                    
                    initial_pitch: number<-0.2 .. 0.2>,
                    initial_roll: number<-0.2 .. 0.2>,

                    ball_noise: 0.010,
                    plate_noise: 0.017,
                }
            }
        }
    }
}

# Special string to hook up the simulator visualizer
# in the web interface.
const SimulatorVisualizer = "/moabviz/"
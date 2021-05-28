###

# MSFT Bonsai 
# Copyright 2021 Microsoft
# This code is licensed under MIT license (see LICENSE for details)

# Moab sample illustrating how to import a pre-trained neural network
# model in a Bonsai brain. Use the Jupyter notebook to
# create a dummy deep state transform model in either Tensorflow v1.15.2 
# SavedModelBuilder or ONNX format.

# Use the bonsai-cli to import the model to the bonsai service:

# bonsai imported model create
#   --name <ml-model-name>
#   --modelfilepath <model>
#   --description "state transform NN"
#   --display-name <ml-model-name>

# Where: <model> might be state_transform_deep.zip or state_transform_deep.onnx

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

type ObservableState {
    # Ball X,Y position
    ball_x: number<-MaxDistancePerStep - RadiusOfPlate .. RadiusOfPlate + MaxDistancePerStep>,
    ball_y: number<-MaxDistancePerStep - RadiusOfPlate .. RadiusOfPlate + MaxDistancePerStep>,

    # Ball X,Y velocity
    ball_vel_x: number<-MaxVelocity .. MaxVelocity>,
    ball_vel_y: number<-MaxVelocity .. MaxVelocity>,
    
    # Testing added sim observables
    estimated_x: number<-MaxDistancePerStep - RadiusOfPlate .. RadiusOfPlate + MaxDistancePerStep>,
    estimated_y:number<-MaxDistancePerStep - RadiusOfPlate .. RadiusOfPlate + MaxDistancePerStep>,
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
    
    # Add the imported concept by name with the correct type definitions
    # - can only have one input
    # - cannot use image inputs
    # - must have an input state with the same dimesnions as the Inkling object
    #   it maps to
    concept ImportedConcept(input): ObservableState {
        import {Model: "<ml-model-name>"} 
    }

    concept MoveToCenter(ImportedConcept): SimAction {
        curriculum {
            # The source of training for this concept is a simulator that
            #  - can be configured for each episode using fields defined in SimConfig,
            #  - accepts per-iteration actions defined in SimAction, and
            #  - outputs states with the fields defined in SimState.
            source simulator MoabSim(Action: SimAction, Config: SimConfig): ObservableState {
                # Automatically launch the simulator with this
                # registered package name.
                package "Moab"
            }

            training {
                # Limit episodes to 250 iterations instead of the default 1000.
                EpisodeIterationLimit: 250
            }

            # The objective of training is expressed as a goal with two
            # subgoals: don't let the ball fall off the plate, and drive
            # the ball to the center of the plate.
            goal (State: ObservableState) {
                avoid `Fall Off Plate`:
                    Math.Hypot(State.ball_x, State.ball_y)
                    in Goal.RangeAbove(RadiusOfPlate * 0.8)
                drive `Center Of Plate`:
                    [State.ball_x, State.ball_y]
                    in Goal.Sphere([0, 0], CloseEnough)
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
                }
            }
        }
    }
    output MoveToCenter
}

# Special string to hook up the simulator visualizer
# in the web interface.
const SimulatorVisualizer = "/moabviz/"

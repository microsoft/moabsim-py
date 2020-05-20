###

# MSFT Bonsai 
# Copyright 2020 Microsoft

# Moab Experimental 
# This inkling is for exposing additional information for future experiments
# for internal developers trying to improve deployments.
# Traditional rewards and terminal conditions can be used if uncommented.

###

inkling "2.0"

using Math
using Goal

experiment {
    #auto_curriculum: "True",
    success_termination_threshold: "0.90",
    success_termination_window: "150",
    reward_convergence_termination_threshold: "999",
}

# Time constant per step
const DefaultTimeDelta = 0.045   # s

# Ping-Pong ball constants
const PingPongRadius = 0.020    # m
const PingPongShell = 0.0002    # m

# Distances measured in meters
const CloseEnough = 0.02
const RadiusOfPlate = 0.1125 

# Velocities measured in meters per sec.
const MaxVelocity = 1.0
const MaxInitialVelocity = 0.05

# Noise added to the real ball position to create the estimated ball position
const DefaultBallNoise = 0.000    # m

# Noise added to the commanded plate position to create the real plate position
const DefaultPlateNoise = (Math.Pi / 180.0) * 0 # rad

# This is the state received from the simulator
# after each iteration.
type SimState {
    # Reflected control parameters that were passed in
    pitch: number<-1 .. 1>,
    roll: number<-1 .. 1>,

    # Reflected episode config parameters.
    # See SimConfig for descriptions and units.
    time_delta: number,
    plate_theta_vel_limit: number,
    plate_theta_acc: number,
    plate_theta_limit: number,
    ball_noise: number,
    plate_noise: number,

    ball_radius: number,
    ball_shell: number,

    target_x: number<-RadiusOfPlate .. RadiusOfPlate>,
    target_y: number<-RadiusOfPlate .. RadiusOfPlate>,

    # Plate state used for training
    plate_theta_x: number,
    plate_theta_y: number,

    # Ball modelled state used for rendering
    ball_x: number<-RadiusOfPlate .. RadiusOfPlate>,
    ball_y: number<-RadiusOfPlate .. RadiusOfPlate>,

    ball_vel_x: number<-MaxVelocity .. MaxVelocity>,
    ball_vel_y: number<-MaxVelocity .. MaxVelocity>,

    # "Observed" ball position, an emulated estimate of what the camera sees
    estimated_x: number<-RadiusOfPlate .. RadiusOfPlate>,
    estimated_y: number<-RadiusOfPlate .. RadiusOfPlate>,

    estimated_vel_x: number<-MaxVelocity .. MaxVelocity>,
    estimated_vel_y: number<-MaxVelocity .. MaxVelocity>,

    ball_fell_off: number<0, 1,>,
}

# State that represents the input to the policy
type ObservableState {
    # Ball X,Y position, noise applied
    ball_x: number<-RadiusOfPlate .. RadiusOfPlate>,
    ball_y: number<-RadiusOfPlate .. RadiusOfPlate>,

    # Ball X,Y velocity, noise applied
    ball_vel_x: number<-MaxVelocity .. MaxVelocity>,
    ball_vel_y: number<-MaxVelocity .. MaxVelocity>,
}

# Action that represents the output of the policy
type SimAction {
    input_pitch: number<-1 .. 1>,  # scalar over plate rotation about x-axis
    input_roll: number<-1 .. 1>,  # scalar over plate rotation about y-axis
}

# Per-episode configuration that can be sent to the simulator.
# All iterations within an episode will use the same configuration.
type SimConfig {
    # Model configuration
    time_delta: number<0.02 .. 0.05>,       # Simulation step time delta in (s)
    ball_noise: number,             # Noise to add to real ball positions to create estimated positions (mm)
    plate_noise: number,            # Noise, to add to the commanded plate angles to create actual plate angles (rad)

    ball_radius: number,            # Radius of the ball in (m)
    ball_shell: number,             # Shell thickness of ball in (m), shell>0, shell<=radius

    # Goal that the AI could move the ball towards
    target_x: number<-RadiusOfPlate .. RadiusOfPlate>,
    target_y: number<-RadiusOfPlate .. RadiusOfPlate>,

    # Model initial ball conditions
    initial_x: number<-RadiusOfPlate .. RadiusOfPlate>,     # in (m)
    initial_y: number<-RadiusOfPlate .. RadiusOfPlate>,

    # Model initial ball velocity conditions
    initial_vel_x: number<-MaxInitialVelocity .. MaxInitialVelocity>,  # in (m/s)
    initial_vel_y: number<-MaxInitialVelocity .. MaxInitialVelocity>,

    # Model initial plate conditions
    initial_pitch: number<-1 .. 1>,    # scalar over full plate rotation range
    initial_roll: number<-1 .. 1>,    # scalar over full plate rotation range
}

function TransformState(State: SimState): ObservableState {
    # Simulated sensor noise using gaussian
    # and skewing of the ball perception with a rotated plate using ray tracing
    return {
        ball_x: State.ball_x,
        ball_y: State.ball_y,
        ball_vel_x: State.ball_vel_x,
        ball_vel_y: State.ball_vel_y,
    }
}

# Reward function that is evaluated after each iteration
function BalanceBallReward(State: SimState) {
    # Return a negative reward if the ball is off the plate
    # or we have hit the max iteration count for the episode.
    if IsBallOffPlate(State) {
        return -10
    }

    var DistanceToTarget = GetDistanceToTarget(State)
    # Agent is being rewarded based on ground truth state despite noisy sensors
    var Speed = Math.Hypot(State.ball_vel_x, State.ball_vel_y)

    if DistanceToTarget < CloseEnough {
        return 10
    }

    # Shape the reward.
    return CloseEnough / DistanceToTarget * 10
}

# Terminal function that is evaluated after each iteration
function BalanceBallTerminal(State: SimState) {
    # We consider it a terminal condition when the ball
    # has rolled off the plate or we have hit the maximum
    # number of iterations.
    return IsBallOffPlate(State)
}

function IsBallOffPlate(State: SimState) {
    return State.ball_fell_off > 0
}

function GetVectorMagnitude(x: number, y: number) {
    return ((x ** 2) + (y ** 2)) ** 0.5
}

function GetDistanceToTarget(State: SimState) {
    var dx = State.ball_x - State.target_x
    var dy = State.ball_y - State.target_y

    return GetVectorMagnitude(dx, dy)
}

graph (input: ObservableState) {
    concept MoveToTargetLoc(input): SimAction {
        curriculum {
            source simulator (Action: SimAction, Config: SimConfig): SimState {
            }

            # avoid falling off the plate when the perceived position is near edge of tilted plate
            # drive ball to balance in center of plate
            goal (State: SimState) {
                avoid `Fall Off Plate`:
                    Math.Hypot(State.ball_x, State.ball_y) in Goal.RangeAbove(RadiusOfPlate * 0.9)
                drive `Center Of Plate`:
                    [State.ball_x, State.ball_y] in Goal.Sphere([0, 0], CloseEnough)
            }

            # To use reward and terminal functions instead of goals, comment
            # out goal statement above and uncomment the following.
            #reward BalanceBallReward
            #terminal BalanceBallTerminal

            # Specify transform for what info is sent to the AI
            state TransformState

            training {
                # Limit episodes to 250 iterations instead of the default 1000.
                EpisodeIterationLimit: 250,
                #TotalIterationLimit: 700000,
                #LessonSuccessThreshold: 0.90,
           }


            lesson `Lesson 1` {
                scenario {
                    time_delta: DefaultTimeDelta,
                    ball_noise: DefaultBallNoise,
                    plate_noise: DefaultPlateNoise,

                    ball_radius: number<PingPongRadius * 0.80 .. PingPongRadius * 1.20>,
                    ball_shell: PingPongShell,

                    target_x: 0,
                    target_y: 0,

                    initial_x: number<-RadiusOfPlate * 0.636 .. RadiusOfPlate * 0.636>,
                    initial_y: number<-RadiusOfPlate * 0.636 .. RadiusOfPlate * 0.636>,

                    initial_vel_x: number<-0.02 .. 0.02>,
                    initial_vel_y: number<-0.02 .. 0.02>,
                    
                    initial_pitch: number<-0.2 .. 0.2>,
                    initial_roll: number<-0.2 .. 0.2>,
                }
            }
        }
    }
}

# Special string to hook up the simulator visualizer
# in the web interface.
const SimulatorVisualizer = "/moabviz/"
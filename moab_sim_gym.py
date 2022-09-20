"""
Gym Wrapper for the Moab plate+ball balancing device.
Edition on top of moab_model.py
"""
__author__ = "Hossein Kahdivi Heris"
__copyright__ = "Copyright 2022, Microsoft Corp."

# We need to disable a check because the typeshed stubs for jinja are incomplete.
# pyright: strict, reportUnknownMemberType=false

import logging
import math
from typing import Any, Dict 
import gym 
from gym import spaces
import numpy as np 
from moab_model import MoabModel, clamp
from moab_model import PLATE_ORIGIN_TO_SURFACE_OFFSET

log = logging.getLogger(__name__)


class MoabSim(gym.Env):
    def __init__(self):
        super().__init__()
        self.model = MoabModel()
        self._episode_count = 0
        self.model.reset()
        n_obs = 4 # ballx, bally, ball_velx, ball_vely
        n_act = 2 #  pitch, roll 
        # max x = 0.12, max vel = 6 => space max = 10
        self.observation_space = spaces.Box(low = -10, high = 10, shape = (n_obs,))
        self.action_space = spaces.Box(low = -1, high = 1, shape = (n_act,))

    def _set_velocity_for_speed_and_direction(self, speed: float, direction: float):
        # get the heading
        dx = self.model.target_x - self.model.ball.x
        dy = self.model.target_y - self.model.ball.y

        # direction is meaningless if we're already at the target
        if (dx != 0) or (dy != 0):

            # set the magnitude
            vel = vector.set_length([dx, dy, 0.0], speed)

            # rotate by direction around Z-axis at ball position
            rot = matrix33.create_from_axis_rotation([0.0, 0.0, 1.0], direction)
            vel = matrix33.apply_to_vector(rot, vel)

            # unpack into ball velocity
            self.model.ball_vel.x = vel[0]
            self.model.ball_vel.y = vel[1]
            self.model.ball_vel.z = vel[2]

    def reset(self) -> Any:
        # return to known good state to avoid accidental episode-episode dependencies
        self.model.reset()
        # Distances measured in meters
        RadiusOfPlate = 0.1125 
        # Velocities measured in meters per sec.
        MaxVelocity = 6.0
        MaxInitialVelocity = 1.0
        # Threshold for ball placement
        CloseEnough = 0.02
        # Default time delta between simulation steps (s)
        DefaultTimeDelta = 0.045
        # Maximum distance per step in meters
        MaxDistancePerStep = DefaultTimeDelta * MaxVelocity
        # Ping-Pong ball constants
        PingPongRadius = 0.020    # m
        PingPongShell = 0.0002    # m
        config: Dict[str, float] = {
            "initial_x": np.random.uniform(-RadiusOfPlate,RadiusOfPlate),     # in (m)
            "initial_y": np.random.uniform(-RadiusOfPlate,RadiusOfPlate),
            # Model initial ball velocity conditions
            "initial_vel_x": np.random.uniform(-MaxInitialVelocity,MaxInitialVelocity),  # in (m/s)
            "initial_vel_y": np.random.uniform(-MaxInitialVelocity,MaxInitialVelocity),
            # Range -1 to 1 is a scaled value that represents
            # the full plate rotation range supported by the hardware.
            "initial_pitch": np.random.uniform(-1,1),
            "initial_roll": np.random.uniform(-1,1),
            # Model configuration
            "ball_radius": np.random.uniform(PingPongRadius*0.8, PingPongRadius*1.2),            # Radius of the ball in (m)
            "ball_shell": np.random.uniform(PingPongShell*0.8, PingPongShell*1.2),             # Shell thickness of ball in (m), shell>0, shell<=radius
            "EpisodeIterationLimit": 250
        }

        self.EpisodeIterationLimit = config.get("EpisodeIterationLimit", 250)
        # initial control state. these are all [-1..1] unitless
        self.model.roll = config.get("initial_roll", self.model.roll)
        self.model.pitch = config.get("initial_pitch", self.model.pitch)

        self.model.height_z = config.get("initial_height_z", self.model.height_z)

        # constants, SI units.
        self.model.time_delta = config.get("time_delta", self.model.time_delta)
        self.model.jitter = config.get("jitter", self.model.jitter)
        self.model.gravity = config.get("gravity", self.model.gravity)
        self.model.plate_theta_vel_limit = config.get(
            "plate_theta_vel_limit", self.model.plate_theta_vel_limit
        )
        self.model.plate_theta_acc = config.get(
            "plate_theta_acc", self.model.plate_theta_acc
        )
        self.model.plate_theta_limit = config.get(
            "plate_theta_limit", self.model.plate_theta_limit
        )
        self.model.plate_z_limit = config.get("plate_z_limit", self.model.plate_z_limit)

        self.model.ball_mass = config.get("ball_mass", self.model.ball_mass)
        self.model.ball_radius = config.get("ball_radius", self.model.ball_radius)
        self.model.ball_shell = config.get("ball_shell", self.model.ball_shell)

        self.model.obstacle_radius = config.get(
            "obstacle_radius", self.model.obstacle_radius
        )
        self.model.obstacle_x = config.get("obstacle_x", self.model.obstacle_x)
        self.model.obstacle_y = config.get("obstacle_y", self.model.obstacle_y)

        # a target position the AI can try and move the ball to
        self.model.target_x = config.get("target_x", self.model.target_x)
        self.model.target_y = config.get("target_y", self.model.target_y)

        # observation config
        self.model.ball_noise = config.get("ball_noise", self.model.ball_noise)
        self.model.plate_noise = config.get("plate_noise", self.model.plate_noise)

        # now we can update the initial plate metrics from the constants and the controls
        self.model.update_plate(plate_reset=True)

        # initial ball state after updating plate
        self.model.set_initial_ball(
            config.get("initial_x", self.model.ball.x),
            config.get("initial_y", self.model.ball.y),
            config.get("initial_z", self.model.ball.z),
        )

        # velocity set as a vector
        self.model.ball_vel.x = config.get("initial_vel_x", self.model.ball_vel.x)
        self.model.ball_vel.y = config.get("initial_vel_y", self.model.ball_vel.y)
        self.model.ball_vel.z = config.get("initial_vel_z", self.model.ball_vel.z)

        # velocity set as a speed/direction towards target
        initial_speed = config.get("initial_speed", None)
        initial_direction = config.get("initial_direction", None)
        if initial_speed is not None and initial_direction is not None:
            self._set_velocity_for_speed_and_direction(initial_speed, initial_direction)

        # new episode, iteration count reset
        self.iteration_count = 0
        self._episode_count += 1

        return self._get_observation()

    def _get_observation(self):
        state_dict = self.model.state()
        observation = [state_dict["ball_x"], state_dict["ball_y"],
                state_dict["ball_vel_x"], state_dict["ball_vel_y"]]
        return np.array(observation, dtype=np.float32) 
    
    def _get_reward(self) -> float:
        # ball.z relative to plate
        zpos = self.model.ball.z - (
            self.model.plate.z + self.model.ball_radius + PLATE_ORIGIN_TO_SURFACE_OFFSET
        )

        distance_to_center = math.sqrt(
            math.pow(self.model.ball.x, 2.0)
            + math.pow(self.model.ball.y, 2.0)
            + math.pow(zpos, 2.0)
        )
        return -distance_to_center
    
    def _is_terminal(self) -> bool:
        return self.model.halted() or (self.iteration_count>= self.EpisodeIterationLimit)

    def step(self, action: Any) -> Any:
        # use new syntax or fall back to old parameter names
        self.model.roll = action[0]
        self.model.pitch = action[1]

        # clamp inputs to legal ranges
        self.model.roll = clamp(self.model.roll, -1.0, 1.0)
        self.model.pitch = clamp(self.model.pitch, -1.0, 1.0)
        
        # someone to double check below
        # self.model.height_z = clamp(
        #     action.get("input_height_z", self.model.height_z), -1.0, 1.0
        # )
        self.model.step()
        self.iteration_count += 1

        return self._get_observation(), self._get_reward(), self._is_terminal(), {}



if __name__ == "__main__":
    env = MoabSim()
    observation = env.reset()
    for _ in range(1000):
        action = env.action_space.sample()
        print(f'sample action at {env.iteration_count} is {action}')
        observation, reward, terminated, info = env.step(action)
        if terminated:
            print(f'iteration at {env.iteration_count} and terminated')
            observation = env.reset()
            import time
            time.sleep(3)
            
        print(f'iteration at {env.iteration_count} and observation is \n {observation}')
    
    env.close()


# Use case: control type 1a (see Problem Types <insert link here>)
## Use case problem

Control problems are problems where the goal is to find optimal next action to optimize certain objective given constraints for a system in a sequential process. For example, if we consider Moab as a system then the objective is to move the ball to the center of the plate as soon as possible. Constraints are the physical boundaries of the plate, and actions are the pitch and roll angle command that the controller (or brain) needs to take at each time step to optimize the objective. Control problem are the most direct application of reinforcement learning seen in the literature. 

### Business problem

Optimize the HVAC inside of a house according to a desired set temperature.

### Objective

Minimize the deviation of $T_{in}$ (internal temperature of the house) to $T_{set}$ (defined temperature setpoint)

## Problem simulation description

- The model *HouseEnergy* simulates an hvac system in house. Written in `python`.
- Control problem description:

|                        | Definition                                                   | Notes |
| ---------------------- | ------------------------------------------------------------ | ----- |
| Objective              |  Minimize the deviation of $T_{in}$ (internal temperature of the house) to $T_{set}$ (defined temperature setpoint)    |                          |
| Constraints            |   None |
| Observations           | $T_{in}$ (internal temp), $T_{set}$ (defined setpoint), $T_{out}$ (outdoor temperature) | Tout and Tset are predefined in the sim |
| Actions                |  hvacON| discrete value 0 or 1 |
| Control Frequency      | every 5 min | |
| Episode configurations | 288 iterations per episode, episode terminates if $abs(T_{in} - T_{set})$ exceeds 10C, K(thermal conductivity), C(thermal capacity), Qhvac (hvac thermal power), schedule_index (1 or 2, defines the Tset schedule), number_of_days, timestep, Tin_initial | |



## Solution approach

#### High level solution architecture

- The brain is used to directly control hvacON
- We use goals

#### Brain experiment card

|                        | Definition                                                   | Notes |
| ---------------------- | ------------------------------------------------------------ | ----- |
| State                  | Tin, Tset, Tout |       |
| Terminal               |     N/A (using goals)      |       |
| Action                 |                hvacON     |       |
| Reward or Goal         |            `TempDiff(State.Tin, State.Tset) in Goal.RangeBelow(MaxDeviation)                  |    using goals, MaxDeviation = 2   |
| Episode configurations |          single config, no randomization of K,C, etc.                              |       |

### Results
![](./houseenergy-brain.png)
- < Policy vs standard benchmark - missing>








# this is one of the cached base images available for ACI
FROM python:3.7.4

# Install libraries and dependencies
RUN apt-get update && \
  apt-get install -y --no-install-recommends \
  && rm -rf /var/lib/apt/lists/*

# Install SDK3 Python
COPY microsoft-bonsai-api/Python ./microsoft-bonsai-api
COPY sim-common ./sim-common
RUN pip3 install -U setuptools \
  && cd microsoft-bonsai-api \
  && python3 setup.py develop \
  && cd ../sim-common \
  && python3 setup.py develop \
  && pip3 uninstall -y setuptools

# Set up the simulator
WORKDIR /sim

# Copy simulator files to /sim
COPY samples/moabsim-py /sim

# Install simulator dependencies
RUN pip3 install -r requirements.txt

# This will be the command to run the simulator
CMD ["python", "moab_sim.py", "--verbose"]

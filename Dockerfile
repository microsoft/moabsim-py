# this is one of the cached base images available for ACI
FROM python:3.7.4

# Install libraries and dependencies
RUN apt-get update && \
  apt-get install -y --no-install-recommends \
  && rm -rf /var/lib/apt/lists/*

# Pull python packages from internal feed
COPY pip.conf /root/.pip/pip.conf

# Install SDK3 Python
COPY bonsai3-py ./bonsai3-py
RUN pip3 install -U setuptools \
  && cd bonsai3-py \
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

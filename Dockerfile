# this is one of the cached base images available for ACI
FROM python:3.7.4

# Install libraries and dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

# Install dependencies
RUN pip3 install -U setuptools \
    && pip3 install git+https://github.com/microsoft/bonsai-common \
    && pip3 uninstall -y setuptools

# Set up the simulator
WORKDIR /sim

# Copy simulator files to /sim
COPY samples/moabsim-py /sim

# Install simulator dependencies
RUN pip3 install -r requirements.txt

# This will be the command to run the simulator
CMD ["python", "moab_sim.py"]

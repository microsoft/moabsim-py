# this is one of the cached base images available for ACI
FROM python:3.7.4

# Install libraries and dependencies
RUN apt-get update && \
  apt-get install -y --no-install-recommends \
  && rm -rf /var/lib/apt/lists/*

# Pull python packages from internal feed
COPY pip.conf /root/.pip/pip.conf

# Install SDK3 Python
# Microsoft-bonsai-api is required to install bonsai-common. The docker context does not include the entire repo, so we 
# can't copy the diectory. Therefore wheel must be built before attempting to build this DockerFile. 
# Run the build_microsoft_bonsai_api_wheel.sh script prior to building this Dockerfile.
COPY microsoft_bonsai_api*.whl ./
COPY bonsai-common ./bonsai-common
RUN pip3 install -U setuptools \
  && pip3 install microsoft_bonsai_api*.whl \
  && cd bonsai-common \
  && python3 setup.py develop \
  && pip3 uninstall -y setuptools

# Delete wheel
RUN rm microsoft_bonsai_api*.whl

# Set up the simulator
WORKDIR /sim

# Copy simulator files to /sim
COPY samples/moabsim-py /sim

# Install simulator dependencies
RUN pip3 install -r requirements.txt

# This will be the command to run the simulator
CMD ["python", "moab_sim.py"]

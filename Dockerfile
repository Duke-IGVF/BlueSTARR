ARG TENSORFLOW_VERSION=2.15.0-gpu

FROM tensorflow/tensorflow:${TENSORFLOW_VERSION}

RUN apt-get update && apt-get install --no-install-recommends -y git

WORKDIR /bluestarr

COPY requirements.txt .
RUN pip install numpy pandas scikit-learn silence-tensorflow git+https://github.com/Duke-GCB/majoros-python-utils.git
RUN pip install tensorflow==2.15.0 keras-nlp==0.12.1
COPY *.py .

# syntax=docker.io/docker/dockerfile:1@sha256:42399d4635eddd7a9b8a24be879d2f9a930d0ed040a61324cfdf59ef1357b3b2

FROM --platform=$BUILDPLATFORM docker.io/library/alpine@sha256:21a3deaa0d32a8057914f36584b5288d2e5ecc984380bc0118285c70fa8c9300 AS alpine
# TODO: switch to newer ubuntu
FROM --platform=$BUILDPLATFORM docker.io/library/ubuntu:18.04@sha256:c2aa13782650aa7ade424b12008128b60034c795f25456e8eb552d0a0f447cad AS ubuntu

FROM alpine AS mediapipe-src
WORKDIR /w
ARG MEDIAPIPE_COMMIT
RUN set -ux \
 && apk add --no-cache git \
 && git init \
 && git remote add origin https://github.com/google/mediapipe \
 && git fetch --depth 1 origin $MEDIAPIPE_COMMIT \
 && git checkout FETCH_HEAD \
 && rm -rf .git

FROM ubuntu AS base
WORKDIR /mediapipe
ENV DEBIAN_FRONTEND=noninteractive
RUN set -ux \
 && apt update \
 && apt install -y --no-install-recommends \
        build-essential \
        gcc-8 g++-8 \
        ca-certificates \
        curl \
        ffmpeg \
        git \
        wget \
        unzip \
        python3-dev \
        python3-opencv \
        python3-pip \
        libopencv-core-dev \
        libopencv-highgui-dev \
        libopencv-imgproc-dev \
        libopencv-video-dev \
        libopencv-calib3d-dev \
        libopencv-features2d-dev \
        software-properties-common \
 && add-apt-repository -y ppa:openjdk-r/ppa \
 && apt update \
 && apt install -y openjdk-8-jdk
RUN set -ux \
 && update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-8 800 --slave /usr/bin/g++ g++ /usr/bin/g++-8 \
 && update-alternatives --install /usr/bin/python python /usr/bin/python3 1
RUN set -ux \
 && pip3 install --upgrade setuptools \
 && pip3 install wheel \
 && pip3 install future \
 && pip3 install six==1.14.0
ARG BAZEL_VERSION=5.2.0
RUN set -ux \
 && mkdir /bazel \
 && wget --no-check-certificate -O /bazel/installer.sh "https://github.com/bazelbuild/bazel/releases/download/${BAZEL_VERSION}/bazel-${BAZEL_VERSION}-installer-linux-x86_64.sh" \
 && wget --no-check-certificate -O /bazel/LICENSE.txt "https://raw.githubusercontent.com/bazelbuild/bazel/master/LICENSE" \
 && chmod +x /bazel/installer.sh \
 && /bazel/installer.sh \
 && rm /bazel/installer.sh
#full static
# https://github.com/bazelbuild/bazel/issues/8672#issuecomment-505064783
# https://github.com/bazelbuild/bazel/issues/8672#issuecomment-507634776
# https://blog.jessfraz.com/post/top-10-favorite-ldflags/
#  --unresolved-symbols=ignore-all
RUN set -ux \
 && mkdir /x \
 && echo ' --platform_suffix=-cpu' >/bazelflags
### RUN set -ux \
###  #    # Fix for OpenCV v4
###  # && sed -i 's%#include <opencv2/optflow.hpp>%#include <opencv2/video/tracking.hpp>%' mediapipe/framework/port/opencv_video_inc.h \
###     # Use OpenCV v4
###  && sed -i 's%# "include/%"include/%g' third_party/opencv_linux.BUILD

FROM base AS base-cpu
RUN \
  --mount=from=mediapipe-src,source=/w,target=/mediapipe,rw \
  --mount=type=cache,target=/root/.cache/bazel \
    set -ux \
 && bazel build $(cat /bazelflags) \
                -c opt \
                --define MEDIAPIPE_DISABLE_GPU=1 \
                mediapipe/examples/desktop/hello_world:hello_world \
 && cp ./bazel-bin/mediapipe/examples/desktop/hello_world/hello_world /x/hello_world_cpu
RUN \
  --mount=from=mediapipe-src,source=/w,target=/mediapipe,rw \
  --mount=type=cache,target=/root/.cache/bazel \
    set -ux \
 && bazel build $(cat /bazelflags) \
                -c opt \
                --define MEDIAPIPE_DISABLE_GPU=1 \
                //mediapipe/calculators/tflite:tflite_inference_calculator
RUN \
  --mount=from=mediapipe-src,source=/w,target=/mediapipe,rw \
  --mount=type=cache,target=/root/.cache/bazel \
    set -ux \
 && bazel build $(cat /bazelflags) \
                -c opt \
                --define MEDIAPIPE_DISABLE_GPU=1 \
                //mediapipe/calculators/tflite:tflite_converter_calculator
RUN \
  --mount=from=mediapipe-src,source=/w,target=/mediapipe,rw \
  --mount=type=cache,target=/root/.cache/bazel \
    set -ux \
 && bazel build $(cat /bazelflags) \
                -c opt \
                --define MEDIAPIPE_DISABLE_GPU=1 \
                //mediapipe/calculators/tflite:tflite_tensors_to_detections_calculator

FROM scratch AS hello_world_cpu
COPY --from=base-cpu /x/hello_world_cpu /


FROM base AS base-gpu
RUN set -ux \
 && apt install -y --no-install-recommends \
        mesa-common-dev \
        libegl1-mesa-dev \
        libgles2-mesa-dev \
        mesa-utils \
 && echo ' --platform_suffix=-gpu' >/bazelflags
RUN \
  --mount=from=mediapipe-src,source=/w,target=/mediapipe,rw \
  --mount=type=cache,target=/root/.cache/bazel \
    set -ux \
 && bazel build $(cat /bazelflags) \
                -c opt \
                --copt -DMESA_EGL_NO_X11_HEADERS --copt -DEGL_NO_X11 \
                mediapipe/examples/desktop/hello_world:hello_world \
 && cp ./bazel-bin/mediapipe/examples/desktop/hello_world/hello_world /x/hello_world_gpu
RUN \
  --mount=from=mediapipe-src,source=/w,target=/mediapipe,rw \
  --mount=type=cache,target=/root/.cache/bazel \
    set -ux \
 && bazel build $(cat /bazelflags) \
                -c opt \
                --copt -DMESA_EGL_NO_X11_HEADERS --copt -DEGL_NO_X11 \
                //mediapipe/calculators/tflite:tflite_inference_calculator
RUN \
  --mount=from=mediapipe-src,source=/w,target=/mediapipe,rw \
  --mount=type=cache,target=/root/.cache/bazel \
    set -ux \
 && bazel build $(cat /bazelflags) \
                -c opt \
                --copt -DMESA_EGL_NO_X11_HEADERS --copt -DEGL_NO_X11 \
                //mediapipe/calculators/tflite:tflite_converter_calculator
RUN \
  --mount=from=mediapipe-src,source=/w,target=/mediapipe,rw \
  --mount=type=cache,target=/root/.cache/bazel \
    set -ux \
 && bazel build $(cat /bazelflags) \
                -c opt \
                --copt -DMESA_EGL_NO_X11_HEADERS --copt -DEGL_NO_X11 \
                //mediapipe/calculators/tflite:tflite_tensors_to_detections_calculator

FROM scratch AS hello_world_gpu
COPY --from=base-gpu /x/hello_world_gpu /
FROM scratch AS libs
# COPY --from=base-cpu /usr/lib/x86_64-linux-gnu/libopencv_*.so.*.* /
# root@067576c6a3e2:/mediapipe# ldd /y/iris_tracking_gpu | awk '{print $3}' |grep /usr/lib/x86_64-linux-gnu/ | sort -u
COPY --from=base-cpu \
    /usr/lib/x86_64-linux-gnu/libCharLS.so.1 \
    /usr/lib/x86_64-linux-gnu/libEGL.so.1 \
    /usr/lib/x86_64-linux-gnu/libGLdispatch.so.0 \
    /usr/lib/x86_64-linux-gnu/libHalf.so.12 \
    /usr/lib/x86_64-linux-gnu/libIex-2_2.so.12 \
    /usr/lib/x86_64-linux-gnu/libIlmImf-2_2.so.22 \
    /usr/lib/x86_64-linux-gnu/libIlmThread-2_2.so.12 \
    /usr/lib/x86_64-linux-gnu/libX11.so.6 \
    /usr/lib/x86_64-linux-gnu/libXau.so.6 \
    /usr/lib/x86_64-linux-gnu/libXcomposite.so.1 \
    /usr/lib/x86_64-linux-gnu/libXcursor.so.1 \
    /usr/lib/x86_64-linux-gnu/libXdamage.so.1 \
    /usr/lib/x86_64-linux-gnu/libXdmcp.so.6 \
    /usr/lib/x86_64-linux-gnu/libXext.so.6 \
    /usr/lib/x86_64-linux-gnu/libXfixes.so.3 \
    /usr/lib/x86_64-linux-gnu/libXi.so.6 \
    /usr/lib/x86_64-linux-gnu/libXinerama.so.1 \
    /usr/lib/x86_64-linux-gnu/libXrandr.so.2 \
    /usr/lib/x86_64-linux-gnu/libXrender.so.1 \
    /usr/lib/x86_64-linux-gnu/libaec.so.0 \
    /usr/lib/x86_64-linux-gnu/libarpack.so.2 \
    /usr/lib/x86_64-linux-gnu/libasn1.so.8 \
    /usr/lib/x86_64-linux-gnu/libatk-1.0.so.0 \
    /usr/lib/x86_64-linux-gnu/libatk-bridge-2.0.so.0 \
    /usr/lib/x86_64-linux-gnu/libatspi.so.0 \
    /usr/lib/x86_64-linux-gnu/libavcodec.so.57 \
    /usr/lib/x86_64-linux-gnu/libavformat.so.57 \
    /usr/lib/x86_64-linux-gnu/libavutil.so.55 \
    /usr/lib/x86_64-linux-gnu/libblas.so.3 \
    /usr/lib/x86_64-linux-gnu/libbluray.so.2 \
    /usr/lib/x86_64-linux-gnu/libcairo-gobject.so.2 \
    /usr/lib/x86_64-linux-gnu/libcairo.so.2 \
    /usr/lib/x86_64-linux-gnu/libchromaprint.so.1 \
    /usr/lib/x86_64-linux-gnu/libcroco-0.6.so.3 \
    /usr/lib/x86_64-linux-gnu/libcrypto.so.1.1 \
    /usr/lib/x86_64-linux-gnu/libcrystalhd.so.3 \
    /usr/lib/x86_64-linux-gnu/libcurl-gnutls.so.4 \
    /usr/lib/x86_64-linux-gnu/libdap.so.25 \
    /usr/lib/x86_64-linux-gnu/libdapclient.so.6 \
    /usr/lib/x86_64-linux-gnu/libdatrie.so.1 \
    /usr/lib/x86_64-linux-gnu/libdc1394.so.22 \
    /usr/lib/x86_64-linux-gnu/libdrm.so.2 \
    /usr/lib/x86_64-linux-gnu/libepoxy.so.0 \
    /usr/lib/x86_64-linux-gnu/libepsilon.so.1 \
    /usr/lib/x86_64-linux-gnu/libexif.so.12 \
    /usr/lib/x86_64-linux-gnu/libffi.so.6 \
    /usr/lib/x86_64-linux-gnu/libfontconfig.so.1 \
    /usr/lib/x86_64-linux-gnu/libfreetype.so.6 \
    /usr/lib/x86_64-linux-gnu/libfreexl.so.1 \
    /usr/lib/x86_64-linux-gnu/libfyba.so.0 \
    /usr/lib/x86_64-linux-gnu/libfygm.so.0 \
    /usr/lib/x86_64-linux-gnu/libfyut.so.0 \
    /usr/lib/x86_64-linux-gnu/libgdcmCommon.so.2.8 \
    /usr/lib/x86_64-linux-gnu/libgdcmDICT.so.2.8 \
    /usr/lib/x86_64-linux-gnu/libgdcmDSED.so.2.8 \
    /usr/lib/x86_64-linux-gnu/libgdcmIOD.so.2.8 \
    /usr/lib/x86_64-linux-gnu/libgdcmMSFF.so.2.8 \
    /usr/lib/x86_64-linux-gnu/libgdcmjpeg12.so.2.8 \
    /usr/lib/x86_64-linux-gnu/libgdcmjpeg16.so.2.8 \
    /usr/lib/x86_64-linux-gnu/libgdcmjpeg8.so.2.8 \
    /usr/lib/x86_64-linux-gnu/libgdk-3.so.0 \
    /usr/lib/x86_64-linux-gnu/libgdk_pixbuf-2.0.so.0 \
    /usr/lib/x86_64-linux-gnu/libgeos-3.6.2.so \
    /usr/lib/x86_64-linux-gnu/libgeos_c.so.1 \
    /usr/lib/x86_64-linux-gnu/libgeotiff.so.2 \
    /usr/lib/x86_64-linux-gnu/libgfortran.so.4 \
    /usr/lib/x86_64-linux-gnu/libgif.so.7 \
    /usr/lib/x86_64-linux-gnu/libgio-2.0.so.0 \
    /usr/lib/x86_64-linux-gnu/libglib-2.0.so.0 \
    /usr/lib/x86_64-linux-gnu/libgme.so.0 \
    /usr/lib/x86_64-linux-gnu/libgmodule-2.0.so.0 \
    /usr/lib/x86_64-linux-gnu/libgmp.so.10 \
    /usr/lib/x86_64-linux-gnu/libgnutls.so.30 \
    /usr/lib/x86_64-linux-gnu/libgobject-2.0.so.0 \
    /usr/lib/x86_64-linux-gnu/libgomp.so.1 \
    /usr/lib/x86_64-linux-gnu/libgphoto2.so.6 \
    /usr/lib/x86_64-linux-gnu/libgphoto2_port.so.12 \
    /usr/lib/x86_64-linux-gnu/libgraphite2.so.3 \
    /usr/lib/x86_64-linux-gnu/libgsm.so.1 \
    /usr/lib/x86_64-linux-gnu/libgssapi.so.3 \
    /usr/lib/x86_64-linux-gnu/libgssapi_krb5.so.2 \
    /usr/lib/x86_64-linux-gnu/libgtk-3.so.0 \
    /usr/lib/x86_64-linux-gnu/libharfbuzz.so.0 \
    /usr/lib/x86_64-linux-gnu/libhcrypto.so.4 \
    /usr/lib/x86_64-linux-gnu/libhdf5_serial.so.100 \
    /usr/lib/x86_64-linux-gnu/libhdf5_serial_hl.so.100 \
    /usr/lib/x86_64-linux-gnu/libheimbase.so.1 \
    /usr/lib/x86_64-linux-gnu/libheimntlm.so.0 \
    /usr/lib/x86_64-linux-gnu/libhogweed.so.4 \
    /usr/lib/x86_64-linux-gnu/libhx509.so.5 \
    /usr/lib/x86_64-linux-gnu/libicudata.so.60 \
    /usr/lib/x86_64-linux-gnu/libicuuc.so.60 \
    /usr/lib/x86_64-linux-gnu/libidn2.so.0 \
    /usr/lib/x86_64-linux-gnu/libjbig.so.0 \
    /usr/lib/x86_64-linux-gnu/libjpeg.so.8 \
    /usr/lib/x86_64-linux-gnu/libk5crypto.so.3 \
    /usr/lib/x86_64-linux-gnu/libkmlbase.so.1 \
    /usr/lib/x86_64-linux-gnu/libkmldom.so.1 \
    /usr/lib/x86_64-linux-gnu/libkmlengine.so.1 \
    /usr/lib/x86_64-linux-gnu/libkrb5.so.26 \
    /usr/lib/x86_64-linux-gnu/libkrb5.so.3 \
    /usr/lib/x86_64-linux-gnu/libkrb5support.so.0 \
    /usr/lib/x86_64-linux-gnu/liblapack.so.3 \
    /usr/lib/x86_64-linux-gnu/liblber-2.4.so.2 \
    /usr/lib/x86_64-linux-gnu/liblcms2.so.2 \
    /usr/lib/x86_64-linux-gnu/libldap_r-2.4.so.2 \
    /usr/lib/x86_64-linux-gnu/libltdl.so.7 \
    /usr/lib/x86_64-linux-gnu/liblz4.so.1 \
    /usr/lib/x86_64-linux-gnu/libminizip.so.1 \
    /usr/lib/x86_64-linux-gnu/libmp3lame.so.0 \
    /usr/lib/x86_64-linux-gnu/libmpg123.so.0 \
    /usr/lib/x86_64-linux-gnu/libmysqlclient.so.20 \
    /usr/lib/x86_64-linux-gnu/libnetcdf.so.13 \
    /usr/lib/x86_64-linux-gnu/libnettle.so.6 \
    /usr/lib/x86_64-linux-gnu/libnghttp2.so.14 \
    /usr/lib/x86_64-linux-gnu/libnspr4.so \
    /usr/lib/x86_64-linux-gnu/libnss3.so \
    /usr/lib/x86_64-linux-gnu/libnssutil3.so \
    /usr/lib/x86_64-linux-gnu/libnuma.so.1 \
    /usr/lib/x86_64-linux-gnu/libodbc.so.2 \
    /usr/lib/x86_64-linux-gnu/libodbcinst.so.2 \
    /usr/lib/x86_64-linux-gnu/libogg.so.0 \
    /usr/lib/x86_64-linux-gnu/libopencv_calib3d.so.3.2 \
    /usr/lib/x86_64-linux-gnu/libopencv_core.so.3.2 \
    /usr/lib/x86_64-linux-gnu/libopencv_features2d.so.3.2 \
    /usr/lib/x86_64-linux-gnu/libopencv_flann.so.3.2 \
    /usr/lib/x86_64-linux-gnu/libopencv_highgui.so.3.2 \
    /usr/lib/x86_64-linux-gnu/libopencv_imgcodecs.so.3.2 \
    /usr/lib/x86_64-linux-gnu/libopencv_imgproc.so.3.2 \
    /usr/lib/x86_64-linux-gnu/libopencv_video.so.3.2 \
    /usr/lib/x86_64-linux-gnu/libopencv_videoio.so.3.2 \
    /usr/lib/x86_64-linux-gnu/libopenjp2.so.7 \
    /usr/lib/x86_64-linux-gnu/libopenmpt.so.0 \
    /usr/lib/x86_64-linux-gnu/libopus.so.0 \
    /usr/lib/x86_64-linux-gnu/libp11-kit.so.0 \
    /usr/lib/x86_64-linux-gnu/libpango-1.0.so.0 \
    /usr/lib/x86_64-linux-gnu/libpangocairo-1.0.so.0 \
    /usr/lib/x86_64-linux-gnu/libpangoft2-1.0.so.0 \
    /usr/lib/x86_64-linux-gnu/libpixman-1.so.0 \
    /usr/lib/x86_64-linux-gnu/libplc4.so \
    /usr/lib/x86_64-linux-gnu/libplds4.so \
    /usr/lib/x86_64-linux-gnu/libpng16.so.16 \
    /usr/lib/x86_64-linux-gnu/libpoppler.so.73 \
    /usr/lib/x86_64-linux-gnu/libpq.so.5 \
    /usr/lib/x86_64-linux-gnu/libproj.so.12 \
    /usr/lib/x86_64-linux-gnu/libpsl.so.5 \
    /usr/lib/x86_64-linux-gnu/libqhull.so.7 \
    /usr/lib/x86_64-linux-gnu/libquadmath.so.0 \
    /usr/lib/x86_64-linux-gnu/libraw1394.so.11 \
    /usr/lib/x86_64-linux-gnu/libroken.so.18 \
    /usr/lib/x86_64-linux-gnu/librsvg-2.so.2 \
    /usr/lib/x86_64-linux-gnu/librtmp.so.1 \
    /usr/lib/x86_64-linux-gnu/libsasl2.so.2 \
    /usr/lib/x86_64-linux-gnu/libshine.so.3 \
    /usr/lib/x86_64-linux-gnu/libsmime3.so \
    /usr/lib/x86_64-linux-gnu/libsnappy.so.1 \
    /usr/lib/x86_64-linux-gnu/libsoxr.so.0 \
    /usr/lib/x86_64-linux-gnu/libspatialite.so.7 \
    /usr/lib/x86_64-linux-gnu/libspeex.so.1 \
    /usr/lib/x86_64-linux-gnu/libsqlite3.so.0 \
    /usr/lib/x86_64-linux-gnu/libssh-gcrypt.so.4 \
    /usr/lib/x86_64-linux-gnu/libssl.so.1.1 \
    /usr/lib/x86_64-linux-gnu/libstdc++.so.6 \
    /usr/lib/x86_64-linux-gnu/libsuperlu.so.5 \
    /usr/lib/x86_64-linux-gnu/libswresample.so.2 \
    /usr/lib/x86_64-linux-gnu/libswscale.so.4 \
    /usr/lib/x86_64-linux-gnu/libsz.so.2 \
    /usr/lib/x86_64-linux-gnu/libtasn1.so.6 \
    /usr/lib/x86_64-linux-gnu/libtbb.so.2 \
    /usr/lib/x86_64-linux-gnu/libthai.so.0 \
    /usr/lib/x86_64-linux-gnu/libtheoradec.so.1 \
    /usr/lib/x86_64-linux-gnu/libtheoraenc.so.1 \
    /usr/lib/x86_64-linux-gnu/libtiff.so.5 \
    /usr/lib/x86_64-linux-gnu/libtwolame.so.0 \
    /usr/lib/x86_64-linux-gnu/libunistring.so.2 \
    /usr/lib/x86_64-linux-gnu/liburiparser.so.1 \
    /usr/lib/x86_64-linux-gnu/libva-drm.so.2 \
    /usr/lib/x86_64-linux-gnu/libva-x11.so.2 \
    /usr/lib/x86_64-linux-gnu/libva.so.2 \
    /usr/lib/x86_64-linux-gnu/libvdpau.so.1 \
    /usr/lib/x86_64-linux-gnu/libvorbis.so.0 \
    /usr/lib/x86_64-linux-gnu/libvorbisenc.so.2 \
    /usr/lib/x86_64-linux-gnu/libvorbisfile.so.3 \
    /usr/lib/x86_64-linux-gnu/libvpx.so.5 \
    /usr/lib/x86_64-linux-gnu/libwavpack.so.1 \
    /usr/lib/x86_64-linux-gnu/libwayland-client.so.0 \
    /usr/lib/x86_64-linux-gnu/libwayland-cursor.so.0 \
    /usr/lib/x86_64-linux-gnu/libwayland-egl.so.1 \
    /usr/lib/x86_64-linux-gnu/libwebp.so.6 \
    /usr/lib/x86_64-linux-gnu/libwebpmux.so.3 \
    /usr/lib/x86_64-linux-gnu/libwind.so.0 \
    /usr/lib/x86_64-linux-gnu/libx264.so.152 \
    /usr/lib/x86_64-linux-gnu/libx265.so.146 \
    /usr/lib/x86_64-linux-gnu/libxcb-render.so.0 \
    /usr/lib/x86_64-linux-gnu/libxcb-shm.so.0 \
    /usr/lib/x86_64-linux-gnu/libxcb.so.1 \
    /usr/lib/x86_64-linux-gnu/libxerces-c-3.2.so \
    /usr/lib/x86_64-linux-gnu/libxkbcommon.so.0 \
    /usr/lib/x86_64-linux-gnu/libxml2.so.2 \
    /usr/lib/x86_64-linux-gnu/libxvidcore.so.4 \
    /usr/lib/x86_64-linux-gnu/libzvbi.so.0 \
    /
COPY --from=base-cpu \
    /usr/lib/libgdal.so.20 \
    /lib/x86_64-linux-gnu/libjson-c.so.3 \
    /usr/lib/libarmadillo.so.8 \
    /usr/lib/libogdi.so.3.2 \
    /
FROM base-cpu AS builder-selfie_segmentation_cpu
RUN \
  --mount=from=mediapipe-src,source=/w,target=/mediapipe,rw \
  --mount=type=cache,target=/root/.cache/bazel \
    set -ux \
 && bazel build $(cat /bazelflags) \
                -c opt \
                --define MEDIAPIPE_DISABLE_GPU=1 \
                mediapipe/examples/desktop/selfie_segmentation:selfie_segmentation_cpu \
 && cp ./bazel-bin/mediapipe/examples/desktop/selfie_segmentation/selfie_segmentation_cpu /x/

FROM scratch AS selfie_segmentation_cpu
COPY --from=builder-selfie_segmentation_cpu /x/selfie_segmentation_cpu /
FROM base-cpu AS builder-object_detection_cpu
RUN \
  --mount=from=mediapipe-src,source=/w,target=/mediapipe,rw \
  --mount=type=cache,target=/root/.cache/bazel \
    set -ux \
 && bazel build $(cat /bazelflags) \
                -c opt \
                --define MEDIAPIPE_DISABLE_GPU=1 \
                mediapipe/examples/desktop/object_detection:object_detection_cpu \
 && cp ./bazel-bin/mediapipe/examples/desktop/object_detection/object_detection_cpu /x/

FROM scratch AS object_detection_cpu
COPY --from=builder-object_detection_cpu /x/object_detection_cpu /
FROM base-cpu AS builder-holistic_tracking_cpu
RUN \
  --mount=from=mediapipe-src,source=/w,target=/mediapipe,rw \
  --mount=type=cache,target=/root/.cache/bazel \
    set -ux \
 && bazel build $(cat /bazelflags) \
                -c opt \
                --define MEDIAPIPE_DISABLE_GPU=1 \
                mediapipe/examples/desktop/holistic_tracking:holistic_tracking_cpu \
 && cp ./bazel-bin/mediapipe/examples/desktop/holistic_tracking/holistic_tracking_cpu /x/

FROM scratch AS holistic_tracking_cpu
COPY --from=builder-holistic_tracking_cpu /x/holistic_tracking_cpu /
FROM base-cpu AS builder-hair_segmentation_cpu
RUN \
  --mount=from=mediapipe-src,source=/w,target=/mediapipe,rw \
  --mount=type=cache,target=/root/.cache/bazel \
    set -ux \
 && bazel build $(cat /bazelflags) \
                -c opt \
                --define MEDIAPIPE_DISABLE_GPU=1 \
                mediapipe/examples/desktop/hair_segmentation:hair_segmentation_cpu \
 && cp ./bazel-bin/mediapipe/examples/desktop/hair_segmentation/hair_segmentation_cpu /x/

FROM scratch AS hair_segmentation_cpu
COPY --from=builder-hair_segmentation_cpu /x/hair_segmentation_cpu /
FROM base-cpu AS builder-face_detection_cpu
RUN \
  --mount=from=mediapipe-src,source=/w,target=/mediapipe,rw \
  --mount=type=cache,target=/root/.cache/bazel \
    set -ux \
 && bazel build $(cat /bazelflags) \
                -c opt \
                --define MEDIAPIPE_DISABLE_GPU=1 \
                mediapipe/examples/desktop/face_detection:face_detection_cpu \
 && cp ./bazel-bin/mediapipe/examples/desktop/face_detection/face_detection_cpu /x/

FROM scratch AS face_detection_cpu
COPY --from=builder-face_detection_cpu /x/face_detection_cpu /
FROM base-cpu AS builder-face_mesh_cpu
RUN \
  --mount=from=mediapipe-src,source=/w,target=/mediapipe,rw \
  --mount=type=cache,target=/root/.cache/bazel \
    set -ux \
 && bazel build $(cat /bazelflags) \
                -c opt \
                --define MEDIAPIPE_DISABLE_GPU=1 \
                mediapipe/examples/desktop/face_mesh:face_mesh_cpu \
 && cp ./bazel-bin/mediapipe/examples/desktop/face_mesh/face_mesh_cpu /x/

FROM scratch AS face_mesh_cpu
COPY --from=builder-face_mesh_cpu /x/face_mesh_cpu /
FROM base-cpu AS builder-object_tracking_cpu
RUN \
  --mount=from=mediapipe-src,source=/w,target=/mediapipe,rw \
  --mount=type=cache,target=/root/.cache/bazel \
    set -ux \
 && bazel build $(cat /bazelflags) \
                -c opt \
                --define MEDIAPIPE_DISABLE_GPU=1 \
                mediapipe/examples/desktop/object_tracking:object_tracking_cpu \
 && cp ./bazel-bin/mediapipe/examples/desktop/object_tracking/object_tracking_cpu /x/

FROM scratch AS object_tracking_cpu
COPY --from=builder-object_tracking_cpu /x/object_tracking_cpu /
FROM base-cpu AS builder-iris_tracking_cpu
RUN \
  --mount=from=mediapipe-src,source=/w,target=/mediapipe,rw \
  --mount=type=cache,target=/root/.cache/bazel \
    set -ux \
 && bazel build $(cat /bazelflags) \
                -c opt \
                --define MEDIAPIPE_DISABLE_GPU=1 \
                mediapipe/examples/desktop/iris_tracking:iris_tracking_cpu \
 && cp ./bazel-bin/mediapipe/examples/desktop/iris_tracking/iris_tracking_cpu /x/

FROM scratch AS iris_tracking_cpu
COPY --from=builder-iris_tracking_cpu /x/iris_tracking_cpu /
FROM base-cpu AS builder-pose_tracking_cpu
RUN \
  --mount=from=mediapipe-src,source=/w,target=/mediapipe,rw \
  --mount=type=cache,target=/root/.cache/bazel \
    set -ux \
 && bazel build $(cat /bazelflags) \
                -c opt \
                --define MEDIAPIPE_DISABLE_GPU=1 \
                mediapipe/examples/desktop/pose_tracking:pose_tracking_cpu \
 && cp ./bazel-bin/mediapipe/examples/desktop/pose_tracking/pose_tracking_cpu /x/

FROM scratch AS pose_tracking_cpu
COPY --from=builder-pose_tracking_cpu /x/pose_tracking_cpu /
FROM base-cpu AS builder-hand_tracking_cpu
RUN \
  --mount=from=mediapipe-src,source=/w,target=/mediapipe,rw \
  --mount=type=cache,target=/root/.cache/bazel \
    set -ux \
 && bazel build $(cat /bazelflags) \
                -c opt \
                --define MEDIAPIPE_DISABLE_GPU=1 \
                mediapipe/examples/desktop/hand_tracking:hand_tracking_cpu \
 && cp ./bazel-bin/mediapipe/examples/desktop/hand_tracking/hand_tracking_cpu /x/

FROM scratch AS hand_tracking_cpu
COPY --from=builder-hand_tracking_cpu /x/hand_tracking_cpu /
FROM base-gpu AS builder-holistic_tracking_gpu
RUN \
  --mount=from=mediapipe-src,source=/w,target=/mediapipe,rw \
  --mount=type=cache,target=/root/.cache/bazel \
    set -ux \
 && bazel build $(cat /bazelflags) \
                -c opt \
                --copt -DMESA_EGL_NO_X11_HEADERS --copt -DEGL_NO_X11 \
                mediapipe/examples/desktop/holistic_tracking:holistic_tracking_gpu \
 && cp ./bazel-bin/mediapipe/examples/desktop/holistic_tracking/holistic_tracking_gpu /x/

FROM scratch AS holistic_tracking_gpu
COPY --from=builder-holistic_tracking_gpu /x/holistic_tracking_gpu /
FROM base-gpu AS builder-hair_segmentation_gpu
RUN \
  --mount=from=mediapipe-src,source=/w,target=/mediapipe,rw \
  --mount=type=cache,target=/root/.cache/bazel \
    set -ux \
 && bazel build $(cat /bazelflags) \
                -c opt \
                --copt -DMESA_EGL_NO_X11_HEADERS --copt -DEGL_NO_X11 \
                mediapipe/examples/desktop/hair_segmentation:hair_segmentation_gpu \
 && cp ./bazel-bin/mediapipe/examples/desktop/hair_segmentation/hair_segmentation_gpu /x/

FROM scratch AS hair_segmentation_gpu
COPY --from=builder-hair_segmentation_gpu /x/hair_segmentation_gpu /
FROM base-gpu AS builder-object_detection_gpu
RUN \
  --mount=from=mediapipe-src,source=/w,target=/mediapipe,rw \
  --mount=type=cache,target=/root/.cache/bazel \
    set -ux \
 && bazel build $(cat /bazelflags) \
                -c opt \
                --copt -DMESA_EGL_NO_X11_HEADERS --copt -DEGL_NO_X11 \
                mediapipe/examples/desktop/object_detection:object_detection_gpu \
 && cp ./bazel-bin/mediapipe/examples/desktop/object_detection/object_detection_gpu /x/

FROM scratch AS object_detection_gpu
COPY --from=builder-object_detection_gpu /x/object_detection_gpu /
FROM base-gpu AS builder-selfie_segmentation_gpu
RUN \
  --mount=from=mediapipe-src,source=/w,target=/mediapipe,rw \
  --mount=type=cache,target=/root/.cache/bazel \
    set -ux \
 && bazel build $(cat /bazelflags) \
                -c opt \
                --copt -DMESA_EGL_NO_X11_HEADERS --copt -DEGL_NO_X11 \
                mediapipe/examples/desktop/selfie_segmentation:selfie_segmentation_gpu \
 && cp ./bazel-bin/mediapipe/examples/desktop/selfie_segmentation/selfie_segmentation_gpu /x/

FROM scratch AS selfie_segmentation_gpu
COPY --from=builder-selfie_segmentation_gpu /x/selfie_segmentation_gpu /
FROM base-gpu AS builder-iris_tracking_gpu
RUN \
  --mount=from=mediapipe-src,source=/w,target=/mediapipe,rw \
  --mount=type=cache,target=/root/.cache/bazel \
    set -ux \
 && bazel build $(cat /bazelflags) \
                -c opt \
                --copt -DMESA_EGL_NO_X11_HEADERS --copt -DEGL_NO_X11 \
                mediapipe/examples/desktop/iris_tracking:iris_tracking_gpu \
 && cp ./bazel-bin/mediapipe/examples/desktop/iris_tracking/iris_tracking_gpu /x/

FROM scratch AS iris_tracking_gpu
COPY --from=builder-iris_tracking_gpu /x/iris_tracking_gpu /
FROM base-gpu AS builder-pose_tracking_gpu
RUN \
  --mount=from=mediapipe-src,source=/w,target=/mediapipe,rw \
  --mount=type=cache,target=/root/.cache/bazel \
    set -ux \
 && bazel build $(cat /bazelflags) \
                -c opt \
                --copt -DMESA_EGL_NO_X11_HEADERS --copt -DEGL_NO_X11 \
                mediapipe/examples/desktop/pose_tracking:pose_tracking_gpu \
 && cp ./bazel-bin/mediapipe/examples/desktop/pose_tracking/pose_tracking_gpu /x/

FROM scratch AS pose_tracking_gpu
COPY --from=builder-pose_tracking_gpu /x/pose_tracking_gpu /
FROM base-gpu AS builder-hand_tracking_gpu
RUN \
  --mount=from=mediapipe-src,source=/w,target=/mediapipe,rw \
  --mount=type=cache,target=/root/.cache/bazel \
    set -ux \
 && bazel build $(cat /bazelflags) \
                -c opt \
                --copt -DMESA_EGL_NO_X11_HEADERS --copt -DEGL_NO_X11 \
                mediapipe/examples/desktop/hand_tracking:hand_tracking_gpu \
 && cp ./bazel-bin/mediapipe/examples/desktop/hand_tracking/hand_tracking_gpu /x/

FROM scratch AS hand_tracking_gpu
COPY --from=builder-hand_tracking_gpu /x/hand_tracking_gpu /
FROM base-gpu AS builder-object_tracking_gpu
RUN \
  --mount=from=mediapipe-src,source=/w,target=/mediapipe,rw \
  --mount=type=cache,target=/root/.cache/bazel \
    set -ux \
 && bazel build $(cat /bazelflags) \
                -c opt \
                --copt -DMESA_EGL_NO_X11_HEADERS --copt -DEGL_NO_X11 \
                mediapipe/examples/desktop/object_tracking:object_tracking_gpu \
 && cp ./bazel-bin/mediapipe/examples/desktop/object_tracking/object_tracking_gpu /x/

FROM scratch AS object_tracking_gpu
COPY --from=builder-object_tracking_gpu /x/object_tracking_gpu /
FROM base-gpu AS builder-face_detection_gpu
RUN \
  --mount=from=mediapipe-src,source=/w,target=/mediapipe,rw \
  --mount=type=cache,target=/root/.cache/bazel \
    set -ux \
 && bazel build $(cat /bazelflags) \
                -c opt \
                --copt -DMESA_EGL_NO_X11_HEADERS --copt -DEGL_NO_X11 \
                mediapipe/examples/desktop/face_detection:face_detection_gpu \
 && cp ./bazel-bin/mediapipe/examples/desktop/face_detection/face_detection_gpu /x/

FROM scratch AS face_detection_gpu
COPY --from=builder-face_detection_gpu /x/face_detection_gpu /
FROM base-gpu AS builder-face_mesh_gpu
RUN \
  --mount=from=mediapipe-src,source=/w,target=/mediapipe,rw \
  --mount=type=cache,target=/root/.cache/bazel \
    set -ux \
 && bazel build $(cat /bazelflags) \
                -c opt \
                --copt -DMESA_EGL_NO_X11_HEADERS --copt -DEGL_NO_X11 \
                mediapipe/examples/desktop/face_mesh:face_mesh_gpu \
 && cp ./bazel-bin/mediapipe/examples/desktop/face_mesh/face_mesh_gpu /x/

FROM scratch AS face_mesh_gpu
COPY --from=builder-face_mesh_gpu /x/face_mesh_gpu /
